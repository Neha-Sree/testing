"""
Health Worker portal endpoints.

Covers: worker registration, mother assignment, home visits (with GPS +
photo), lab test entry, report upload, and assigned-mothers listing
augmented with computed risk levels.
"""
from __future__ import annotations

import os
import shutil
from datetime import datetime
from pathlib import Path
from typing import Optional
from uuid import uuid4

from fastapi import Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session

from .database import get_db
from .models import FetalGrowthData, HealthWorker, HomeVisit, LabTest, Mother, Report
from .paths import HW_PROFILES_DIR, REPORTS_DIR, VISITS_DIR
from .risk_engine import compute_risk


_REPORT_TYPES = {"scan", "blood", "urine", "ultrasound", "thyroid", "growth_scan", "prescription", "other"}
_VISIT_STATUSES = {"scheduled", "completed", "cancelled"}


def _serialize_worker(worker: HealthWorker) -> dict:
    return {
        "id": worker.id,
        "worker_id": worker.worker_id,
        "full_name": worker.full_name,
        "phone": worker.phone,
        "region": worker.region,
        "profile_image_path": worker.profile_image_path,
        "created_at": worker.created_at.isoformat() if worker.created_at else None,
    }


def _serialize_visit(visit: HomeVisit) -> dict:
    return {
        "id": visit.id,
        "patient_id": visit.patient_id,
        "health_worker_id": visit.health_worker_id,
        "scheduled_date": visit.scheduled_date.isoformat() if visit.scheduled_date else None,
        "completed_at": visit.completed_at.isoformat() if visit.completed_at else None,
        "gps_lat": visit.gps_lat,
        "gps_lon": visit.gps_lon,
        "address": visit.address,
        "notes": visit.notes,
        "observations": visit.observations,
        "photo_path": visit.photo_path,
        "status": visit.status,
        "created_at": visit.created_at.isoformat() if visit.created_at else None,
    }


def _serialize_lab(lab: LabTest) -> dict:
    return {
        "id": lab.id,
        "patient_id": lab.patient_id,
        "test_date": lab.test_date.isoformat() if lab.test_date else None,
        "measured_by": lab.measured_by,
        "hemoglobin": lab.hemoglobin,
        "blood_sugar_fasting": lab.blood_sugar_fasting,
        "blood_sugar_post": lab.blood_sugar_post,
        "urine_sugar": lab.urine_sugar,
        "urine_protein": lab.urine_protein,
        "thyroid_tsh": lab.thyroid_tsh,
        "iron_ferritin": lab.iron_ferritin,
        "calcium": lab.calcium,
        "infection_notes": lab.infection_notes,
        "notes": lab.notes,
        "femur_length_cm": lab.femur_length_cm,
        "head_circumference_cm": lab.head_circumference_cm,
        "created_at": lab.created_at.isoformat() if lab.created_at else None,
    }


def _serialize_report(report: Report) -> dict:
    return {
        "id": report.id,
        "patient_id": report.patient_id,
        "report_type": report.report_type,
        "file_path": report.file_path,
        "file_name": report.file_name,
        "uploaded_by": report.uploaded_by,
        "uploader_type": report.uploader_type,
        "report_date": report.report_date.isoformat() if report.report_date else None,
        "notes": report.notes,
        "created_at": report.created_at.isoformat() if report.created_at else None,
    }


# --- Health Worker profile ---------------------------------------------------

def upsert_health_worker(
    worker_id: str = Form(...),
    full_name: str = Form(...),
    phone: str | None = Form(default=None),
    password: str | None = Form(default=None),
    region: str | None = Form(default=None),
    profile_image: UploadFile | None = File(default=None),
    db: Session = Depends(get_db),
):
    worker_id = worker_id.strip().upper()
    full_name = full_name.strip()
    if not worker_id:
        raise HTTPException(status_code=400, detail="worker_id is required")
    if not full_name:
        raise HTTPException(status_code=400, detail="full_name is required")

    stored_image_path = None
    if profile_image is not None and profile_image.filename:
        ext = os.path.splitext(profile_image.filename)[1].lower()
        if ext not in {".jpg", ".jpeg", ".png", ".webp"}:
            raise HTTPException(status_code=400, detail="Unsupported image format")
        filename = f"hw_{worker_id}_{uuid4().hex}{ext}"
        target_path = (HW_PROFILES_DIR / filename).resolve()
        with target_path.open("wb") as fp:
            shutil.copyfileobj(profile_image.file, fp)
        stored_image_path = str(target_path)

    worker = db.query(HealthWorker).filter(HealthWorker.worker_id == worker_id).first()
    if worker is None:
        worker = HealthWorker(
            worker_id=worker_id,
            full_name=full_name,
            phone=phone,
            password=password or "password123",
            region=region,
            profile_image_path=stored_image_path,
        )
        db.add(worker)
    else:
        worker.full_name = full_name
        if phone is not None:
            worker.phone = phone
        if password is not None:
            worker.password = password
        if region is not None:
            worker.region = region
        if stored_image_path is not None:
            worker.profile_image_path = stored_image_path

    db.commit()
    db.refresh(worker)
    return _serialize_worker(worker)


def get_health_worker(worker_id: str, db: Session = Depends(get_db)):
    normalized = worker_id.strip().upper()
    worker = db.query(HealthWorker).filter(HealthWorker.worker_id == normalized).first()
    if worker is None:
        raise HTTPException(status_code=404, detail="Health worker not found")
    return _serialize_worker(worker)


# --- Mother assignment & listing --------------------------------------------

def assign_mother_to_health_worker(
    worker_id: str,
    patient_id: str,
    db: Session = Depends(get_db),
):
    hw = worker_id.strip().upper()
    pid = patient_id.strip().upper()
    mother = db.query(Mother).filter(Mother.patient_id == pid).first()
    if mother is None:
        raise HTTPException(status_code=404, detail="Mother not found")
    mother.health_worker_id = hw
    db.commit()
    db.refresh(mother)
    return {
        "message": "Mother assigned to health worker",
        "patient_id": mother.patient_id,
        "health_worker_id": mother.health_worker_id,
    }


def list_assigned_mothers(worker_id: str, db: Session = Depends(get_db)):
    hw = worker_id.strip().upper()
    mothers = (
        db.query(Mother)
        .filter(Mother.health_worker_id == hw)
        .order_by(Mother.created_at.desc())
        .all()
    )
    payload = []
    for mother in mothers:
        risk = compute_risk(db, mother.patient_id)
        payload.append(
            {
                "patient_id": mother.patient_id,
                "full_name": mother.full_name,
                "age": mother.age,
                "pregnant_weeks": mother.pregnant_weeks,
                "due_date": mother.due_date.isoformat() if mother.due_date else None,
                "blood_group": mother.blood_group,
                "phone": mother.phone,
                "address": mother.address,
                "doctor_id": mother.doctor_id,
                "risk_level": risk.level,
                "risk_score": risk.score,
                "risk_reasons": risk.reasons,
            }
        )
    return payload


# --- Home Visits -------------------------------------------------------------

def schedule_home_visit(
    patient_id: str = Form(...),
    health_worker_id: str = Form(...),
    scheduled_date: str = Form(...),
    notes: str = Form(default=""),
    db: Session = Depends(get_db),
):
    pid = patient_id.strip().upper()
    hw = health_worker_id.strip().upper()
    try:
        date_value = datetime.fromisoformat(scheduled_date)
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid scheduled_date") from error

    visit = HomeVisit(
        patient_id=pid,
        health_worker_id=hw,
        scheduled_date=date_value,
        notes=notes.strip() or None,
        status="scheduled",
    )
    db.add(visit)
    db.commit()
    db.refresh(visit)
    return _serialize_visit(visit)


def complete_home_visit(
    visit_id: int,
    gps_lat: float | None = Form(default=None),
    gps_lon: float | None = Form(default=None),
    address: str | None = Form(default=None),
    observations: str | None = Form(default=None),
    notes: str | None = Form(default=None),
    photo: UploadFile | None = File(default=None),
    db: Session = Depends(get_db),
):
    visit = db.query(HomeVisit).filter(HomeVisit.id == visit_id).first()
    if visit is None:
        raise HTTPException(status_code=404, detail="Home visit not found")

    if photo is not None and photo.filename:
        ext = os.path.splitext(photo.filename)[1].lower()
        if ext not in {".jpg", ".jpeg", ".png", ".webp"}:
            raise HTTPException(status_code=400, detail="Unsupported photo format")
        filename = f"visit_{visit_id}_{uuid4().hex}{ext}"
        target_path = (VISITS_DIR / filename).resolve()
        with target_path.open("wb") as fp:
            shutil.copyfileobj(photo.file, fp)
        visit.photo_path = str(target_path)

    if gps_lat is not None:
        visit.gps_lat = gps_lat
    if gps_lon is not None:
        visit.gps_lon = gps_lon
    if address is not None:
        visit.address = address.strip() or None
    if observations is not None:
        visit.observations = observations.strip() or None
    if notes is not None:
        visit.notes = notes.strip() or None

    visit.status = "completed"
    visit.completed_at = datetime.utcnow()
    db.commit()
    db.refresh(visit)
    return _serialize_visit(visit)


def list_health_worker_visits(worker_id: str, db: Session = Depends(get_db)):
    hw = worker_id.strip().upper()
    visits = (
        db.query(HomeVisit)
        .filter(HomeVisit.health_worker_id == hw)
        .order_by(HomeVisit.scheduled_date.desc())
        .limit(200)
        .all()
    )
    return [_serialize_visit(v) for v in visits]


def list_patient_visits(patient_id: str, db: Session = Depends(get_db)):
    pid = patient_id.strip().upper()
    visits = (
        db.query(HomeVisit)
        .filter(HomeVisit.patient_id == pid)
        .order_by(HomeVisit.scheduled_date.desc())
        .limit(200)
        .all()
    )
    return [_serialize_visit(v) for v in visits]


# --- Lab tests ---------------------------------------------------------------

def create_lab_test(
    patient_id: str = Form(...),
    test_date: str = Form(...),
    measured_by: str | None = Form(default=None),
    hemoglobin: float | None = Form(default=None),
    blood_sugar_fasting: float | None = Form(default=None),
    blood_sugar_post: float | None = Form(default=None),
    urine_sugar: str | None = Form(default=None),
    urine_protein: str | None = Form(default=None),
    thyroid_tsh: float | None = Form(default=None),
    iron_ferritin: float | None = Form(default=None),
    calcium: float | None = Form(default=None),
    infection_notes: str | None = Form(default=None),
    notes: str | None = Form(default=None),
    femur_length_cm: float | None = Form(default=None),
    head_circumference_cm: float | None = Form(default=None),
    db: Session = Depends(get_db),
):
    pid = patient_id.strip().upper()
    try:
        date_value = datetime.fromisoformat(test_date)
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid test_date") from error

    lab = LabTest(
        patient_id=pid,
        test_date=date_value,
        measured_by=(measured_by or "").strip().upper() or None,
        hemoglobin=hemoglobin,
        blood_sugar_fasting=blood_sugar_fasting,
        blood_sugar_post=blood_sugar_post,
        urine_sugar=urine_sugar,
        urine_protein=urine_protein,
        thyroid_tsh=thyroid_tsh,
        iron_ferritin=iron_ferritin,
        calcium=calcium,
        infection_notes=infection_notes,
        notes=notes,
        femur_length_cm=femur_length_cm,
        head_circumference_cm=head_circumference_cm,
    )
    db.add(lab)
    db.commit()
    db.refresh(lab)

    risk = compute_risk(db, pid, persist=True)
    return {"lab_test": _serialize_lab(lab), "risk": risk.as_dict(), "ai_diet_context_updated": True}


def list_lab_tests(patient_id: str, db: Session = Depends(get_db)):
    pid = patient_id.strip().upper()
    labs = (
        db.query(LabTest)
        .filter(LabTest.patient_id == pid)
        .order_by(LabTest.test_date.desc())
        .limit(200)
        .all()
    )
    return [_serialize_lab(l) for l in labs]


# --- Fetal growth ------------------------------------------------------------

def create_fetal_growth(
    patient_id: str = Form(...),
    pregnant_weeks: int = Form(...),
    measured_by: str | None = Form(default=None),
    fetal_weight_grams: float | None = Form(default=None),
    fetal_length_cm: float | None = Form(default=None),
    heart_rate_bpm: int | None = Form(default=None),
    fundal_height_cm: float | None = Form(default=None),
    amniotic_fluid_index: float | None = Form(default=None),
    femur_length_cm: float | None = Form(default=None),
    head_circumference_cm: float | None = Form(default=None),
    notes: str | None = Form(default=None),
    db: Session = Depends(get_db),
):
    pid = patient_id.strip().upper()
    if pregnant_weeks < 4 or pregnant_weeks > 44:
        raise HTTPException(status_code=400, detail="pregnant_weeks must be between 4 and 44")

    growth = FetalGrowthData(
        patient_id=pid,
        measurement_date=datetime.utcnow(),
        pregnant_weeks=pregnant_weeks,
        fetal_weight_grams=fetal_weight_grams,
        fetal_length_cm=fetal_length_cm,
        heart_rate_bpm=heart_rate_bpm,
        fundal_height_cm=fundal_height_cm,
        amniotic_fluid_index=amniotic_fluid_index,
        femur_length_cm=femur_length_cm,
        head_circumference_cm=head_circumference_cm,
        notes=(notes or "").strip() or None,
        measured_by=(measured_by or "").strip().upper() or None,
    )
    db.add(growth)
    db.commit()
    db.refresh(growth)

    mother = db.query(Mother).filter(Mother.patient_id == pid).first()
    if mother is not None and (mother.pregnant_weeks is None or mother.pregnant_weeks < pregnant_weeks):
        mother.pregnant_weeks = pregnant_weeks
        db.commit()

    risk = compute_risk(db, pid, persist=True)
    return {
        "fetal_growth": {
            "id": growth.id,
            "patient_id": growth.patient_id,
            "pregnant_weeks": growth.pregnant_weeks,
            "fetal_weight_grams": growth.fetal_weight_grams,
            "measurement_date": growth.measurement_date.isoformat() if growth.measurement_date else None,
        },
        "risk": risk.as_dict(),
        "ai_diet_context_updated": True,
    }


# --- Reports -----------------------------------------------------------------

def upload_report(
    patient_id: str = Form(...),
    report_type: str = Form(...),
    uploaded_by: str | None = Form(default=None),
    uploader_type: str | None = Form(default=None),
    report_date: str | None = Form(default=None),
    notes: str | None = Form(default=None),
    extract: str = Form(default="false"),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    pid = patient_id.strip().upper()
    rtype = report_type.strip().lower()
    if rtype not in _REPORT_TYPES:
        raise HTTPException(status_code=400, detail=f"Invalid report_type. Must be one of: {sorted(_REPORT_TYPES)}")

    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="File is required")
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in {".jpg", ".jpeg", ".png", ".webp", ".pdf", ".txt", ".csv", ".json"}:
        raise HTTPException(status_code=400, detail="Unsupported file format (jpg/png/webp/pdf/txt/csv/json only)")

    filename = f"{pid}_{rtype}_{uuid4().hex}{ext}"
    target_path = (REPORTS_DIR / filename).resolve()
    with target_path.open("wb") as fp:
        shutil.copyfileobj(file.file, fp)

    parsed_report_date: Optional[datetime] = None
    if report_date:
        try:
            parsed_report_date = datetime.fromisoformat(report_date)
        except ValueError:
            parsed_report_date = None

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
    payload = _serialize_report(report)
    payload["ai_diet_context_updated"] = True
    extract_flag = str(extract or "").strip().lower() in {"1", "true", "yes", "on"}
    if extract_flag:
        from .report_ai_extractor import run_extraction_for_report

        payload["extraction"] = run_extraction_for_report(report.id, db)
    return payload


def list_reports(patient_id: str, db: Session = Depends(get_db)):
    pid = patient_id.strip().upper()
    reports = (
        db.query(Report)
        .filter(Report.patient_id == pid)
        .order_by(Report.created_at.desc())
        .limit(200)
        .all()
    )
    return [_serialize_report(r) for r in reports]


# --- Risk --------------------------------------------------------------------

def get_patient_risk(patient_id: str, db: Session = Depends(get_db)):
    risk = compute_risk(db, patient_id)
    return risk.as_dict()
