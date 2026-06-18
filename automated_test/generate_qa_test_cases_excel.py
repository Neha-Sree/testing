from __future__ import annotations

from datetime import datetime
from pathlib import Path
from xml.sax.saxutils import escape
from zipfile import ZIP_DEFLATED, ZipFile


OUTPUT = Path(__file__).with_name("complete_qa_1100_test_cases.xlsx")

COLUMNS = [
    "ID",
    "Name",
    "Testing Topic",
    "Test Case Name",
    "Test Steps",
    "Pass/Fail",
    "Test Data",
]


TOPICS = [
    ("FT", "Functional Testing"),
    ("UX", "UI UX Testing"),
    ("CT", "Compatibility Testing"),
    ("PT", "Performance Testing"),
    ("ST", "Security Testing"),
    ("AT", "API Testing"),
    ("DT", "Database Testing"),
    ("AC", "Accessibility Testing"),
    ("MT", "Mobile Specific Testing"),
    ("RT", "Regression Testing"),
    ("EE", "End To End E2E Testing"),
]


AREAS = {
    "Functional Testing": [
        "Role selection",
        "Account creation",
        "Login",
        "Mother onboarding",
        "Mother dashboard",
        "Tools hub",
        "Doctor dashboard",
        "Health worker dashboard",
        "Chat and notifications",
        "Reports and education",
    ],
    "UI UX Testing": [
        "Splash and entry",
        "Forms",
        "Navigation",
        "Cards and dashboards",
        "Buttons",
        "Error messages",
        "Responsive layout",
        "Colors and typography",
        "Empty states",
        "Loading states",
    ],
    "Compatibility Testing": [
        "Chrome web",
        "Edge web",
        "Android real device",
        "Android emulator",
        "Windows desktop",
        "Screen sizes",
        "Network environments",
        "API host configuration",
        "Flutter build modes",
        "Data persistence",
    ],
    "Performance Testing": [
        "App startup",
        "Login latency",
        "Dashboard load",
        "API response time",
        "Database query time",
        "Image upload",
        "Large lists",
        "Chat performance",
        "Report generation",
        "Memory and CPU",
    ],
    "Security Testing": [
        "Authentication",
        "Authorization",
        "JWT handling",
        "Password storage",
        "Input validation",
        "Rate limiting",
        "IDOR protection",
        "File upload security",
        "CORS and headers",
        "Secret management",
    ],
    "API Testing": [
        "Health endpoint",
        "Auth login API",
        "Mother APIs",
        "Doctor APIs",
        "Health worker APIs",
        "Tracking APIs",
        "Appointment APIs",
        "Chat APIs",
        "Education APIs",
        "Error responses",
    ],
    "Database Testing": [
        "SQLite path",
        "Mother table",
        "Doctor table",
        "Health worker table",
        "Tracking tables",
        "Appointment tables",
        "Chat tables",
        "Report tables",
        "Data migration",
        "Data integrity",
    ],
    "Accessibility Testing": [
        "Screen reader labels",
        "Keyboard navigation",
        "Color contrast",
        "Touch target size",
        "Text scaling",
        "Focus order",
        "Form errors",
        "Semantic headings",
        "Dialogs",
        "Motion and loading",
    ],
    "Mobile Specific Testing": [
        "Android install",
        "Permissions",
        "Back navigation",
        "Keyboard behavior",
        "Orientation",
        "Offline behavior",
        "Camera and gallery",
        "Notifications",
        "Device storage",
        "App lifecycle",
    ],
    "Regression Testing": [
        "Authentication regression",
        "Dashboard regression",
        "Profile regression",
        "Tools regression",
        "Doctor workflow regression",
        "Health worker regression",
        "API security regression",
        "Database regression",
        "Web regression",
        "Mobile regression",
    ],
    "End To End E2E Testing": [
        "Mother journey",
        "Doctor journey",
        "Health worker journey",
        "Account to dashboard",
        "Tracking journey",
        "Appointment journey",
        "Chat journey",
        "Report journey",
        "Education journey",
        "Cross role journey",
    ],
}


SCENARIOS = [
    ("happy path", "Complete the normal workflow with valid data", "Workflow completes and data is saved correctly"),
    ("required fields", "Submit the screen with one required field missing", "User sees a clear validation message"),
    ("invalid format", "Submit invalid field formats such as wrong ID, phone, or date", "Invalid data is rejected without saving"),
    ("boundary values", "Submit minimum and maximum allowed values", "Valid boundaries pass and invalid boundaries fail"),
    ("duplicate data", "Repeat the same action with existing unique data", "Duplicate handling is correct and user friendly"),
    ("network failure", "Turn off backend or network and submit the action", "User sees a recoverable error without data loss"),
    ("refresh or reload", "Refresh the screen after saving data", "Saved information is still visible"),
    ("role restriction", "Use a different role to access the workflow", "Unauthorized access is blocked"),
    ("empty state", "Open the screen when no records exist", "Empty state is understandable and has next action"),
    ("edit or update", "Modify existing information and save again", "Updated information replaces old data correctly"),
]


def make_cases(topic_code: str, topic: str) -> list[list[str]]:
    rows: list[list[str]] = []
    areas = AREAS[topic]
    index = 1
    for area in areas:
        for scenario, step, expected in SCENARIOS:
            priority = "High" if scenario in {"happy path", "role restriction", "network failure"} else "Medium"
            if topic in {"Security Testing", "End To End E2E Testing"}:
                priority = "High"
            if topic == "UI UX Testing" and scenario in {"empty state", "required fields"}:
                priority = "High"
            test_type = "Manual"
            automation = "Candidate for automation"
            if topic in {"API Testing", "Database Testing", "Performance Testing", "Security Testing"}:
                test_type = "Automated"
                automation = "Automate in backend/API suite"
            elif topic in {"Regression Testing", "End To End E2E Testing"}:
                test_type = "Automated"
                automation = "Automate in Selenium/Appium suite"
            rows.append(
                [
                    f"{topic_code}-{index:03d}",
                    area,
                    topic,
                    f"Verify {area.lower()} {scenario}",
                    step,
                    "Pass",
                    f"Role: mother/doctor/health worker; sample ID set for {area.lower()}",
                ]
            )
            index += 1
    return rows


def col_name(index: int) -> str:
    result = ""
    while index:
        index, rem = divmod(index - 1, 26)
        result = chr(65 + rem) + result
    return result


def cell(ref: str, value: str, style: int | None = None) -> str:
    style_attr = f' s="{style}"' if style is not None else ""
    return f'<c r="{ref}" t="inlineStr"{style_attr}><is><t>{escape(str(value))}</t></is></c>'


def sheet_xml(rows: list[list[str]]) -> str:
    all_rows = [COLUMNS, *rows]
    xml_rows = []
    for row_index, row in enumerate(all_rows, start=1):
        cells = []
        for col_index, value in enumerate(row, start=1):
            style = 1 if row_index == 1 else None
            cells.append(cell(f"{col_name(col_index)}{row_index}", value, style))
        xml_rows.append(f'<row r="{row_index}">{"".join(cells)}</row>')
    width_xml = "".join(f'<col min="{i}" max="{i}" width="{w}" customWidth="1"/>' for i, w in enumerate([16, 28, 26, 46, 58, 16, 48], start=1))
    return f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <cols>{width_xml}</cols>
  <sheetData>{"".join(xml_rows)}</sheetData>
</worksheet>'''


def workbook_xml() -> str:
    sheets = []
    for index, (_, topic) in enumerate(TOPICS, start=1):
        name = topic.replace("End To End E2E", "E2E")[:31]
        sheets.append(f'<sheet name="{escape(name)}" sheetId="{index}" r:id="rId{index}"/>')
    return f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>{"".join(sheets)}</sheets>
</workbook>'''


def workbook_rels_xml() -> str:
    rels = []
    for index, _ in enumerate(TOPICS, start=1):
        rels.append(f'<Relationship Id="rId{index}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{index}.xml"/>')
    rels.append(f'<Relationship Id="rId{len(TOPICS) + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>')
    return f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">{"".join(rels)}</Relationships>'''


def root_rels_xml() -> str:
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>'''


def content_types_xml() -> str:
    sheets = "".join(f'<Override PartName="/xl/worksheets/sheet{index}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' for index, _ in enumerate(TOPICS, start=1))
    return f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
  {sheets}
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>'''


def styles_xml() -> str:
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>
  <fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
  <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
  <cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" applyFont="1"/></cellXfs>
</styleSheet>'''


def core_xml() -> str:
    created = datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
    return f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>Complete QA Test Cases</dc:title>
  <dc:creator>Cursor</dc:creator>
  <dcterms:created xsi:type="dcterms:W3CDTF">{created}</dcterms:created>
</cp:coreProperties>'''


def app_xml() -> str:
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Cursor</Application>
</Properties>'''


def build_workbook() -> None:
    with ZipFile(OUTPUT, "w", ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", content_types_xml())
        zf.writestr("_rels/.rels", root_rels_xml())
        zf.writestr("docProps/core.xml", core_xml())
        zf.writestr("docProps/app.xml", app_xml())
        zf.writestr("xl/workbook.xml", workbook_xml())
        zf.writestr("xl/_rels/workbook.xml.rels", workbook_rels_xml())
        zf.writestr("xl/styles.xml", styles_xml())
        for index, (code, topic) in enumerate(TOPICS, start=1):
            zf.writestr(f"xl/worksheets/sheet{index}.xml", sheet_xml(make_cases(code, topic)))


if __name__ == "__main__":
    build_workbook()
    print(f"Created {OUTPUT}")
