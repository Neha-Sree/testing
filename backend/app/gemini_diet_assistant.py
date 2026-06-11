"""Gemini-backed pregnancy diet assistant with deterministic safe fallback."""
from __future__ import annotations

from . import env as _env  # noqa: F401 — ensure GEMINI_API_KEY from backend/.env

import json
import logging
import os
import re
import urllib.error
import urllib.request
from datetime import date, datetime
from typing import Any, Optional

from sqlalchemy.orm import Session

from .diet_engine import MEAL_SLOTS, generate_daily_plan, _trimester_from_weeks
from .models import (
    AiDietAssistantPlan,
    DoctorDietRestriction,
    HealthMetrics,
    LabTest,
    Mother,
    MotherDietProfile,
    Report,
    RiskAssessment,
    SymptomLog,
)

log = logging.getLogger(__name__)

GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}"

_DEFAULT_WARNINGS = [
    "Educational support only; not a replacement for doctor advice.",
    "Avoid alcohol, raw seafood, unpasteurized dairy, high-mercury fish, and excessive caffeine during pregnancy.",
    "Contact a doctor or emergency service for bleeding, severe headache, chest pain, severe abdominal pain, seizures, fainting, or reduced fetal movements.",
]


def _safe_json_list(value: Optional[str]) -> list[str]:
    if not value:
        return []
    try:
        data = json.loads(value)
    except (json.JSONDecodeError, TypeError):
        return [v.strip() for v in str(value).split(",") if v.strip()]
    if isinstance(data, list):
        return [str(v) for v in data]
    return []


def _iso(value: Any) -> Optional[str]:
    return value.isoformat() if hasattr(value, "isoformat") else None


def _row_dict(row: Any, fields: list[str]) -> Optional[dict[str, Any]]:
    if row is None:
        return None
    payload: dict[str, Any] = {}
    for field in fields:
        value = getattr(row, field, None)
        payload[field] = _iso(value) if isinstance(value, datetime) else value
    return payload


def _merge_allergies(mother: Optional[Mother], profile: Optional[MotherDietProfile]) -> list[str]:
    merged: list[str] = []
    if mother and mother.allergies:
        merged.extend(_safe_json_list(mother.allergies) if mother.allergies.strip().startswith("[") else [v.strip() for v in mother.allergies.split(",") if v.strip()])
    if profile:
        merged.extend(_safe_json_list(profile.allergies))
    seen: set[str] = set()
    out: list[str] = []
    for item in merged:
        key = item.strip().lower()
        if key and key not in seen:
            seen.add(key)
            out.append(item.strip())
    return out


def _complications(profile: Optional[MotherDietProfile], risk: Optional[RiskAssessment]) -> list[str]:
    items: list[str] = []
    if profile:
        items.extend(_safe_json_list(profile.medical_conditions))
    if risk:
        items.extend(_safe_json_list(risk.reasons))
    seen: set[str] = set()
    out: list[str] = []
    for item in items:
        key = item.strip().lower()
        if key and key not in seen:
            seen.add(key)
            out.append(item.strip())
    return out


def collect_patient_context(db: Session, patient_id: str) -> dict[str, Any]:
    pid = patient_id.strip().upper()
    mother = db.query(Mother).filter(Mother.patient_id == pid).first()
    profile = db.query(MotherDietProfile).filter(MotherDietProfile.patient_id == pid).first()
    latest_metrics = (
        db.query(HealthMetrics)
        .filter(HealthMetrics.patient_id == pid)
        .order_by(HealthMetrics.measurement_date.desc(), HealthMetrics.created_at.desc())
        .first()
    )
    latest_lab = (
        db.query(LabTest)
        .filter(LabTest.patient_id == pid)
        .order_by(LabTest.test_date.desc(), LabTest.created_at.desc())
        .first()
    )
    restrictions = (
        db.query(DoctorDietRestriction)
        .filter(DoctorDietRestriction.patient_id == pid, DoctorDietRestriction.is_active == True)  # noqa: E712
        .order_by(DoctorDietRestriction.created_at.desc())
        .limit(10)
        .all()
    )
    symptoms = (
        db.query(SymptomLog)
        .filter(SymptomLog.patient_id == pid)
        .order_by(SymptomLog.logged_at.desc())
        .limit(5)
        .all()
    )
    reports = (
        db.query(Report)
        .filter(Report.patient_id == pid)
        .order_by(Report.created_at.desc())
        .limit(5)
        .all()
    )
    risk = (
        db.query(RiskAssessment)
        .filter(RiskAssessment.patient_id == pid)
        .order_by(RiskAssessment.computed_at.desc())
        .first()
    )

    pregnant_weeks = mother.pregnant_weeks if mother else None
    trimester = _trimester_from_weeks(pregnant_weeks)
    allergies = _merge_allergies(mother, profile)
    complications = _complications(profile, risk)

    return {
        "patient_id": pid,
        "trimester": trimester,
        "pregnant_weeks": pregnant_weeks,
        "allergies": allergies,
        "complications": complications,
        "mother": _row_dict(
            mother,
            [
                "full_name",
                "age",
                "weight_kg",
                "blood_group",
                "pregnant_weeks",
                "due_date",
                "allergies",
                "doctor_id",
            ],
        ),
        "diet_profile": None
        if profile is None
        else {
            "height_cm": profile.height_cm,
            "weight_kg": profile.weight_kg,
            "bmi": profile.bmi,
            "allergies": _safe_json_list(profile.allergies),
            "food_preferences": _safe_json_list(profile.food_preferences),
            "medical_conditions": _safe_json_list(profile.medical_conditions),
            "diet_type": profile.diet_type,
            "cuisine": profile.cuisine,
            "vitamin_d_level": profile.vitamin_d_level,
            "protein_level": profile.protein_level,
            "notes": profile.notes,
        },
        "latest_health_metrics": _row_dict(
            latest_metrics,
            [
                "measurement_date",
                "weight_kg",
                "blood_pressure_systolic",
                "blood_pressure_diastolic",
                "heart_rate_bpm",
                "blood_sugar",
                "temperature_celsius",
                "oxygen_saturation",
                "fetal_movement",
                "swelling",
                "notes",
                "measured_by",
            ],
        ),
        "latest_lab_test": _row_dict(
            latest_lab,
            [
                "test_date",
                "hemoglobin",
                "blood_sugar_fasting",
                "blood_sugar_post",
                "urine_sugar",
                "urine_protein",
                "thyroid_tsh",
                "iron_ferritin",
                "calcium",
                "infection_notes",
                "notes",
                "measured_by",
            ],
        ),
        "doctor_restrictions": [
            {
                "restricted_foods": _safe_json_list(r.restricted_foods),
                "required_nutrients": _safe_json_list(r.required_nutrients),
                "medical_warnings": _safe_json_list(r.medical_warnings),
                "notes": r.notes,
                "doctor_id": r.doctor_id,
            }
            for r in restrictions
        ],
        "recent_symptoms": [
            {
                "symptom_text": s.symptom_text,
                "severity": s.severity,
                "notes": s.notes,
                "logged_at": _iso(s.logged_at),
            }
            for s in symptoms
        ],
        "recent_reports": [
            {
                "report_type": r.report_type,
                "file_name": r.file_name,
                "notes": r.notes,
                "report_date": _iso(r.report_date),
                "uploaded_by": r.uploaded_by,
                "uploader_type": r.uploader_type,
            }
            for r in reports
        ],
        "latest_risk": None
        if risk is None
        else {
            "level": risk.level,
            "score": risk.score,
            "reasons": _safe_json_list(risk.reasons),
            "computed_at": _iso(risk.computed_at),
        },
    }


def _build_prompt(context: dict[str, Any], *, dislike_feedback: Optional[str] = None, previous_plan: Optional[dict[str, Any]] = None) -> str:
    feedback_block = ""
    if dislike_feedback:
        feedback_block = (
            f"\nThe mother did not like the previous plan. Her feedback: {dislike_feedback.strip()}\n"
            "Generate a clearly different plan that still respects all safety rules, allergies, complications, "
            "trimester needs, and latest blood levels.\n"
        )
    if previous_plan:
        feedback_block += f"\nPrevious plan summary (avoid repeating the same meals):\n{json.dumps(previous_plan, ensure_ascii=True, default=str)[:4000]}\n"

    trimester = context.get("trimester")
    weeks = context.get("pregnant_weeks")
    return (
        "You are a cautious pregnancy nutrition assistant for a maternal-healthcare app. "
        "Create an educational diet plan customized for the mother's current trimester, latest blood/lab levels "
        "entered by the health worker, stated allergies, medical complications/conditions, food preferences, "
        "and doctor restrictions.\n\n"
        f"Current trimester: {trimester} (gestational weeks: {weeks}). "
        "Adjust meal choices and nutrient emphasis for this trimester.\n"
        "If hemoglobin/iron is low, emphasize iron-rich safe foods. If blood sugar is high, favor low-GI meals. "
        "If calcium is low, emphasize calcium-rich options. Never contradict doctor restrictions.\n\n"
        "Safety rules: respect all doctor restrictions and allergies; avoid unsafe pregnancy foods such as raw seafood, "
        "undercooked eggs/meat, unpasteurized dairy, high-mercury fish, alcohol, and excessive caffeine; do not diagnose; "
        "include doctor questions for high-risk or abnormal data; advise urgent care for red flags.\n\n"
        f"{feedback_block}"
        "Return JSON only, no markdown. Required schema:\n"
        "{\n"
        '  "meals": {\n'
        '    "breakfast": {"name": "", "portion": "", "rationale": "", "calories": 0, "nutrients_focus": []},\n'
        '    "mid_morning": {"name": "", "portion": "", "rationale": "", "calories": 0, "nutrients_focus": []},\n'
        '    "lunch": {"name": "", "portion": "", "rationale": "", "calories": 0, "nutrients_focus": []},\n'
        '    "evening_snack": {"name": "", "portion": "", "rationale": "", "calories": 0, "nutrients_focus": []},\n'
        '    "dinner": {"name": "", "portion": "", "rationale": "", "calories": 0, "nutrients_focus": []},\n'
        '    "bedtime": {"name": "", "portion": "", "rationale": "", "calories": 0, "nutrients_focus": []}\n'
        "  },\n"
        '  "hydration_recommendation": "",\n'
        '  "warnings": [],\n'
        '  "questions_for_doctor": [],\n'
        '  "rationale": "",\n'
        '  "daily_calories_estimate": 0\n'
        "}\n\n"
        f"Patient context JSON:\n{json.dumps(context, ensure_ascii=True, default=str)}"
    )


def _strip_markdown_json(text: str) -> str:
    cleaned = text.strip()
    fence = re.search(r"```(?:json)?\s*(.*?)```", cleaned, flags=re.IGNORECASE | re.DOTALL)
    if fence:
        cleaned = fence.group(1).strip()
    if not cleaned.startswith("{"):
        start = cleaned.find("{")
        end = cleaned.rfind("}")
        if start >= 0 and end > start:
            cleaned = cleaned[start : end + 1]
    return cleaned


def _as_string_list(value: Any) -> list[str]:
    if isinstance(value, list):
        return [str(v) for v in value if str(v).strip()]
    if value is None:
        return []
    return [str(value)]


def _validate_ai_payload(payload: dict[str, Any]) -> dict[str, Any]:
    meals_in = payload.get("meals")
    if not isinstance(meals_in, dict):
        raise ValueError("missing meals object")

    meals: dict[str, dict[str, Any]] = {}
    for slot in MEAL_SLOTS:
        item = meals_in.get(slot)
        if not isinstance(item, dict):
            raise ValueError(f"missing meal slot {slot}")
        name = str(item.get("name") or "").strip()
        if not name:
            raise ValueError(f"missing meal name for {slot}")
        calories_raw = item.get("calories", 0)
        try:
            calories = int(float(calories_raw or 0))
        except (TypeError, ValueError):
            calories = 0
        meals[slot] = {
            "name": name,
            "portion": str(item.get("portion") or "").strip(),
            "rationale": str(item.get("rationale") or item.get("description") or "").strip(),
            "calories": calories,
            "nutrients_focus": _as_string_list(item.get("nutrients_focus")),
        }

    warnings = _as_string_list(payload.get("warnings"))
    for warning in _DEFAULT_WARNINGS:
        if warning not in warnings:
            warnings.append(warning)

    try:
        daily_calories = int(float(payload.get("daily_calories_estimate") or 0))
    except (TypeError, ValueError):
        daily_calories = sum((m.get("calories") or 0) for m in meals.values())

    return {
        "meals": meals,
        "hydration_recommendation": str(payload.get("hydration_recommendation") or "Aim for small, frequent water intake through the day unless your doctor has restricted fluids.").strip(),
        "warnings": warnings,
        "questions_for_doctor": _as_string_list(payload.get("questions_for_doctor")),
        "rationale": str(payload.get("rationale") or "Plan based on available pregnancy profile, latest health-worker data, and diet safety rules.").strip(),
        "daily_calories_estimate": daily_calories,
    }


def _call_gemini(prompt: str, api_key: str) -> str:
    url = GEMINI_URL.format(model=GEMINI_MODEL, key=api_key)
    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.25,
            "responseMimeType": "application/json",
        },
    }
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=60) as response:  # noqa: S310 - Google API URL is fixed above.
        data = json.loads(response.read().decode("utf-8"))
    candidates = data.get("candidates") or []
    if not candidates:
        raise ValueError("Gemini returned no candidates")
    parts = (((candidates[0] or {}).get("content") or {}).get("parts") or [])
    text = "".join(str(part.get("text") or "") for part in parts if isinstance(part, dict)).strip()
    if not text:
        raise ValueError("Gemini returned empty text")
    return text


def _fallback_payload(db: Session, patient_id: str, target_date: date, reason: str) -> dict[str, Any]:
    plan = generate_daily_plan(db, patient_id, target_date, force=True)
    try:
        meals_in = json.loads(plan.meals) if plan.meals else {}
    except json.JSONDecodeError:
        meals_in = {}

    meals: dict[str, dict[str, Any]] = {}
    for slot in MEAL_SLOTS:
        meal = meals_in.get(slot) if isinstance(meals_in, dict) else {}
        if not isinstance(meal, dict):
            meal = {}
        tags = meal.get("tags") if isinstance(meal.get("tags"), list) else []
        meals[slot] = {
            "name": str(meal.get("name") or "Safe pregnancy meal"),
            "portion": str(meal.get("portion") or ""),
            "rationale": str(meal.get("description") or plan.rationale or "Rule-based pregnancy diet fallback."),
            "calories": int(meal.get("calories") or 0),
            "nutrients_focus": [str(t).replace("_", " ") for t in tags[:4]],
        }
    return {
        "meals": meals,
        "hydration_recommendation": f"Aim for about {plan.water_goal_ml} ml water today unless your doctor advised a different fluid limit.",
        "warnings": list(_DEFAULT_WARNINGS),
        "questions_for_doctor": [
            "Ask your doctor if any lab value or symptom needs a special diet change.",
        ],
        "rationale": plan.rationale or "Safe rule-based pregnancy diet generated from available patient data.",
        "daily_calories_estimate": plan.daily_calories,
        "fallback_reason": reason,
    }


def _persist_plan(
    db: Session,
    patient_id: str,
    target_date: date,
    payload: dict[str, Any],
    context: dict[str, Any],
    source: str,
    fallback_reason: Optional[str] = None,
) -> AiDietAssistantPlan:
    day_start = datetime(target_date.year, target_date.month, target_date.day)
    row = (
        db.query(AiDietAssistantPlan)
        .filter(AiDietAssistantPlan.patient_id == patient_id, AiDietAssistantPlan.plan_date == day_start)
        .first()
    )
    if row is None:
        row = AiDietAssistantPlan(patient_id=patient_id, plan_date=day_start)
        db.add(row)
    row.source = source
    row.model_name = GEMINI_MODEL if source == "gemini" else None
    row.meals = json.dumps(payload["meals"])
    row.hydration_recommendation = payload["hydration_recommendation"]
    row.warnings = json.dumps(payload["warnings"])
    row.questions_for_doctor = json.dumps(payload["questions_for_doctor"])
    row.rationale = payload["rationale"]
    row.context_summary = json.dumps(
        {
            "latest_health_metrics": context.get("latest_health_metrics"),
            "latest_lab_test": context.get("latest_lab_test"),
            "latest_risk": context.get("latest_risk"),
            "recent_symptoms_count": len(context.get("recent_symptoms") or []),
            "recent_reports_count": len(context.get("recent_reports") or []),
        }
    )
    row.fallback_reason = fallback_reason
    row.daily_calories_estimate = payload.get("daily_calories_estimate")
    row.generated_at = datetime.utcnow()
    db.commit()
    db.refresh(row)
    return row


def serialize_ai_plan(row: AiDietAssistantPlan) -> dict[str, Any]:
    def loads(value: Optional[str], default: Any) -> Any:
        if not value:
            return default
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return default

    return {
        "id": row.id,
        "patient_id": row.patient_id,
        "plan_date": row.plan_date.isoformat() if row.plan_date else None,
        "source": row.source,
        "model_name": row.model_name,
        "meals": loads(row.meals, {}),
        "hydration_recommendation": row.hydration_recommendation,
        "warnings": loads(row.warnings, []),
        "questions_for_doctor": loads(row.questions_for_doctor, []),
        "rationale": row.rationale,
        "context_summary": loads(row.context_summary, {}),
        "fallback_reason": row.fallback_reason,
        "daily_calories_estimate": row.daily_calories_estimate,
        "generated_at": row.generated_at.isoformat() if row.generated_at else None,
        "message": (
            "AI key not configured; showing safe rule-based pregnancy diet plan."
            if row.source != "gemini" and row.fallback_reason == "GEMINI_API_KEY not configured"
            else (
                f"Gemini was unavailable; showing safe rule-based plan. ({row.fallback_reason})"
                if row.source != "gemini" and row.fallback_reason
                else None
            )
        ),
    }


def generate_ai_diet_plan(
    db: Session,
    patient_id: str,
    target_date: Optional[date] = None,
    *,
    dislike_feedback: Optional[str] = None,
) -> AiDietAssistantPlan:
    pid = patient_id.strip().upper()
    target = target_date or datetime.utcnow().date()
    context = collect_patient_context(db, pid)
    previous = latest_ai_diet_plan(db, pid)
    previous_summary = None
    if previous and previous.meals:
        try:
            previous_summary = {
                "meals": json.loads(previous.meals),
                "rationale": previous.rationale,
            }
        except json.JSONDecodeError:
            previous_summary = None

    api_key = os.getenv("GEMINI_API_KEY", "").strip()

    if not api_key:
        reason = "GEMINI_API_KEY not configured"
        payload = _fallback_payload(db, pid, target, reason)
        return _persist_plan(db, pid, target, payload, context, "rule_based_fallback", reason)

    try:
        raw = _call_gemini(
            _build_prompt(
                context,
                dislike_feedback=dislike_feedback,
                previous_plan=previous_summary if dislike_feedback else None,
            ),
            api_key,
        )
        decoded = json.loads(_strip_markdown_json(raw))
        if not isinstance(decoded, dict):
            raise ValueError("Gemini JSON root was not an object")
        payload = _validate_ai_payload(decoded)
        return _persist_plan(db, pid, target, payload, context, "gemini")
    except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError, ValueError, TimeoutError) as exc:
        reason = f"Gemini unavailable or invalid response: {exc}"
        log.warning("Gemini diet assistant fallback for %s: %s", pid, exc)
        payload = _fallback_payload(db, pid, target, reason)
        return _persist_plan(db, pid, target, payload, context, "rule_based_fallback", reason)


def latest_ai_diet_plan(db: Session, patient_id: str) -> Optional[AiDietAssistantPlan]:
    pid = patient_id.strip().upper()
    return (
        db.query(AiDietAssistantPlan)
        .filter(AiDietAssistantPlan.patient_id == pid)
        .order_by(AiDietAssistantPlan.generated_at.desc(), AiDietAssistantPlan.id.desc())
        .first()
    )
