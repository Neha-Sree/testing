import json
import os
import re
import shutil
from datetime import datetime, timedelta
from pathlib import Path
from uuid import uuid4

from . import env as _env  # noqa: F401 — loads backend/.env before other app imports

from fastapi import Depends, FastAPI, File, Form, HTTPException, Query, Request, UploadFile, Body, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
from sqlalchemy.orm import Session

from .database import Base, engine, get_db
from .pregnancy_utils import (
    current_pregnant_weeks,
    ensure_due_date_from_weeks,
    infer_due_date_from_weeks,
)
from .auth import (
    AuthUser,
    create_access_token,
    decode_access_token,
    hash_password,
    needs_password_upgrade,
    role_from_user_id,
    verify_password,
)
from .models import (ContractionSession, KickSession, Mother, SleepSession, PillPrescription, PillIntake, Appointment,
                     DietLog, FetalGrowthData, HydrationLog, StepsLog, HealthMetrics, ChatRoom, ChatMessage, ChatNotification,
                     HealthWorker, Doctor, HomeVisit, LabTest, Report, ReportExtraction, RiskAssessment,
                     MotherDietProfile, MealTemplate, DoctorDietRestriction, DietPlan, MealCompletion,
                     AiDietAssistantPlan,
                     Article, Faq, DailyTip, ArticleBookmark, ReadingProgress,
                     SymptomLog, MoodLog, DeliveryRecord, NewbornRecord, NewbornVital, NewbornVaccination, EmergencyAlert)
from .tools_endpoints import (create_diet_log, get_diet_logs, create_fetal_growth_data, get_fetal_growth_data,
                             create_hydration_log, get_hydration_logs, create_steps_log, get_steps_logs,
                             create_health_metrics, get_health_metrics, get_patient_dashboard_data,
                             create_or_get_chat_room, send_message, get_chat_messages, get_user_chat_rooms, mark_messages_as_read)
from .health_worker_endpoints import (
    upsert_health_worker, get_health_worker, assign_mother_to_health_worker, list_assigned_mothers,
    schedule_home_visit, complete_home_visit, list_health_worker_visits, list_patient_visits,
    create_lab_test, list_lab_tests, create_fetal_growth, upload_report, list_reports, get_patient_risk,
)
from .diet_endpoints import (
    get_diet_profile, upsert_diet_profile,
    create_doctor_restriction, list_doctor_restrictions, deactivate_doctor_restriction,
    get_today_plan, regenerate_today_plan, get_plan_for_date, mark_meal_complete,
    doctor_patient_diet_summary, list_meal_templates,
    generate_ai_assistant_plan, get_latest_ai_assistant_plan,
)
from .seed_diet import seed_meal_templates
from .seed_education import seed_education
from .seed_doctor import seed_doctor_demo
from .report_ai_extractor import upload_report_and_extract
from .education_endpoints import (
    list_articles, get_article, recommended_articles, create_article, approve_article,
    toggle_bookmark, list_bookmarks, save_reading_progress, get_reading_streak,
    list_faqs, create_faq, ask_question, get_today_tip,
)
from .doctor_endpoints import (
    doctor_overview,
    doctor_risk_feed,
    doctor_today_appointments,
    doctor_near_delivery,
    doctor_missed_medications,
    doctor_analytics,
    mother_profile_bundle,
    list_mother_symptoms,
    create_mother_symptom,
    list_mood_logs,
    create_mood_log,
    mother_fetal_growth_series,
    create_delivery,
    get_mother_delivery,
    list_doctor_deliveries,
    create_newborn,
    get_newborn,
    get_mother_newborn,
    create_newborn_vital,
    list_newborn_vitals,
    create_newborn_vaccination,
    list_newborn_vaccinations,
    list_doctor_newborns,
    create_emergency,
    list_doctor_emergencies,
    acknowledge_emergency,
    resolve_emergency,
)
from .database import SessionLocal

app = FastAPI(title="Life Nest Backend")


_PUBLIC_ROUTES = {
    ("GET", "/health"),
    ("POST", "/auth/login"),
    ("POST", "/mothers/onboarding"),
    ("POST", "/doctors/onboarding"),
    ("POST", "/health-workers/onboarding"),
    ("GET", "/education/articles"),
    ("GET", "/education/faqs"),
    ("GET", "/diet/meal-templates"),
}

_PUBLIC_PREFIXES = ("/docs", "/redoc", "/openapi.json", "/uploads/")


def _json_error(status_code: int, detail: str) -> JSONResponse:
    return JSONResponse(status_code=status_code, content={"detail": detail})


def _path_parts(path: str) -> list[str]:
    return [part for part in path.strip("/").split("/") if part]


def _bearer_user(request: Request) -> AuthUser | None:
    header = request.headers.get("authorization", "")
    scheme, _, token = header.partition(" ")
    if scheme.lower() != "bearer" or not token:
        return None
    return decode_access_token(token)


def _mother_for_patient(db: Session, patient_id: str) -> Mother | None:
    return db.query(Mother).filter(Mother.patient_id == patient_id.strip().upper()).first()


def _can_access_patient(db: Session, user: AuthUser, patient_id: str) -> bool:
    pid = patient_id.strip().upper()
    if user.role == "mother":
        return user.user_id == pid
    mother = _mother_for_patient(db, pid)
    if mother is None:
        # Let the endpoint return its normal 404/empty result while still requiring auth.
        return True
    if user.role == "doctor":
        return (mother.doctor_id or "").strip().upper() == user.user_id
    if user.role == "health_worker":
        return (mother.health_worker_id or "").strip().upper() == user.user_id
    return False


def _authorized_for_path(db: Session, user: AuthUser, method: str, path: str) -> bool:
    parts = _path_parts(path)
    if not parts:
        return True

    if parts[0] == "doctor" and len(parts) >= 2:
        return user.role == "doctor" and user.user_id == parts[1].upper()

    if parts[0] == "doctors" and len(parts) >= 2:
        return user.role == "doctor" and user.user_id == parts[1].upper()

    if parts[0] == "health-workers" and len(parts) >= 2:
        return user.role == "health_worker" and user.user_id == parts[1].upper()

    if parts[0] == "home-visits":
        if len(parts) >= 3 and parts[1] == "health-worker":
            return user.role == "health_worker" and user.user_id == parts[2].upper()
        if len(parts) >= 3 and parts[1] == "patient":
            return _can_access_patient(db, user, parts[2])
        return user.role in {"doctor", "health_worker"}

    if parts[0] in {"lab-tests", "reports", "risk", "health-metrics"} and len(parts) >= 2:
        return _can_access_patient(db, user, parts[1])

    if parts[0] == "hydration" and len(parts) >= 3 and parts[1] == "logs":
        return _can_access_patient(db, user, parts[2])

    if parts[0] == "diet":
        if len(parts) >= 3 and parts[1] in {"profile", "restrictions", "doctor-summary"}:
            if parts[1] in {"restrictions", "doctor-summary"} and method in {"POST", "DELETE"}:
                return user.role == "doctor"
            return _can_access_patient(db, user, parts[2])
        if parts[1] in {"plan"} and len(parts) >= 3 and parts[2] not in {"regenerate", "complete-meal"}:
            return _can_access_patient(db, user, parts[2])
        if parts[1] == "ai-assistant-plan":
            if len(parts) >= 4 and parts[2] == "latest":
                return _can_access_patient(db, user, parts[3])
            return user.role == "mother"
        return user.role in {"mother", "doctor"}

    if parts[0] == "education":
        if len(parts) >= 4 and parts[1] == "articles" and parts[2] == "recommended":
            return _can_access_patient(db, user, parts[3])
        if len(parts) >= 4 and parts[1] == "tips" and parts[2] == "today":
            return _can_access_patient(db, user, parts[3])
        if len(parts) >= 3 and parts[1] in {"bookmarks", "streak"}:
            return user.user_id == parts[2].upper() or user.role == "doctor"
        if len(parts) >= 4 and parts[1] == "articles" and parts[3] == "bookmark":
            return user.role == "mother"
        if method == "POST":
            return user.role == "doctor"

    if parts[0] == "mothers" and len(parts) >= 2:
        return _can_access_patient(db, user, parts[1])

    if parts[0] == "mothers" and len(parts) == 1:
        return user.role in {"doctor", "health_worker"}

    if parts[0] == "chat":
        return user.role in {"mother", "doctor", "health_worker"}

    if parts[0] in {"deliveries", "newborns", "emergencies"}:
        return user.role == "doctor"

    if parts[0] in {"fetal-growth"}:
        return user.role in {"doctor", "health_worker"}

    return True


@app.middleware("http")
async def authenticate_and_authorize(request: Request, call_next):
    method = request.method.upper()
    path = request.url.path.rstrip("/") or "/"
    if (method, path) in _PUBLIC_ROUTES or any(path.startswith(prefix) for prefix in _PUBLIC_PREFIXES):
        return await call_next(request)
    if method == "GET" and re.fullmatch(r"/education/articles/\d+", path):
        return await call_next(request)

    user = _bearer_user(request)
    if user is None:
        return _json_error(401, "Authentication required")

    db = SessionLocal()
    try:
        if not _authorized_for_path(db, user, method, path):
            return _json_error(403, "Not authorized for this resource")
    finally:
        db.close()

    request.state.user = user
    return await call_next(request)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from pydantic import BaseModel

class LoginRequest(BaseModel):
    user_id: str
    password: str


_LOGIN_ATTEMPTS: dict[str, list[float]] = {}
_LOGIN_LIMIT = 10
_LOGIN_WINDOW_SECONDS = 60


def _check_login_rate_limit(user_id: str) -> None:
    now = datetime.utcnow().timestamp()
    key = user_id.strip().upper() or "UNKNOWN"
    attempts = [ts for ts in _LOGIN_ATTEMPTS.get(key, []) if now - ts < _LOGIN_WINDOW_SECONDS]
    if len(attempts) >= _LOGIN_LIMIT:
        _LOGIN_ATTEMPTS[key] = attempts
        raise HTTPException(status_code=429, detail="Too many login attempts")
    attempts.append(now)
    _LOGIN_ATTEMPTS[key] = attempts


def _clear_login_rate_limit(user_id: str) -> None:
    _LOGIN_ATTEMPTS.pop(user_id.strip().upper(), None)

@app.post("/auth/login")
def login(req: LoginRequest, db: Session = Depends(get_db)):
    uid = req.user_id.strip().upper()
    pwd = req.password
    _check_login_rate_limit(uid)

    if uid.startswith("MUM"):
        user = db.query(Mother).filter(Mother.patient_id == uid).first()
        role = "mother"
    elif uid.startswith("HWN"):
        user = db.query(HealthWorker).filter(HealthWorker.worker_id == uid).first()
        role = "health_worker"
    elif uid.startswith("DOC"):
        user = db.query(Doctor).filter(Doctor.doctor_id == uid).first()
        role = "doctor"
    else:
        raise HTTPException(status_code=400, detail="Invalid user ID prefix")

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    stored_password = getattr(user, "password", None)
    if not verify_password(stored_password, pwd):
        raise HTTPException(status_code=401, detail="Invalid password")

    if needs_password_upgrade(stored_password):
        user.password = hash_password(pwd)
        db.commit()

    _clear_login_rate_limit(uid)

    return {
        "message": "Login successful",
        "user_id": uid,
        "role": role,
        "access_token": create_access_token(uid, role),
        "token_type": "bearer",
    }

Base.metadata.create_all(bind=engine)


def _ensure_mothers_columns():
    with engine.begin() as connection:
        column_rows = connection.execute(text("PRAGMA table_info(mothers)")).fetchall()
        existing_columns = {row[1] for row in column_rows}
        if "pregnant_weeks" not in existing_columns:
            connection.execute(text("ALTER TABLE mothers ADD COLUMN pregnant_weeks INTEGER"))
        if "due_date" not in existing_columns:
            connection.execute(text("ALTER TABLE mothers ADD COLUMN due_date DATETIME"))
        if "doctor_id" not in existing_columns:
            connection.execute(text("ALTER TABLE mothers ADD COLUMN doctor_id VARCHAR"))
        if "health_worker_id" not in existing_columns:
            connection.execute(text("ALTER TABLE mothers ADD COLUMN health_worker_id VARCHAR"))
        if "address" not in existing_columns:
            connection.execute(text("ALTER TABLE mothers ADD COLUMN address VARCHAR"))
        if "phone" not in existing_columns:
            connection.execute(text("ALTER TABLE mothers ADD COLUMN phone VARCHAR"))
        if "emergency_contact" not in existing_columns:
            connection.execute(text("ALTER TABLE mothers ADD COLUMN emergency_contact VARCHAR"))
        if "allergies" not in existing_columns:
            connection.execute(text("ALTER TABLE mothers ADD COLUMN allergies VARCHAR"))
        if "password" not in existing_columns:
            connection.execute(text("ALTER TABLE mothers ADD COLUMN password VARCHAR"))


def _ensure_doctors_columns():
    with engine.begin() as connection:
        rows = connection.execute(text("PRAGMA table_info(doctors)")).fetchall()
        cols = {row[1] for row in rows}
        if "phone" not in cols:
            connection.execute(text("ALTER TABLE doctors ADD COLUMN phone VARCHAR"))
        if "password" not in cols:
            connection.execute(text("ALTER TABLE doctors ADD COLUMN password VARCHAR"))


def _ensure_health_workers_columns():
    with engine.begin() as connection:
        rows = connection.execute(text("PRAGMA table_info(health_workers)")).fetchall()
        cols = {row[1] for row in rows}
        if "phone" not in cols:
            connection.execute(text("ALTER TABLE health_workers ADD COLUMN phone VARCHAR"))
        if "region" not in cols:
            connection.execute(text("ALTER TABLE health_workers ADD COLUMN region VARCHAR"))
        if "profile_image_path" not in cols:
            connection.execute(text("ALTER TABLE health_workers ADD COLUMN profile_image_path VARCHAR"))
        if "password" not in cols:
            connection.execute(text("ALTER TABLE health_workers ADD COLUMN password VARCHAR"))


def _ensure_lab_tests_columns():
    with engine.begin() as connection:
        rows = connection.execute(text("PRAGMA table_info(lab_tests)")).fetchall()
        cols = {row[1] for row in rows}
        if "femur_length_cm" not in cols:
            connection.execute(text("ALTER TABLE lab_tests ADD COLUMN femur_length_cm FLOAT"))
        if "head_circumference_cm" not in cols:
            connection.execute(text("ALTER TABLE lab_tests ADD COLUMN head_circumference_cm FLOAT"))


def _ensure_fetal_growth_data_columns():
    with engine.begin() as connection:
        rows = connection.execute(text("PRAGMA table_info(fetal_growth_data)")).fetchall()
        cols = {row[1] for row in rows}
        if "femur_length_cm" not in cols:
            connection.execute(text("ALTER TABLE fetal_growth_data ADD COLUMN femur_length_cm FLOAT"))
        if "head_circumference_cm" not in cols:
            connection.execute(text("ALTER TABLE fetal_growth_data ADD COLUMN head_circumference_cm FLOAT"))


def _ensure_health_metrics_columns():
    """Add vitals columns used by the maternal risk engine (existing SQLite DBs)."""
    with engine.begin() as connection:
        rows = connection.execute(text("PRAGMA table_info(health_metrics)")).fetchall()
        if not rows:
            return
        cols = {row[1] for row in rows}
        if "oxygen_saturation" not in cols:
            connection.execute(text("ALTER TABLE health_metrics ADD COLUMN oxygen_saturation FLOAT"))
        if "fetal_movement" not in cols:
            connection.execute(text("ALTER TABLE health_metrics ADD COLUMN fetal_movement VARCHAR(30)"))
        if "swelling" not in cols:
            connection.execute(text("ALTER TABLE health_metrics ADD COLUMN swelling VARCHAR(40)"))


def _ensure_pill_prescription_columns():
    with engine.begin() as connection:
        rows = connection.execute(text("PRAGMA table_info(pill_prescriptions)")).fetchall()
        if not rows:
            return
        cols = {row[1] for row in rows}
        additions = [
            ("dose_schedule_json", "ALTER TABLE pill_prescriptions ADD COLUMN dose_schedule_json TEXT"),
            ("trimester_safety", "ALTER TABLE pill_prescriptions ADD COLUMN trimester_safety VARCHAR(80)"),
            ("refill_reminder_days", "ALTER TABLE pill_prescriptions ADD COLUMN refill_reminder_days INTEGER"),
            ("interaction_warnings", "ALTER TABLE pill_prescriptions ADD COLUMN interaction_warnings VARCHAR(500)"),
            ("allergy_concerns", "ALTER TABLE pill_prescriptions ADD COLUMN allergy_concerns VARCHAR(500)"),
        ]
        for name, stmt in additions:
            if name not in cols:
                connection.execute(text(stmt))


def _ensure_tools_tables():
    # Create all new tables for tools data
    Base.metadata.create_all(bind=engine, tables=[
        ContractionSession.__table__,
        KickSession.__table__,
        SleepSession.__table__,
        PillPrescription.__table__,
        PillIntake.__table__,
        Appointment.__table__,
        DietLog.__table__,
        FetalGrowthData.__table__,
        HydrationLog.__table__,
        StepsLog.__table__,
        HealthMetrics.__table__,
        ChatRoom.__table__,
        ChatMessage.__table__,
        ChatNotification.__table__,
        HealthWorker.__table__,
        HomeVisit.__table__,
        LabTest.__table__,
        Report.__table__,
        RiskAssessment.__table__,
        MotherDietProfile.__table__,
        MealTemplate.__table__,
        DoctorDietRestriction.__table__,
        DietPlan.__table__,
        MealCompletion.__table__,
        AiDietAssistantPlan.__table__,
        Article.__table__,
        Faq.__table__,
        DailyTip.__table__,
        ArticleBookmark.__table__,
        ReadingProgress.__table__,
        SymptomLog.__table__,
        MoodLog.__table__,
        DeliveryRecord.__table__,
        NewbornRecord.__table__,
        NewbornVital.__table__,
        NewbornVaccination.__table__,
        EmergencyAlert.__table__,
    ])


_ensure_mothers_columns()
_ensure_doctors_columns()
_ensure_health_workers_columns()
_ensure_lab_tests_columns()
_ensure_fetal_growth_data_columns()
_ensure_tools_tables()
_ensure_health_metrics_columns()
_ensure_pill_prescription_columns()


def _seed_diet_library() -> None:
    """Idempotently seed curated meal templates on startup."""
    db = SessionLocal()
    try:
        seed_meal_templates(db)
    finally:
        db.close()


def _seed_education_library() -> None:
    """Idempotently seed curated articles, FAQs and daily tips on startup."""
    db = SessionLocal()
    try:
        seed_education(db)
    finally:
        db.close()


def _seed_doctor_demo() -> None:
    db = SessionLocal()
    try:
        seed_doctor_demo(db)
    finally:
        db.close()


_seed_diet_library()
_seed_education_library()
_seed_doctor_demo()

UPLOADS_DIR = Path("uploads")
UPLOADS_DIR.mkdir(parents=True, exist_ok=True)

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request as StarletteRequest

class _CrossOriginResourcePolicyMiddleware(BaseHTTPMiddleware):
    """Add Cross-Origin-Resource-Policy: cross-origin to /uploads responses
    so Flutter Web (Chrome) can load profile images across origins."""
    async def dispatch(self, request: StarletteRequest, call_next):
        response = await call_next(request)
        if request.url.path.startswith("/uploads"):
            response.headers["Cross-Origin-Resource-Policy"] = "cross-origin"
        return response

app.add_middleware(_CrossOriginResourcePolicyMiddleware)
app.mount("/uploads", StaticFiles(directory=str(UPLOADS_DIR)), name="uploads")


@app.get("/health")
def health():
    return {"ok": True}


@app.post("/mothers/onboarding")
async def create_or_update_mother_onboarding(
    patient_id: str = Form(...),
    full_name: str = Form(...),
    age: int | None = Form(default=None),
    weight_kg: float | None = Form(default=None),
    blood_group: str | None = Form(default=None),
    pregnant_weeks: int | None = Form(default=None),
    due_date: str | None = Form(default=None),
    phone: str | None = Form(default=None),
    address: str | None = Form(default=None),
    emergency_contact: str | None = Form(default=None),
    allergies: str | None = Form(default=None),
    password: str | None = Form(default=None),
    profile_image: UploadFile | None = File(default=None),
    db: Session = Depends(get_db),
):
    patient_id = patient_id.strip().upper()
    full_name = full_name.strip()

    if not patient_id:
        raise HTTPException(status_code=400, detail="patient_id is required")
    if not full_name:
        raise HTTPException(status_code=400, detail="full_name is required")

    parsed_due_date: datetime | None = None
    if due_date:
        try:
            parsed_due_date = datetime.fromisoformat(due_date)
        except ValueError as error:
            raise HTTPException(status_code=400, detail="Invalid due_date format") from error

    stored_image_path = None
    if profile_image is not None:
        ext = os.path.splitext(profile_image.filename or "")[1].lower()
        if ext not in {".jpg", ".jpeg", ".png", ".webp"}:
            raise HTTPException(status_code=400, detail="Unsupported image format")

        filename = f"{patient_id}_{uuid4().hex}{ext}"
        target_path = UPLOADS_DIR / filename
        with target_path.open("wb") as output_file:
            shutil.copyfileobj(profile_image.file, output_file)
        stored_image_path = str(target_path)

    if parsed_due_date is None and pregnant_weeks is not None:
        parsed_due_date = infer_due_date_from_weeks(pregnant_weeks)

    mother = db.query(Mother).filter(Mother.patient_id == patient_id).first()
    if mother is None:
        if not password:
            raise HTTPException(status_code=400, detail="password is required")
        mother = Mother(
            patient_id=patient_id,
            full_name=full_name,
            age=age,
            weight_kg=weight_kg,
            blood_group=blood_group,
            pregnant_weeks=pregnant_weeks,
            due_date=parsed_due_date,
            profile_image_path=stored_image_path,
            phone=phone,
            address=address,
            emergency_contact=emergency_contact,
            allergies=allergies,
            password=hash_password(password),
        )
        db.add(mother)
    else:
        mother.full_name = full_name
        mother.age = age
        mother.weight_kg = weight_kg
        mother.blood_group = blood_group
        mother.pregnant_weeks = pregnant_weeks
        if parsed_due_date is not None:
            mother.due_date = parsed_due_date
        elif pregnant_weeks is not None:
            mother.due_date = infer_due_date_from_weeks(
                pregnant_weeks,
                anchor=mother.created_at or datetime.utcnow(),
            )
        mother.phone = phone
        mother.address = address
        mother.emergency_contact = emergency_contact
        mother.allergies = allergies
        if password is not None:
            if not password:
                raise HTTPException(status_code=400, detail="password is required")
            mother.password = hash_password(password)
        if stored_image_path is not None:
            mother.profile_image_path = stored_image_path

    db.commit()
    db.refresh(mother)

    return {
        "id": mother.id,
        "patient_id": mother.patient_id,
        "full_name": mother.full_name,
        "age": mother.age,
        "weight_kg": mother.weight_kg,
        "blood_group": mother.blood_group,
        "pregnant_weeks": current_pregnant_weeks(mother),
        "due_date": mother.due_date.isoformat() if mother.due_date else None,
        "profile_image_path": mother.profile_image_path,
        "phone": mother.phone,
        "address": mother.address,
        "emergency_contact": mother.emergency_contact,
        "allergies": mother.allergies,
    }


@app.get("/mothers/{patient_id}")
def get_mother_by_patient_id(patient_id: str, db: Session = Depends(get_db)):
    normalized_id = patient_id.strip().upper()
    mother = db.query(Mother).filter(Mother.patient_id == normalized_id).first()
    if mother is None:
        raise HTTPException(status_code=404, detail="Mother record not found")

    if mother.due_date is None and mother.pregnant_weeks is not None:
        ensure_due_date_from_weeks(mother)
        db.commit()
        db.refresh(mother)

    return {
        "id": mother.id,
        "patient_id": mother.patient_id,
        "full_name": mother.full_name,
        "age": mother.age,
        "weight_kg": mother.weight_kg,
        "blood_group": mother.blood_group,
        "pregnant_weeks": current_pregnant_weeks(mother),
        "due_date": mother.due_date.isoformat() if mother.due_date else None,
        "profile_image_path": mother.profile_image_path,
        "doctor_id": mother.doctor_id,
        "health_worker_id": mother.health_worker_id,
        "phone": mother.phone,
        "address": mother.address,
        "emergency_contact": mother.emergency_contact,
        "allergies": mother.allergies,
    }


@app.get("/mothers")
def list_mothers(db: Session = Depends(get_db)):
    mothers = db.query(Mother).order_by(Mother.id.desc()).all()
    return [
        {
            "id": mother.id,
            "patient_id": mother.patient_id,
            "full_name": mother.full_name,
            "age": mother.age,
            "weight_kg": mother.weight_kg,
            "blood_group": mother.blood_group,
            "pregnant_weeks": current_pregnant_weeks(mother),
            "due_date": mother.due_date.isoformat() if mother.due_date else None,
            "profile_image_path": mother.profile_image_path,
            "doctor_id": mother.doctor_id,
            "created_at": mother.created_at.isoformat() if mother.created_at else None,
        }
        for mother in mothers
    ]


@app.post("/doctors/onboarding")
def create_or_update_doctor_onboarding(
    doctor_id: str = Form(...),
    full_name: str = Form(...),
    phone: str | None = Form(default=None),
    password: str | None = Form(default=None),
    db: Session = Depends(get_db),
):
    normalized_id = doctor_id.strip().upper()
    full_name = full_name.strip()
    if not normalized_id:
        raise HTTPException(status_code=400, detail="doctor_id is required")
    if not full_name:
        raise HTTPException(status_code=400, detail="full_name is required")
    if password is not None and not password:
        raise HTTPException(status_code=400, detail="password is required")

    doctor = db.query(Doctor).filter(Doctor.doctor_id == normalized_id).first()
    if doctor is None:
        if not password:
            raise HTTPException(status_code=400, detail="password is required")
        doctor = Doctor(
            doctor_id=normalized_id,
            full_name=full_name,
            phone=phone,
            password=hash_password(password),
        )
        db.add(doctor)
    else:
        doctor.full_name = full_name
        if phone is not None:
            doctor.phone = phone
        if password is not None:
            doctor.password = hash_password(password)

    db.commit()
    db.refresh(doctor)
    return {
        "id": doctor.id,
        "doctor_id": doctor.doctor_id,
        "full_name": doctor.full_name,
        "phone": doctor.phone,
        "created_at": doctor.created_at.isoformat() if doctor.created_at else None,
    }


@app.put("/mothers/{patient_id}")
def update_mother_profile(
    patient_id: str,
    profile_data: dict = Body(...),
    db: Session = Depends(get_db),
):
    normalized_id = patient_id.strip().upper()
    mother = db.query(Mother).filter(Mother.patient_id == normalized_id).first()
    
    if mother is None:
        raise HTTPException(status_code=404, detail="Mother record not found")
    
    # Map every supported field from the JSON payload onto the Mother model.
    # We accept either ``name`` (legacy) or ``full_name``.
    if "name" in profile_data and profile_data["name"]:
        mother.full_name = profile_data["name"]
    if "full_name" in profile_data and profile_data["full_name"]:
        mother.full_name = profile_data["full_name"]
    if "blood_group" in profile_data:
        mother.blood_group = profile_data["blood_group"]
    if "age" in profile_data and profile_data["age"] not in (None, ""):
        try:
            mother.age = int(profile_data["age"])
        except (TypeError, ValueError):
            pass
    if "weight_kg" in profile_data and profile_data["weight_kg"] not in (None, ""):
        try:
            mother.weight_kg = float(profile_data["weight_kg"])
        except (TypeError, ValueError):
            pass
    if "pregnant_weeks" in profile_data and profile_data["pregnant_weeks"] not in (None, ""):
        try:
            new_weeks = int(profile_data["pregnant_weeks"])
            mother.pregnant_weeks = new_weeks
            if "due_date" not in profile_data or not profile_data["due_date"]:
                mother.due_date = infer_due_date_from_weeks(new_weeks)
        except (TypeError, ValueError):
            pass
    if "due_date" in profile_data and profile_data["due_date"]:
        try:
            mother.due_date = datetime.fromisoformat(profile_data["due_date"])
        except ValueError:
            pass
    if "phone" in profile_data:
        mother.phone = profile_data["phone"]
    if "emergency_contact" in profile_data:
        mother.emergency_contact = profile_data["emergency_contact"]
    if "address" in profile_data:
        mother.address = profile_data["address"]
    if "allergies" in profile_data:
        mother.allergies = profile_data["allergies"]

    db.commit()
    db.refresh(mother)

    return {
        "id": mother.id,
        "patient_id": mother.patient_id,
        "full_name": mother.full_name,
        "age": mother.age,
        "weight_kg": mother.weight_kg,
        "blood_group": mother.blood_group,
        "pregnant_weeks": current_pregnant_weeks(mother),
        "due_date": mother.due_date.isoformat() if mother.due_date else None,
        "profile_image_path": mother.profile_image_path,
        "doctor_id": mother.doctor_id,
        "health_worker_id": mother.health_worker_id,
        "phone": mother.phone,
        "address": mother.address,
        "emergency_contact": mother.emergency_contact,
        "updated_at": datetime.now().isoformat(),
    }


@app.post("/mothers/{patient_id}/profile-image")
async def upload_mother_profile_image(
    patient_id: str,
    profile_image: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    """Upload (or replace) a mother's profile image. Returns the new path."""
    normalized_id = patient_id.strip().upper()
    mother = db.query(Mother).filter(Mother.patient_id == normalized_id).first()
    if mother is None:
        raise HTTPException(status_code=404, detail="Mother record not found")

    ext = os.path.splitext(profile_image.filename or "")[1].lower()
    if ext not in {".jpg", ".jpeg", ".png", ".webp"}:
        raise HTTPException(status_code=400, detail="Unsupported image format")

    filename = f"{normalized_id}_{uuid4().hex}{ext}"
    target_path = UPLOADS_DIR / filename
    with target_path.open("wb") as output_file:
        shutil.copyfileobj(profile_image.file, output_file)
    mother.profile_image_path = str(target_path)
    db.commit()
    db.refresh(mother)
    return {
        "patient_id": mother.patient_id,
        "profile_image_path": mother.profile_image_path,
    }


@app.get("/doctors/{doctor_id}/patients")
def get_patients_by_doctor(doctor_id: str, db: Session = Depends(get_db)):
    normalized_doctor_id = doctor_id.strip().upper()
    patients = db.query(Mother).filter(Mother.doctor_id == normalized_doctor_id).order_by(Mother.created_at.desc()).all()
    return [
        {
            "id": mother.id,
            "patient_id": mother.patient_id,
            "full_name": mother.full_name,
            "age": mother.age,
            "blood_group": mother.blood_group,
            "pregnant_weeks": current_pregnant_weeks(mother),
            "due_date": mother.due_date.isoformat() if mother.due_date else None,
            "created_at": mother.created_at.isoformat() if mother.created_at else None,
        }
        for mother in patients
    ]


@app.post("/doctors/{doctor_id}/assign-patient/{patient_id}")
def assign_patient_to_doctor(
    doctor_id: str,
    patient_id: str,
    db: Session = Depends(get_db),
):
    normalized_doctor_id = doctor_id.strip().upper()
    normalized_patient_id = patient_id.strip().upper()
    
    mother = db.query(Mother).filter(Mother.patient_id == normalized_patient_id).first()
    if mother is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    
    mother.doctor_id = normalized_doctor_id
    db.commit()
    db.refresh(mother)
    
    return {
        "message": "Patient assigned to doctor successfully",
        "patient_id": mother.patient_id,
        "doctor_id": mother.doctor_id,
        "full_name": mother.full_name,
    }


@app.post("/mothers/{patient_id}/contractions")
def save_contraction_session(
    patient_id: str,
    session_date: str = Form(...),
    contraction_seconds: int = Form(...),
    relaxation_seconds: int = Form(...),
    lap_count: int = Form(...),
    timeline_data: str = Form(default=""),
    db: Session = Depends(get_db),
):
    normalized_id = patient_id.strip().upper()
    if not normalized_id:
        raise HTTPException(status_code=400, detail="patient_id is required")

    try:
        parsed_date = datetime.fromisoformat(session_date)
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid session_date format") from error

    session = ContractionSession(
        patient_id=normalized_id,
        session_date=parsed_date,
        contraction_seconds=max(contraction_seconds, 0),
        relaxation_seconds=max(relaxation_seconds, 0),
        lap_count=max(lap_count, 0),
        timeline_data=timeline_data if timeline_data else None,
    )
    db.add(session)
    db.commit()
    db.refresh(session)

    return {
        "id": session.id,
        "patient_id": session.patient_id,
        "session_date": session.session_date.isoformat(),
        "contraction_seconds": session.contraction_seconds,
        "relaxation_seconds": session.relaxation_seconds,
        "lap_count": session.lap_count,
        "timeline_data": session.timeline_data,
        "created_at": session.created_at.isoformat() if session.created_at else None,
    }


@app.get("/mothers/{patient_id}/contractions")
def list_contraction_sessions(patient_id: str, db: Session = Depends(get_db)):
    normalized_id = patient_id.strip().upper()
    sessions = (
        db.query(ContractionSession)
        .filter(ContractionSession.patient_id == normalized_id)
        .order_by(ContractionSession.session_date.desc())
        .all()
    )
    return [
        {
            "id": session.id,
            "patient_id": session.patient_id,
            "session_date": session.session_date.isoformat(),
            "contraction_seconds": session.contraction_seconds,
            "relaxation_seconds": session.relaxation_seconds,
            "lap_count": session.lap_count,
            "timeline_data": session.timeline_data,
            "created_at": session.created_at.isoformat() if session.created_at else None,
        }
        for session in sessions
    ]


@app.post("/mothers/{patient_id}/sleep")
def save_sleep_session(
    patient_id: str,
    session_date: str = Form(...),
    sleep_hours: float = Form(...),
    goal_hours: float = Form(...),
    db: Session = Depends(get_db),
):
    """Upsert a sleep session per calendar day.

    If a row already exists for the same calendar date, update it rather than
    creating a duplicate. Mothers should see exactly one sleep entry per day.
    """
    normalized_id = patient_id.strip().upper()
    if not normalized_id:
        raise HTTPException(status_code=400, detail="patient_id is required")

    try:
        parsed_date = datetime.fromisoformat(session_date)
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid session_date format") from error

    day_start = datetime(parsed_date.year, parsed_date.month, parsed_date.day)
    day_end = day_start + timedelta(days=1)
    is_goal_met = sleep_hours >= goal_hours

    session = (
        db.query(SleepSession)
        .filter(
            SleepSession.patient_id == normalized_id,
            SleepSession.session_date >= day_start,
            SleepSession.session_date < day_end,
        )
        .first()
    )
    if session is None:
        session = SleepSession(
            patient_id=normalized_id,
            session_date=parsed_date,
            sleep_hours=max(sleep_hours, 0.0),
            goal_hours=max(goal_hours, 0.0),
            is_goal_met=is_goal_met,
        )
        db.add(session)
    else:
        session.session_date = parsed_date
        session.sleep_hours = max(sleep_hours, 0.0)
        session.goal_hours = max(goal_hours, 0.0)
        session.is_goal_met = is_goal_met
    db.commit()
    db.refresh(session)

    return {
        "id": session.id,
        "patient_id": session.patient_id,
        "session_date": session.session_date.isoformat(),
        "sleep_hours": session.sleep_hours,
        "goal_hours": session.goal_hours,
        "is_goal_met": session.is_goal_met,
        "created_at": session.created_at.isoformat() if session.created_at else None,
    }


@app.get("/mothers/{patient_id}/sleep")
def list_sleep_sessions(patient_id: str, db: Session = Depends(get_db)):
    normalized_id = patient_id.strip().upper()
    sessions = (
        db.query(SleepSession)
        .filter(SleepSession.patient_id == normalized_id)
        .order_by(SleepSession.session_date.desc())
        .all()
    )
    return [
        {
            "id": session.id,
            "patient_id": session.patient_id,
            "session_date": session.session_date.isoformat(),
            "sleep_hours": session.sleep_hours,
            "goal_hours": session.goal_hours,
            "is_goal_met": session.is_goal_met,
            "created_at": session.created_at.isoformat() if session.created_at else None,
        }
        for session in sessions
    ]


@app.post("/mothers/{patient_id}/kicks")
def save_kick_session(
    patient_id: str,
    session_date: str = Form(...),
    kick_count: int = Form(...),
    duration_minutes: float = Form(...),
    db: Session = Depends(get_db),
):
    normalized_id = patient_id.strip().upper()
    if not normalized_id:
        raise HTTPException(status_code=400, detail="patient_id is required")

    try:
        parsed_date = datetime.fromisoformat(session_date)
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid session_date format") from error

    session = KickSession(
        patient_id=normalized_id,
        session_date=parsed_date,
        kick_count=max(kick_count, 0),
        duration_minutes=max(duration_minutes, 0.0),
    )
    db.add(session)
    db.commit()
    db.refresh(session)

    return {
        "id": session.id,
        "patient_id": session.patient_id,
        "session_date": session.session_date.isoformat(),
        "kick_count": session.kick_count,
        "duration_minutes": session.duration_minutes,
        "created_at": session.created_at.isoformat() if session.created_at else None,
    }


@app.get("/mothers/{patient_id}/kicks")
def list_kick_sessions(patient_id: str, db: Session = Depends(get_db)):
    normalized_id = patient_id.strip().upper()
    sessions = (
        db.query(KickSession)
        .filter(KickSession.patient_id == normalized_id)
        .order_by(KickSession.session_date.desc())
        .all()
    )
    return [
        {
            "id": session.id,
            "patient_id": session.patient_id,
            "session_date": session.session_date.isoformat(),
            "kick_count": session.kick_count,
            "duration_minutes": session.duration_minutes,
            "created_at": session.created_at.isoformat() if session.created_at else None,
        }
        for session in sessions
    ]


@app.post("/mothers/{patient_id}/prescriptions")
def create_pill_prescription(
    patient_id: str,
    doctor_id: str = Form(...),
    pill_name: str = Form(...),
    dosage: str = Form(...),
    timing: str = Form(...),
    meal_time: str = Form(...),
    frequency: str = Form(...),
    start_date: str = Form(...),
    end_date: str = Form(default=""),
    notes: str = Form(default=""),
    dose_schedule_json: str = Form(default=""),
    trimester_safety: str = Form(default=""),
    refill_reminder_days: int = Form(default=0),
    interaction_warnings: str = Form(default=""),
    allergy_concerns: str = Form(default=""),
    db: Session = Depends(get_db),
):
    normalized_patient_id = patient_id.strip().upper()
    normalized_doctor_id = doctor_id.strip().upper()

    allowed_timing = {"before_food", "after_food", "with_food"}
    allowed_meals = {
        "breakfast", "lunch", "dinner", "morning", "afternoon", "evening", "night", "bedtime",
    }

    if not normalized_patient_id:
        raise HTTPException(status_code=400, detail="patient_id is required")
    if not normalized_doctor_id:
        raise HTTPException(status_code=400, detail="doctor_id is required")
    if not pill_name:
        raise HTTPException(status_code=400, detail="pill_name is required")
    if timing not in allowed_timing:
        raise HTTPException(
            status_code=400,
            detail="timing must be 'before_food', 'after_food', or 'with_food'",
        )
    mt = (meal_time or "").strip().lower()
    if mt not in allowed_meals and not mt.startswith("dose_"):
        raise HTTPException(
            status_code=400,
            detail="meal_time must be a known period or dose_* slot id",
        )

    dose_json_clean = dose_schedule_json.strip() if dose_schedule_json else None
    if dose_json_clean:
        try:
            parsed_schedule = json.loads(dose_json_clean)
            if not isinstance(parsed_schedule, dict):
                raise ValueError("schedule must be an object")
        except (json.JSONDecodeError, ValueError) as error:
            raise HTTPException(status_code=400, detail="Invalid dose_schedule_json") from error

    try:
        parsed_start_date = datetime.fromisoformat(start_date)
        parsed_end_date = datetime.fromisoformat(end_date) if end_date else None
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid date format") from error

    refill_val = refill_reminder_days if refill_reminder_days and refill_reminder_days > 0 else None

    prescription = PillPrescription(
        patient_id=normalized_patient_id,
        doctor_id=normalized_doctor_id,
        pill_name=pill_name.strip(),
        dosage=dosage.strip(),
        timing=timing,
        meal_time=mt,
        frequency=frequency.strip(),
        start_date=parsed_start_date,
        end_date=parsed_end_date,
        notes=notes.strip() if notes else None,
        dose_schedule_json=dose_json_clean,
        trimester_safety=trimester_safety.strip() if trimester_safety else None,
        refill_reminder_days=refill_val,
        interaction_warnings=interaction_warnings.strip() if interaction_warnings else None,
        allergy_concerns=allergy_concerns.strip() if allergy_concerns else None,
    )
    db.add(prescription)
    db.commit()
    db.refresh(prescription)

    return {
        "id": prescription.id,
        "patient_id": prescription.patient_id,
        "doctor_id": prescription.doctor_id,
        "pill_name": prescription.pill_name,
        "dosage": prescription.dosage,
        "timing": prescription.timing,
        "meal_time": prescription.meal_time,
        "frequency": prescription.frequency,
        "start_date": prescription.start_date.isoformat(),
        "end_date": prescription.end_date.isoformat() if prescription.end_date else None,
        "notes": prescription.notes,
        "dose_schedule_json": prescription.dose_schedule_json,
        "trimester_safety": prescription.trimester_safety,
        "refill_reminder_days": prescription.refill_reminder_days,
        "interaction_warnings": prescription.interaction_warnings,
        "allergy_concerns": prescription.allergy_concerns,
        "is_active": prescription.is_active,
        "created_at": prescription.created_at.isoformat() if prescription.created_at else None,
    }


@app.get("/mothers/{patient_id}/prescriptions")
def list_pill_prescriptions(patient_id: str, db: Session = Depends(get_db)):
    normalized_id = patient_id.strip().upper()
    prescriptions = (
        db.query(PillPrescription)
        .filter(PillPrescription.patient_id == normalized_id, PillPrescription.is_active == True)
        .order_by(PillPrescription.created_at.desc())
        .all()
    )
    return [
        {
            "id": prescription.id,
            "patient_id": prescription.patient_id,
            "doctor_id": prescription.doctor_id,
            "pill_name": prescription.pill_name,
            "dosage": prescription.dosage,
            "timing": prescription.timing,
            "meal_time": prescription.meal_time,
            "frequency": prescription.frequency,
            "start_date": prescription.start_date.isoformat(),
            "end_date": prescription.end_date.isoformat() if prescription.end_date else None,
            "notes": prescription.notes,
            "dose_schedule_json": prescription.dose_schedule_json,
            "trimester_safety": prescription.trimester_safety,
            "refill_reminder_days": prescription.refill_reminder_days,
            "interaction_warnings": prescription.interaction_warnings,
            "allergy_concerns": prescription.allergy_concerns,
            "is_active": prescription.is_active,
            "created_at": prescription.created_at.isoformat() if prescription.created_at else None,
        }
        for prescription in prescriptions
    ]


@app.post("/mothers/{patient_id}/pill-intake")
def record_pill_intake(
    patient_id: str,
    prescription_id: int = Form(...),
    intake_date: str = Form(...),
    meal_time: str = Form(...),
    taken: bool = Form(...),
    notes: str = Form(default=""),
    db: Session = Depends(get_db),
):
    normalized_id = patient_id.strip().upper()
    meal_key = (meal_time or "").strip().lower()

    allowed = {
        "breakfast", "lunch", "dinner", "morning", "afternoon", "evening", "night", "bedtime",
    }
    if not meal_key or (meal_key not in allowed and not meal_key.startswith("dose_")):
        raise HTTPException(
            status_code=400,
            detail="meal_time must be a known period or dose_* (e.g. dose_0)",
        )

    if not normalized_id:
        raise HTTPException(status_code=400, detail="patient_id is required")

    try:
        parsed_date = datetime.fromisoformat(intake_date)
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid intake_date format") from error

    intake = PillIntake(
        patient_id=normalized_id,
        prescription_id=prescription_id,
        intake_date=parsed_date,
        meal_time=meal_key,
        taken=taken,
        taken_at=datetime.now() if taken else None,
        notes=notes.strip() if notes else None,
    )
    db.add(intake)
    db.commit()
    db.refresh(intake)

    return {
        "id": intake.id,
        "patient_id": intake.patient_id,
        "prescription_id": intake.prescription_id,
        "intake_date": intake.intake_date.isoformat(),
        "meal_time": intake.meal_time,
        "taken": intake.taken,
        "taken_at": intake.taken_at.isoformat() if intake.taken_at else None,
        "notes": intake.notes,
        "created_at": intake.created_at.isoformat() if intake.created_at else None,
    }


@app.get("/mothers/{patient_id}/pill-intake")
def list_pill_intakes(
    patient_id: str,
    date: str = "",
    db: Session = Depends(get_db),
):
    """List pill intakes, optionally filtered to a single day.

    ``date`` is a query parameter (ISO datetime). When provided, returns every
    intake whose ``intake_date`` falls on the same calendar day.
    """
    normalized_id = patient_id.strip().upper()

    query = db.query(PillIntake).filter(PillIntake.patient_id == normalized_id)

    if date:
        try:
            parsed_date = datetime.fromisoformat(date)
            day_start = datetime(parsed_date.year, parsed_date.month, parsed_date.day)
            day_end = day_start + timedelta(days=1)
            query = query.filter(
                PillIntake.intake_date >= day_start,
                PillIntake.intake_date < day_end,
            )
        except ValueError:
            pass  # invalid date → ignore filter
    
    intakes = query.order_by(PillIntake.intake_date.desc()).all()
    
    return [
        {
            "id": intake.id,
            "patient_id": intake.patient_id,
            "prescription_id": intake.prescription_id,
            "intake_date": intake.intake_date.isoformat(),
            "meal_time": intake.meal_time,
            "taken": intake.taken,
            "taken_at": intake.taken_at.isoformat() if intake.taken_at else None,
            "notes": intake.notes,
            "created_at": intake.created_at.isoformat() if intake.created_at else None,
        }
        for intake in intakes
    ]


_MEAL_ORDER = {
    "breakfast": 0,
    "morning": 1,
    "mid_morning": 2,
    "lunch": 3,
    "afternoon": 4,
    "evening": 5,
    "evening_snack": 5,
    "dinner": 6,
    "night": 7,
    "bedtime": 8,
    "dose_0": 20,
    "dose_1": 21,
    "dose_2": 22,
    "dose_3": 23,
    "dose_4": 24,
    "dose_5": 25,
}


def _infer_doses_per_day(frequency: str) -> int:
    f = (frequency or "").lower().replace("-", " ").replace("_", " ")
    if any(x in f for x in ("qid", "four time", "4 time", "4x daily", "4 x")):
        return 4
    if any(x in f for x in ("tid", "three time", "3 time", "3x daily", "3 x")):
        return 3
    if any(x in f for x in ("bid", "twice", "2 time", "2x daily", "2 x", "two time")):
        return 2
    m = re.search(r"\b([2-4])\s*time", f)
    if m:
        return int(m.group(1))
    return 1


def _dose_slot_ids_for_prescription(p: PillPrescription) -> list[str]:
    raw = getattr(p, "dose_schedule_json", None)
    if raw:
        try:
            data = json.loads(raw)
            doses = data.get("doses") or []
            ids: list[str] = []
            for i, d in enumerate(doses):
                mid = str(d.get("id") or "").strip().lower()
                if not mid:
                    mid = f"dose_{i}"
                ids.append(mid)
            if ids:
                return ids
        except (json.JSONDecodeError, TypeError, ValueError, AttributeError):
            pass
    n = _infer_doses_per_day(p.frequency or "")
    if n <= 1:
        return [(p.meal_time or "breakfast").strip().lower()]
    return [f"dose_{i}" for i in range(n)]


@app.get("/mothers/{patient_id}/pill-history")
def get_pill_history(
    patient_id: str,
    days: int = 30,
    db: Session = Depends(get_db),
):
    """Per-day adherence history for the last ``days`` days.

    A prescription appears on a day when either:
    - its [start_date, end_date] range covers that day, OR
    - the mother has an intake record on that day for it.

    This makes "history" useful even when a prescription has already ended
    but the mother kept a record of doses, and means days with zero activity
    return ``items=[]`` so the client can hide them.
    """
    normalized_id = patient_id.strip().upper()
    days = max(1, min(days, 90))
    today = datetime.utcnow().date()
    start_date = today - timedelta(days=days - 1)
    start_dt = datetime(start_date.year, start_date.month, start_date.day)

    prescriptions = (
        db.query(PillPrescription)
        .filter(PillPrescription.patient_id == normalized_id)
        .all()
    )

    intakes = (
        db.query(PillIntake)
        .filter(
            PillIntake.patient_id == normalized_id,
            PillIntake.intake_date >= start_dt,
        )
        .all()
    )

    # Lookup: (iso-date, prescription_id, meal_time) -> intake
    intake_by_key: dict[tuple[str, int, str], PillIntake] = {}
    # Set of (iso-date, prescription_id) where the mother logged at least one
    # action so we can still surface ended prescriptions on those days.
    intake_days: set[tuple[str, int]] = set()
    for intake in intakes:
        if not intake.intake_date:
            continue
        d = intake.intake_date.date().isoformat()
        meal = (intake.meal_time or "").strip().lower()
        intake_by_key[(d, intake.prescription_id, meal)] = intake
        intake_days.add((d, intake.prescription_id))

    prescriptions_by_id = {p.id: p for p in prescriptions}

    history: list[dict] = []
    for offset in range(days):
        current = today - timedelta(days=offset)
        day_iso = current.isoformat()
        items: list[dict] = []
        taken_count = 0
        missed_count = 0
        for prescription in prescriptions:
            pres_in_range = True
            if prescription.start_date and prescription.start_date.date() > current:
                pres_in_range = False
            if prescription.end_date and prescription.end_date.date() < current:
                pres_in_range = False
            has_intake = (day_iso, prescription.id) in intake_days
            if not pres_in_range and not has_intake:
                continue
            for meal_time in _dose_slot_ids_for_prescription(prescription):
                intake = intake_by_key.get((day_iso, prescription.id, meal_time))
                taken = bool(intake and intake.taken)
                if taken:
                    taken_count += 1
                elif pres_in_range:
                    missed_count += 1
                items.append({
                    "prescription_id": prescription.id,
                    "pill_name": prescription.pill_name,
                    "dosage": prescription.dosage,
                    "timing": prescription.timing,
                    "meal_time": meal_time,
                    "dose_slot": meal_time,
                    "frequency": prescription.frequency,
                    "taken": taken,
                    "in_range": pres_in_range,
                    "taken_at": intake.taken_at.isoformat() if intake and intake.taken_at else None,
                    "notes": intake.notes if intake else None,
                })
        # Stable ordering within a day: by meal time, then pill name.
        items.sort(
            key=lambda it: (
                _MEAL_ORDER.get((it.get("meal_time") or "").lower(), 99),
                (it.get("pill_name") or "").lower(),
            )
        )
        adherence_pct = 0
        total = taken_count + missed_count
        if total:
            adherence_pct = round((taken_count / total) * 100)
        history.append({
            "date": day_iso,
            "items": items,
            "taken": taken_count,
            "missed": missed_count,
            "active_count": sum(1 for it in items if it.get("in_range")),
            "adherence_pct": adherence_pct,
        })

    # Quick header stats for the client.
    total_taken = sum(d["taken"] for d in history)
    total_missed = sum(d["missed"] for d in history)
    window_total = total_taken + total_missed
    window_adherence = (
        round((total_taken / window_total) * 100) if window_total else 0
    )

    return {
        "days": history,
        "window_days": days,
        "total_taken": total_taken,
        "total_missed": total_missed,
        "window_adherence_pct": window_adherence,
        "prescription_count": len(prescriptions_by_id),
    }


@app.post("/mothers/{patient_id}/appointments")
def create_appointment(
    patient_id: str,
    health_worker_id: str = Form(...),
    appointment_date: str = Form(...),
    appointment_time: str = Form(...),
    duration_minutes: int = Form(default=30),
    appointment_type: str = Form(...),
    notes: str = Form(default=""),
    db: Session = Depends(get_db),
):
    normalized_patient_id = patient_id.strip().upper()
    normalized_health_worker_id = health_worker_id.strip().upper()
    
    if not normalized_patient_id:
        raise HTTPException(status_code=400, detail="patient_id is required")
    if not normalized_health_worker_id:
        raise HTTPException(status_code=400, detail="health_worker_id is required")
    if not appointment_time:
        raise HTTPException(status_code=400, detail="appointment_time is required")

    try:
        parsed_date = datetime.fromisoformat(appointment_date)
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid appointment_date format") from error

    appointment = Appointment(
        patient_id=normalized_patient_id,
        health_worker_id=normalized_health_worker_id,
        appointment_date=parsed_date,
        appointment_time=appointment_time.strip(),
        duration_minutes=max(duration_minutes, 15),
        appointment_type=appointment_type.strip(),
        notes=notes.strip() if notes else None,
    )
    db.add(appointment)
    db.commit()
    db.refresh(appointment)

    return {
        "id": appointment.id,
        "patient_id": appointment.patient_id,
        "health_worker_id": appointment.health_worker_id,
        "appointment_date": appointment.appointment_date.isoformat(),
        "appointment_time": appointment.appointment_time,
        "duration_minutes": appointment.duration_minutes,
        "appointment_type": appointment.appointment_type,
        "status": appointment.status,
        "notes": appointment.notes,
        "created_at": appointment.created_at.isoformat() if appointment.created_at else None,
        "updated_at": appointment.updated_at.isoformat() if appointment.updated_at else None,
    }


@app.get("/mothers/{patient_id}/appointments")
def list_appointments(
    patient_id: str,
    date: str = Query(default=""),
    status: str = Query(default=""),
    db: Session = Depends(get_db),
):
    normalized_id = patient_id.strip().upper()
    
    query = db.query(Appointment).filter(Appointment.patient_id == normalized_id)
    
    if date:
        try:
            parsed_date = datetime.fromisoformat(date)
            query = query.filter(Appointment.appointment_date == parsed_date)
        except ValueError:
            pass  # If date is invalid, return all appointments
    
    if status:
        query = query.filter(Appointment.status == status)
    
    appointments = query.order_by(Appointment.appointment_date.asc(), Appointment.appointment_time.asc()).all()
    
    return [
        {
            "id": appointment.id,
            "patient_id": appointment.patient_id,
            "health_worker_id": appointment.health_worker_id,
            "appointment_date": appointment.appointment_date.isoformat(),
            "appointment_time": appointment.appointment_time,
            "duration_minutes": appointment.duration_minutes,
            "appointment_type": appointment.appointment_type,
            "status": appointment.status,
            "notes": appointment.notes,
            "created_at": appointment.created_at.isoformat() if appointment.created_at else None,
            "updated_at": appointment.updated_at.isoformat() if appointment.updated_at else None,
        }
        for appointment in appointments
    ]


# === CHAT API ENDPOINTS ===

app.post("/chat/room")(create_or_get_chat_room)
app.post("/chat/message")(send_message)
app.get("/chat/messages/{room_id}")(get_chat_messages)
app.get("/chat/rooms/{user_id}/{user_type}")(get_user_chat_rooms)
app.post("/chat/read")(mark_messages_as_read)


# === LIVE CHAT WEBSOCKET ===

from .chat_websocket import chat_websocket_endpoint  # noqa: E402  (after app exists)


@app.websocket("/ws/chat/{room_id}")
async def chat_ws(websocket: WebSocket, room_id: str, user_id: str = "", user_type: str = ""):
    """Live chat WebSocket.

    Clients connect to `ws://host/ws/chat/<room_id>?user_id=<id>&user_type=<doctor|mother>`
    and receive `{"type": "message"|"typing"|"presence"|"read"}` events.
    See `app/chat_websocket.py` for the full protocol.
    """
    await chat_websocket_endpoint(websocket, room_id, user_id, user_type)


@app.get("/health-workers/{health_worker_id}/appointments")
def list_health_worker_appointments(
    health_worker_id: str,
    date: str = Query(default=""),
    status: str = Query(default=""),
    db: Session = Depends(get_db),
):
    normalized_id = health_worker_id.strip().upper()
    
    query = db.query(Appointment).filter(Appointment.health_worker_id == normalized_id)
    
    if date:
        try:
            parsed_date = datetime.fromisoformat(date)
            query = query.filter(Appointment.appointment_date == parsed_date)
        except ValueError:
            pass  # If date is invalid, return all appointments
    
    if status:
        query = query.filter(Appointment.status == status)
    
    appointments = query.order_by(Appointment.appointment_date.asc(), Appointment.appointment_time.asc()).all()
    
    return [
        {
            "id": appointment.id,
            "patient_id": appointment.patient_id,
            "health_worker_id": appointment.health_worker_id,
            "appointment_date": appointment.appointment_date.isoformat(),
            "appointment_time": appointment.appointment_time,
            "duration_minutes": appointment.duration_minutes,
            "appointment_type": appointment.appointment_type,
            "status": appointment.status,
            "notes": appointment.notes,
            "created_at": appointment.created_at.isoformat() if appointment.created_at else None,
            "updated_at": appointment.updated_at.isoformat() if appointment.updated_at else None,
        }
        for appointment in appointments
    ]


@app.put("/appointments/{appointment_id}")
def update_appointment_status(
    appointment_id: int,
    status: str = Form(...),
    notes: str = Form(default=""),
    db: Session = Depends(get_db),
):
    if status not in ["scheduled", "completed", "cancelled"]:
        raise HTTPException(status_code=400, detail="Invalid status. Must be 'scheduled', 'completed', or 'cancelled'")

    appointment = db.query(Appointment).filter(Appointment.id == appointment_id).first()
    if not appointment:
        raise HTTPException(status_code=404, detail="Appointment not found")

    appointment.status = status
    if notes.strip():
        appointment.notes = notes.strip()
    
    db.commit()
    db.refresh(appointment)

    return {
        "id": appointment.id,
        "patient_id": appointment.patient_id,
        "health_worker_id": appointment.health_worker_id,
        "appointment_date": appointment.appointment_date.isoformat(),
        "appointment_time": appointment.appointment_time,
        "duration_minutes": appointment.duration_minutes,
        "appointment_type": appointment.appointment_type,
        "status": appointment.status,
        "notes": appointment.notes,
        "created_at": appointment.created_at.isoformat() if appointment.created_at else None,
        "updated_at": appointment.updated_at.isoformat() if appointment.updated_at else None,
    }


# === HYDRATION ENDPOINTS ===

@app.post("/hydration/logs")
def create_hydration_log_endpoint(
    patient_id: str = Form(...),
    water_ml: float = Form(...),
    goal_ml: float = Form(2500.0),
    db: Session = Depends(get_db)
):
    return create_hydration_log(patient_id, water_ml, goal_ml, db)


@app.get("/hydration/logs/{patient_id}")
def get_hydration_logs_endpoint(patient_id: str, db: Session = Depends(get_db)):
    return get_hydration_logs(patient_id, db)


# === HEALTH WORKER ENDPOINTS ===

app.post("/health-workers/onboarding")(upsert_health_worker)
app.get("/health-workers/{worker_id}")(get_health_worker)
app.post("/health-workers/{worker_id}/assign-mother/{patient_id}")(assign_mother_to_health_worker)
app.get("/health-workers/{worker_id}/mothers")(list_assigned_mothers)

app.post("/home-visits")(schedule_home_visit)
app.put("/home-visits/{visit_id}/complete")(complete_home_visit)
app.get("/home-visits/health-worker/{worker_id}")(list_health_worker_visits)
app.get("/home-visits/patient/{patient_id}")(list_patient_visits)

app.post("/lab-tests")(create_lab_test)
app.get("/lab-tests/{patient_id}")(list_lab_tests)

app.post("/fetal-growth")(create_fetal_growth)

app.post("/reports/upload")(upload_report)
app.post("/reports/upload-and-extract")(upload_report_and_extract)
app.get("/reports/{patient_id}")(list_reports)

app.get("/risk/{patient_id}")(get_patient_risk)


# === AI PERSONALIZED PREGNANCY DIET SYSTEM ===

app.get("/diet/profile/{patient_id}")(get_diet_profile)
app.post("/diet/profile")(upsert_diet_profile)

app.post("/diet/restrictions")(create_doctor_restriction)
app.get("/diet/restrictions/{patient_id}")(list_doctor_restrictions)
app.delete("/diet/restrictions/{restriction_id}")(deactivate_doctor_restriction)

app.get("/diet/plan/today/{patient_id}")(get_today_plan)
app.post("/diet/plan/regenerate")(regenerate_today_plan)
app.get("/diet/plan/{patient_id}")(get_plan_for_date)
app.post("/diet/plan/complete-meal")(mark_meal_complete)

app.get("/diet/doctor-summary/{patient_id}")(doctor_patient_diet_summary)
app.get("/diet/meal-templates")(list_meal_templates)

app.get("/diet/ai-assistant-plan/latest/{patient_id}")(get_latest_ai_assistant_plan)
app.post("/diet/ai-assistant-plan/generate")(generate_ai_assistant_plan)


# === PREGNANCY LEARNING CENTER (articles, FAQs, daily tips) ===

app.get("/education/articles")(list_articles)
app.get("/education/articles/recommended/{patient_id}")(recommended_articles)
app.get("/education/articles/{article_id}")(get_article)
app.post("/education/articles")(create_article)
app.post("/education/articles/{article_id}/approve")(approve_article)
app.post("/education/articles/{article_id}/bookmark")(toggle_bookmark)

app.get("/education/bookmarks/{user_id}")(list_bookmarks)
app.post("/education/progress")(save_reading_progress)
app.get("/education/streak/{user_id}")(get_reading_streak)

app.get("/education/faqs")(list_faqs)
app.post("/education/faqs")(create_faq)
app.post("/education/ask")(ask_question)

app.get("/education/tips/today/{patient_id}")(get_today_tip)


# === DOCTOR PORTAL (overview, clinical bundle, deliveries, newborns, emergencies) ===

app.get("/doctor/{doctor_id}/overview")(doctor_overview)
app.get("/doctor/{doctor_id}/risk-feed")(doctor_risk_feed)
app.get("/doctor/{doctor_id}/today-appointments")(doctor_today_appointments)
app.get("/doctor/{doctor_id}/near-delivery")(doctor_near_delivery)
app.get("/doctor/{doctor_id}/missed-medications")(doctor_missed_medications)
app.get("/doctor/{doctor_id}/analytics")(doctor_analytics)

app.get("/mothers/{patient_id}/profile-bundle")(mother_profile_bundle)
app.get("/mothers/{patient_id}/symptoms")(list_mother_symptoms)
app.post("/mothers/{patient_id}/symptoms")(create_mother_symptom)
app.get("/mothers/{patient_id}/mood-logs")(list_mood_logs)
app.post("/mothers/{patient_id}/mood-logs")(create_mood_log)
app.get("/mothers/{patient_id}/fetal-growth")(mother_fetal_growth_series)

app.post("/deliveries")(create_delivery)
app.get("/mothers/{patient_id}/delivery")(get_mother_delivery)
app.get("/doctor/{doctor_id}/deliveries")(list_doctor_deliveries)

app.post("/newborns")(create_newborn)
app.get("/newborns/{newborn_id}")(get_newborn)
app.get("/mothers/{patient_id}/newborn")(get_mother_newborn)
app.post("/newborns/{newborn_id}/vitals")(create_newborn_vital)
app.get("/newborns/{newborn_id}/vitals")(list_newborn_vitals)
app.post("/newborns/{newborn_id}/vaccinations")(create_newborn_vaccination)
app.get("/newborns/{newborn_id}/vaccinations")(list_newborn_vaccinations)
app.get("/doctor/{doctor_id}/newborns")(list_doctor_newborns)

app.post("/emergencies")(create_emergency)
app.get("/doctor/{doctor_id}/emergencies")(list_doctor_emergencies)
app.post("/emergencies/{alert_id}/acknowledge")(acknowledge_emergency)
app.post("/emergencies/{alert_id}/resolve")(resolve_emergency)


# === HEALTH METRICS / VITAL SIGNS ENDPOINTS ===

@app.post("/health-metrics")
def create_health_metrics_endpoint(
    patient_id: str = Form(...),
    weight_kg: float | None = Form(default=None),
    blood_pressure_systolic: int | None = Form(default=None),
    blood_pressure_diastolic: int | None = Form(default=None),
    heart_rate_bpm: int | None = Form(default=None),
    blood_sugar: float | None = Form(default=None),
    temperature_celsius: float | None = Form(default=None),
    oxygen_saturation: float | None = Form(default=None),
    fetal_movement: str | None = Form(default=None),
    swelling: str | None = Form(default=None),
    notes: str = Form(default=""),
    measured_by: str = Form(default=""),
    db: Session = Depends(get_db),
):
    metric = create_health_metrics(
        patient_id=patient_id,
        weight_kg=weight_kg,
        blood_pressure_systolic=blood_pressure_systolic,
        blood_pressure_diastolic=blood_pressure_diastolic,
        heart_rate_bpm=heart_rate_bpm,
        blood_sugar=blood_sugar,
        temperature_celsius=temperature_celsius,
        oxygen_saturation=oxygen_saturation,
        fetal_movement=fetal_movement,
        swelling=swelling,
        notes=notes,
        measured_by=measured_by,
        db=db,
    )
    from .risk_engine import compute_risk
    risk = compute_risk(db, patient_id, persist=True)
    return {"health_metric": metric, "risk": risk.as_dict()}


@app.get("/health-metrics/{patient_id}")
def list_health_metrics_endpoint(patient_id: str, db: Session = Depends(get_db)):
    return get_health_metrics(patient_id, db)
