"""
FastAPI endpoints for the AI Personalized Pregnancy Diet System.

Access:
- ``mother``: own profile, today's plan, water/meal logging, feedback.
- ``doctor``: view a patient's nutrition state, add/remove restrictions.

All endpoints are role-checked at the call-site via the ``role`` query/body
parameter so they can be reused easily from the existing Flutter screens
without bolting on a new auth layer (Phase 5 will add proper JWT).
"""
from __future__ import annotations

import json
import logging
from datetime import date, datetime, timedelta
from typing import Optional

from fastapi import Body, Depends, Form, HTTPException, Query
from sqlalchemy.orm import Session

from .database import get_db
from .diet_engine import (
    MEAL_SLOTS,
    compile_constraints,
    generate_daily_plan,
    nutrition_score,
)
from .gemini_diet_assistant import (
    generate_ai_diet_plan,
    latest_ai_diet_plan,
    serialize_ai_plan,
)
from .models import (
    DietPlan,
    DoctorDietRestriction,
    MealCompletion,
    MealTemplate,
    Mother,
    MotherDietProfile,
)

log = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _parse_json_list(value: Optional[str]) -> list[str]:
    if not value:
        return []
    if isinstance(value, list):
        return [str(v) for v in value]
    try:
        data = json.loads(value)
    except json.JSONDecodeError:
        # Allow plain comma-separated strings as a convenience for forms.
        return [v.strip() for v in value.split(",") if v.strip()]
    return [str(v) for v in data] if isinstance(data, list) else []


def _serialize_profile(p: MotherDietProfile) -> dict:
    return {
        "id": p.id,
        "patient_id": p.patient_id,
        "height_cm": p.height_cm,
        "weight_kg": p.weight_kg,
        "bmi": p.bmi,
        "allergies": _parse_json_list(p.allergies),
        "food_preferences": _parse_json_list(p.food_preferences),
        "medical_conditions": _parse_json_list(p.medical_conditions),
        "diet_type": p.diet_type,
        "cuisine": p.cuisine,
        "vitamin_d_level": p.vitamin_d_level,
        "protein_level": p.protein_level,
        "notes": p.notes,
        "updated_at": p.updated_at.isoformat() if p.updated_at else None,
    }


def _serialize_restriction(r: DoctorDietRestriction) -> dict:
    return {
        "id": r.id,
        "patient_id": r.patient_id,
        "doctor_id": r.doctor_id,
        "restricted_foods": _parse_json_list(r.restricted_foods),
        "required_nutrients": _parse_json_list(r.required_nutrients),
        "medical_warnings": _parse_json_list(r.medical_warnings),
        "notes": r.notes,
        "is_active": r.is_active,
        "created_at": r.created_at.isoformat() if r.created_at else None,
    }


def _serialize_plan(plan: DietPlan, completions: Optional[list[MealCompletion]] = None) -> dict:
    try:
        meals = json.loads(plan.meals) if plan.meals else {}
    except json.JSONDecodeError:
        meals = {}
    completion_map = {c.slot: c for c in (completions or [])}
    for slot in MEAL_SLOTS:
        meal = meals.get(slot, {"name": "—"})
        comp = completion_map.get(slot)
        meal["completed"] = bool(comp and comp.completed)
        meal["feedback_rating"] = comp.feedback_rating if comp else None
        meal["feedback_text"] = comp.feedback_text if comp else None
        meals[slot] = meal
    return {
        "id": plan.id,
        "patient_id": plan.patient_id,
        "plan_date": plan.plan_date.isoformat() if plan.plan_date else None,
        "trimester": plan.trimester,
        "meals": meals,
        "daily_calories": plan.daily_calories,
        "daily_protein_g": plan.daily_protein_g,
        "daily_iron_mg": plan.daily_iron_mg,
        "daily_calcium_mg": plan.daily_calcium_mg,
        "daily_carbs_g": plan.daily_carbs_g,
        "daily_fat_g": plan.daily_fat_g,
        "daily_fiber_g": plan.daily_fiber_g,
        "water_goal_ml": plan.water_goal_ml,
        "rationale": plan.rationale,
        "generated_at": plan.generated_at.isoformat() if plan.generated_at else None,
    }


def _ensure_mother_exists(db: Session, patient_id: str) -> Mother:
    pid = patient_id.strip().upper()
    mother = db.query(Mother).filter(Mother.patient_id == pid).first()
    if mother is None:
        raise HTTPException(status_code=404, detail=f"Mother {pid} not found")
    return mother


# ---------------------------------------------------------------------------
# Mother profile
# ---------------------------------------------------------------------------

def get_diet_profile(patient_id: str, db: Session = Depends(get_db)):
    pid = patient_id.strip().upper()
    _ensure_mother_exists(db, pid)
    profile = db.query(MotherDietProfile).filter(MotherDietProfile.patient_id == pid).first()
    if profile is None:
        return {
            "patient_id": pid,
            "exists": False,
            "allergies": [],
            "food_preferences": [],
            "medical_conditions": [],
        }
    return _serialize_profile(profile) | {"exists": True}


def upsert_diet_profile(
    patient_id: str = Form(...),
    height_cm: Optional[float] = Form(None),
    weight_kg: Optional[float] = Form(None),
    allergies: Optional[str] = Form(None),
    food_preferences: Optional[str] = Form(None),
    medical_conditions: Optional[str] = Form(None),
    diet_type: Optional[str] = Form(None),
    cuisine: Optional[str] = Form(None),
    vitamin_d_level: Optional[float] = Form(None),
    protein_level: Optional[float] = Form(None),
    notes: Optional[str] = Form(None),
    db: Session = Depends(get_db),
):
    pid = patient_id.strip().upper()
    _ensure_mother_exists(db, pid)
    profile = db.query(MotherDietProfile).filter(MotherDietProfile.patient_id == pid).first()
    bmi = None
    if height_cm and weight_kg and height_cm > 0:
        h_m = height_cm / 100.0
        bmi = round(weight_kg / (h_m * h_m), 2)

    fields = {
        "height_cm": height_cm,
        "weight_kg": weight_kg,
        "bmi": bmi,
        "allergies": json.dumps(_parse_json_list(allergies)),
        "food_preferences": json.dumps(_parse_json_list(food_preferences)),
        "medical_conditions": json.dumps(_parse_json_list(medical_conditions)),
        "diet_type": diet_type,
        "cuisine": cuisine,
        "vitamin_d_level": vitamin_d_level,
        "protein_level": protein_level,
        "notes": notes,
    }
    if profile is None:
        profile = MotherDietProfile(patient_id=pid, **{k: v for k, v in fields.items() if v is not None})
    else:
        for k, v in fields.items():
            # Allow clearing JSON-encoded lists by sending empty value.
            if k in {"allergies", "food_preferences", "medical_conditions"}:
                setattr(profile, k, v)
            elif v is not None:
                setattr(profile, k, v)
    db.add(profile)
    db.commit()
    db.refresh(profile)

    # Regenerate today's plan so the profile change is reflected immediately.
    try:
        generate_daily_plan(db, pid, force=True)
    except Exception as e:  # noqa: BLE001
        log.warning("Plan regeneration after profile update failed for %s: %s", pid, e)
    return _serialize_profile(profile)


# ---------------------------------------------------------------------------
# Doctor restrictions
# ---------------------------------------------------------------------------

def create_doctor_restriction(
    patient_id: str = Form(...),
    doctor_id: str = Form(...),
    restricted_foods: Optional[str] = Form(None),
    required_nutrients: Optional[str] = Form(None),
    medical_warnings: Optional[str] = Form(None),
    notes: Optional[str] = Form(None),
    db: Session = Depends(get_db),
):
    pid = patient_id.strip().upper()
    did = doctor_id.strip().upper()
    _ensure_mother_exists(db, pid)
    row = DoctorDietRestriction(
        patient_id=pid,
        doctor_id=did,
        restricted_foods=json.dumps(_parse_json_list(restricted_foods)),
        required_nutrients=json.dumps(_parse_json_list(required_nutrients)),
        medical_warnings=json.dumps(_parse_json_list(medical_warnings)),
        notes=notes,
        is_active=True,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    # Regenerate today's plan immediately so the doctor's directive is reflected.
    try:
        generate_daily_plan(db, pid, force=True)
    except Exception as e:  # noqa: BLE001
        log.warning("Plan regeneration after restriction add failed for %s: %s", pid, e)
    return _serialize_restriction(row)


def list_doctor_restrictions(
    patient_id: str,
    active_only: bool = Query(True),
    db: Session = Depends(get_db),
):
    pid = patient_id.strip().upper()
    q = db.query(DoctorDietRestriction).filter(DoctorDietRestriction.patient_id == pid)
    if active_only:
        q = q.filter(DoctorDietRestriction.is_active == True)  # noqa: E712
    rows = q.order_by(DoctorDietRestriction.created_at.desc()).all()
    return [_serialize_restriction(r) for r in rows]


def deactivate_doctor_restriction(
    restriction_id: int,
    db: Session = Depends(get_db),
):
    row = db.query(DoctorDietRestriction).filter(DoctorDietRestriction.id == restriction_id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Restriction not found")
    row.is_active = False
    db.commit()
    try:
        generate_daily_plan(db, row.patient_id, force=True)
    except Exception:
        pass
    return {"id": row.id, "is_active": row.is_active}


# ---------------------------------------------------------------------------
# Plan
# ---------------------------------------------------------------------------

def _completions_for(db: Session, plan: DietPlan) -> list[MealCompletion]:
    return (
        db.query(MealCompletion)
        .filter(MealCompletion.plan_id == plan.id)
        .all()
    )


def get_today_plan(
    patient_id: str,
    db: Session = Depends(get_db),
):
    pid = patient_id.strip().upper()
    _ensure_mother_exists(db, pid)
    plan = generate_daily_plan(db, pid)
    completions = _completions_for(db, plan)
    payload = _serialize_plan(plan, completions)
    payload["score"] = nutrition_score(plan)
    return payload


def regenerate_today_plan(
    patient_id: str = Form(...),
    db: Session = Depends(get_db),
):
    pid = patient_id.strip().upper()
    _ensure_mother_exists(db, pid)
    plan = generate_daily_plan(db, pid, force=True)
    # Wipe today's completions because slots may have changed.
    db.query(MealCompletion).filter(MealCompletion.plan_id == plan.id).delete()
    db.commit()
    payload = _serialize_plan(plan, [])
    payload["score"] = nutrition_score(plan)
    return payload


def generate_ai_assistant_plan(
    patient_id: str = Form(...),
    target_date: Optional[str] = Form(None),
    dislike_feedback: Optional[str] = Form(None),
    db: Session = Depends(get_db),
):
    pid = patient_id.strip().upper()
    _ensure_mother_exists(db, pid)
    parsed_date: Optional[date] = None
    if target_date:
        try:
            parsed_date = date.fromisoformat(target_date)
        except ValueError as error:
            raise HTTPException(status_code=400, detail="target_date must be YYYY-MM-DD") from error
    plan = generate_ai_diet_plan(db, pid, parsed_date, dislike_feedback=dislike_feedback)
    return serialize_ai_plan(plan)


def get_latest_ai_assistant_plan(
    patient_id: str,
    db: Session = Depends(get_db),
):
    """Return the most recent saved AI plan only — does not call Gemini (use POST /generate)."""
    pid = patient_id.strip().upper()
    _ensure_mother_exists(db, pid)
    plan = latest_ai_diet_plan(db, pid)
    if plan is None:
        raise HTTPException(status_code=404, detail="No AI diet plan generated yet")
    return serialize_ai_plan(plan)


def get_plan_for_date(
    patient_id: str,
    target_date: str = Query(..., description="YYYY-MM-DD"),
    db: Session = Depends(get_db),
):
    pid = patient_id.strip().upper()
    try:
        d = date.fromisoformat(target_date)
    except ValueError:
        raise HTTPException(status_code=400, detail="target_date must be YYYY-MM-DD")
    day_start = datetime(d.year, d.month, d.day)
    plan = (
        db.query(DietPlan)
        .filter(DietPlan.patient_id == pid, DietPlan.plan_date == day_start)
        .first()
    )
    if plan is None:
        raise HTTPException(status_code=404, detail="No plan for that date")
    completions = _completions_for(db, plan)
    payload = _serialize_plan(plan, completions)
    payload["score"] = nutrition_score(plan)
    return payload


def mark_meal_complete(
    plan_id: int = Form(...),
    slot: str = Form(...),
    completed: bool = Form(True),
    feedback_rating: Optional[int] = Form(None),
    feedback_text: Optional[str] = Form(None),
    db: Session = Depends(get_db),
):
    slot_norm = slot.strip().lower()
    if slot_norm not in MEAL_SLOTS:
        raise HTTPException(status_code=400, detail=f"Unknown slot {slot}")
    plan = db.query(DietPlan).filter(DietPlan.id == plan_id).first()
    if plan is None:
        raise HTTPException(status_code=404, detail="Plan not found")
    row = (
        db.query(MealCompletion)
        .filter(MealCompletion.plan_id == plan_id, MealCompletion.slot == slot_norm)
        .first()
    )
    if row is None:
        row = MealCompletion(
            patient_id=plan.patient_id,
            plan_id=plan.id,
            plan_date=plan.plan_date,
            slot=slot_norm,
            completed=completed,
            feedback_rating=feedback_rating,
            feedback_text=feedback_text,
        )
        db.add(row)
    else:
        row.completed = completed
        if feedback_rating is not None:
            row.feedback_rating = feedback_rating
        if feedback_text is not None:
            row.feedback_text = feedback_text
        row.completed_at = datetime.utcnow()
    db.commit()
    db.refresh(row)
    return {
        "plan_id": row.plan_id,
        "slot": row.slot,
        "completed": row.completed,
        "feedback_rating": row.feedback_rating,
        "feedback_text": row.feedback_text,
    }


# ---------------------------------------------------------------------------
# Doctor / oversight views
# ---------------------------------------------------------------------------

def doctor_patient_diet_summary(
    patient_id: str,
    db: Session = Depends(get_db),
):
    pid = patient_id.strip().upper()
    _ensure_mother_exists(db, pid)
    plan = generate_daily_plan(db, pid)
    profile = db.query(MotherDietProfile).filter(MotherDietProfile.patient_id == pid).first()
    restrictions = (
        db.query(DoctorDietRestriction)
        .filter(DoctorDietRestriction.patient_id == pid, DoctorDietRestriction.is_active == True)  # noqa: E712
        .order_by(DoctorDietRestriction.created_at.desc())
        .all()
    )
    constraints = compile_constraints(db, pid)

    # 7-day adherence
    week_start = datetime.utcnow().date() - timedelta(days=6)
    week_start_dt = datetime(week_start.year, week_start.month, week_start.day)
    completions = (
        db.query(MealCompletion)
        .filter(MealCompletion.patient_id == pid, MealCompletion.plan_date >= week_start_dt)
        .all()
    )
    total_completions = sum(1 for c in completions if c.completed)
    adherence_pct = round(min(100, (total_completions / (7 * len(MEAL_SLOTS))) * 100))

    score = nutrition_score(plan)
    deficiencies: list[str] = []
    if score["components"].get("iron", 100) < 60:
        deficiencies.append("Iron below 60% of target")
    if score["components"].get("calcium", 100) < 60:
        deficiencies.append("Calcium below 60% of target")
    if score["components"].get("protein", 100) < 60:
        deficiencies.append("Protein below 60% of target")

    return {
        "patient_id": pid,
        "profile": _serialize_profile(profile) if profile else None,
        "today_plan": _serialize_plan(plan, _completions_for(db, plan)),
        "score": score,
        "active_restrictions": [_serialize_restriction(r) for r in restrictions],
        "constraints": {
            "trimester": constraints.trimester,
            "required_tags": constraints.required_tags,
            "forbidden_tags": constraints.forbidden_tags,
            "allergies": constraints.allergies,
            "rationale": constraints.rationale,
        },
        "adherence_pct_7d": adherence_pct,
        "deficiency_alerts": deficiencies,
    }


def list_meal_templates(
    slot: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    q = db.query(MealTemplate).filter(MealTemplate.is_active == True)  # noqa: E712
    if slot:
        q = q.filter(MealTemplate.slot == slot.strip().lower())
    rows = q.order_by(MealTemplate.slot, MealTemplate.name).all()
    return [
        {
            "id": r.id,
            "slot": r.slot,
            "name": r.name,
            "description": r.description,
            "portion": r.portion,
            "calories": r.calories,
            "protein_g": r.protein_g,
            "iron_mg": r.iron_mg,
            "calcium_mg": r.calcium_mg,
            "tags": _parse_json_list(r.tags),
            "allergens": _parse_json_list(r.allergens),
            "diet_type": r.diet_type,
            "cuisine": r.cuisine,
        }
        for r in rows
    ]
