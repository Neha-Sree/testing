"""Shared helpers for the DAST pass.

This module keeps the workspace-local test scripts small and deterministic.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
from typing import Iterable


WORKSPACE_ROOT = Path(__file__).resolve().parents[1]
BACKEND_MAIN = WORKSPACE_ROOT / "backend" / "app" / "main.py"
INPUT_PATH = WORKSPACE_ROOT / "input.json"
REPORT_PATH = Path(__file__).resolve().with_name("report.json")
SAVEPOINT_PATH = Path(__file__).resolve().with_name("savepoint.json")


@dataclass(frozen=True)
class Route:
    method: str
    path: str
    expected_access: str
    source: str


def load_config() -> dict:
    with INPUT_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def base_url() -> str:
    return load_config()["baseUrl"].rstrip("/")


def now_utc() -> str:
    return datetime.utcnow().isoformat() + "Z"


def sanitize_path(path: str) -> str:
    return path.strip().rstrip("/") or "/"


def discover_routes_from_main() -> list[Route]:
    """Parse `backend/app/main.py` for route registrations.

    The app centralizes route wiring here, so the regex-based parser is enough
    for a dependable inventory without importing the running app.
    """

    source = BACKEND_MAIN.read_text(encoding="utf-8")
    routes: list[Route] = []

    patterns = [
        re.compile(r'@app\.(get|post|put|patch|delete|head|options)\("([^"]+)"\)'),
        re.compile(r'app\.(get|post|put|patch|delete|head|options)\("([^"]+)"\)\('),
        re.compile(r'@app\.websocket\("([^"]+)"\)'),
    ]

    for line in source.splitlines():
        line = line.strip()
        match = patterns[0].search(line) or patterns[1].search(line)
        if match:
            method = match.group(1).upper()
            path = sanitize_path(match.group(2))
            routes.append(Route(method=method, path=path, expected_access="public", source="main.py"))
            continue
        ws_match = patterns[2].search(line)
        if ws_match:
            routes.append(Route(method="WS", path=sanitize_path(ws_match.group(1)), expected_access="public", source="main.py"))

    unique: list[Route] = []
    seen: set[tuple[str, str]] = set()
    for route in routes:
        key = (route.method, route.path)
        if key in seen:
            continue
        seen.add(key)
        unique.append(route)
    return unique


def filter_discovery_scope(routes: Iterable[Route]) -> list[Route]:
    ignored_exact = {"/health", "/metrics"}
    ignored_roots = ("/actuator/", "/metrics/")
    return [
        route
        for route in routes
        if route.path not in ignored_exact and not route.path.startswith(ignored_roots)
    ]


def write_savepoint(payload: dict) -> None:
    SAVEPOINT_PATH.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")


def append_report(records: list[dict]) -> None:
    REPORT_PATH.write_text(json.dumps(records, indent=2, sort_keys=False), encoding="utf-8")


def report_record(**kwargs) -> dict:
    base = {
        "endpoint": None,
        "method": None,
        "role": None,
        "status": None,
        "expected_status": None,
        "finding": False,
        "severity": "info",
        "response_time_ms": 0,
        "test_category": None,
        "note": None,
        "timestamp": now_utc(),
    }
    base.update(kwargs)
    return base


def route_catalog_as_dicts(routes: Iterable[Route]) -> list[dict]:
    return [asdict(route) for route in routes]
