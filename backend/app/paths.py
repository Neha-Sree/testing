"""Absolute paths for uploads — independent of process working directory."""
from __future__ import annotations

from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parent.parent
UPLOADS_DIR = BACKEND_ROOT / "uploads"
REPORTS_DIR = UPLOADS_DIR / "reports"
VISITS_DIR = UPLOADS_DIR / "visits"
HW_PROFILES_DIR = UPLOADS_DIR / "health_workers"

for _dir in (UPLOADS_DIR, REPORTS_DIR, VISITS_DIR, HW_PROFILES_DIR):
    _dir.mkdir(parents=True, exist_ok=True)


def resolve_stored_path(path_str: str) -> Path:
    """Resolve a stored relative or absolute file path to an on-disk location."""
    raw = Path(path_str)
    if raw.is_absolute() and raw.is_file():
        return raw
    candidates = [
        raw,
        Path.cwd() / raw,
        BACKEND_ROOT / raw,
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()
    return raw
