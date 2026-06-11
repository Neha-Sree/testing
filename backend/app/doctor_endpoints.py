"""
Doctor portal: overview, risk feed, appointments, analytics, clinical bundles,
deliveries, newborns, emergencies, symptoms, fetal growth series.
"""
from __future__ import annotations

import json
from datetime import datetime, timedelta, time as dt_time
from pathlib import Path
from typing import Any
from uuid import uuid4

from fastapi import Depends, Form, HTTPException
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from .database import get_db
from .models import (
    Appointment,
    DeliveryRecord,
    EmergencyAlert,
    FetalGrowthData,
    HealthMetrics,
    HomeVisit,
    LabTest,
    Mother,
    MoodLog,
    NewbornRecord,
    NewbornVaccination,
    NewbornVital,
    PillIntake,
    PillPrescription,
    Report,
    RiskAssessment,
    SymptomLog,
)
from .risk_engine import compute_risk

UPLOADS_DIR = Path("uploads")
REPORTS_DIR = UPLOADS_DIR / "reports"
REPORTS_DIR.mkdir(parents=True, exist_ok=True)

_LEVEL_RANK = {"green": 0, "yellow": 1, "red": 2, "critical": 3}


def _norm(s: str) -> str:
    return (s or "").strip().upper()


def _assigned_mothers(db: Session, doctor_id: str) -> list[Mother]:
    did = _norm(doctor_id)
    return db.query(Mother).filter(Mother.doctor_id == did).order_by(Mother.full_name.asc()).all()


def _assigned_patient_ids(db: Session, doctor_id: str) -> set[str]:
    return {m.patient_id for m in _assigned_mothers(db, doctor_id)}


def _mother_public(m: Mother) -> dict[str, Any]:
    return {
        "id": m.id,
        "patient_id": m.patient_id,
        "full_name": m.full_name,
        "age": m.age,
        "blood_group": m.blood_group,
        "pregnant_weeks": m.pregnant_weeks,
        "due_date": m.due_date.isoformat() if m.due_date else None,
        "doctor_id": m.doctor_id,
        "health_worker_id": m.health_worker_id,
        "phone": m.phone,
        "address": m.address,
        "emergency_contact": m.emergency_contact,
        "profile_image_path": m.profile_image_path,
        "weight_kg": m.weight_kg,
    }


def _trimester(weeks: int | None) -> int | None:
    if weeks is None:
        return None
    if weeks <= 13:
        return 1
    if weeks <= 27:
        return 2
    return 3


def _pill_adherence_window(db: Session, patient_id: str, days: int) -> tuple[float, int]:
    """Returns (ratio 0..1, expected_doses) for active prescriptions in the rolling window."""
    pid = _norm(patient_id)
    end_d = datetime.utcnow().date()
    start_d = end_d - timedelta(days=max(1, days) - 1)

    rxs = (
        db.query(PillPrescription)
        .filter(PillPrescription.patient_id == pid, PillPrescription.is_active == True)  # noqa: E712
        .all()
    )
    expected = 0
    rx_ids: list[int] = []
    for rx in rxs:
        if not rx.start_date:
            continue
        rs = rx.start_date.date() if hasattr(rx.start_date, "date") else rx.start_date
        re = rx.end_date.date() if rx.end_date and hasattr(rx.end_date, "date") else (rx.end_date or end_d)
        if isinstance(re, datetime):
            re = re.date()
        if isinstance(rs, datetime):
            rs = rs.date()
        overlap_start = max(start_d, rs)
        overlap_end = min(end_d, re)
        if overlap_start > overlap_end:
            continue
        d = overlap_start
        while d <= overlap_end:
            expected += 1
            d += timedelta(days=1)
        rx_ids.append(rx.id)

    if expected == 0:
        return (1.0, 0)

    start_dt = datetime.combine(start_d, dt_time.min)
    end_dt = datetime.combine(end_d, dt_time.max)
    q = db.query(PillIntake).filter(
        PillIntake.patient_id == pid,
        PillIntake.intake_date >= start_dt,
        PillIntake.intake_date <= end_dt,
        PillIntake.taken == True,  # noqa: E712
    )
    if rx_ids:
        q = q.filter(PillIntake.prescription_id.in_(rx_ids))
    taken = q.count()
    ratio = min(1.0, float(taken) / float(expected))
    return (ratio, expected)


def doctor_overview(doctor_id: str, db: Session = Depends(get_db)):
    did = _norm(doctor_id)
    mothers = _assigned_mothers(db, did)
    pids = [m.patient_id for m in mothers]
    today = datetime.utcnow().date()
    today_start = datetime.combine(today, dt_time.min)
    today_end = datetime.combine(today, dt_time.max)

    total_assigned = len(mothers)

    appt_q = db.query(Appointment).filter(Appointment.patient_id.in_(pids)) if pids else None
    todays_appts = 0
    if appt_q is not None:
        todays_appts = (
            appt_q.filter(Appointment.appointment_date >= today_start, Appointment.appointment_date <= today_end)
            .count()
        )

    high_risk = 0
    for m in mothers:
        r = (
            db.query(RiskAssessment)
            .filter(RiskAssessment.patient_id == m.patient_id)
            .order_by(RiskAssessment.computed_at.desc())
            .first()
        )
        if r and r.level in ("red", "critical"):
            high_risk += 1

    near_delivery = 0
    cutoff_nd = today + timedelta(days=30)
    for m in mothers:
        if m.due_date and today <= m.due_date.date() <= cutoff_nd:
            near_delivery += 1

    missed_med = 0
    for m in mothers:
        ratio, exp = _pill_adherence_window(db, m.patient_id, 7)
        if exp >= 3 and ratio < 0.8:
            missed_med += 1

    if pids:
        emerg_filt = or_(EmergencyAlert.doctor_id == did, EmergencyAlert.patient_id.in_(pids))
    else:
        emerg_filt = EmergencyAlert.doctor_id == did
    open_emergencies = (
        db.query(EmergencyAlert).filter(EmergencyAlert.status == "open", emerg_filt).count()
    )

    delivered = db.query(DeliveryRecord).filter(DeliveryRecord.doctor_id == did).count()

    nb_mother_ids = (
        db.query(NewbornRecord.mother_patient_id)
        .filter(NewbornRecord.mother_patient_id.in_(pids))
        .distinct()
        .count()
        if pids
        else 0
    )

    def _card(key: str, count: int, icon: str, color: str, trend: str = "Stable") -> dict[str, Any]:
        return {"key": key, "count": count, "icon": icon, "color": color, "trend_hint": trend}

    return {
        "cards": [
            _card("assigned", total_assigned, "people", "#1976D2", "Active panel"),
            _card("appointments_today", todays_appts, "event", "#00897B", "Scheduled today"),
            _card("high_risk", high_risk, "warning", "#D32F2F", "Latest assessment"),
            _card("near_delivery", near_delivery, "child_care", "#F9A825", "EDD ≤ 30 days"),
            _card("missed_medication", missed_med, "medication", "#F9A825", "<80% × 7d"),
            _card("emergency_open", open_emergencies, "emergency", "#D32F2F", "Needs action"),
            _card("delivered", delivered, "local_hospital", "#43A047", "Recorded births"),
            _card("newborns_observation", nb_mother_ids, "cradle", "#00897B", "Mothers with newborn"),
        ],
        "totals": {
            "total_assigned_mothers": total_assigned,
            "appointments_today": todays_appts,
            "high_risk_pregnancies": high_risk,
            "mothers_near_delivery_30d": near_delivery,
            "missed_medication_cases": missed_med,
            "emergency_alerts_open": open_emergencies,
            "delivered_mothers": delivered,
            "newborns_under_observation": nb_mother_ids,
        },
    }


def doctor_risk_feed(
    doctor_id: str,
    level: str = "all",
    limit: int = 50,
    db: Session = Depends(get_db),
):
    did = _norm(doctor_id)
    pids = _assigned_patient_ids(db, did)
    if not pids:
        return {"items": []}

    items: list[dict[str, Any]] = []

    risks = (
        db.query(RiskAssessment)
        .filter(RiskAssessment.patient_id.in_(pids))
        .order_by(RiskAssessment.computed_at.desc())
        .limit(200)
        .all()
    )
    for r in risks:
        try:
            reasons = json.loads(r.reasons) if r.reasons else []
        except json.JSONDecodeError:
            reasons = [r.reasons or ""]
        mother = db.query(Mother).filter(Mother.patient_id == r.patient_id).first()
        items.append(
            {
                "id": f"risk-{r.id}",
                "type": "risk_assessment",
                "patient_id": r.patient_id,
                "mother_name": mother.full_name if mother else r.patient_id,
                "level": r.level,
                "summary": "; ".join(reasons[:3]) if reasons else r.level,
                "computed_at": r.computed_at.isoformat() if r.computed_at else None,
                "score": r.score,
            }
        )

    symptoms = (
        db.query(SymptomLog)
        .filter(SymptomLog.patient_id.in_(pids))
        .order_by(SymptomLog.logged_at.desc())
        .limit(100)
        .all()
    )
    for s in symptoms:
        mother = db.query(Mother).filter(Mother.patient_id == s.patient_id).first()
        items.append(
            {
                "id": f"symptom-{s.id}",
                "type": "symptom",
                "patient_id": s.patient_id,
                "mother_name": mother.full_name if mother else s.patient_id,
                "level": s.severity,
                "summary": s.symptom_text,
                "computed_at": s.logged_at.isoformat() if s.logged_at else None,
                "score": _LEVEL_RANK.get(s.severity, 0),
            }
        )

    for m in _assigned_mothers(db, did):
        ratio, exp = _pill_adherence_window(db, m.patient_id, 7)
        if exp >= 3 and ratio < 0.8:
            items.append(
                {
                    "id": f"missed-med-{m.patient_id}",
                    "type": "missed_medication",
                    "patient_id": m.patient_id,
                    "mother_name": m.full_name,
                    "level": "red" if ratio < 0.5 else "yellow",
                    "summary": f"Pill adherence {int(ratio * 100)}% over 7 days",
                    "computed_at": datetime.utcnow().isoformat(),
                    "score": _LEVEL_RANK["red" if ratio < 0.5 else "yellow"],
                }
            )

    def _keep(it: dict[str, Any]) -> bool:
        lv = (it.get("level") or "green").lower()
        if level == "all":
            return lv in ("green", "yellow", "red", "critical")
        if level == "red":
            return lv in ("red", "critical")
        if level == "critical":
            return lv == "critical"
        return True

    items = [it for it in items if _keep(it)]
    items.sort(
        key=lambda x: (
            -_LEVEL_RANK.get((x.get("level") or "green").lower(), 0),
            x.get("computed_at") or "",
        )
    )
    return {"items": items[: max(1, min(limit, 200))]}


def doctor_today_appointments(doctor_id: str, db: Session = Depends(get_db)):
    did = _norm(doctor_id)
    mothers = _assigned_mothers(db, did)
    pids = [m.patient_id for m in mothers]
    mid = {m.patient_id: m for m in mothers}
    today = datetime.utcnow().date()
    today_start = datetime.combine(today, dt_time.min)
    today_end = datetime.combine(today, dt_time.max)

    if not pids:
        return {"pending": [], "completed": [], "cancelled": [], "scheduled": []}

    rows = (
        db.query(Appointment)
        .filter(
            Appointment.patient_id.in_(pids),
            Appointment.appointment_date >= today_start,
            Appointment.appointment_date <= today_end,
        )
        .order_by(Appointment.appointment_time.asc())
        .all()
    )

    grouped: dict[str, list[dict[str, Any]]] = {"pending": [], "completed": [], "cancelled": [], "scheduled": []}
    for a in rows:
        m = mid.get(a.patient_id)
        entry = {
            "id": a.id,
            "patient_id": a.patient_id,
            "mother_name": m.full_name if m else a.patient_id,
            "blood_group": m.blood_group if m else None,
            "pregnant_weeks": m.pregnant_weeks if m else None,
            "appointment_date": a.appointment_date.isoformat() if a.appointment_date else None,
            "appointment_time": a.appointment_time,
            "duration_minutes": a.duration_minutes,
            "appointment_type": a.appointment_type,
            "status": a.status,
            "notes": a.notes,
            "health_worker_id": a.health_worker_id,
        }
        st = (a.status or "scheduled").lower()
        if st == "completed":
            grouped["completed"].append(entry)
        elif st == "cancelled":
            grouped["cancelled"].append(entry)
        elif st == "scheduled":
            grouped["scheduled"].append(entry)
            grouped["pending"].append(entry)
        else:
            grouped["pending"].append(entry)

    return grouped


def doctor_near_delivery(doctor_id: str, days: int = 30, db: Session = Depends(get_db)):
    did = _norm(doctor_id)
    today = datetime.utcnow().date()
    end = today + timedelta(days=max(1, min(days, 120)))
    out: list[dict[str, Any]] = []
    for m in _assigned_mothers(db, did):
        if not m.due_date:
            continue
        dd = m.due_date.date() if hasattr(m.due_date, "date") else m.due_date
        if today <= dd <= end:
            r = (
                db.query(RiskAssessment)
                .filter(RiskAssessment.patient_id == m.patient_id)
                .order_by(RiskAssessment.computed_at.desc())
                .first()
            )
            out.append(
                {
                    **_mother_public(m),
                    "risk_level": r.level if r else "unknown",
                    "days_until_due": (dd - today).days,
                }
            )
    out.sort(key=lambda x: x.get("days_until_due", 999))
    return {"mothers": out}


def doctor_missed_medications(doctor_id: str, days: int = 7, db: Session = Depends(get_db)):
    did = _norm(doctor_id)
    out: list[dict[str, Any]] = []
    for m in _assigned_mothers(db, did):
        ratio, exp = _pill_adherence_window(db, m.patient_id, days)
        if exp >= 3 and ratio < 0.8:
            out.append(
                {
                    **_mother_public(m),
                    "adherence_ratio": ratio,
                    "adherence_pct": int(ratio * 100),
                    "expected_doses": exp,
                    "window_days": days,
                }
            )
    out.sort(key=lambda x: x["adherence_ratio"])
    return {"mothers": out}


def doctor_analytics(doctor_id: str, db: Session = Depends(get_db)):
    did = _norm(doctor_id)
    pids = list(_assigned_patient_ids(db, did))
    since = datetime.utcnow() - timedelta(days=90)

    risk_trend: dict[str, dict[str, int]] = {}
    if pids:
        assessments = (
            db.query(RiskAssessment)
            .filter(RiskAssessment.patient_id.in_(pids), RiskAssessment.computed_at >= since)
            .order_by(RiskAssessment.computed_at.asc())
            .all()
        )
        for a in assessments:
            day = a.computed_at.date().isoformat() if a.computed_at else ""
            if not day:
                continue
            risk_trend.setdefault(day, {"green": 0, "yellow": 0, "red": 0, "critical": 0})
            lv = (a.level or "green").lower()
            if lv in risk_trend[day]:
                risk_trend[day][lv] += 1

    adherence_by_mother: list[dict[str, Any]] = []
    for m in _assigned_mothers(db, did):
        ratio, exp = _pill_adherence_window(db, m.patient_id, 14)
        if exp > 0:
            adherence_by_mother.append(
                {"patient_id": m.patient_id, "name": m.full_name, "adherence_pct": int(ratio * 100)}
            )

    fetal_weights: list[float] = []
    if pids:
        growth_rows = (
            db.query(FetalGrowthData)
            .filter(FetalGrowthData.patient_id.in_(pids), FetalGrowthData.fetal_weight_grams.isnot(None))
            .all()
        )
        for g in growth_rows:
            if g.fetal_weight_grams:
                fetal_weights.append(float(g.fetal_weight_grams))

    appt_completed = appt_cancelled = appt_scheduled = 0
    if pids:
        for st, c in (
            db.query(Appointment.status, func.count())
            .filter(Appointment.patient_id.in_(pids))
            .group_by(Appointment.status)
            .all()
        ):
            s = (st or "").lower()
            if s == "completed":
                appt_completed = int(c)
            elif s == "cancelled":
                appt_cancelled = int(c)
            else:
                appt_scheduled += int(c)

    trimester_buckets = {"1": 0, "2": 0, "3": 0, "unknown": 0}
    for m in _assigned_mothers(db, did):
        t = _trimester(m.pregnant_weeks)
        trimester_buckets[str(t) if t else "unknown"] = trimester_buckets.get(str(t) if t else "unknown", 0) + 1

    return {
        "risk_trend_by_day": risk_trend,
        "adherence_by_mother": adherence_by_mother[:50],
        "fetal_weight_samples": fetal_weights[:200],
        "appointments": {
            "completed": appt_completed,
            "cancelled": appt_cancelled,
            "scheduled_or_other": appt_scheduled,
        },
        "trimester_distribution": trimester_buckets,
    }


def mother_profile_bundle(patient_id: str, db: Session = Depends(get_db)):
    pid = _norm(patient_id)
    m = db.query(Mother).filter(Mother.patient_id == pid).first()
    if not m:
        raise HTTPException(status_code=404, detail="Mother not found")

    latest_metrics = (
        db.query(HealthMetrics)
        .filter(HealthMetrics.patient_id == pid)
        .order_by(HealthMetrics.measurement_date.desc())
        .first()
    )
    latest_lab = (
        db.query(LabTest).filter(LabTest.patient_id == pid).order_by(LabTest.test_date.desc()).first()
    )
    symptoms = (
        db.query(SymptomLog)
        .filter(SymptomLog.patient_id == pid)
        .order_by(SymptomLog.logged_at.desc())
        .limit(10)
        .all()
    )
    rx = (
        db.query(PillPrescription)
        .filter(PillPrescription.patient_id == pid, PillPrescription.is_active == True)  # noqa: E712
        .order_by(PillPrescription.created_at.desc())
        .all()
    )
    ratio, exp = _pill_adherence_window(db, pid, 14)
    risk = (
        db.query(RiskAssessment)
        .filter(RiskAssessment.patient_id == pid)
        .order_by(RiskAssessment.computed_at.desc())
        .first()
    )
    upcoming = (
        db.query(Appointment)
        .filter(
            Appointment.patient_id == pid,
            Appointment.appointment_date >= datetime.utcnow(),
            Appointment.status != "cancelled",
        )
        .order_by(Appointment.appointment_date.asc())
        .limit(5)
        .all()
    )
    delivery = db.query(DeliveryRecord).filter(DeliveryRecord.patient_id == pid).order_by(DeliveryRecord.delivery_date.desc()).first()
    newborn = db.query(NewbornRecord).filter(NewbornRecord.mother_patient_id == pid).order_by(NewbornRecord.created_at.desc()).first()
    last_visit = (
        db.query(HomeVisit)
        .filter(HomeVisit.patient_id == pid, HomeVisit.status == "completed")
        .order_by(HomeVisit.scheduled_date.desc())
        .first()
    )

    def _hm(h: HealthMetrics | None) -> dict[str, Any] | None:
        if not h:
            return None
        return {
            "measurement_date": h.measurement_date.isoformat() if h.measurement_date else None,
            "weight_kg": h.weight_kg,
            "blood_pressure_systolic": h.blood_pressure_systolic,
            "blood_pressure_diastolic": h.blood_pressure_diastolic,
            "heart_rate_bpm": h.heart_rate_bpm,
            "blood_sugar": h.blood_sugar,
            "temperature_celsius": h.temperature_celsius,
            "oxygen_saturation": h.oxygen_saturation,
            "fetal_movement": h.fetal_movement,
            "swelling": h.swelling,
            "notes": h.notes,
        }

    def _lb(l: LabTest | None) -> dict[str, Any] | None:
        if not l:
            return None
        return {
            "test_date": l.test_date.isoformat() if l.test_date else None,
            "hemoglobin": l.hemoglobin,
            "blood_sugar_fasting": l.blood_sugar_fasting,
            "blood_sugar_post": l.blood_sugar_post,
            "urine_protein": l.urine_protein,
            "notes": l.notes,
            "femur_length_cm": l.femur_length_cm,
            "head_circumference_cm": l.head_circumference_cm,
        }

    return {
        "mother": _mother_public(m),
        "trimester": _trimester(m.pregnant_weeks),
        "latest_health_metrics": _hm(latest_metrics),
        "latest_lab": _lb(latest_lab),
        "symptoms": [
            {
                "id": s.id,
                "symptom_text": s.symptom_text,
                "severity": s.severity,
                "notes": s.notes,
                "logged_at": s.logged_at.isoformat() if s.logged_at else None,
            }
            for s in symptoms
        ],
        "active_prescriptions": [
            {
                "id": p.id,
                "pill_name": p.pill_name,
                "dosage": p.dosage,
                "meal_time": p.meal_time,
                "frequency": p.frequency,
                "start_date": p.start_date.isoformat() if p.start_date else None,
                "end_date": p.end_date.isoformat() if p.end_date else None,
            }
            for p in rx
        ],
        "adherence_14d_ratio": ratio,
        "adherence_14d_pct": int(ratio * 100) if exp > 0 else None,
        "latest_risk": (
            {
                "level": risk.level,
                "score": risk.score,
                "reasons": json.loads(risk.reasons) if risk.reasons else [],
                "computed_at": risk.computed_at.isoformat() if risk.computed_at else None,
            }
            if risk
            else None
        ),
        "upcoming_appointments": [
            {
                "id": a.id,
                "appointment_date": a.appointment_date.isoformat() if a.appointment_date else None,
                "appointment_time": a.appointment_time,
                "status": a.status,
                "appointment_type": a.appointment_type,
            }
            for a in upcoming
        ],
        "delivery": (
            {
                "id": delivery.id,
                "delivery_date": delivery.delivery_date.isoformat() if delivery.delivery_date else None,
                "delivery_type": delivery.delivery_type,
                "baby_count": delivery.baby_count,
                "hospital": delivery.hospital,
                "notes": delivery.notes,
            }
            if delivery
            else None
        ),
        "newborn": (
            {
                "id": newborn.id,
                "patient_id": newborn.patient_id,
                "name": newborn.name,
                "sex": newborn.sex,
                "birth_weight_g": newborn.birth_weight_g,
                "apgar_1min": newborn.apgar_1min,
                "apgar_5min": newborn.apgar_5min,
            }
            if newborn
            else None
        ),
        "last_visit": (
            {
                "scheduled_date": last_visit.scheduled_date.isoformat() if last_visit and last_visit.scheduled_date else None,
                "completed_at": last_visit.completed_at.isoformat() if last_visit and last_visit.completed_at else None,
                "notes": last_visit.notes,
            }
            if last_visit
            else None
        ),
        "clinical_notes": [],
    }


def list_mother_symptoms(patient_id: str, limit: int = 20, db: Session = Depends(get_db)):
    pid = _norm(patient_id)
    rows = (
        db.query(SymptomLog)
        .filter(SymptomLog.patient_id == pid)
        .order_by(SymptomLog.logged_at.desc())
        .limit(max(1, min(limit, 100)))
        .all()
    )
    return [
        {
            "id": r.id,
            "symptom_text": r.symptom_text,
            "severity": r.severity,
            "notes": r.notes,
            "logged_at": r.logged_at.isoformat() if r.logged_at else None,
        }
        for r in rows
    ]


def create_mother_symptom(
    patient_id: str,
    symptom_text: str = Form(...),
    severity: str = Form("yellow"),
    notes: str = Form(""),
    db: Session = Depends(get_db),
):
    pid = _norm(patient_id)
    if not db.query(Mother).filter(Mother.patient_id == pid).first():
        raise HTTPException(status_code=404, detail="Mother not found")
    sev = (severity or "yellow").lower()
    if sev not in _LEVEL_RANK:
        sev = "yellow"
    row = SymptomLog(patient_id=pid, symptom_text=symptom_text.strip(), severity=sev, notes=notes or None)
    db.add(row)
    db.commit()
    db.refresh(row)
    risk = compute_risk(db, pid, persist=True)
    return {"id": row.id, "patient_id": pid, "risk": risk.as_dict()}


_MOODS = frozenset(
    {
        "happy",
        "calm",
        "neutral",
        "tired",
        "sad",
        "anxious",
        "grumpy",
        "angry",
        "stressed",
        "overwhelmed",
    }
)


def list_mood_logs(
    patient_id: str,
    limit: int = 40,
    db: Session = Depends(get_db),
):
    pid = _norm(patient_id)
    if not db.query(Mother).filter(Mother.patient_id == pid).first():
        raise HTTPException(status_code=404, detail="Mother not found")
    lim = max(1, min(limit, 100))
    rows = (
        db.query(MoodLog)
        .filter(MoodLog.patient_id == pid)
        .order_by(MoodLog.logged_at.desc())
        .limit(lim)
        .all()
    )
    return [
        {
            "id": r.id,
            "mood": r.mood,
            "notes": r.notes,
            "logged_at": r.logged_at.isoformat() if r.logged_at else None,
        }
        for r in rows
    ]


def create_mood_log(
    patient_id: str,
    mood: str = Form(...),
    notes: str = Form(""),
    db: Session = Depends(get_db),
):
    pid = _norm(patient_id)
    if not db.query(Mother).filter(Mother.patient_id == pid).first():
        raise HTTPException(status_code=404, detail="Mother not found")
    mood_c = (mood or "").strip().lower()
    if mood_c not in _MOODS:
        raise HTTPException(status_code=400, detail=f"Invalid mood. Use one of: {sorted(_MOODS)}")
    row = MoodLog(patient_id=pid, mood=mood_c, notes=(notes or "").strip() or None)
    db.add(row)
    db.commit()
    db.refresh(row)
    risk = compute_risk(db, pid, persist=True)
    return {"id": row.id, "patient_id": pid, "mood": mood_c, "risk": risk.as_dict()}


def mother_fetal_growth_series(patient_id: str, db: Session = Depends(get_db)):
    pid = _norm(patient_id)
    rows = (
        db.query(FetalGrowthData)
        .filter(FetalGrowthData.patient_id == pid)
        .order_by(FetalGrowthData.pregnant_weeks.asc(), FetalGrowthData.measurement_date.asc())
        .all()
    )
    by_week: dict[int, FetalGrowthData] = {}
    for r in rows:
        by_week[r.pregnant_weeks] = r

    metrics_by_week: dict[int, HealthMetrics] = {}
    for h in (
        db.query(HealthMetrics)
        .filter(HealthMetrics.patient_id == pid)
        .order_by(HealthMetrics.measurement_date.desc())
        .limit(50)
        .all()
    ):
        m = db.query(Mother).filter(Mother.patient_id == pid).first()
        wk = m.pregnant_weeks if m else None
        if wk and wk not in metrics_by_week:
            metrics_by_week[wk] = h

    series: list[dict[str, Any]] = []
    for week in sorted(by_week.keys()):
        g = by_week[week]
        hr = g.heart_rate_bpm
        if hr is None:
            mh = metrics_by_week.get(week)
            if mh and mh.heart_rate_bpm:
                hr = mh.heart_rate_bpm
        series.append(
            {
                "week": week,
                "fetal_weight_g": g.fetal_weight_grams,
                "heart_rate": hr,
                "femur_length": g.femur_length_cm,
                "head_circumference": g.head_circumference_cm,
                "amniotic_fluid": g.amniotic_fluid_index,
                "measurement_date": g.measurement_date.isoformat() if g.measurement_date else None,
            }
        )

    latest_lab = (
        db.query(LabTest)
        .filter(LabTest.patient_id == pid)
        .order_by(LabTest.test_date.desc())
        .first()
    )
    if latest_lab and (latest_lab.femur_length_cm or latest_lab.head_circumference_cm):
        m = db.query(Mother).filter(Mother.patient_id == pid).first()
        wk = m.pregnant_weeks if m else None
        if wk:
            series.append(
                {
                    "week": wk,
                    "fetal_weight_g": None,
                    "heart_rate": None,
                    "femur_length": latest_lab.femur_length_cm,
                    "head_circumference": latest_lab.head_circumference_cm,
                    "amniotic_fluid": None,
                    "measurement_date": latest_lab.test_date.isoformat() if latest_lab.test_date else None,
                    "source": "lab",
                }
            )

    return {"patient_id": pid, "series": series}


# --- Deliveries --------------------------------------------------------------

def create_delivery(
    patient_id: str = Form(...),
    doctor_id: str = Form(...),
    delivery_date: str = Form(...),
    delivery_type: str = Form(...),
    complications: str = Form(""),
    baby_count: int = Form(1),
    hospital: str = Form(""),
    notes: str = Form(""),
    db: Session = Depends(get_db),
):
    pid = _norm(patient_id)
    did = _norm(doctor_id)
    if not db.query(Mother).filter(Mother.patient_id == pid).first():
        raise HTTPException(status_code=404, detail="Mother not found")
    try:
        dd = datetime.fromisoformat(delivery_date)
    except ValueError as e:
        raise HTTPException(status_code=400, detail="Invalid delivery_date") from e
    dt = (delivery_type or "").strip().lower()
    if dt not in ("vaginal", "c_section", "assisted", "other"):
        raise HTTPException(status_code=400, detail="Invalid delivery_type")
    row = DeliveryRecord(
        patient_id=pid,
        doctor_id=did,
        delivery_date=dd,
        delivery_type=dt,
        complications=complications or None,
        baby_count=max(1, baby_count),
        hospital=hospital or None,
        notes=notes or None,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id, "patient_id": pid}


def get_mother_delivery(patient_id: str, db: Session = Depends(get_db)):
    pid = _norm(patient_id)
    row = db.query(DeliveryRecord).filter(DeliveryRecord.patient_id == pid).order_by(DeliveryRecord.delivery_date.desc()).first()
    if not row:
        return {"delivery": None}
    return {
        "delivery": {
            "id": row.id,
            "patient_id": row.patient_id,
            "doctor_id": row.doctor_id,
            "delivery_date": row.delivery_date.isoformat() if row.delivery_date else None,
            "delivery_type": row.delivery_type,
            "complications": row.complications,
            "baby_count": row.baby_count,
            "hospital": row.hospital,
            "notes": row.notes,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        }
    }


def list_doctor_deliveries(doctor_id: str, db: Session = Depends(get_db)):
    did = _norm(doctor_id)
    rows = (
        db.query(DeliveryRecord)
        .filter(DeliveryRecord.doctor_id == did)
        .order_by(DeliveryRecord.delivery_date.desc())
        .limit(200)
        .all()
    )
    return [
        {
            "id": r.id,
            "patient_id": r.patient_id,
            "delivery_date": r.delivery_date.isoformat() if r.delivery_date else None,
            "delivery_type": r.delivery_type,
            "baby_count": r.baby_count,
            "hospital": r.hospital,
        }
        for r in rows
    ]


# --- Newborns ----------------------------------------------------------------


def _next_newborn_patient_id(db: Session) -> str:
    for _ in range(20):
        cand = "NB-" + uuid4().hex[:10].upper()
        if not db.query(NewbornRecord).filter(NewbornRecord.patient_id == cand).first():
            return cand
    return "NB-" + uuid4().hex.upper()


def create_newborn(
    mother_patient_id: str = Form(...),
    name: str = Form(""),
    sex: str = Form(""),
    birth_weight_g: float | None = Form(default=None),
    birth_height_cm: float | None = Form(default=None),
    apgar_1min: int | None = Form(default=None),
    apgar_5min: int | None = Form(default=None),
    head_circumference_cm: float | None = Form(default=None),
    observations: str = Form(""),
    db: Session = Depends(get_db),
):
    mid = _norm(mother_patient_id)
    if not db.query(Mother).filter(Mother.patient_id == mid).first():
        raise HTTPException(status_code=404, detail="Mother not found")
    pid = _next_newborn_patient_id(db)
    row = NewbornRecord(
        patient_id=pid,
        mother_patient_id=mid,
        name=name or None,
        sex=sex or None,
        birth_weight_g=birth_weight_g,
        birth_height_cm=birth_height_cm,
        apgar_1min=apgar_1min,
        apgar_5min=apgar_5min,
        head_circumference_cm=head_circumference_cm,
        observations=observations or None,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id, "patient_id": row.patient_id, "mother_patient_id": mid}


def get_newborn(newborn_id: int, db: Session = Depends(get_db)):
    row = db.query(NewbornRecord).filter(NewbornRecord.id == newborn_id).first()
    if not row:
        raise HTTPException(status_code=404, detail="Newborn not found")
    return {
        "id": row.id,
        "patient_id": row.patient_id,
        "mother_patient_id": row.mother_patient_id,
        "name": row.name,
        "sex": row.sex,
        "birth_weight_g": row.birth_weight_g,
        "birth_height_cm": row.birth_height_cm,
        "apgar_1min": row.apgar_1min,
        "apgar_5min": row.apgar_5min,
        "head_circumference_cm": row.head_circumference_cm,
        "observations": row.observations,
        "created_at": row.created_at.isoformat() if row.created_at else None,
    }


def get_mother_newborn(patient_id: str, db: Session = Depends(get_db)):
    pid = _norm(patient_id)
    row = db.query(NewbornRecord).filter(NewbornRecord.mother_patient_id == pid).order_by(NewbornRecord.created_at.desc()).first()
    if not row:
        return {"newborn": None}
    return {"newborn": get_newborn(row.id, db)}


def create_newborn_vital(
    newborn_id: int,
    recorded_at: str = Form(...),
    weight_g: float | None = Form(default=None),
    height_cm: float | None = Form(default=None),
    temperature_c: float | None = Form(default=None),
    jaundice_level: str = Form(""),
    feeding_type: str = Form(""),
    sleep_hours: float | None = Form(default=None),
    notes: str = Form(""),
    db: Session = Depends(get_db),
):
    if not db.query(NewbornRecord).filter(NewbornRecord.id == newborn_id).first():
        raise HTTPException(status_code=404, detail="Newborn not found")
    try:
        ts = datetime.fromisoformat(recorded_at)
    except ValueError as e:
        raise HTTPException(status_code=400, detail="Invalid recorded_at") from e
    row = NewbornVital(
        newborn_id=newborn_id,
        recorded_at=ts,
        weight_g=weight_g,
        height_cm=height_cm,
        temperature_c=temperature_c,
        jaundice_level=jaundice_level or None,
        feeding_type=feeding_type or None,
        sleep_hours=sleep_hours,
        notes=notes or None,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id}


def list_newborn_vitals(newborn_id: int, db: Session = Depends(get_db)):
    if not db.query(NewbornRecord).filter(NewbornRecord.id == newborn_id).first():
        raise HTTPException(status_code=404, detail="Newborn not found")
    rows = (
        db.query(NewbornVital)
        .filter(NewbornVital.newborn_id == newborn_id)
        .order_by(NewbornVital.recorded_at.desc())
        .limit(100)
        .all()
    )
    return [
        {
            "id": r.id,
            "recorded_at": r.recorded_at.isoformat() if r.recorded_at else None,
            "weight_g": r.weight_g,
            "height_cm": r.height_cm,
            "temperature_c": r.temperature_c,
            "jaundice_level": r.jaundice_level,
            "feeding_type": r.feeding_type,
            "sleep_hours": r.sleep_hours,
            "notes": r.notes,
        }
        for r in rows
    ]


def create_newborn_vaccination(
    newborn_id: int,
    vaccine_name: str = Form(...),
    scheduled_date: str = Form(""),
    given_date: str = Form(""),
    batch_no: str = Form(""),
    notes: str = Form(""),
    db: Session = Depends(get_db),
):
    if not db.query(NewbornRecord).filter(NewbornRecord.id == newborn_id).first():
        raise HTTPException(status_code=404, detail="Newborn not found")

    def _pd(s: str) -> datetime | None:
        if not (s or "").strip():
            return None
        try:
            return datetime.fromisoformat(s.strip())
        except ValueError:
            return None

    row = NewbornVaccination(
        newborn_id=newborn_id,
        vaccine_name=vaccine_name.strip(),
        scheduled_date=_pd(scheduled_date),
        given_date=_pd(given_date),
        batch_no=batch_no or None,
        notes=notes or None,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id}


def list_newborn_vaccinations(newborn_id: int, db: Session = Depends(get_db)):
    if not db.query(NewbornRecord).filter(NewbornRecord.id == newborn_id).first():
        raise HTTPException(status_code=404, detail="Newborn not found")
    rows = (
        db.query(NewbornVaccination)
        .filter(NewbornVaccination.newborn_id == newborn_id)
        .order_by(NewbornVaccination.id.desc())
        .limit(50)
        .all()
    )
    return [
        {
            "id": r.id,
            "vaccine_name": r.vaccine_name,
            "scheduled_date": r.scheduled_date.isoformat() if r.scheduled_date else None,
            "given_date": r.given_date.isoformat() if r.given_date else None,
            "batch_no": r.batch_no,
            "notes": r.notes,
        }
        for r in rows
    ]


def list_doctor_newborns(doctor_id: str, db: Session = Depends(get_db)):
    did = _norm(doctor_id)
    pids = _assigned_patient_ids(db, did)
    if not pids:
        return {"newborns": []}
    rows = (
        db.query(NewbornRecord)
        .filter(NewbornRecord.mother_patient_id.in_(pids))
        .order_by(NewbornRecord.created_at.desc())
        .limit(200)
        .all()
    )
    out = []
    for r in rows:
        mother = db.query(Mother).filter(Mother.patient_id == r.mother_patient_id).first()
        out.append(
            {
                **get_newborn(r.id, db),
                "mother_name": mother.full_name if mother else r.mother_patient_id,
            }
        )
    return {"newborns": out}


# --- Emergencies -------------------------------------------------------------


def create_emergency(
    patient_id: str = Form(...),
    doctor_id: str = Form(""),
    raised_by: str = Form(""),
    level: str = Form("critical"),
    source: str = Form("sos"),
    summary: str = Form(...),
    db: Session = Depends(get_db),
):
    pid = _norm(patient_id)
    mother = db.query(Mother).filter(Mother.patient_id == pid).first()
    did = _norm(doctor_id) if doctor_id else None
    if not did and mother and mother.doctor_id:
        did = mother.doctor_id
    src = (source or "sos").strip().lower()
    if src not in ("sos", "symptom", "metric", "missed_med"):
        src = "sos"
    lv = (level or "critical").lower()
    if lv not in _LEVEL_RANK:
        lv = "critical"
    row = EmergencyAlert(
        patient_id=pid,
        doctor_id=did,
        raised_by=(raised_by or "").strip().upper() or None,
        level=lv,
        source=src,
        summary=summary.strip(),
        status="open",
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id}


def list_doctor_emergencies(doctor_id: str, status: str = "open", db: Session = Depends(get_db)):
    did = _norm(doctor_id)
    pids = list(_assigned_patient_ids(db, did))
    if pids:
        base_filt = or_(EmergencyAlert.doctor_id == did, EmergencyAlert.patient_id.in_(pids))
    else:
        base_filt = EmergencyAlert.doctor_id == did
    q = db.query(EmergencyAlert).filter(base_filt)
    st = (status or "open").strip().lower()
    if st != "all":
        q = q.filter(EmergencyAlert.status == st)
    rows = q.order_by(EmergencyAlert.created_at.desc()).limit(200).all()
    return [
        {
            "id": r.id,
            "patient_id": r.patient_id,
            "level": r.level,
            "source": r.source,
            "summary": r.summary,
            "status": r.status,
            "created_at": r.created_at.isoformat() if r.created_at else None,
            "resolved_at": r.resolved_at.isoformat() if r.resolved_at else None,
        }
        for r in rows
    ]


def acknowledge_emergency(alert_id: int, db: Session = Depends(get_db)):
    row = db.query(EmergencyAlert).filter(EmergencyAlert.id == alert_id).first()
    if not row:
        raise HTTPException(status_code=404, detail="Not found")
    row.status = "acknowledged"
    db.commit()
    return {"ok": True, "id": alert_id, "status": row.status}


def resolve_emergency(alert_id: int, db: Session = Depends(get_db)):
    row = db.query(EmergencyAlert).filter(EmergencyAlert.id == alert_id).first()
    if not row:
        raise HTTPException(status_code=404, detail="Not found")
    row.status = "resolved"
    row.resolved_at = datetime.utcnow()
    db.commit()
    return {"ok": True, "id": alert_id, "status": row.status}
