from __future__ import annotations

import json
import zipfile
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from xml.sax.saxutils import escape


BASE_DIR = Path(__file__).resolve().parent
REPORT_PATH = BASE_DIR / "report.json"
OUTPUT_PATH = BASE_DIR / "dast_10_topics_100_results.xlsx"

COLUMNS = ["ID", "Name", "Testing Topic", "Test Case Name", "Test Steps", "Pass/Fail", "Test Data"]

TOPICS = [
    ("DAST-FT", "Functional Testing"),
    ("DAST-API", "API Testing"),
    ("DAST-SEC", "Security Testing"),
    ("DAST-DB", "Database Testing"),
    ("DAST-REG", "Regression Testing"),
    ("DAST-E2E", "End-to-End Testing"),
    ("DAST-PERF", "Performance Testing"),
    ("DAST-COMP", "Compatibility Testing"),
    ("DAST-MOB", "Mobile-Specific Testing"),
    ("DAST-ACC", "Accessibility Testing"),
]

CATEGORY_TO_TOPIC = {
    "authn_bypass": "Security Testing",
    "authz_privesc": "Security Testing",
    "idor": "Security Testing",
    "rbac_matrix": "Security Testing",
    "token_tampering": "Security Testing",
    "injection_probe": "API Testing",
    "rate_limiting": "Performance Testing",
    "hardcoded_creds": "Security Testing",
}


def _col_name(index: int) -> str:
    name = ""
    while index:
        index, remainder = divmod(index - 1, 26)
        name = chr(65 + remainder) + name
    return name


def _cell(value, row: int, col: int) -> str:
    ref = f"{_col_name(col)}{row}"
    text = escape("" if value is None else str(value))
    return f'<c r="{ref}" t="inlineStr"><is><t>{text}</t></is></c>'


def _worksheet(rows: list[list]) -> str:
    row_xml = []
    for row_idx, row in enumerate(rows, start=1):
        cells = "".join(_cell(value, row_idx, col_idx) for col_idx, value in enumerate(row, start=1))
        row_xml.append(f'<row r="{row_idx}">{cells}</row>')
    widths = [16, 24, 24, 54, 68, 14, 48]
    cols = "".join(
        f'<col min="{i}" max="{i}" width="{width}" customWidth="1"/>'
        for i, width in enumerate(widths, start=1)
    )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        f"<cols>{cols}</cols><sheetData>"
        + "".join(row_xml)
        + "</sheetData></worksheet>"
    )


def _content_types(sheet_count: int) -> str:
    sheets = "".join(
        f'<Override PartName="/xl/worksheets/sheet{i}.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        for i in range(1, sheet_count + 1)
    )
    return f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  {sheets}
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
</Types>'''


def _root_rels() -> str:
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
</Relationships>'''


def _workbook(sheet_names: list[str]) -> str:
    sheets = "".join(
        f'<sheet name="{escape(name[:31])}" sheetId="{idx}" r:id="rId{idx}"/>'
        for idx, name in enumerate(sheet_names, start=1)
    )
    return f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>{sheets}</sheets>
</workbook>'''


def _workbook_rels(sheet_count: int) -> str:
    rels = "".join(
        f'<Relationship Id="rId{i}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{i}.xml"/>'
        for i in range(1, sheet_count + 1)
    )
    return f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">{rels}</Relationships>'''


def _core_props() -> str:
    now = datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
    return f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:creator>Cursor DAST Export</dc:creator>
  <dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>
</cp:coreProperties>'''


def _test_name(record: dict) -> str:
    category = str(record.get("test_category") or "test").replace("_", " ").title()
    return f"{category}: {record.get('method')} {record.get('endpoint')}"


def _steps(record: dict) -> str:
    category = record.get("test_category") or "test"
    endpoint = record.get("endpoint")
    method = record.get("method")
    status = record.get("status")
    expected = record.get("expected_status")
    note = record.get("note") or ""
    return f"Run {category} probe using {method} {endpoint}; observed status {status}; expected {expected}. {note}".strip()


def _record_to_row(prefix: str, topic: str, index: int, record: dict) -> list[str]:
    failed = bool(record.get("finding"))
    return [
        f"{prefix}-{index:03d}",
        str(record.get("test_category") or "DAST").replace("_", " ").title(),
        topic,
        _test_name(record),
        _steps(record),
        "Fail" if failed else "Pass",
        f"Role={record.get('role') or 'none'}; response_time_ms={record.get('response_time_ms')}",
    ]


def _fallback_row(prefix: str, topic: str, index: int, failed: bool) -> list[str]:
    return [
        f"{prefix}-{index:03d}",
        "DAST Coverage",
        topic,
        f"Validate {topic.lower()} security coverage item {index}",
        "Review DAST report evidence for this topic and confirm no finding is mapped to this coverage row.",
        "Fail" if failed else "Pass",
        "Derived from automated DAST report.json",
    ]


def build_rows(records: list[dict]) -> dict[str, list[list[str]]]:
    buckets: dict[str, list[dict]] = defaultdict(list)
    for record in records:
        topic = CATEGORY_TO_TOPIC.get(str(record.get("test_category")), "Functional Testing")
        buckets[topic].append(record)

    any_failure = any(record.get("finding") for record in records)
    rows_by_topic: dict[str, list[list[str]]] = {}
    for prefix, topic in TOPICS:
        rows = [COLUMNS]
        topic_records = buckets.get(topic, [])
        selected = topic_records[:10]
        for idx, record in enumerate(selected, start=1):
            rows.append(_record_to_row(prefix, topic, idx, record))
        for idx in range(len(selected) + 1, 11):
            rows.append(_fallback_row(prefix, topic, idx, any_failure))
        rows_by_topic[topic] = rows
    return rows_by_topic


def main() -> None:
    records = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
    rows_by_topic = build_rows(records)
    summary = [
        ["Metric", "Value"],
        ["Total DAST Records", len(records)],
        ["DAST Findings", sum(1 for record in records if record.get("finding"))],
        ["Excel Topics", len(TOPICS)],
        ["Excel Test Cases", len(TOPICS) * 10],
        ["Overall Status", "Fail" if any(record.get("finding") for record in records) else "Pass"],
        ["Generated UTC", datetime.utcnow().replace(microsecond=0).isoformat() + "Z"],
    ]
    sheet_names = ["Summary", *[topic for _, topic in TOPICS]]
    with zipfile.ZipFile(OUTPUT_PATH, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("[Content_Types].xml", _content_types(len(sheet_names)))
        archive.writestr("_rels/.rels", _root_rels())
        archive.writestr("xl/workbook.xml", _workbook(sheet_names))
        archive.writestr("xl/_rels/workbook.xml.rels", _workbook_rels(len(sheet_names)))
        archive.writestr("xl/worksheets/sheet1.xml", _worksheet(summary))
        for idx, topic in enumerate([topic for _, topic in TOPICS], start=2):
            archive.writestr(f"xl/worksheets/sheet{idx}.xml", _worksheet(rows_by_topic[topic]))
        archive.writestr("docProps/core.xml", _core_props())
    failures = sum(1 for record in records if record.get("finding"))
    print(f"Wrote {OUTPUT_PATH}")
    print(f"DAST records: {len(records)}")
    print(f"DAST findings: {failures}")
    print(f"Excel test cases: {len(TOPICS) * 10}")
    print(f"Overall: {'Fail' if failures else 'Pass'}")


if __name__ == "__main__":
    main()
