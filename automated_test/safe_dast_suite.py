"""Safe DAST suite for the Life Nest API.

The suite sends requests only to the configured BASE_URL from input.json and
does not execute destructive DELETE/PUT/PATCH probes. Those endpoints are
recorded as skipped so the report is explicit about coverage gaps.
"""

from __future__ import annotations

import base64
import json
import re
import time
from datetime import datetime
from pathlib import Path
from typing import Callable
from urllib.parse import urlparse

import requests

from dast_common import (
    REPORT_PATH,
    SAVEPOINT_PATH,
    base_url,
    discover_routes_from_main,
    filter_discovery_scope,
    load_config,
    route_catalog_as_dicts,
    write_savepoint,
)

WORKSPACE_ROOT = Path(__file__).resolve().parents[1]
BACKEND_DIR = WORKSPACE_ROOT / "backend"

PUBLIC_ENDPOINTS = {
    ("POST", "/auth/login"),
    ("POST", "/mothers/onboarding"),
    ("POST", "/doctors/onboarding"),
    ("POST", "/health-workers/onboarding"),
    ("GET", "/education/articles"),
    ("GET", "/education/articles/{article_id}"),
    ("GET", "/education/faqs"),
    ("GET", "/diet/meal-templates"),
}

SAFE_METHODS = {"GET", "HEAD", "POST"}
DESTRUCTIVE_METHODS = {"DELETE", "PUT", "PATCH"}

SAMPLE_VALUES = {
    "patient_id": "MUM40293",
    "doctor_id": "DOC001",
    "worker_id": "HWN001",
    "health_worker_id": "HWN001",
    "user_id": "MUM40293",
    "user_type": "mother",
    "room_id": "room1",
    "appointment_id": "1",
    "visit_id": "1",
    "article_id": "1",
    "restriction_id": "1",
    "newborn_id": "1",
    "alert_id": "1",
}

OTHER_VALUES = {
    **SAMPLE_VALUES,
    "patient_id": "MUM84202",
    "doctor_id": "DOC03375",
    "user_id": "MUM84202",
}

SQLI_PAYLOADS = [
    "' OR '1'='1",
    "'; SELECT 1; --",
    "' UNION SELECT NULL --",
]


def _now() -> str:
    return datetime.utcnow().isoformat() + "Z"


def _fake_jwt(role: str, subject: str) -> str:
    header = {"alg": "none", "typ": "JWT"}
    payload = {"sub": subject, "role": role, "exp": 4102444800}

    def encode(obj: dict) -> str:
        raw = json.dumps(obj, separators=(",", ":")).encode("utf-8")
        return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")

    return f"Bearer {encode(header)}.{encode(payload)}."


def _token_for(role: str) -> str | None:
    cfg = load_config()
    token = cfg.get(role) or cfg.get(role.replace("-", "_"))
    if not token or token == "NO_TOKEN_REQUIRED":
        if role in {"mother", "doctor", "health_worker"}:
            subject = {"mother": "MUM40293", "doctor": "DOC001", "health_worker": "HWN001"}[role]
            return _fake_jwt(role, subject)
        return None
    return token if token.lower().startswith("bearer ") else f"Bearer {token}"


def _headers(role: str | None = None, malformed: bool = False) -> dict:
    headers = {"Content-Type": "application/json"}
    if malformed:
        headers["Authorization"] = "Bearer malformed.token.value"
    elif role:
        token = _token_for(role)
        if token:
            headers["Authorization"] = token
    return headers


def _route_path(path_template: str, values: dict[str, str] | None = None) -> str:
    values = values or SAMPLE_VALUES
    path = path_template
    for key in re.findall(r"{([^}]+)}", path_template):
        path = path.replace("{" + key + "}", values.get(key, "1"))
    return path


def _expected_access(method: str, path: str) -> str:
    if (method, path) in PUBLIC_ENDPOINTS:
        return "public"
    if path.startswith("/doctor/") or path.startswith("/doctors/"):
        return "doctor"
    if path.startswith("/health-workers/") or path.startswith("/home-visits/"):
        return "health_worker"
    if path.startswith("/mothers/") or "{patient_id}" in path:
        return "mother-own-or-assigned-clinician"
    if path.startswith("/education/articles") and method == "POST":
        return "doctor"
    if path.startswith("/diet/restrictions") or path.startswith("/diet/doctor-summary"):
        return "doctor"
    return "requires-auth"


def _record(
    records: list[dict],
    *,
    route: tuple[str, str] | None = None,
    endpoint: str | None = None,
    method: str | None = None,
    role: str,
    status,
    expected_status,
    finding: bool,
    severity: str,
    response_time_ms: int,
    test_category: str,
    note: str,
) -> None:
    route_method, route_path = route if route else (method, endpoint)
    records.append(
        {
            "endpoint": endpoint or route_path,
            "method": method or route_method,
            "role": role,
            "status": status,
            "expected_status": expected_status,
            "finding": finding,
            "severity": severity,
            "response_time_ms": response_time_ms,
            "test_category": test_category,
            "note": note,
            "timestamp": _now(),
        }
    )


def _request(method: str, path: str, **kwargs):
    base = base_url()
    parsed_base = urlparse(base)
    url = base + path
    parsed_url = urlparse(url)
    if (parsed_url.scheme, parsed_url.netloc) != (parsed_base.scheme, parsed_base.netloc):
        raise RuntimeError(f"Refusing out-of-scope URL: {url}")
    start = time.time()
    try:
        response = requests.request(method, url, timeout=5, allow_redirects=False, **kwargs)
        return response, int((time.time() - start) * 1000)
    except requests.RequestException as exc:
        return exc, int((time.time() - start) * 1000)


def discover_routes():
    routes = filter_discovery_scope(discover_routes_from_main())
    write_savepoint(
        {
            "completed": False,
            "timestamp": _now(),
            "total_tests": 0,
            "routes": route_catalog_as_dicts(routes),
        }
    )
    return routes


def category_authn_bypass(records: list[dict]) -> None:
    for route in discover_routes():
        if (route.method, route.path) in PUBLIC_ENDPOINTS:
            continue
        if route.method in DESTRUCTIVE_METHODS or route.method == "WS":
            _record(
                records,
                route=(route.method, route.path),
                role="none",
                status="SKIPPED",
                expected_status=401,
                finding=False,
                severity="info",
                response_time_ms=0,
                test_category="authn_bypass",
                note="Skipped unsafe or non-HTTP method per scope",
            )
            continue
        path = _route_path(route.path)
        kwargs = {"headers": _headers()}
        if route.method == "POST":
            kwargs["json"] = {}
        response, ms = _request(route.method, path, **kwargs)
        status = getattr(response, "status_code", 0)
        finding = isinstance(status, int) and 200 <= status < 300
        _record(
            records,
            endpoint=path,
            method=route.method,
            role="none",
            status=status,
            expected_status=401,
            finding=finding,
            severity="critical" if finding else "info",
            response_time_ms=ms,
            test_category="authn_bypass",
            note="No auth required" if finding else "Blocked or validation prevented unauthenticated success",
        )


def category_token_tampering(records: list[dict]) -> None:
    protected_gets = [
        r
        for r in discover_routes()
        if r.method == "GET" and (r.method, r.path) not in PUBLIC_ENDPOINTS
    ][:15]
    for route in protected_gets:
        path = _route_path(route.path)
        for role, malformed in (("forged_admin", False), ("malformed", True)):
            headers = _headers("doctor" if not malformed else None, malformed=malformed)
            response, ms = _request("GET", path, headers=headers)
            status = getattr(response, "status_code", 0)
            finding = isinstance(status, int) and 200 <= status < 300
            _record(
                records,
                endpoint=path,
                method="GET",
                role=role,
                status=status,
                expected_status=401,
                finding=finding,
                severity="high" if finding else "info",
                response_time_ms=ms,
                test_category="token_tampering",
                note="Forged/malformed token accepted" if finding else "Token rejected or request blocked",
            )


def category_authz_privesc(records: list[dict]) -> None:
    targets = [
        r
        for r in discover_routes()
        if r.method == "GET" and _expected_access(r.method, r.path) in {"doctor", "health_worker"}
    ]
    for route in targets:
        lower_role = "mother" if _expected_access(route.method, route.path) == "doctor" else "doctor"
        path = _route_path(route.path)
        response, ms = _request("GET", path, headers=_headers(lower_role))
        status = getattr(response, "status_code", 0)
        finding = isinstance(status, int) and 200 <= status < 300
        _record(
            records,
            endpoint=path,
            method="GET",
            role=lower_role,
            status=status,
            expected_status=403,
            finding=finding,
            severity="high" if finding else "info",
            response_time_ms=ms,
            test_category="authz_privesc",
            note="Lower-privilege role accessed restricted endpoint" if finding else "Privilege boundary held",
        )


def category_idor(records: list[dict]) -> None:
    patient_gets = [
        r for r in discover_routes() if r.method == "GET" and "{patient_id}" in r.path
    ]
    for route in patient_gets:
        path = _route_path(route.path, OTHER_VALUES)
        response, ms = _request("GET", path, headers=_headers("mother"))
        status = getattr(response, "status_code", 0)
        finding = isinstance(status, int) and 200 <= status < 300
        _record(
            records,
            endpoint=path,
            method="GET",
            role="mother-as-other-patient",
            status=status,
            expected_status=403,
            finding=finding,
            severity="high" if finding else "info",
            response_time_ms=ms,
            test_category="idor",
            note="Cross-patient object accessible" if finding else "Cross-patient access blocked or object absent",
        )


def category_rbac_matrix(records: list[dict]) -> None:
    role_targets = [
        r
        for r in discover_routes()
        if r.method == "GET" and _expected_access(r.method, r.path) != "public"
    ][:10]
    roles = ["anonymous", "mother", "doctor", "health_worker"]
    for route in role_targets:
        required = _expected_access(route.method, route.path)
        for role in roles:
            if role == "anonymous":
                headers = _headers()
            else:
                headers = _headers(role)
            path = _route_path(route.path)
            response, ms = _request("GET", path, headers=headers)
            status = getattr(response, "status_code", 0)
            allowed = isinstance(status, int) and 200 <= status < 300
            should_block = role == "anonymous" or (
                required in {"doctor", "health_worker"} and role != required
            )
            finding = allowed and should_block
            _record(
                records,
                endpoint=path,
                method="GET",
                role=role,
                status=status,
                expected_status=403 if should_block else 200,
                finding=finding,
                severity="high" if finding else "info",
                response_time_ms=ms,
                test_category="rbac_matrix",
                note=f"Required={required}; role={role}; allowed={allowed}",
            )


def category_injection_probe(records: list[dict]) -> None:
    targets = [
        "/mothers/{patient_id}",
        "/education/articles",
        "/diet/plan/today/{patient_id}",
        "/reports/{patient_id}",
    ]
    for target in targets:
        for payload in SQLI_PAYLOADS:
            if "{patient_id}" in target:
                path = target.replace("{patient_id}", requests.utils.quote(payload, safe=""))
            else:
                path = target + "?q=" + requests.utils.quote(payload, safe="")
            response, ms = _request("GET", path, headers=_headers("mother"))
            status = getattr(response, "status_code", 0)
            finding = status >= 500 or ms > 5000
            _record(
                records,
                endpoint=path,
                method="GET",
                role="probe",
                status=status,
                expected_status="non-5xx",
                finding=finding,
                severity="medium" if finding else "info",
                response_time_ms=ms,
                test_category="injection_probe",
                note="Anomalous error/timing" if finding else "No obvious injection signal",
            )


def category_rate_limiting(records: list[dict]) -> None:
    saw_429 = False
    last_status = None
    total_ms = 0
    for _ in range(30):
        response, ms = _request(
            "POST",
            "/auth/login",
            headers=_headers(),
            json={"user_id": "MUM40293", "password": "wrong-password-for-dast"},
        )
        total_ms += ms
        last_status = getattr(response, "status_code", 0)
        if last_status == 429:
            saw_429 = True
            break
        time.sleep(0.05)
    _record(
        records,
        endpoint="/auth/login",
        method="POST",
        role="burst",
        status=last_status,
        expected_status=429,
        finding=not saw_429,
        severity="medium" if not saw_429 else "info",
        response_time_ms=total_ms,
        test_category="rate_limiting",
        note="No 429 in 30-request burst" if not saw_429 else "Rate limit observed",
    )


def category_hardcoded_creds(records: list[dict]) -> None:
    secret_assignments = [
        re.compile(r"\bGEMINI_API_KEY\s*=\s*['\"]?([^'\"\s#]+)", re.IGNORECASE),
        re.compile(r"\b(?:AUTH_SECRET_KEY|JWT_SECRET_KEY|SECRET_KEY)\s*=\s*['\"]?([^'\"\s#]+)", re.IGNORECASE),
    ]
    weak_password_patterns = [
        re.compile(r"password123", re.IGNORECASE),
        re.compile(r"default\s*=\s*[\"']password", re.IGNORECASE),
    ]

    def _looks_like_placeholder(value: str) -> bool:
        normalized = value.strip().lower()
        return (
            not normalized
            or "placeholder" in normalized
            or normalized.startswith("your_")
            or normalized in {"changeme", "change-me", "example", "none", "null"}
        )

    for path in BACKEND_DIR.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in {".py", ".env", ".example"}:
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        rel = path.relative_to(BACKEND_DIR)
        for pattern in weak_password_patterns:
            if pattern.search(text):
                _record(
                    records,
                    endpoint=f"file:{rel}",
                    method="SCAN",
                    role="static",
                    status="FOUND",
                    expected_status="NOT_PRESENT",
                    finding=True,
                    severity="high",
                    response_time_ms=0,
                    test_category="hardcoded_creds",
                    note=f"Potential weak default password pattern: {pattern.pattern}",
                )
        for pattern in secret_assignments:
            for match in pattern.finditer(text):
                value = match.group(1)
                if _looks_like_placeholder(value):
                    continue
                _record(
                    records,
                    endpoint=f"file:{rel}",
                    method="SCAN",
                    role="static",
                    status="FOUND",
                    expected_status="NOT_PRESENT",
                    finding=True,
                    severity="high",
                    response_time_ms=0,
                    test_category="hardcoded_creds",
                    note="Potential hardcoded secret assignment",
                )


CATEGORY_RUNNERS: dict[str, Callable[[list[dict]], None]] = {
    "authn_bypass": category_authn_bypass,
    "authz_privesc": category_authz_privesc,
    "idor": category_idor,
    "rbac_matrix": category_rbac_matrix,
    "token_tampering": category_token_tampering,
    "injection_probe": category_injection_probe,
    "rate_limiting": category_rate_limiting,
    "hardcoded_creds": category_hardcoded_creds,
}


def run_categories(category_names: list[str] | None = None) -> list[dict]:
    records: list[dict] = []
    names = category_names or list(CATEGORY_RUNNERS)
    for name in names:
        print(f"\n=== Running {name} ===")
        CATEGORY_RUNNERS[name](records)
        REPORT_PATH.write_text(json.dumps(records, indent=2), encoding="utf-8")
        SAVEPOINT_PATH.write_text(
            json.dumps(
                {
                    "completed": name == names[-1],
                    "timestamp": _now(),
                    "total_tests": len(records),
                    "last_category": name,
                },
                indent=2,
            ),
            encoding="utf-8",
        )
    return records


def print_summary(records: list[dict]) -> None:
    findings = [record for record in records if record["finding"]]
    by_severity: dict[str, int] = {}
    by_category: dict[str, int] = {}
    for record in findings:
        by_severity[record["severity"]] = by_severity.get(record["severity"], 0) + 1
        by_category[record["test_category"]] = by_category.get(record["test_category"], 0) + 1

    print("\nDAST SUMMARY")
    print(f"Endpoints discovered : {len(discover_routes())}")
    print(f"Tests run            : {len(records)}")
    print(f"Findings             : {len(findings)}")
    print(f"Clean/skipped        : {len(records) - len(findings)}")
    print("\nFindings by severity:")
    for severity in ("critical", "high", "medium", "low", "info"):
        if severity in by_severity:
            print(f"  {severity:<10} {by_severity[severity]}")
    print("\nFindings by category:")
    for category, count in sorted(by_category.items(), key=lambda item: item[0]):
        print(f"  {category:<18} {count}")
    print(f"\nReport written to: {REPORT_PATH}")
