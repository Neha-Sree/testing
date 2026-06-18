"""Export automated_test/report.json to an Excel .xlsx workbook.

Uses only the Python standard library so it works even when openpyxl/xlsxwriter
are not installed.
"""

from __future__ import annotations

import json
import zipfile
from collections import Counter
from datetime import datetime
from pathlib import Path
from xml.sax.saxutils import escape


BASE_DIR = Path(__file__).resolve().parent
REPORT_PATH = BASE_DIR / "report.json"
SAVEPOINT_PATH = BASE_DIR / "savepoint.json"
OUTPUT_PATH = BASE_DIR / "backend_dast_report.xlsx"


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
    if isinstance(value, bool):
        return f'<c r="{ref}" t="b"><v>{1 if value else 0}</v></c>'
    if isinstance(value, (int, float)) and not isinstance(value, bool):
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
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
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
  <Override PartName="/xl/worksheets/sheet3.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>"""


def _root_rels() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>"""


def _workbook() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Summary" sheetId="1" r:id="rId1"/>
    <sheet name="Findings" sheetId="2" r:id="rId2"/>
    <sheet name="All Results" sheetId="3" r:id="rId3"/>
  </sheets>
</workbook>"""


def _workbook_rels() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet3.xml"/>
</Relationships>"""


def _core_props() -> str:
    now = datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:creator>Cursor DAST Export</dc:creator>
  <cp:lastModifiedBy>Cursor DAST Export</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified>
</cp:coreProperties>"""


def _app_props() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Cursor DAST Export</Application>
</Properties>"""


def main() -> None:
    records = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
    findings = [record for record in records if record.get("finding")]
    severity_counts = Counter(record.get("severity", "unknown") for record in findings)
    category_counts = Counter(record.get("test_category", "unknown") for record in findings)

    summary_rows = [
        ["Life Nest Backend DAST Report"],
        ["Generated UTC", datetime.utcnow().replace(microsecond=0).isoformat() + "Z"],
        ["Report JSON", str(REPORT_PATH)],
        [],
        ["Metric", "Value"],
        ["Total tests", len(records)],
        ["Findings", len(findings)],
        ["Clean/skipped", len(records) - len(findings)],
        [],
        ["Findings by Severity", "Count"],
    ]
    for severity in ("critical", "high", "medium", "low", "info"):
        summary_rows.append([severity, severity_counts.get(severity, 0)])
    summary_rows.extend([[], ["Findings by Category", "Count"]])
    for category, count in sorted(category_counts.items()):
        summary_rows.append([category, count])

    headers = [
        "endpoint",
        "method",
        "role",
        "status",
        "expected_status",
        "finding",
        "severity",
        "response_time_ms",
        "test_category",
        "note",
        "timestamp",
    ]
    finding_rows = [headers] + [[record.get(header, "") for header in headers] for record in findings]
    all_rows = [headers] + [[record.get(header, "") for header in headers] for record in records]

    with zipfile.ZipFile(OUTPUT_PATH, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("[Content_Types].xml", _content_types())
        archive.writestr("_rels/.rels", _root_rels())
        archive.writestr("xl/workbook.xml", _workbook())
        archive.writestr("xl/_rels/workbook.xml.rels", _workbook_rels())
        archive.writestr("xl/worksheets/sheet1.xml", _worksheet(summary_rows))
        archive.writestr("xl/worksheets/sheet2.xml", _worksheet(finding_rows))
        archive.writestr("xl/worksheets/sheet3.xml", _worksheet(all_rows))
        archive.writestr("docProps/core.xml", _core_props())
        archive.writestr("docProps/app.xml", _app_props())

    if SAVEPOINT_PATH.exists():
        savepoint = json.loads(SAVEPOINT_PATH.read_text(encoding="utf-8"))
    else:
        savepoint = {}
    savepoint["completed"] = True
    savepoint["timestamp"] = records[-1]["timestamp"] if records else datetime.utcnow().isoformat() + "Z"
    savepoint["total_tests"] = len(records)
    SAVEPOINT_PATH.write_text(json.dumps(savepoint, indent=2), encoding="utf-8")

    print(f"Wrote {OUTPUT_PATH}")
    print(f"Total tests: {len(records)}")
    print(f"Findings: {len(findings)}")


if __name__ == "__main__":
    main()
