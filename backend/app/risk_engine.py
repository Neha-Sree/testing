"""
Rule-based maternal risk engine.

Uses explicit clinical bands for BP, Hb, fasting glucose, maternal pulse,
temperature, SpO2, fetal movement, swelling, and optional weight trends.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Iterable, List, Optional

from sqlalchemy.orm import Session

from .clinical_terms import (
    classify_symptom_severity,
    infection_indicates_risk,
    normalize_fetal_movement,
    normalize_swelling,
)
from .models import FetalGrowthData, HealthMetrics, LabTest, MoodLog, Mother, RiskAssessment, SymptomLog
from .pregnancy_utils import current_pregnant_weeks


_LEVEL_POINTS = {"green": 0, "yellow": 1, "red": 3, "critical": 5}
_LEVEL_ORDER = ["green", "yellow", "red", "critical"]


@dataclass
class _Reason:
    level: str
    text: str


@dataclass
class RiskResult:
    level: str = "green"
    score: int = 0
    reasons: List[str] = field(default_factory=list)

    def as_dict(self) -> dict:
        return {"level": self.level, "score": self.score, "reasons": list(self.reasons)}


def _bp_reasons(metrics: Optional[HealthMetrics]) -> Iterable[_Reason]:
    if metrics is None:
        return
    sys_, dia = metrics.blood_pressure_systolic, metrics.blood_pressure_diastolic
    if sys_ is None and dia is None:
        return
    if sys_ is None or dia is None:
        return
    # Emergency: ≥160/110
    if sys_ >= 160 or dia >= 110:
        yield _Reason(
            "critical",
            f"Emergency BP {sys_}/{dia} mmHg (≥160/110) — seek urgent care",
        )
    # High risk: ≥140/90
    elif sys_ >= 140 or dia >= 90:
        yield _Reason(
            "red",
            f"High-risk BP {sys_}/{dia} mmHg (≥140/90)",
        )
    # Borderline: 120–139 / 80–89
    elif (120 <= sys_ <= 139) or (80 <= dia <= 89):
        yield _Reason(
            "yellow",
            f"Borderline BP {sys_}/{dia} mmHg (120–139 / 80–89)",
        )


def _temp_reasons(metrics: Optional[HealthMetrics]) -> Iterable[_Reason]:
    if metrics is None or metrics.temperature_celsius is None:
        return
    t = metrics.temperature_celsius
    if t > 38.0:
        yield _Reason("red", f"Fever risk: temperature {t}°C (> 38)")
    elif t < 36.5:
        yield _Reason("yellow", f"Low temperature {t}°C (< 36.5) — verify if unwell")


def _maternal_pulse_reasons(metrics: Optional[HealthMetrics]) -> Iterable[_Reason]:
    """Maternal pulse (heart_rate_bpm on HealthMetrics).
    Normal in pregnancy: 60–100 bpm (slight physiological increase is common).
    100–120 = mild tachycardia → yellow.
    > 120 = significant tachycardia → red.
    < 60 = bradycardia → yellow.
    """
    if metrics is None or metrics.heart_rate_bpm is None:
        return
    hr = metrics.heart_rate_bpm
    if hr > 120:
        yield _Reason("red", f"High-risk pulse {hr} bpm (> 120) — significant tachycardia")
    elif hr > 100:
        yield _Reason("yellow", f"Mild tachycardia {hr} bpm (100–120) — monitor closely")
    elif hr < 60:
        yield _Reason("yellow", f"Low pulse {hr} bpm (< 60) — clinical correlation")


def _oxygen_reasons(metrics: Optional[HealthMetrics]) -> Iterable[_Reason]:
    if metrics is None or metrics.oxygen_saturation is None:
        return
    spo2 = metrics.oxygen_saturation
    if spo2 < 90:
        yield _Reason("critical", f"Emergency SpO2 {spo2}% (< 90)")
    elif spo2 < 95:
        yield _Reason("yellow", f"Moderate SpO2 risk {spo2}% (90–94)")


def _fasting_glucose_reasons(value: Optional[float], *, source: str) -> Iterable[_Reason]:
    """Pregnancy fasting glucose thresholds (IADPSG / WHO 2013 / ADA).
    Normal  : < 92 mg/dL
    GDM threshold  : ≥ 92 mg/dL → yellow
    Diabetes threshold : ≥ 126 mg/dL → red
    Hypoglycaemia : < 70 mg/dL → yellow
    """
    if value is None:
        return
    if value >= 126:
        yield _Reason("red", f"High-risk fasting glucose {value} mg/dL (≥126) — {source}")
    elif value >= 92:
        yield _Reason(
            "yellow",
            f"Elevated fasting glucose {value} mg/dL (92–125, GDM threshold ≥92) — {source}",
        )
    elif value < 70:
        yield _Reason("yellow", f"Low glucose {value} mg/dL (< 70) — {source}")


def _fetal_movement_reasons(movement: Optional[str]) -> Iterable[_Reason]:
    normalized = normalize_fetal_movement(movement)
    if normalized == "none":
        yield _Reason("critical", "No fetal movement reported — emergency assessment")
    elif normalized == "reduced":
        yield _Reason("red", "Reduced fetal movement — high risk; urgent review")


def _swelling_reasons(swelling: Optional[str]) -> Iterable[_Reason]:
    normalized = normalize_swelling(swelling)
    if normalized == "face_hands_sudden":
        yield _Reason(
            "red",
            "Sudden face/hand swelling — high risk (possible pre-eclampsia)",
        )
    elif normalized == "feet_mild":
        yield _Reason(
            "yellow",
            "Mild feet/ankle swelling — common in pregnancy; monitor BP and symptoms",
        )


def _weight_trend_reasons(
    db: Session,
    patient_id: str,
    latest: Optional[HealthMetrics],
    mother_weeks: Optional[int],
) -> Iterable[_Reason]:
    if latest is None or latest.weight_kg is None:
        return
    prior = (
        db.query(HealthMetrics)
        .filter(
            HealthMetrics.patient_id == patient_id,
            HealthMetrics.weight_kg.isnot(None),
            HealthMetrics.id != latest.id,
        )
        .order_by(HealthMetrics.measurement_date.desc())
        .first()
    )
    if prior is None or prior.weight_kg is None:
        return
    delta = latest.weight_kg - prior.weight_kg
    days = (latest.measurement_date - prior.measurement_date).days
    if days <= 0:
        days = 1
    if days <= 14 and delta >= 5:
        yield _Reason(
            "red",
            f"Excessive gain risk: ~{delta:.1f} kg over {days}d — sudden high increase",
        )
    elif days <= 14 and delta >= 3:
        yield _Reason(
            "yellow",
            f"Notable weight increase ~{delta:.1f} kg over {days}d — monitor closely",
        )
    if (
        mother_weeks is not None
        and mother_weeks >= 16
        and days >= 28
        and 0 <= delta < 1.0
    ):
        yield _Reason(
            "yellow",
            f"Underweight gain risk: only ~{delta:.1f} kg over {days}d — nutritional review",
        )
    if delta <= -2.0 and days <= 42:
        yield _Reason(
            "yellow",
            f"Weight loss ~{abs(delta):.1f} kg over {days}d — clinical review",
        )


def _lab_reasons(lab: Optional[LabTest]) -> Iterable[_Reason]:
    if lab is None:
        return
    if lab.hemoglobin is not None:
        h = lab.hemoglobin
        if h < 7.0:
            yield _Reason("critical", f"Severe anemia: Hb {h} g/dL (< 7)")
        elif h < 9.0:
            yield _Reason("red", f"Moderate anemia: Hb {h} g/dL (7–8.9)")
        elif h < 11.0:
            yield _Reason("yellow", f"Mild anemia: Hb {h} g/dL (9–10.9)")
    if lab.blood_sugar_fasting is not None:
        yield from _fasting_glucose_reasons(lab.blood_sugar_fasting, source="lab fasting")
    if lab.blood_sugar_post is not None:
        bsp = lab.blood_sugar_post
        if bsp >= 200:
            yield _Reason("red", f"Post-meal glucose {bsp} mg/dL (≥200) — diabetes range")
        elif bsp >= 153:
            yield _Reason(
                "red",
                f"Post-meal glucose {bsp} mg/dL (≥153) — GDM range (IADPSG 2-hour threshold)",
            )
        elif bsp >= 140:
            yield _Reason(
                "yellow",
                f"Post-meal glucose {bsp} mg/dL (140–152) — borderline; GDM screening advised",
            )
    if lab.urine_protein and lab.urine_protein.strip().lower() not in {"", "neg", "negative", "trace"}:
        yield _Reason("red", f"Urine protein {lab.urine_protein} — possible preeclampsia")
    if lab.urine_sugar and lab.urine_sugar.strip().lower() not in {"", "neg", "negative", "trace"}:
        yield _Reason("yellow", f"Urine sugar {lab.urine_sugar}")
    if lab.thyroid_tsh is not None:
        tsh = lab.thyroid_tsh
        # Pregnancy-specific TSH reference ranges (ATA / WHO):
        # T1: 0.1 – 2.5 mIU/L  |  T2: 0.2 – 3.0  |  T3: 0.3 – 3.0
        # Without trimester context we use the most conservative upper limit (2.5)
        # to avoid missing subclinical hypothyroidism in early pregnancy.
        if tsh > 4.0:
            yield _Reason("red", f"Significantly elevated TSH {tsh} mIU/L (>4.0) — hypothyroid risk")
        elif tsh > 2.5:
            yield _Reason(
                "yellow",
                f"TSH {tsh} mIU/L (>2.5) — above first-trimester upper limit; thyroid check advised",
            )
        elif tsh < 0.1:
            yield _Reason("yellow", f"Very low TSH {tsh} mIU/L (<0.1) — hyperthyroid risk")
    if lab.iron_ferritin is not None and lab.iron_ferritin < 15:
        yield _Reason("yellow", f"Low ferritin {lab.iron_ferritin} ng/mL")
    if lab.calcium is not None and lab.calcium < 8.5:
        yield _Reason("yellow", f"Low calcium {lab.calcium} mg/dL")


_RISKY_SYMPTOM_KEYWORDS = (
    "swelling",
    "oedema",
    "edema",
    "headache",
    "bleed",
    "bleeding",
    "dizziness",
    "breath",
    "vision",
    "abdominal",
    "pain",
    "fever",
    "movement",
    "contractions",
    "fluid",
    "vomit",
    "chest",
    "hypertension",
    "preeclampsia",
    "pre-eclampsia",
    "proteinuria",
    "oligohydramnios",
    "polyhydramnios",
    "infection",
    "uti",
)


def _symptom_log_reasons(db: Session, patient_id: str) -> Iterable[_Reason]:
    """Recent self-reported symptoms (last 7 days)."""
    cutoff = datetime.utcnow() - timedelta(days=7)
    rows = (
        db.query(SymptomLog)
        .filter(SymptomLog.patient_id == patient_id)
        .order_by(SymptomLog.logged_at.desc())
        .limit(30)
        .all()
    )
    seen: set[str] = set()
    for r in rows:
        lt = r.logged_at
        if lt is not None and getattr(lt, "tzinfo", None):
            lt = lt.replace(tzinfo=None)
        if lt is not None and lt < cutoff:
            continue
        key = f"{r.severity}:{r.symptom_text}"
        if key in seen:
            continue
        seen.add(key)
        severity = (r.severity or "").strip().lower()
        if severity in {"", "green", "info"}:
            inferred = classify_symptom_severity(r.symptom_text)
            if inferred:
                severity = inferred
        if severity == "critical":
            yield _Reason("critical", f"Logged symptom (critical): {r.symptom_text}")
        elif severity == "red":
            yield _Reason("red", f"Logged symptom (urgent): {r.symptom_text}")
        elif severity == "yellow":
            low = (r.symptom_text or "").lower()
            if any(k in low for k in _RISKY_SYMPTOM_KEYWORDS):
                yield _Reason("yellow", f"Symptom to monitor: {r.symptom_text}")


def _mood_reasons(db: Session, patient_id: str) -> Iterable[_Reason]:
    latest = (
        db.query(MoodLog)
        .filter(MoodLog.patient_id == patient_id)
        .order_by(MoodLog.logged_at.desc())
        .first()
    )
    if latest is None:
        return
    age = datetime.utcnow() - (latest.logged_at.replace(tzinfo=None) if latest.logged_at else datetime.utcnow())
    if age > timedelta(days=3):
        return
    m = (latest.mood or "").lower()
    if m in {"sad", "anxious", "overwhelmed", "stressed", "grumpy", "angry"}:
        yield _Reason(
            "yellow",
            f"Recent mood: {m} — consider discussing emotional wellbeing with your care team",
        )


def _fetal_growth_reasons(growth: Optional[FetalGrowthData]) -> Iterable[_Reason]:
    if growth is None:
        return
    if growth.heart_rate_bpm is not None:
        hr = growth.heart_rate_bpm
        if hr < 110 or hr > 160:
            yield _Reason(
                "red",
                f"Fetal heart rate {hr} bpm outside typical range (110–160) — ultrasound review",
            )
    if growth.amniotic_fluid_index is not None:
        afi = growth.amniotic_fluid_index
        if afi < 5:
            yield _Reason("red", f"Low amniotic fluid (AFI {afi} cm) — oligohydramnios risk")
        elif afi > 25:
            yield _Reason("yellow", f"High amniotic fluid (AFI {afi} cm) — polyhydramnios review")
    if growth.notes:
        yield from _fetal_movement_reasons(growth.notes)
        low = growth.notes.lower()
        if any(t in low for t in ("placenta previa", "abruption", "iugr", "growth restriction", "small for dates")):
            yield _Reason("red", f"Fetal growth concern noted: {growth.notes[:120]}")


def _infection_reasons(lab: Optional[LabTest]) -> Iterable[_Reason]:
    if lab is None or not lab.infection_notes:
        return
    if infection_indicates_risk(lab.infection_notes):
        yield _Reason("yellow", f"Infection indicator on labs: {lab.infection_notes[:120]}")


def compute_risk(db: Session, patient_id: str, *, persist: bool = False) -> RiskResult:
    """Compute the current risk level from latest vitals and lab tests."""
    pid = patient_id.strip().upper()

    mother: Optional[Mother] = db.query(Mother).filter(Mother.patient_id == pid).first()
    mother_weeks = current_pregnant_weeks(mother)

    latest_metrics: Optional[HealthMetrics] = (
        db.query(HealthMetrics)
        .filter(HealthMetrics.patient_id == pid)
        .order_by(HealthMetrics.measurement_date.desc(), HealthMetrics.created_at.desc())
        .first()
    )
    latest_lab: Optional[LabTest] = (
        db.query(LabTest)
        .filter(LabTest.patient_id == pid)
        .order_by(LabTest.test_date.desc())
        .first()
    )
    latest_growth: Optional[FetalGrowthData] = (
        db.query(FetalGrowthData)
        .filter(FetalGrowthData.patient_id == pid)
        .order_by(FetalGrowthData.measurement_date.desc(), FetalGrowthData.created_at.desc())
        .first()
    )

    reasons: List[_Reason] = []
    reasons.extend(_bp_reasons(latest_metrics))
    reasons.extend(_temp_reasons(latest_metrics))
    reasons.extend(_maternal_pulse_reasons(latest_metrics))
    reasons.extend(_oxygen_reasons(latest_metrics))
    if latest_metrics is not None and latest_metrics.blood_sugar is not None:
        reasons.extend(
            _fasting_glucose_reasons(latest_metrics.blood_sugar, source="vitals (fasting)")
        )
    fetal_movement = latest_metrics.fetal_movement if latest_metrics else None
    swelling = latest_metrics.swelling if latest_metrics else None
    reasons.extend(_fetal_movement_reasons(fetal_movement))
    reasons.extend(_swelling_reasons(swelling))
    reasons.extend(_weight_trend_reasons(db, pid, latest_metrics, mother_weeks))
    reasons.extend(_lab_reasons(latest_lab))
    reasons.extend(_infection_reasons(latest_lab))
    reasons.extend(_fetal_growth_reasons(latest_growth))
    reasons.extend(_symptom_log_reasons(db, pid))
    reasons.extend(_mood_reasons(db, pid))

    cutoff = datetime.utcnow() - timedelta(days=21)
    no_recent_metrics = latest_metrics is None or (
        latest_metrics.measurement_date and latest_metrics.measurement_date < cutoff
    )
    no_recent_lab = latest_lab is None or (latest_lab.test_date and latest_lab.test_date < cutoff)
    if no_recent_metrics and no_recent_lab:
        reasons.append(_Reason("yellow", "No recent vitals or lab tests on file"))

    level = "green"
    score = 0
    for r in reasons:
        score += _LEVEL_POINTS.get(r.level, 0)
        if _LEVEL_ORDER.index(r.level) > _LEVEL_ORDER.index(level):
            level = r.level

    result = RiskResult(level=level, score=score, reasons=[r.text for r in reasons])

    if persist:
        record = RiskAssessment(
            patient_id=pid,
            level=result.level,
            score=result.score,
            reasons=json.dumps(result.reasons),
        )
        db.add(record)
        db.commit()

    return result
