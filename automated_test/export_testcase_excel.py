"""Export DAST results in testcase-status format.

Columns:
- Test Case ID
- Testcase Name
- Pass/Fail
- Criticality
- Role
- Timestamp
"""

from __future__ import annotations

import json
import zipfile
from datetime import datetime
from pathlib import Path
from xml.sax.saxutils import escape


BASE_DIR = Path(__file__).resolve().parent
REPORT_PATH = BASE_DIR / "report.json"
OUTPUT_PATH = BASE_DIR / "backend_dast_testcase_report.xlsx"


def _col_name(index: int) -> str:
    name = ""
    while index:
        index, remainder = divmod(index - 1, 26)
        name = chr(65 + remainder) + name
    return name


def _cell(value, row: int, col: int) -> str:
    ref = f"{_col_name(col)}{row}"
    if value is None:
        value = ""
    if isinstance(value, (int, float)):
        return f'<c r="{ref}"><v>{value}</v></c>'
    text = escape(str(value))
    return f'<c r="{ref}" t="inlineStr"><is><t>{text}</t></is></c>'


def _worksheet(rows: list[list]) -> str:
    row_xml = []
    for row_idx, row in enumerate(rows, start=1):
        cells = "".join(_cell(value, row_idx, col_idx) for col_idx, value in enumerate(row, start=1))
        row_xml.append(f'<row r="{row_idx}">{cells}</row>')
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<sheetData>'
        + "".join(row_xml)
        + "</sheetData></worksheet>"
    )


def _content_types() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
</Types>"""


def _root_rels() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
</Relationships>"""


def _workbook() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Test Cases" sheetId="1" r:id="rId1"/>
    <sheet name="Summary" sheetId="2" r:id="rId2"/>
  </sheets>
</workbook>"""


def _workbook_rels() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
</Relationships>"""


def _core_props() -> str:
    now = datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:creator>Cursor DAST Export</dc:creator>
  <dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified>
</cp:coreProperties>"""


def _testcase_name(record: dict) -> str:
    category = str(record.get("test_category") or "test").replace("_", " ").title()
    method = record.get("method") or ""
    endpoint = record.get("endpoint") or ""
    note = record.get("note") or ""
    if note:
        return f"{category}: {method} {endpoint} - {note}"
    return f"{category}: {method} {endpoint}"


def main() -> None:
    records = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
    rows = [["Test Case ID", "Testcase Name", "Pass/Fail", "Criticality", "Role", "Timestamp"]]

    for index, record in enumerate(records, start=1):
        failed = bool(record.get("finding"))
        rows.append(
            [
                f"DAST-{index:04d}",
                _testcase_name(record),
                "FAIL" if failed else "PASS",
                str(record.get("severity") or "").upper() if failed else "",
                record.get("role") or "",
                record.get("timestamp") or "",
            ]
        )

    failures = sum(1 for record in records if record.get("finding"))
    summary_rows = [
        ["Metric", "Value"],
        ["Total Test Cases", len(records)],
        ["Passed", len(records) - failures],
        ["Failed", failures],
        ["Overall Status", "FAILED" if failures else "PASSED"],
        ["Generated UTC", datetime.utcnow().replace(microsecond=0).isoformat() + "Z"],
    ]

    with zipfile.ZipFile(OUTPUT_PATH, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("[Content_Types].xml", _content_types())
        archive.writestr("_rels/.rels", _root_rels())
        archive.writestr("xl/workbook.xml", _workbook())
        archive.writestr("xl/_rels/workbook.xml.rels", _workbook_rels())
        archive.writestr("xl/worksheets/sheet1.xml", _worksheet(rows))
        archive.writestr("xl/worksheets/sheet2.xml", _worksheet(summary_rows))
        archive.writestr("docProps/core.xml", _core_props())

    print(f"Wrote {OUTPUT_PATH}")
    print(f"Total Test Cases: {len(records)}")
    print(f"Passed: {len(records) - failures}")
    print(f"Failed: {failures}")
    print(f"Overall Status: {'FAILED' if failures else 'PASSED'}")


if __name__ == "__main__":
    main()
