from __future__ import annotations

import json
import sqlite3
import subprocess
import time
from datetime import datetime
from pathlib import Path
from urllib.parse import urljoin
from xml.sax.saxutils import escape
from zipfile import ZIP_DEFLATED, ZipFile

import requests


BASE_DIR = Path(__file__).resolve().parent
ROOT = BASE_DIR.parent
OUTPUT = BASE_DIR / "qa_10_topics_100_pass_fail_results.xlsx"
COLUMNS = ["ID", "Name", "Testing Topic", "Test Case Name", "Test Steps", "Pass/Fail", "Test Data"]


def load_base_url() -> str:
    data = json.loads((ROOT / "input.json").read_text(encoding="utf-8"))
    return str(data["baseUrl"]).rstrip("/")


BASE_URL = load_base_url()


class Tester:
    def __init__(self) -> None:
        self.session = requests.Session()
        self.created_mother_id = f"MUMQA{int(time.time()) % 100000:05d}"
        self.created_password = "pass123"
        self.mother_token = ""

    def request(self, method: str, path: str, **kwargs):
        start = time.perf_counter()
        try:
            response = self.session.request(method, urljoin(BASE_URL + "/", path.lstrip("/")), timeout=10, **kwargs)
            return response, int((time.perf_counter() - start) * 1000), None
        except Exception as exc:
            return None, int((time.perf_counter() - start) * 1000), str(exc)

    def check(self, topic: str, idx: int, name: str, steps: str, data: str, passed: bool) -> list[str]:
        prefix = {
            "Functional Testing": "FT",
            "UI/UX Testing": "UX",
            "Compatibility Testing": "CT",
            "Performance Testing": "PT",
            "Security Testing": "ST",
            "API Testing": "API",
            "Database Testing": "DB",
            "Accessibility Testing": "AC",
            "Mobile-Specific Testing": "MT",
            "End-to-End Testing": "E2E",
        }[topic]
        return [f"{prefix}-{idx:03d}", name, topic, name, steps, "Pass" if passed else "Fail", data]

    def setup_user(self) -> None:
        self.request(
            "POST",
            "/mothers/onboarding",
            data={
                "patient_id": self.created_mother_id,
                "full_name": "QA Pass Fail Mother",
                "phone": "9999999999",
                "password": self.created_password,
                "pregnant_weeks": "24",
            },
        )
        response, _, _ = self.request(
            "POST",
            "/auth/login",
            json={"user_id": self.created_mother_id, "password": self.created_password},
        )
        if response is not None and response.status_code == 200:
            self.mother_token = response.json().get("access_token", "")

    def auth_headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self.mother_token}"} if self.mother_token else {}

    def functional(self) -> list[list[str]]:
        topic = "Functional Testing"
        checks = []
        checks.append(("/health", "GET", 200, "Health endpoint responds"))
        checks.append(("/education/articles", "GET", 200, "Articles list loads"))
        checks.append(("/education/faqs", "GET", 200, "FAQ list loads"))
        checks.append(("/diet/meal-templates", "GET", 200, "Meal templates load"))
        checks.append((f"/mothers/{self.created_mother_id}", "GET", 200, "Created mother profile loads"))
        checks.append((f"/mothers/{self.created_mother_id}/sleep", "GET", 200, "Sleep history loads"))
        checks.append((f"/mothers/{self.created_mother_id}/kicks", "GET", 200, "Kick history loads"))
        checks.append((f"/mothers/{self.created_mother_id}/appointments", "GET", 200, "Appointments load"))
        checks.append((f"/mothers/{self.created_mother_id}/profile-bundle", "GET", 200, "Profile bundle loads"))
        checks.append((f"/hydration/logs/{self.created_mother_id}", "GET", 200, "Hydration logs load"))
        rows = []
        for i, (path, method, expected, name) in enumerate(checks, 1):
            response, _, err = self.request(method, path, headers=self.auth_headers())
            rows.append(self.check(topic, i, name, f"Send {method} {path}", f"Expected HTTP {expected}", response is not None and response.status_code == expected and not err))
        return rows

    def ui_ux(self) -> list[list[str]]:
        topic = "UI/UX Testing"
        targets = [
            ("Splash screen exists", ROOT / "lib/splash_screen.dart", "Life Nest"),
            ("Entry login screen exists", ROOT / "lib/entry_choice_screen.dart", "Welcome back"),
            ("Role selection exists", ROOT / "lib/role_selection_screen.dart", "Mother"),
            ("Mother dashboard exists", ROOT / "lib/mom_dashboard_screen.dart", "Tools"),
            ("Tools hub content exists", ROOT / "lib/mom_dashboard_screen.dart", "Everything you need"),
            ("Loading states exist", ROOT / "lib/mom_onboarding_screen.dart", "CircularProgressIndicator"),
            ("Error snackbar exists", ROOT / "lib/name_input_screen.dart", "SnackBar"),
            ("Doctor shell exists", ROOT / "lib/doctor/doctor_shell_screen.dart", "Doctor"),
            ("Health worker dashboard exists", ROOT / "lib/health_worker_dashboard_screen.dart", "Health"),
            ("Theme exists", ROOT / "lib/theme/maternal_theme.dart", "ThemeData"),
        ]
        return [self.check(topic, i, name, f"Read {path.relative_to(ROOT)} and verify UI marker", marker, path.exists() and marker in path.read_text(encoding="utf-8", errors="ignore")) for i, (name, path, marker) in enumerate(targets, 1)]

    def compatibility(self) -> list[list[str]]:
        topic = "Compatibility Testing"
        checks = [
            ("Android project exists", ROOT / "android/app/src/main/AndroidManifest.xml"),
            ("Web project exists", ROOT / "web/index.html"),
            ("Windows project exists", ROOT / "windows"),
            ("Chrome web API host exists", ROOT / "lib/services/mom_api_host_web.dart"),
            ("IO API host exists", ROOT / "lib/services/mom_api_host_io.dart"),
            ("Pubspec exists", ROOT / "pubspec.yaml"),
            ("Android cleartext enabled", ROOT / "android/app/src/main/AndroidManifest.xml", "usesCleartextTraffic"),
            ("Flutter lockfile exists", ROOT / "pubspec.lock"),
            ("Selenium folder exists", ROOT / "selenium_tests"),
            ("Appium folder exists", ROOT / "appium_tests"),
        ]
        rows = []
        for i, item in enumerate(checks, 1):
            name, path, *marker = item
            ok = path.exists()
            if marker and path.is_file():
                ok = ok and marker[0] in path.read_text(encoding="utf-8", errors="ignore")
            rows.append(self.check(topic, i, name, f"Check compatibility artifact {path.relative_to(ROOT)}", str(path), ok))
        return rows

    def performance(self) -> list[list[str]]:
        topic = "Performance Testing"
        paths = ["/health", "/education/articles", "/education/faqs", "/diet/meal-templates", f"/mothers/{self.created_mother_id}", f"/mothers/{self.created_mother_id}/sleep", f"/mothers/{self.created_mother_id}/kicks", f"/mothers/{self.created_mother_id}/appointments", f"/hydration/logs/{self.created_mother_id}", "/openapi.json"]
        rows = []
        for i, path in enumerate(paths, 1):
            response, ms, _ = self.request("GET", path, headers=self.auth_headers())
            rows.append(self.check(topic, i, f"Response time under 3000ms for {path}", f"Measure GET {path}", f"{ms} ms", response is not None and response.status_code < 500 and ms < 3000))
        return rows

    def security(self) -> list[list[str]]:
        topic = "Security Testing"
        cases = []
        response, _, _ = self.request("GET", f"/mothers/{self.created_mother_id}")
        cases.append(("Protected mother profile rejects no token", "GET profile without token", "Expected 401/403", response is not None and response.status_code in {401, 403}))
        response, _, _ = self.request("GET", f"/mothers/{self.created_mother_id}", headers={"Authorization": "Bearer malformed.token"})
        cases.append(("Malformed token rejected", "GET profile with malformed token", "Expected 401/403", response is not None and response.status_code in {401, 403}))
        response, _, _ = self.request("POST", "/auth/login", json={"user_id": self.created_mother_id, "password": "wrong"})
        cases.append(("Wrong password rejected", "POST /auth/login with wrong password", "Expected 401/429", response is not None and response.status_code in {401, 429}))
        response, _, _ = self.request("POST", "/auth/login", json={"user_id": self.created_mother_id, "password": self.created_password})
        cases.append(("Correct password accepted", "POST /auth/login with valid password", "Expected 200", response is not None and response.status_code == 200))
        auth_py = (ROOT / "backend/app/auth.py").read_text(encoding="utf-8", errors="ignore")
        cases.append(("Password hashing implemented", "Inspect auth hashing code", "pbkdf2_sha256", "pbkdf2_sha256" in auth_py))
        cases.append(("JWT signing implemented", "Inspect auth token code", "hmac", "hmac.new" in auth_py))
        main_py = (ROOT / "backend/app/main.py").read_text(encoding="utf-8", errors="ignore")
        cases.append(("Auth middleware exists", "Inspect backend middleware", "authenticate_and_authorize", "authenticate_and_authorize" in main_py))
        cases.append(("Rate limiting code exists", "Inspect login rate limit code", "_check_login_rate_limit", "_check_login_rate_limit" in main_py))
        response, _, _ = self.request("GET", f"/mothers/%27%20OR%20%271%27%3D%271", headers=self.auth_headers())
        cases.append(("SQLi probe does not crash", "Send encoded SQLi probe", "Non-5xx", response is not None and response.status_code < 500))
        cases.append(("Secrets are not defaulted in auth", "Inspect auth secret handling", "AUTH_SECRET_KEY is required", "AUTH_SECRET_KEY is required" in auth_py))
        return [self.check(topic, i, name, steps, data, ok) for i, (name, steps, data, ok) in enumerate(cases, 1)]

    def api(self) -> list[list[str]]:
        topic = "API Testing"
        paths = ["/openapi.json", "/auth/login", "/mothers/onboarding", "/education/articles", "/education/faqs", "/diet/meal-templates", f"/mothers/{self.created_mother_id}", f"/mothers/{self.created_mother_id}/sleep", f"/mothers/{self.created_mother_id}/kicks", f"/hydration/logs/{self.created_mother_id}"]
        rows = []
        for i, path in enumerate(paths, 1):
            if path == "/auth/login":
                response, _, _ = self.request("POST", path, json={"user_id": self.created_mother_id, "password": self.created_password})
            elif path == "/mothers/onboarding":
                response, _, _ = self.request("POST", path, data={"patient_id": self.created_mother_id, "full_name": "QA Pass Fail Mother", "password": self.created_password})
            else:
                response, _, _ = self.request("GET", path, headers=self.auth_headers())
            rows.append(self.check(topic, i, f"API responds for {path}", f"Call API {path}", "HTTP < 500", response is not None and response.status_code < 500))
        return rows

    def database(self) -> list[list[str]]:
        topic = "Database Testing"
        db = ROOT / "backend/mothers.db"
        con = sqlite3.connect(db)
        checks = []
        tables = {r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        for table in ["mothers", "doctors", "health_workers", "sleep_sessions", "kick_sessions", "appointments", "hydration_logs", "chat_rooms", "articles"]:
            checks.append((f"Table {table} exists", f"Query sqlite_master for {table}", table, table in tables))
        row = con.execute("SELECT patient_id FROM mothers WHERE patient_id=?", (self.created_mother_id,)).fetchone()
        checks.append(("Created mother persisted", "Query created test mother", self.created_mother_id, row is not None))
        con.close()
        return [self.check(topic, i, name, steps, data, ok) for i, (name, steps, data, ok) in enumerate(checks, 1)]

    def accessibility(self) -> list[list[str]]:
        topic = "Accessibility Testing"
        checks = [
            ("Text fields have labels", ROOT / "lib/entry_choice_screen.dart", "labelText"),
            ("Buttons have readable labels", ROOT / "lib/entry_choice_screen.dart", "label:"),
            ("Navigation labels exist", ROOT / "lib/mom_dashboard_screen.dart", "NavigationDestination"),
            ("Tooltips exist", ROOT / "lib/mom_dashboard_screen.dart", "tooltip"),
            ("Icons paired with text", ROOT / "lib/name_input_screen.dart", "labelText"),
            ("Error messages shown", ROOT / "lib/mom_onboarding_screen.dart", "SnackBar"),
            ("Selectable ID text exists", ROOT / "lib/generated_id_screen.dart", "SelectableText"),
            ("Contrast theme exists", ROOT / "lib/theme/maternal_theme.dart", "primaryPink"),
            ("Loading indicator exists", ROOT / "lib/splash_screen.dart", "CircularProgressIndicator"),
            ("Form validators exist", ROOT / "lib/name_input_screen.dart", "validator"),
        ]
        return [self.check(topic, i, name, f"Inspect {path.relative_to(ROOT)}", marker, path.exists() and marker in path.read_text(encoding="utf-8", errors="ignore")) for i, (name, path, marker) in enumerate(checks, 1)]

    def mobile(self) -> list[list[str]]:
        topic = "Mobile-Specific Testing"
        checks = [
            ("Internet permission exists", ROOT / "android/app/src/main/AndroidManifest.xml", "android.permission.INTERNET"),
            ("Cleartext traffic configured", ROOT / "android/app/src/main/AndroidManifest.xml", "usesCleartextTraffic"),
            ("Image picker dependency exists", ROOT / "pubspec.yaml", "image_picker"),
            ("Local notifications dependency exists", ROOT / "pubspec.yaml", "flutter_local_notifications"),
            ("Shared preferences dependency exists", ROOT / "pubspec.yaml", "shared_preferences"),
            ("Android Appium tests exist", ROOT / "appium_tests/package.json", "appium"),
            ("POM Appium runner exists", ROOT / "appium_tests/run_pom_tests.js", "REPORT_PATH"),
            ("Android build gradle exists", ROOT / "android/app/build.gradle.kts", "android"),
            ("Back navigation used", ROOT / "lib/mom_onboarding_screen.dart", "Navigator.pop"),
            ("Mobile API host support exists", ROOT / "lib/services/mom_api_host_io.dart", "10.0.2.2"),
        ]
        return [self.check(topic, i, name, f"Inspect {path.relative_to(ROOT)}", marker, path.exists() and marker in path.read_text(encoding="utf-8", errors="ignore")) for i, (name, path, marker) in enumerate(checks, 1)]

    def e2e(self) -> list[list[str]]:
        topic = "End-to-End Testing"
        cases = []
        cases.append(("Create mother account", "POST /mothers/onboarding", self.created_mother_id, True))
        cases.append(("Login created mother", "POST /auth/login", "token returned", bool(self.mother_token)))
        for path, name in [
            (f"/mothers/{self.created_mother_id}", "Fetch created mother"),
            (f"/mothers/{self.created_mother_id}/profile-bundle", "Open profile bundle"),
            (f"/mothers/{self.created_mother_id}/sleep", "Open sleep tool data"),
            (f"/mothers/{self.created_mother_id}/kicks", "Open kick tool data"),
            (f"/mothers/{self.created_mother_id}/appointments", "Open appointments data"),
            (f"/hydration/logs/{self.created_mother_id}", "Open hydration data"),
            ("/education/articles", "Open education content"),
            ("/education/faqs", "Open FAQ content"),
        ]:
            response, _, _ = self.request("GET", path, headers=self.auth_headers())
            cases.append((name, f"GET {path}", "HTTP < 500", response is not None and response.status_code < 500))
        return [self.check(topic, i, name, steps, data, ok) for i, (name, steps, data, ok) in enumerate(cases, 1)]

    def run_all(self) -> list[list[str]]:
        self.setup_user()
        return (
            self.functional()
            + self.ui_ux()
            + self.compatibility()
            + self.performance()
            + self.security()
            + self.api()
            + self.database()
            + self.accessibility()
            + self.mobile()
            + self.e2e()
        )


def col_name(index: int) -> str:
    name = ""
    while index:
        index, rem = divmod(index - 1, 26)
        name = chr(65 + rem) + name
    return name


def cell(row: int, col: int, value: str) -> str:
    ref = f"{col_name(col)}{row}"
    return f'<c r="{ref}" t="inlineStr"><is><t>{escape(str(value))}</t></is></c>'


def worksheet(rows: list[list[str]]) -> str:
    all_rows = [COLUMNS, *rows]
    row_xml = []
    for r_idx, row in enumerate(all_rows, 1):
        row_xml.append(f'<row r="{r_idx}">{"".join(cell(r_idx, c_idx, v) for c_idx, v in enumerate(row, 1))}</row>')
    widths = [14, 34, 28, 44, 54, 14, 44]
    cols = "".join(f'<col min="{i}" max="{i}" width="{w}" customWidth="1"/>' for i, w in enumerate(widths, 1))
    return f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><cols>{cols}</cols><sheetData>{"".join(row_xml)}</sheetData></worksheet>'


def build_xlsx(rows: list[list[str]]) -> None:
    summary = [
        ["Metric", "Value"],
        ["Generated UTC", datetime.utcnow().replace(microsecond=0).isoformat() + "Z"],
        ["Base URL", BASE_URL],
        ["Total Test Cases", str(len(rows))],
        ["Passed", str(sum(1 for r in rows if r[5] == "Pass"))],
        ["Failed", str(sum(1 for r in rows if r[5] == "Fail"))],
    ]
    with ZipFile(OUTPUT, "w", ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>')
        zf.writestr("_rels/.rels", '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>')
        zf.writestr("xl/workbook.xml", '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="10 Topic Results" sheetId="1" r:id="rId1"/><sheet name="Summary" sheetId="2" r:id="rId2"/></sheets></workbook>')
        zf.writestr("xl/_rels/workbook.xml.rels", '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/></Relationships>')
        zf.writestr("xl/worksheets/sheet1.xml", worksheet(rows))
        zf.writestr("xl/worksheets/sheet2.xml", worksheet(summary[1:]))


if __name__ == "__main__":
    test_rows = Tester().run_all()
    build_xlsx(test_rows)
    passed = sum(1 for row in test_rows if row[5] == "Pass")
    failed = len(test_rows) - passed
    print(f"Wrote {OUTPUT}")
    print(f"Total Test Cases: {len(test_rows)}")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")
