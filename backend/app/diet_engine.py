"""
Rule-based pregnancy diet generation engine.

Generates a deterministic daily meal plan for a mother by combining:

1.  **Trimester** derived from the mother's ``pregnant_weeks``.
2.  **Latest lab values** (``LabTest``) and **vitals** (``HealthMetrics``).
3.  **Diet profile** (``MotherDietProfile``) — allergies, food preferences,
    medical conditions, diet type (veg/non-veg/vegan) and cuisine.
4.  **Mother.allergies** — the allergies field set at onboarding.
5.  **Active doctor restrictions** (``DoctorDietRestriction``) — restricted
    foods/tags, required nutrients and medical warnings.

The engine is intentionally deterministic: given the same inputs and date it
produces the same plan, so a mother sees a stable plan for "today" but a fresh
plan tomorrow. No LLM is involved; results are auditable.
"""
from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Iterable, Optional

from sqlalchemy.orm import Session

from .models import (
    DietPlan,
    DoctorDietRestriction,
    HealthMetrics,
    LabTest,
    MealTemplate,
    Mother,
    MotherDietProfile,
)
from .pregnancy_utils import current_pregnant_weeks

log = logging.getLogger(__name__)


MEAL_SLOTS: tuple[str, ...] = (
    "breakfast",
    "mid_morning",
    "lunch",
    "evening_snack",
    "dinner",
    "bedtime",
)


# Per-trimester nutrient targets (rough, illustrative — not medical advice).
_TRIMESTER_TARGETS: dict[int, dict[str, float]] = {
    1: {"calories": 1900, "protein_g": 70, "iron_mg": 27, "calcium_mg": 1000},
    2: {"calories": 2200, "protein_g": 85, "iron_mg": 27, "calcium_mg": 1000},
    3: {"calories": 2400, "protein_g": 100, "iron_mg": 27, "calcium_mg": 1200},
}

# Canonical allergen synonyms — any of the keys map to the canonical value
# so user-entered "milk" or "lactose" both match template allergen "dairy".
_ALLERGEN_SYNONYMS: dict[str, str] = {
    "milk": "dairy",
    "lactose": "dairy",
    "cheese": "dairy",
    "curd": "dairy",
    "paneer": "dairy",
    "butter": "dairy",
    "cream": "dairy",
    "ghee": "dairy",
    "egg": "eggs",
    "wheat": "gluten",
    "maida": "gluten",
    "atta": "gluten",
    "bread": "gluten",
    "roti": "gluten",
    "peanut": "nuts",
    "peanuts": "nuts",
    "almond": "nuts",
    "almonds": "nuts",
    "cashew": "nuts",
    "cashews": "nuts",
    "walnut": "nuts",
    "walnuts": "nuts",
    "pistachio": "nuts",
    "pistachios": "nuts",
    "tree_nut": "nuts",
    "tree_nuts": "nuts",
    "groundnut": "nuts",
    "shellfish": "fish",
    "seafood": "fish",
    "prawn": "fish",
    "shrimp": "fish",
    "tuna": "fish",
    "salmon": "fish",
    "tofu": "soy",
    "soya": "soy",
    "soybean": "soy",
    "soymilk": "soy",
}


@dataclass
class DietConstraints:
    trimester: int
    diet_type: str = "veg"
    cuisine: str = "indian"
    allergies: list[str] = field(default_factory=list)
    forbidden_tags: list[str] = field(default_factory=list)
    # Hard medical required tags (e.g. low_gi for diabetes)
    required_tags: list[str] = field(default_factory=list)
    # Soft preferred tags (trimester, light, etc.)
    preferred_tags: list[str] = field(default_factory=list)
    rationale: list[str] = field(default_factory=list)
    targets: dict[str, float] = field(default_factory=dict)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _safe_json_list(value: Optional[str]) -> list[str]:
    if not value:
        return []
    try:
        data = json.loads(value)
    except json.JSONDecodeError:
        return []
    if isinstance(data, list):
        return [str(v) for v in data]
    return []


def _trimester_from_weeks(weeks: Optional[int]) -> int:
    if weeks is None:
        return 1
    if weeks <= 13:
        return 1
    if weeks <= 27:
        return 2
    return 3


def _normalize(values: Iterable[str]) -> list[str]:
    return [v.strip().lower().replace(" ", "_") for v in values if v and v.strip()]


def _normalize_allergies(raw_values: Iterable[str]) -> list[str]:
    """Normalize allergen names to canonical forms and deduplicate.

    Common aliases like 'milk' -> 'dairy', 'peanut' -> 'nuts', etc.
    are resolved so template allergen matching is reliable regardless
    of how the user entered their allergy.
    """
    result: list[str] = []
    seen: set[str] = set()
    for v in raw_values:
        normalized = v.strip().lower().replace(" ", "_")
        if not normalized:
            continue
        canonical = _ALLERGEN_SYNONYMS.get(normalized, normalized)
        if canonical not in seen:
            seen.add(canonical)
            result.append(canonical)
    return result


def _parse_free_allergies(raw: str) -> list[str]:
    """Parse allergies stored as either a JSON list or a comma-separated string."""
    raw = raw.strip()
    if raw.startswith("["):
        return _safe_json_list(raw)
    return [v.strip() for v in raw.split(",") if v.strip()]


# ---------------------------------------------------------------------------
# Constraint compilation
# ---------------------------------------------------------------------------

def compile_constraints(db: Session, patient_id: str) -> DietConstraints:
    pid = patient_id.strip().upper()
    mother = db.query(Mother).filter(Mother.patient_id == pid).first()
    profile = db.query(MotherDietProfile).filter(MotherDietProfile.patient_id == pid).first()
    latest_lab = (
        db.query(LabTest)
        .filter(LabTest.patient_id == pid)
        .order_by(LabTest.test_date.desc())
        .first()
    )
    latest_metrics = (
        db.query(HealthMetrics)
        .filter(HealthMetrics.patient_id == pid)
        .order_by(HealthMetrics.measurement_date.desc())
        .first()
    )
    active_restrictions = (
        db.query(DoctorDietRestriction)
        .filter(DoctorDietRestriction.patient_id == pid, DoctorDietRestriction.is_active == True)  # noqa: E712
        .order_by(DoctorDietRestriction.created_at.desc())
        .all()
    )

    trimester = _trimester_from_weeks(current_pregnant_weeks(mother))
    constraints = DietConstraints(
        trimester=trimester,
        diet_type=(profile.diet_type if profile and profile.diet_type else "veg"),
        cuisine=(profile.cuisine if profile and profile.cuisine else "indian"),
        targets=dict(_TRIMESTER_TARGETS[trimester]),
    )

    # Trimester tag — kept in preferred_tags (not required) so the engine
    # strongly prefers trimester-matched meals but can fall back gracefully.
    constraints.preferred_tags.append(f"trimester_{trimester}")
    constraints.rationale.append(
        f"Trimester {trimester} based on {current_pregnant_weeks(mother) if mother else '?'} weeks"
    )

    # ---- Allergies: merge Mother.allergies + MotherDietProfile.allergies ----
    all_allergy_raw: list[str] = []
    if mother and mother.allergies:
        all_allergy_raw.extend(_parse_free_allergies(mother.allergies))
    if profile and profile.allergies:
        all_allergy_raw.extend(_safe_json_list(profile.allergies))
    constraints.allergies = _normalize_allergies(all_allergy_raw)

    if constraints.allergies:
        constraints.rationale.append(f"Allergies excluded: {', '.join(constraints.allergies)}")

    # ---- Medical conditions (from diet profile) ----------------------------
    if profile:
        conds = _normalize(_safe_json_list(profile.medical_conditions))
        if conds:
            constraints.rationale.append(f"Medical conditions: {', '.join(conds)}")
        if "gestational_diabetes" in conds or "diabetes" in conds:
            constraints.required_tags.append("low_gi")
            constraints.forbidden_tags.extend(["high_sugar", "sweet"])
        if "high_bp" in conds or "hypertension" in conds:
            constraints.required_tags.append("low_sodium")
            constraints.forbidden_tags.append("high_sodium")
        if "thyroid" in conds:
            constraints.required_tags.append("iodine_rich")
        if "anemia" in conds:
            constraints.required_tags.append("high_iron")
        if "morning_sickness" in conds:
            constraints.preferred_tags.append("light")
            constraints.forbidden_tags.append("heavy_oily")
        if "obesity" in conds:
            constraints.required_tags.append("low_calorie")
        if "underweight" in conds:
            constraints.required_tags.append("high_calorie")
        if "vitamin_deficiency" in conds:
            constraints.preferred_tags.append("vitamin_rich")

    # ---- Lab values --------------------------------------------------------
    if latest_lab:
        if latest_lab.hemoglobin is not None and latest_lab.hemoglobin < 11.0:
            constraints.required_tags.append("high_iron")
            constraints.rationale.append(
                f"Low Hb {latest_lab.hemoglobin} g/dL → prioritising iron-rich meals"
            )
        if latest_lab.calcium is not None and latest_lab.calcium < 8.5:
            constraints.required_tags.append("high_calcium")
            constraints.rationale.append(
                f"Low calcium {latest_lab.calcium} mg/dL → calcium-rich meals"
            )
        if latest_lab.blood_sugar_fasting is not None and latest_lab.blood_sugar_fasting >= 100:
            constraints.required_tags.append("low_gi")
            constraints.forbidden_tags.extend(["high_sugar", "sweet"])
            constraints.rationale.append("Elevated fasting sugar → low-GI plan")
        if latest_lab.iron_ferritin is not None and latest_lab.iron_ferritin < 15:
            constraints.required_tags.append("high_iron")
        if latest_lab.urine_protein and latest_lab.urine_protein.strip().lower() not in {
            "", "neg", "negative", "trace"
        }:
            constraints.required_tags.append("low_sodium")
            constraints.rationale.append("Proteinuria detected → low-sodium meals")

    if (
        latest_metrics
        and latest_metrics.blood_pressure_systolic
        and latest_metrics.blood_pressure_systolic >= 140
    ):
        constraints.required_tags.append("low_sodium")

    # ---- Doctor restrictions (override everything) -------------------------
    if active_restrictions:
        for r in active_restrictions:
            restricted = _normalize(_safe_json_list(r.restricted_foods))
            required = _normalize(_safe_json_list(r.required_nutrients))
            warnings = _normalize(_safe_json_list(r.medical_warnings))
            if restricted:
                constraints.forbidden_tags.extend(restricted)
                constraints.rationale.append(f"Doctor restriction: avoid {', '.join(restricted)}")
            if required:
                constraints.required_tags.extend(required)
                constraints.rationale.append(f"Doctor requires: {', '.join(required)}")
            if warnings:
                constraints.rationale.append(f"Doctor warnings: {', '.join(warnings)}")
            if r.notes:
                constraints.rationale.append(f"Doctor note: {r.notes}")

    # De-dupe while preserving order
    constraints.required_tags = list(dict.fromkeys(constraints.required_tags))
    constraints.forbidden_tags = list(dict.fromkeys(constraints.forbidden_tags))
    constraints.preferred_tags = list(dict.fromkeys(constraints.preferred_tags))
    return constraints


# ---------------------------------------------------------------------------
# Template filtering & scoring
# ---------------------------------------------------------------------------

def _template_passes(template: MealTemplate, c: DietConstraints, *, relax_required: bool = False) -> bool:
    """Return True if this template is a safe and acceptable choice.

    Hard rules (never relaxed):
    - Template must be active.
    - Template must not contain any of the mother's allergens.
    - Template diet-type must be compatible with mother's diet type.
    - Template must not carry any forbidden tag.

    Soft rule (relaxed when no strict match exists):
    - Template must match at least one medical required tag.
    """
    if not template.is_active:
        return False

    template_tags = set(_safe_json_list(template.tags))
    # Normalize template allergens through the same synonym map so
    # e.g. template allergen "dairy" matches mother allergy "milk".
    template_allergens = set(_normalize_allergies(_safe_json_list(template.allergens)))

    # Allergy hard-stop
    if any(a in template_allergens for a in c.allergies):
        return False

    # Diet type compatibility: vegan ⊂ veg ⊂ non-veg
    if c.diet_type == "vegan" and template.diet_type not in {"vegan"}:
        return False
    if c.diet_type == "veg" and template.diet_type == "non-veg":
        return False

    # Forbidden tag hard-stop
    if any(t in template_tags for t in c.forbidden_tags):
        return False

    # Medical required tags (soft when relax_required=True)
    if not relax_required and c.required_tags:
        if not (template_tags & set(c.required_tags)):
            return False

    return True


def _trimester_matches(template: MealTemplate, trimester: int) -> bool:
    tags = set(_safe_json_list(template.tags))
    return f"trimester_{trimester}" in tags


def _score_template(template: MealTemplate, c: DietConstraints, seed: int) -> float:
    tags = set(_safe_json_list(template.tags))
    score = 0.0

    # Strong boost for trimester match (most important preference)
    if _trimester_matches(template, c.trimester):
        score += 6.0

    # Required tags — more matches is better
    req_matches = len(tags & set(c.required_tags))
    score += 3.0 * req_matches

    # Preferred tags
    score += 1.5 * len(tags & set(c.preferred_tags))

    # Cuisine match
    if template.cuisine.lower() == c.cuisine.lower():
        score += 1.0

    # Light deterministic jitter so equal-score templates rotate day to day.
    jitter = ((template.id * 2654435761) ^ seed) & 0xFFFF
    score += (jitter / 0xFFFF) * 0.4
    return score


def _pick_for_slot(
    db: Session,
    slot: str,
    c: DietConstraints,
    seed: int,
) -> Optional[MealTemplate]:
    """Three-tier selection with graceful fallback.

    Tier 1 — full constraints (allergen-safe + diet-type + forbidden + required tags).
              Prefer trimester-matched meals via scoring.
    Tier 2 — relax medical required tags; still enforce allergens, diet-type, forbidden.
    Tier 3 — allergen-safe + diet-type compatible only (last resort).
    """
    rows = (
        db.query(MealTemplate)
        .filter(MealTemplate.slot == slot, MealTemplate.is_active == True)  # noqa: E712
        .all()
    )

    # Tier 1: full constraints
    candidates = [t for t in rows if _template_passes(t, c, relax_required=False)]

    # Tier 2: relax required-tag rule
    if not candidates:
        candidates = [t for t in rows if _template_passes(t, c, relax_required=True)]
        if candidates:
            log.debug(
                "slot=%s pid=? — no Tier-1 candidates; relaxed required-tags to %d options",
                slot, len(candidates),
            )

    # Tier 3: allergen + diet-type only (medical constraints relaxed)
    if not candidates:
        candidates = [
            t for t in rows
            if not (set(_normalize_allergies(_safe_json_list(t.allergens))) & set(c.allergies))
            and not (set(_safe_json_list(t.tags)) & set(c.forbidden_tags))
            and (c.diet_type == "non-veg" or t.diet_type != "non-veg")
            and (c.diet_type != "vegan" or t.diet_type == "vegan")
        ]
        if candidates:
            log.warning(
                "slot=%s — using Tier-3 fallback (allergy/diet-safe only), %d options",
                slot, len(candidates),
            )

    if not candidates:
        return None

    candidates.sort(key=lambda t: _score_template(t, c, seed), reverse=True)
    return candidates[0]


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def _meal_payload(template: Optional[MealTemplate]) -> dict:
    if template is None:
        return {
            "name": "—",
            "description": "No matching meal found; please update profile or seed library.",
            "calories": 0,
        }
    return {
        "template_id": template.id,
        "name": template.name,
        "description": template.description,
        "portion": template.portion,
        "calories": template.calories,
        "protein_g": template.protein_g,
        "carbs_g": template.carbs_g,
        "fat_g": template.fat_g,
        "fiber_g": template.fiber_g,
        "iron_mg": template.iron_mg,
        "calcium_mg": template.calcium_mg,
        "tags": _safe_json_list(template.tags),
        "allergens": _safe_json_list(template.allergens),
        "cuisine": template.cuisine,
        "diet_type": template.diet_type,
    }


def generate_daily_plan(
    db: Session,
    patient_id: str,
    target_date: Optional[date] = None,
    *,
    force: bool = False,
) -> DietPlan:
    pid = patient_id.strip().upper()
    target_date = target_date or datetime.utcnow().date()
    day_start = datetime(target_date.year, target_date.month, target_date.day)

    existing = (
        db.query(DietPlan)
        .filter(DietPlan.patient_id == pid, DietPlan.plan_date == day_start)
        .first()
    )
    if existing is not None and not force:
        return existing

    constraints = compile_constraints(db, pid)
    seed = int(day_start.strftime("%Y%m%d"))

    meals: dict[str, dict] = {}
    totals = {
        "calories": 0,
        "protein_g": 0.0,
        "iron_mg": 0.0,
        "calcium_mg": 0.0,
        "carbs_g": 0.0,
        "fat_g": 0.0,
        "fiber_g": 0.0,
    }
    for slot in MEAL_SLOTS:
        picked = _pick_for_slot(db, slot, constraints, seed + hash(slot))
        meals[slot] = _meal_payload(picked)
        if picked is not None:
            totals["calories"] += picked.calories
            totals["protein_g"] += picked.protein_g
            totals["iron_mg"] += picked.iron_mg
            totals["calcium_mg"] += picked.calcium_mg
            totals["carbs_g"] += picked.carbs_g
            totals["fat_g"] += picked.fat_g
            totals["fiber_g"] += picked.fiber_g

    # Hydration target: 2.5 L baseline + 250 ml for trimester 3.
    water_goal = 2500 + (250 if constraints.trimester == 3 else 0)

    rationale_text = " | ".join(constraints.rationale) or "Standard healthy pregnancy plan"

    if existing is not None and force:
        plan = existing
        plan.trimester = constraints.trimester
        plan.meals = json.dumps(meals)
        plan.daily_calories = int(totals["calories"])
        plan.daily_protein_g = totals["protein_g"]
        plan.daily_iron_mg = totals["iron_mg"]
        plan.daily_calcium_mg = totals["calcium_mg"]
        plan.daily_carbs_g = totals["carbs_g"]
        plan.daily_fat_g = totals["fat_g"]
        plan.daily_fiber_g = totals["fiber_g"]
        plan.water_goal_ml = water_goal
        plan.rationale = rationale_text
    else:
        plan = DietPlan(
            patient_id=pid,
            plan_date=day_start,
            trimester=constraints.trimester,
            meals=json.dumps(meals),
            daily_calories=int(totals["calories"]),
            daily_protein_g=totals["protein_g"],
            daily_iron_mg=totals["iron_mg"],
            daily_calcium_mg=totals["calcium_mg"],
            daily_carbs_g=totals["carbs_g"],
            daily_fat_g=totals["fat_g"],
            daily_fiber_g=totals["fiber_g"],
            water_goal_ml=water_goal,
            rationale=rationale_text,
        )
        db.add(plan)

    db.commit()
    db.refresh(plan)
    return plan


def llm_variation(_plan: DietPlan, _constraints: DietConstraints) -> DietPlan:  # pragma: no cover
    return _plan


def nutrition_score(plan: DietPlan) -> dict:
    """Score (0..100) of how close the daily plan is to trimester targets."""
    targets = _TRIMESTER_TARGETS.get(plan.trimester or 2, _TRIMESTER_TARGETS[2])
    components = {
        "calories": min(1.0, plan.daily_calories / max(1, targets["calories"])),
        "protein": min(1.0, plan.daily_protein_g / max(1, targets["protein_g"])),
        "iron": min(1.0, plan.daily_iron_mg / max(1, targets["iron_mg"])),
        "calcium": min(1.0, plan.daily_calcium_mg / max(1, targets["calcium_mg"])),
    }
    score = round(sum(components.values()) / len(components) * 100)
    return {
        "score": score,
        "components": {k: round(v * 100) for k, v in components.items()},
        "targets": targets,
        "actual": {
            "calories": plan.daily_calories,
            "protein_g": plan.daily_protein_g,
            "iron_mg": plan.daily_iron_mg,
            "calcium_mg": plan.daily_calcium_mg,
        },
    }
