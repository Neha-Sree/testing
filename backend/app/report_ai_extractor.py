"""AI-assisted report extraction and persistence for mother records."""
from __future__ import annotations

from . import env as _env  # noqa: F401 — load GEMINI_API_KEY from backend/.env

import base64
import json
import logging
import mimetypes
import os
import re
import shutil
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path
from typing import Any, Optional
from uuid import uuid4

from fastapi import Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session

from .clinical_terms import (
    normalize_fetal_movement,
    normalize_urine_dipstick,
)
from .database import get_db
from .models import FetalGrowthData, HealthMetrics, LabTest, Mother, Report, ReportExtraction
from .paths import REPORTS_DIR, resolve_stored_path
from .pregnancy_utils import current_pregnant_weeks
from .risk_engine import compute_risk

log = logging.getLogger(__name__)

GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}"
MAX_REPORT_BYTES = int(os.getenv("REPORT_AI_MAX_BYTES", str(8 * 1024 * 1024)))

REPORT_TYPES = {"scan", "blood", "urine", "ultrasound", "thyroid", "growth_scan", "prescription", "other"}
SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".pdf", ".txt", ".csv", ".json"}
TEXT_EXTENSIONS = {".txt", ".csv", ".json"}


def _iso(value: Any) -> Optional[str]:
    return value.isoformat() if hasattr(value, "isoformat") else None


def _coerce_float(value: Any) -> Optional[float]:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value.strip().rstrip("%"))
        except ValueError:
            return None
    return None


def _json_dumps(value: Any) -> str:
    return json.dumps(value, ensure_ascii=True, default=str)


def _safe_json_loads(value: Optional[str], fallback: Any) -> Any:
    if not value:
        return fallback
    try:
        return json.loads(value)
    except (TypeError, json.JSONDecodeError):
        return fallback


def serialize_report_extraction(row: ReportExtraction) -> dict[str, Any]:
    return {
        "id": row.id,
        "report_id": row.report_id,
        "patient_id": row.patient_id,
        "extractor": row.extractor,
        "status": row.status,
        "extracted": _safe_json_loads(row.extracted_json, {}),
        "applied_to": _safe_json_loads(row.applied_json, []),
        "warnings": _safe_json_loads(row.warnings_json, []),
        "created_at": _iso(row.created_at),
    }


def _strip_markdown_json(text: str) -> str:
    clean = (text or "").strip()
    if clean.startswith("```"):
        clean = re.sub(r"^```(?:json)?", "", clean, flags=re.IGNORECASE).strip()
        clean = re.sub(r"```$", "", clean).strip()
    return clean


def _parse_json_response(text: str) -> dict[str, Any]:
    clean = _strip_markdown_json(text)
    try:
        data = json.loads(clean)
    except json.JSONDecodeError:
        match = re.search(r"\{.*\}", clean, flags=re.DOTALL)
        if not match:
            raise
        data = json.loads(match.group(0))
    if not isinstance(data, dict):
        raise ValueError("Gemini JSON root was not an object")
    return data


def _as_number(value: Any) -> Optional[float]:
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, dict):
        return _as_number(value.get("value"))
    text = str(value).replace(",", "").strip()
    match = re.search(r"-?\d+(?:\.\d+)?", text)
    if not match:
        return None
    try:
        return float(match.group(0))
    except ValueError:
        return None


def _as_int(value: Any) -> Optional[int]:
    number = _as_number(value)
    return int(round(number)) if number is not None else None


def _as_string(value: Any) -> Optional[str]:
    if value is None:
        return None
    if isinstance(value, dict) and "value" in value:
        value = value.get("value")
    if isinstance(value, list):
        return ", ".join(str(v).strip() for v in value if str(v).strip()) or None
    text = str(value).strip()
    return text or None


def _as_string_list(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(v).strip() for v in value if str(v).strip()]
    if isinstance(value, str):
        return [v.strip() for v in re.split(r"[\n;]+", value) if v.strip()]
    return [str(value).strip()]


def _parse_datetime(value: Any) -> Optional[datetime]:
    if isinstance(value, datetime):
        return value
    text = _as_string(value)
    if not text:
        return None
    normalized = text.replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(normalized).replace(tzinfo=None)
    except ValueError:
        pass
    for pattern in ("%d/%m/%Y", "%d-%m-%Y", "%Y/%m/%d", "%d %b %Y", "%d %B %Y"):
        try:
            return datetime.strptime(text, pattern)
        except ValueError:
            continue
    return None


def _section(payload: dict[str, Any], *names: str) -> dict[str, Any]:
    merged: dict[str, Any] = {}
    for name in names:
        value = payload.get(name)
        if isinstance(value, dict):
            merged.update(value)
    return merged


def _field(payload: dict[str, Any], sections: list[dict[str, Any]], *names: str) -> Any:
    for name in names:
        for section in sections:
            if name in section:
                return section[name]
        if name in payload:
            return payload[name]
    return None


def _normalize_payload(payload: dict[str, Any]) -> dict[str, Any]:
    lab = _section(payload, "lab_values", "labs", "lab")
    vitals = _section(payload, "vital_values", "vitals", "health_metrics")
    fetal = _section(payload, "fetal_values", "fetal", "fetal_growth")

    normalized = {
        "report_type": _as_string(payload.get("report_type")) or "other",
        "collection_date": _as_string(payload.get("collection_date")),
        "report_date": _as_string(payload.get("report_date")),
        "lab_values": {
            "hemoglobin": _as_number(_field(payload, [lab], "hemoglobin", "hb")),
            "blood_sugar": _as_number(_field(payload, [lab], "blood_sugar", "glucose")),
            "blood_sugar_fasting": _as_number(_field(payload, [lab], "blood_sugar_fasting", "fasting_blood_sugar", "fbs")),
            "blood_sugar_post": _as_number(_field(payload, [lab], "blood_sugar_post", "post_prandial_blood_sugar", "ppbs")),
            "urine_sugar": _as_string(_field(payload, [lab], "urine_sugar")),
            "urine_protein": _as_string(_field(payload, [lab], "urine_protein", "albumin")),
            "thyroid_tsh": _as_number(_field(payload, [lab], "thyroid_tsh", "tsh")),
            "iron_level": _as_number(_field(payload, [lab], "iron_level", "iron_ferritin", "ferritin")),
            "calcium_level": _as_number(_field(payload, [lab], "calcium_level", "calcium")),
            "infection_indicators": _as_string(_field(payload, [lab], "infection_indicators", "infection_notes", "wbc", "pus_cells")),
        },
        "vital_values": {
            "bp_systolic": _as_int(_field(payload, [vitals], "bp_systolic", "blood_pressure_systolic", "systolic")),
            "bp_diastolic": _as_int(_field(payload, [vitals], "bp_diastolic", "blood_pressure_diastolic", "diastolic")),
            "pulse": _as_int(_field(payload, [vitals], "pulse", "heart_rate", "heart_rate_bpm")),
            "temperature": _as_number(_field(payload, [vitals], "temperature", "temperature_celsius")),
            "oxygen_level": _as_number(_field(payload, [vitals], "oxygen_level", "spo2")),
            "weight_kg": _as_number(_field(payload, [vitals], "weight_kg", "weight")),
            "bmi": _as_number(_field(payload, [vitals], "bmi")),
        },
        "fetal_values": {
            "fetal_heartbeat": _as_int(_field(payload, [fetal], "fetal_heartbeat", "fetal_heart_rate", "heart_rate_bpm")),
            "fetal_weight_g": _as_number(_field(payload, [fetal], "fetal_weight_g", "fetal_weight_grams", "estimated_fetal_weight")),
            "fetal_movement": _as_string(_field(payload, [fetal], "fetal_movement")),
            "head_circumference_cm": _as_number(_field(payload, [fetal], "head_circumference_cm", "hc")),
            "femur_length_cm": _as_number(_field(payload, [fetal], "femur_length_cm", "fl")),
            "amniotic_fluid_level": _as_number(_field(payload, [fetal], "amniotic_fluid_level", "amniotic_fluid_index", "afi")),
            "placenta_status": _as_string(_field(payload, [fetal], "placenta_status", "placenta")),
            "growth_percentile": _as_number(_field(payload, [fetal], "growth_percentile")),
        },
        "abnormalities": _as_string_list(payload.get("abnormalities") or payload.get("warnings")),
        "warnings": _as_string_list(payload.get("warnings")),
        "confidence": payload.get("confidence") if isinstance(payload.get("confidence"), dict) else {},
    }
    if normalized["report_type"] not in REPORT_TYPES:
        normalized["report_type"] = "other"
    return normalized


def _build_prompt(report: Report, text_content: Optional[str]) -> str:
    text_block = f"\nReport text:\n{text_content[:12000]}" if text_content else ""
    return (
        "You extract structured antenatal/maternal healthcare data from medical reports.\n"
        "Return JSON only, with no markdown. If a field is absent, use null. Do not guess.\n"
        "Use numeric values without units where possible.\n"
        "Schema:\n"
        "{\n"
        '  "report_type": "blood|urine|ultrasound|thyroid|growth_scan|prescription|other",\n'
        '  "collection_date": "YYYY-MM-DD|null", "report_date": "YYYY-MM-DD|null",\n'
        '  "lab_values": {"hemoglobin": null, "blood_sugar": null, "blood_sugar_fasting": null, "blood_sugar_post": null, "urine_sugar": null, "urine_protein": null, "thyroid_tsh": null, "iron_level": null, "calcium_level": null, "infection_indicators": null},\n'
        '  "vital_values": {"bp_systolic": null, "bp_diastolic": null, "pulse": null, "temperature": null, "oxygen_level": null, "weight_kg": null, "bmi": null},\n'
        '  "fetal_values": {"fetal_heartbeat": null, "fetal_weight_g": null, "fetal_movement": null, "head_circumference_cm": null, "femur_length_cm": null, "amniotic_fluid_level": null, "placenta_status": null, "growth_percentile": null},\n'
        '  "abnormalities": [], "warnings": [], "confidence": {}\n'
        "}\n"
        f"Patient ID: {report.patient_id}. Original report type: {report.report_type}.{text_block}"
    )


def _report_file_path(report: Report) -> Path:
    return resolve_stored_path(report.file_path)


def _gemini_parts(report: Report, path: Path) -> tuple[list[dict[str, Any]], Optional[str], Optional[str]]:
    ext = path.suffix.lower()
    if ext not in SUPPORTED_EXTENSIONS:
        return [], "unsupported", f"Unsupported report format: {ext or 'unknown'}"
    if not path.exists():
        return [], "failed", "Report file was not found on disk."
    size = path.stat().st_size
    if size > MAX_REPORT_BYTES:
        return [], "too_large", f"Report file is too large for AI extraction ({size} bytes)."

    text_content: Optional[str] = None
    inline_part: Optional[dict[str, Any]] = None
    if ext in TEXT_EXTENSIONS:
        text_content = path.read_text(encoding="utf-8", errors="ignore")
    else:
        mime_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        inline_part = {
            "inline_data": {
                "mime_type": mime_type,
                "data": base64.b64encode(path.read_bytes()).decode("ascii"),
            }
        }
    parts: list[dict[str, Any]] = [{"text": _build_prompt(report, text_content)}]
    if inline_part:
        parts.append(inline_part)
    return parts, None, None


def _call_gemini(parts: list[dict[str, Any]], api_key: str) -> str:
    url = GEMINI_URL.format(model=GEMINI_MODEL, key=api_key)
    payload = {
        "contents": [{"role": "user", "parts": parts}],
        "generationConfig": {
            "temperature": 0.0,
            "responseMimeType": "application/json",
        },
    }
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=90) as response:  # noqa: S310 - fixed Google API URL.
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = ""
        try:
            body = exc.read().decode("utf-8", errors="ignore")[:500]
        except Exception:  # noqa: BLE001
            body = ""
        raise ValueError(f"Gemini HTTP {exc.code}: {body or exc.reason}") from exc
    candidates = data.get("candidates") or []
    if not candidates:
        raise ValueError("Gemini returned no candidates")
    parts_out = (((candidates[0] or {}).get("content") or {}).get("parts") or [])
    text = "".join(str(part.get("text") or "") for part in parts_out if isinstance(part, dict)).strip()
    if not text:
        raise ValueError("Gemini returned empty text")
    return text


def extract_report_data(report: Report) -> dict[str, Any]:
    path = _report_file_path(report)
    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    if not api_key:
        return {
            "status": "key_missing",
            "extracted": {},
            "warnings": ["GEMINI_API_KEY is not configured; report was saved without AI extraction."],
        }

    parts, blocked_status, blocked_warning = _gemini_parts(report, path)
    if blocked_status:
        return {"status": blocked_status, "extracted": {}, "warnings": [blocked_warning] if blocked_warning else []}

    try:
        raw = _call_gemini(parts, api_key)
        decoded = _parse_json_response(raw)
        return {"status": "extracted", "extracted": _normalize_payload(decoded), "warnings": []}
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, ValueError, json.JSONDecodeError) as exc:
        log.warning("Report extraction failed for report %s: %s", report.id, exc)
        return {"status": "failed", "extracted": {}, "warnings": [f"AI extraction failed: {exc}"]}


def _has_any(values: dict[str, Any], keys: list[str]) -> bool:
    return any(values.get(key) is not None and values.get(key) != "" for key in keys)


def _apply_extracted_data(report: Report, extracted: dict[str, Any], db: Session) -> tuple[list[dict[str, Any]], list[str]]:
    applied: list[dict[str, Any]] = []
    warnings: list[str] = []
    pid = report.patient_id.strip().upper()
    actor = (report.uploaded_by or "").strip().upper() or None
    date_value = (
        _parse_datetime(extracted.get("collection_date"))
        or _parse_datetime(extracted.get("report_date"))
        or report.report_date
        or datetime.utcnow()
    )

    if not report.report_date and date_value:
        report.report_date = date_value
    if extracted.get("report_type") and extracted.get("report_type") != "other":
        report.report_type = extracted["report_type"]

    lab_values = extracted.get("lab_values") if isinstance(extracted.get("lab_values"), dict) else {}
    if _has_any(
        lab_values,
        [
            "hemoglobin",
            "blood_sugar",
            "blood_sugar_fasting",
            "blood_sugar_post",
            "urine_sugar",
            "urine_protein",
            "thyroid_tsh",
            "iron_level",
            "calcium_level",
            "infection_indicators",
        ],
    ):
        lab = LabTest(
            patient_id=pid,
            test_date=date_value,
            measured_by=actor,
            hemoglobin=lab_values.get("hemoglobin"),
            blood_sugar_fasting=lab_values.get("blood_sugar_fasting") or lab_values.get("blood_sugar"),
            blood_sugar_post=lab_values.get("blood_sugar_post"),
            urine_sugar=normalize_urine_dipstick(lab_values.get("urine_sugar")),
            urine_protein=normalize_urine_dipstick(lab_values.get("urine_protein")),
            thyroid_tsh=lab_values.get("thyroid_tsh"),
            iron_ferritin=lab_values.get("iron_level"),
            calcium=lab_values.get("calcium_level"),
            infection_notes=lab_values.get("infection_indicators"),
            notes=f"AI extracted from report #{report.id}; review before clinical use.",
        )
        db.add(lab)
        db.flush()
        applied.append({"type": "lab_test", "id": lab.id})

    vital_values = extracted.get("vital_values") if isinstance(extracted.get("vital_values"), dict) else {}
    fetal_values = extracted.get("fetal_values") if isinstance(extracted.get("fetal_values"), dict) else {}
    fetal_movement = normalize_fetal_movement(fetal_values.get("fetal_movement"))
    has_vitals = _has_any(
        vital_values,
        ["bp_systolic", "bp_diastolic", "pulse", "temperature", "oxygen_level", "weight_kg", "bmi"],
    ) or fetal_movement is not None
    if has_vitals:
        notes = ["AI extracted from report; review before clinical use."]
        if vital_values.get("oxygen_level") is not None:
            notes.append(f"Oxygen level noted in report: {vital_values['oxygen_level']}")
        if vital_values.get("bmi") is not None:
            notes.append(f"BMI noted in report: {vital_values['bmi']}")
        if fetal_movement:
            notes.append(f"Fetal movement from report: {fetal_movement}")
        metrics = HealthMetrics(
            patient_id=pid,
            measurement_date=date_value,
            weight_kg=vital_values.get("weight_kg"),
            blood_pressure_systolic=vital_values.get("bp_systolic"),
            blood_pressure_diastolic=vital_values.get("bp_diastolic"),
            heart_rate_bpm=vital_values.get("pulse"),
            blood_sugar=lab_values.get("blood_sugar") or lab_values.get("blood_sugar_fasting"),
            temperature_celsius=vital_values.get("temperature"),
            oxygen_saturation=_coerce_float(vital_values.get("oxygen_level")),
            fetal_movement=fetal_movement,
            notes=" ".join(notes),
            measured_by=actor,
        )
        db.add(metrics)
        db.flush()
        applied.append({"type": "health_metrics", "id": metrics.id})

    if _has_any(
        fetal_values,
        [
            "fetal_heartbeat",
            "fetal_weight_g",
            "fetal_movement",
            "head_circumference_cm",
            "femur_length_cm",
            "amniotic_fluid_level",
            "placenta_status",
            "growth_percentile",
        ],
    ):
        mother = db.query(Mother).filter(Mother.patient_id == pid).first()
        pregnant_weeks = current_pregnant_weeks(mother)
        if pregnant_weeks is None:
            warnings.append("Fetal growth values were extracted, but pregnant_weeks is missing for this mother.")
        else:
            notes = ["AI extracted from report; review before clinical use."]
            for label, key in (
                ("Fetal movement", "fetal_movement"),
                ("Placenta", "placenta_status"),
                ("Growth percentile", "growth_percentile"),
            ):
                if fetal_values.get(key) is not None:
                    notes.append(f"{label}: {fetal_values[key]}")
            if extracted.get("abnormalities"):
                notes.append("Abnormalities: " + "; ".join(_as_string_list(extracted.get("abnormalities"))))
            growth = FetalGrowthData(
                patient_id=pid,
                measurement_date=date_value,
                pregnant_weeks=pregnant_weeks,
                fetal_weight_grams=fetal_values.get("fetal_weight_g"),
                heart_rate_bpm=fetal_values.get("fetal_heartbeat"),
                amniotic_fluid_index=fetal_values.get("amniotic_fluid_level"),
                femur_length_cm=fetal_values.get("femur_length_cm"),
                head_circumference_cm=fetal_values.get("head_circumference_cm"),
                notes=" ".join(notes),
                measured_by=actor,
            )
            db.add(growth)
            db.flush()
            applied.append({"type": "fetal_growth", "id": growth.id})

    return applied, warnings


def run_extraction_for_report(report_id: int, db: Session, *, auto_apply: bool = True) -> dict[str, Any]:
    report = db.query(Report).filter(Report.id == report_id).first()
    if report is None:
        raise HTTPException(status_code=404, detail="Report not found")

    result = extract_report_data(report)
    status = result["status"]
    extracted = result.get("extracted") or {}
    warnings = list(result.get("warnings") or [])
    applied: list[dict[str, Any]] = []

    if status == "extracted" and auto_apply:
        applied, apply_warnings = _apply_extracted_data(report, extracted, db)
        warnings.extend(apply_warnings)
        status = "applied" if applied else "needs_review"
    elif status == "extracted":
        status = "needs_review"

    extraction = ReportExtraction(
        report_id=report.id,
        patient_id=report.patient_id,
        extractor="gemini" if status not in {"key_missing", "unsupported", "too_large"} else "none",
        status=status,
        extracted_json=_json_dumps(extracted),
        applied_json=_json_dumps(applied),
        warnings_json=_json_dumps(warnings),
    )
    db.add(extraction)
    db.commit()
    db.refresh(extraction)

    risk = None
    if applied:
        risk = compute_risk(db, report.patient_id, persist=True).as_dict()
    elif status in {"needs_review", "extracted"} and extracted:
        risk = compute_risk(db, report.patient_id).as_dict()

    payload = serialize_report_extraction(extraction)
    payload["risk"] = risk
    payload["ai_diet_context_updated"] = bool(applied)
    return payload


def _save_report(
    db: Session,
    *,
    patient_id: str,
    report_type: str,
    uploaded_by: Optional[str],
    uploader_type: Optional[str],
    report_date: Optional[str],
    notes: Optional[str],
    file: UploadFile,
) -> Report:
    pid = patient_id.strip().upper()
    rtype = (report_type or "other").strip().lower()
    if rtype not in REPORT_TYPES:
        raise HTTPException(status_code=400, detail=f"Invalid report_type. Must be one of: {sorted(REPORT_TYPES)}")
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="File is required")
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in SUPPORTED_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Unsupported file format (jpg/png/webp/pdf/txt/csv/json only)")

    filename = f"{pid}_{rtype}_{uuid4().hex}{ext}"
    target_path = (REPORTS_DIR / filename).resolve()
    with target_path.open("wb") as fp:
        shutil.copyfileobj(file.file, fp)

    parsed_report_date = _parse_datetime(report_date)
    report = Report(
        patient_id=pid,
        report_type=rtype,
        file_path=str(target_path),
        file_name=file.filename,
        uploaded_by=(uploaded_by or "").strip().upper() or None,
        uploader_type=(uploader_type or "").strip().lower() or None,
        report_date=parsed_report_date,
        notes=notes,
    )
    db.add(report)
    db.commit()
    db.refresh(report)
    return report


def upload_report_and_extract(
    patient_id: str = Form(...),
    uploaded_by_id: str | None = Form(default=None),
    uploaded_by_role: str | None = Form(default=None),
    report_type: str = Form(default="other"),
    report_date: str | None = Form(default=None),
    notes: str | None = Form(default=None),
    auto_apply: str = Form(default="true"),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    role = (uploaded_by_role or "").strip().lower() or None
    if role and role not in {"doctor", "health_worker"}:
        raise HTTPException(status_code=400, detail="uploaded_by_role must be doctor or health_worker")
    report = _save_report(
        db,
        patient_id=patient_id,
        report_type=report_type,
        uploaded_by=uploaded_by_id,
        uploader_type=role,
        report_date=report_date,
        notes=notes,
        file=file,
    )
    auto_apply_flag = str(auto_apply or "").strip().lower() in {"1", "true", "yes", "on"}
    extraction = run_extraction_for_report(report.id, db, auto_apply=auto_apply_flag)
    return {"report": _serialize_report(report), "extraction": extraction}


def rerun_report_extraction(report_id: int, db: Session = Depends(get_db)):
    return run_extraction_for_report(report_id, db)


def get_report_extraction(report_id: int, db: Session = Depends(get_db)):
    row = (
        db.query(ReportExtraction)
        .filter(ReportExtraction.report_id == report_id)
        .order_by(ReportExtraction.created_at.desc(), ReportExtraction.id.desc())
        .first()
    )
    if row is None:
        raise HTTPException(status_code=404, detail="Report extraction not found")
    return serialize_report_extraction(row)


def list_mother_report_extractions(patient_id: str, db: Session = Depends(get_db)):
    pid = patient_id.strip().upper()
    rows = (
        db.query(ReportExtraction)
        .filter(ReportExtraction.patient_id == pid)
        .order_by(ReportExtraction.created_at.desc(), ReportExtraction.id.desc())
        .limit(200)
        .all()
    )
    return [serialize_report_extraction(row) for row in rows]


def _serialize_report(report: Report) -> dict[str, Any]:
    return {
        "id": report.id,
        "patient_id": report.patient_id,
        "report_type": report.report_type,
        "file_path": report.file_path,
        "file_name": report.file_name,
        "uploaded_by": report.uploaded_by,
        "uploader_type": report.uploader_type,
        "report_date": _iso(report.report_date),
        "notes": report.notes,
        "created_at": _iso(report.created_at),
    }
