from sqlalchemy import Column, DateTime, Float, Integer, String, Text, func, Boolean

from .database import Base

class Mother(Base):
    __tablename__ = "mothers"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), unique=True, nullable=False, index=True)
    full_name = Column(String(120), nullable=False)
    age = Column(Integer, nullable=True)
    weight_kg = Column(Float, nullable=True)
    blood_group = Column(String(10), nullable=True)
    pregnant_weeks = Column(Integer, nullable=True)
    due_date = Column(DateTime(timezone=False), nullable=True)
    profile_image_path = Column(String(255), nullable=True)
    doctor_id = Column(String(50), nullable=True, index=True)
    health_worker_id = Column(String(50), nullable=True, index=True)
    address = Column(String(500), nullable=True)
    phone = Column(String(20), nullable=True)
    emergency_contact = Column(String(20), nullable=True)
    allergies = Column(String(500), nullable=True)
    password = Column(String(255), nullable=True, default="password123")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class HealthWorker(Base):
    __tablename__ = "health_workers"

    id = Column(Integer, primary_key=True, index=True)
    worker_id = Column(String(50), unique=True, nullable=False, index=True)
    full_name = Column(String(120), nullable=False)
    phone = Column(String(20), nullable=True)
    region = Column(String(120), nullable=True)
    profile_image_path = Column(String(255), nullable=True)
    password = Column(String(255), nullable=True, default="password123")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class Doctor(Base):
    __tablename__ = "doctors"

    id = Column(Integer, primary_key=True, index=True)
    doctor_id = Column(String(50), unique=True, nullable=False, index=True)
    full_name = Column(String(120), nullable=False)
    phone = Column(String(20), nullable=True)
    password = Column(String(255), nullable=True, default="password123")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class HomeVisit(Base):
    __tablename__ = "home_visits"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    health_worker_id = Column(String(50), nullable=False, index=True)
    scheduled_date = Column(DateTime(timezone=False), nullable=False)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    gps_lat = Column(Float, nullable=True)
    gps_lon = Column(Float, nullable=True)
    address = Column(String(500), nullable=True)
    notes = Column(String(2000), nullable=True)
    observations = Column(String(2000), nullable=True)
    photo_path = Column(String(500), nullable=True)
    status = Column(String(20), nullable=False, default="scheduled")  # scheduled | completed | cancelled
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class LabTest(Base):
    __tablename__ = "lab_tests"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    test_date = Column(DateTime(timezone=False), nullable=False)
    measured_by = Column(String(50), nullable=True)  # health_worker_id or doctor_id
    hemoglobin = Column(Float, nullable=True)  # g/dL
    blood_sugar_fasting = Column(Float, nullable=True)  # mg/dL
    blood_sugar_post = Column(Float, nullable=True)  # mg/dL
    urine_sugar = Column(String(20), nullable=True)  # neg, trace, +, ++, +++
    urine_protein = Column(String(20), nullable=True)
    thyroid_tsh = Column(Float, nullable=True)  # mIU/L
    iron_ferritin = Column(Float, nullable=True)  # ng/mL
    calcium = Column(Float, nullable=True)  # mg/dL
    infection_notes = Column(String(500), nullable=True)
    notes = Column(String(1000), nullable=True)
    femur_length_cm = Column(Float, nullable=True)
    head_circumference_cm = Column(Float, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class Report(Base):
    __tablename__ = "reports"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    report_type = Column(String(30), nullable=False)  # scan | blood | ultrasound | prescription | other
    file_path = Column(String(500), nullable=False)
    file_name = Column(String(200), nullable=False)
    uploaded_by = Column(String(50), nullable=True)  # actor id
    uploader_type = Column(String(20), nullable=True)  # health_worker | doctor | mother
    report_date = Column(DateTime(timezone=False), nullable=True)
    notes = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class ReportExtraction(Base):
    """Stores AI extraction runs for uploaded reports (Gemini, etc.)."""

    __tablename__ = "report_extractions"

    id = Column(Integer, primary_key=True, index=True)
    report_id = Column(Integer, nullable=False, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    extractor = Column(String(30), nullable=False, default="none")
    status = Column(String(40), nullable=False)
    extracted_json = Column(Text, nullable=True)
    applied_json = Column(Text, nullable=True)
    warnings_json = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class RiskAssessment(Base):
    __tablename__ = "risk_assessments"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    level = Column(String(20), nullable=False)  # green | yellow | red | critical
    score = Column(Integer, nullable=False, default=0)
    reasons = Column(String(2000), nullable=True)  # JSON string list of reasons
    computed_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


# ---------------------------------------------------------------------------
# AI Diet system
# ---------------------------------------------------------------------------

class MotherDietProfile(Base):
    __tablename__ = "mother_diet_profiles"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), unique=True, nullable=False, index=True)
    height_cm = Column(Float, nullable=True)
    weight_kg = Column(Float, nullable=True)
    bmi = Column(Float, nullable=True)
    # JSON-encoded lists of strings (kept as TEXT so SQLite stays portable)
    allergies = Column(String(2000), nullable=True, default="[]")
    food_preferences = Column(String(2000), nullable=True, default="[]")
    medical_conditions = Column(String(2000), nullable=True, default="[]")
    diet_type = Column(String(20), nullable=True)  # 'veg' | 'non-veg' | 'vegan'
    cuisine = Column(String(60), nullable=True)  # 'indian' | 'general' | ...
    vitamin_d_level = Column(Float, nullable=True)
    protein_level = Column(Float, nullable=True)
    notes = Column(String(1000), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, onupdate=func.now())


class MealTemplate(Base):
    __tablename__ = "meal_templates"

    id = Column(Integer, primary_key=True, index=True)
    slot = Column(String(20), nullable=False, index=True)
    # breakfast | mid_morning | lunch | evening_snack | dinner | bedtime
    name = Column(String(200), nullable=False)
    description = Column(String(1000), nullable=True)
    portion = Column(String(100), nullable=True)
    calories = Column(Integer, nullable=False, default=0)
    protein_g = Column(Float, nullable=False, default=0.0)
    carbs_g = Column(Float, nullable=False, default=0.0)
    fat_g = Column(Float, nullable=False, default=0.0)
    fiber_g = Column(Float, nullable=False, default=0.0)
    iron_mg = Column(Float, nullable=False, default=0.0)
    calcium_mg = Column(Float, nullable=False, default=0.0)
    # JSON string list of trait tags: e.g. ["trimester_1","high_iron","low_gi","veg"]
    tags = Column(String(1000), nullable=False, default="[]")
    allergens = Column(String(500), nullable=False, default="[]")
    diet_type = Column(String(20), nullable=False, default="veg")
    cuisine = Column(String(60), nullable=False, default="indian")
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class DoctorDietRestriction(Base):
    __tablename__ = "doctor_diet_restrictions"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    doctor_id = Column(String(50), nullable=False, index=True)
    restricted_foods = Column(String(1000), nullable=True, default="[]")  # JSON list of tags or names
    required_nutrients = Column(String(1000), nullable=True, default="[]")  # JSON list of tags
    medical_warnings = Column(String(1000), nullable=True, default="[]")
    notes = Column(String(1000), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class DietPlan(Base):
    __tablename__ = "diet_plans"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    plan_date = Column(DateTime(timezone=False), nullable=False, index=True)
    trimester = Column(Integer, nullable=True)
    # JSON object: {"breakfast": {...}, "mid_morning": {...}, ...}
    meals = Column(String(8000), nullable=False, default="{}")
    daily_calories = Column(Integer, nullable=False, default=0)
    daily_protein_g = Column(Float, nullable=False, default=0.0)
    daily_iron_mg = Column(Float, nullable=False, default=0.0)
    daily_calcium_mg = Column(Float, nullable=False, default=0.0)
    daily_carbs_g = Column(Float, nullable=False, default=0.0)
    daily_fat_g = Column(Float, nullable=False, default=0.0)
    daily_fiber_g = Column(Float, nullable=False, default=0.0)
    water_goal_ml = Column(Integer, nullable=False, default=2500)
    # Human-readable summary of which rules fired
    rationale = Column(String(2000), nullable=True)
    generated_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class MealCompletion(Base):
    __tablename__ = "meal_completions"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    plan_id = Column(Integer, nullable=False, index=True)
    plan_date = Column(DateTime(timezone=False), nullable=False, index=True)
    slot = Column(String(20), nullable=False)
    completed = Column(Boolean, nullable=False, default=True)
    feedback_rating = Column(Integer, nullable=True)  # 1..5
    feedback_text = Column(String(500), nullable=True)
    completed_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class AiDietAssistantPlan(Base):
    """Persisted Gemini / fallback diet assistant output (separate from rule-based [DietPlan])."""

    __tablename__ = "ai_diet_assistant_plans"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    plan_date = Column(DateTime(timezone=False), nullable=False, index=True)
    source = Column(String(40), nullable=False, default="rule_based_fallback")  # gemini | rule_based_fallback
    model_name = Column(String(120), nullable=True)
    meals = Column(Text, nullable=False, default="{}")
    hydration_recommendation = Column(String(2000), nullable=True)
    warnings = Column(Text, nullable=False, default="[]")
    questions_for_doctor = Column(Text, nullable=False, default="[]")
    rationale = Column(String(4000), nullable=True)
    context_summary = Column(Text, nullable=True)
    fallback_reason = Column(String(2000), nullable=True)
    daily_calories_estimate = Column(Integer, nullable=True)
    generated_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


# ---------------------------------------------------------------------------
# Pregnancy Learning Center: Articles, FAQs, Daily Tips
# ---------------------------------------------------------------------------

class Article(Base):
    __tablename__ = "articles"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(300), nullable=False)
    summary = Column(String(600), nullable=True)
    body_markdown = Column(String, nullable=False)  # full article body
    category = Column(String(40), nullable=False, index=True)
    # trimester | nutrition | exercise | emergency | mental_health | baby_dev | general
    trimester = Column(Integer, nullable=True, index=True)  # 1, 2, 3 or NULL for any
    week_min = Column(Integer, nullable=True)
    week_max = Column(Integer, nullable=True)
    # JSON list of condition tags this article is relevant to (e.g. anemia, gestational_diabetes)
    condition_tags = Column(String(800), nullable=False, default="[]")
    # JSON list of free-form tags for search/filter
    tags = Column(String(800), nullable=False, default="[]")
    reading_time_min = Column(Integer, nullable=False, default=3)
    source = Column(String(40), nullable=False, default="curated")
    # curated | doctor | ai
    source_attribution = Column(String(300), nullable=True)  # e.g. "WHO maternal guidelines 2024"
    severity = Column(String(20), nullable=False, default="info")
    # info | warning | emergency
    doctor_approved = Column(Boolean, nullable=False, default=False)
    approved_by_doctor_id = Column(String(50), nullable=True)
    author_id = Column(String(50), nullable=True)  # for doctor-uploaded articles
    illustration_url = Column(String(500), nullable=True)
    key_takeaways = Column(String(2000), nullable=True)  # JSON list[str]
    is_published = Column(Boolean, nullable=False, default=True)
    view_count = Column(Integer, nullable=False, default=0)
    bookmark_count = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, onupdate=func.now())


class Faq(Base):
    __tablename__ = "faqs"

    id = Column(Integer, primary_key=True, index=True)
    question = Column(String(500), nullable=False)
    answer_markdown = Column(String, nullable=False)
    category = Column(String(40), nullable=False, index=True)
    # symptoms | diet | exercise | baby_development | emergency | mental_health | general
    trimester = Column(Integer, nullable=True)
    keywords = Column(String(1000), nullable=False, default="[]")  # JSON list, lowercase
    severity = Column(String(20), nullable=False, default="info")
    related_article_ids = Column(String(500), nullable=True, default="[]")  # JSON list[int]
    doctor_approved = Column(Boolean, nullable=False, default=True)
    source = Column(String(40), nullable=False, default="curated")
    is_published = Column(Boolean, nullable=False, default=True)
    view_count = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class DailyTip(Base):
    __tablename__ = "daily_tips"

    id = Column(Integer, primary_key=True, index=True)
    tip_text = Column(String(500), nullable=False)
    detail_markdown = Column(String, nullable=True)
    trimester = Column(Integer, nullable=True)
    week_min = Column(Integer, nullable=True)
    week_max = Column(Integer, nullable=True)
    condition_tags = Column(String(500), nullable=False, default="[]")
    category = Column(String(40), nullable=False, default="general")
    is_published = Column(Boolean, nullable=False, default=True)


class ArticleBookmark(Base):
    __tablename__ = "article_bookmarks"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(50), nullable=False, index=True)
    article_id = Column(Integer, nullable=False, index=True)
    bookmarked_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class ReadingProgress(Base):
    __tablename__ = "reading_progress"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(50), nullable=False, index=True)
    article_id = Column(Integer, nullable=False, index=True)
    progress_pct = Column(Integer, nullable=False, default=0)  # 0..100
    completed = Column(Boolean, nullable=False, default=False)
    last_read_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, onupdate=func.now())


class ContractionSession(Base):
    __tablename__ = "contraction_sessions"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    session_date = Column(DateTime(timezone=False), nullable=False)
    contraction_seconds = Column(Integer, nullable=False, default=0)
    relaxation_seconds = Column(Integer, nullable=False, default=0)
    lap_count = Column(Integer, nullable=False, default=0)
    timeline_data = Column(String(2000), nullable=True)  # JSON string of detailed timeline
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class SleepSession(Base):
    __tablename__ = "sleep_sessions"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    session_date = Column(DateTime(timezone=False), nullable=False)
    sleep_hours = Column(Float, nullable=False, default=0.0)
    goal_hours = Column(Float, nullable=False, default=8.0)
    is_goal_met = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class PillPrescription(Base):
    __tablename__ = "pill_prescriptions"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    doctor_id = Column(String(50), nullable=False, index=True)
    pill_name = Column(String(200), nullable=False)
    dosage = Column(String(100), nullable=False)
    timing = Column(String(20), nullable=False)  # 'before_food' or 'after_food'
    meal_time = Column(String(20), nullable=False)  # 'breakfast', 'lunch', 'dinner'
    frequency = Column(String(50), nullable=False)  # 'daily', 'twice_daily', etc.
    start_date = Column(DateTime(timezone=False), nullable=False)
    end_date = Column(DateTime(timezone=False), nullable=True)
    notes = Column(String(500), nullable=True)
    # JSON: {"doses":[{"id":"dose_0","label":"Morning","timing":"before_food"},...], ...}
    dose_schedule_json = Column(String(4000), nullable=True)
    trimester_safety = Column(String(80), nullable=True)  # e.g. generally_safe | caution_first | avoid
    refill_reminder_days = Column(Integer, nullable=True)
    interaction_warnings = Column(String(500), nullable=True)
    allergy_concerns = Column(String(500), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class PillIntake(Base):
    __tablename__ = "pill_intakes"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    prescription_id = Column(Integer, nullable=False, index=True)
    intake_date = Column(DateTime(timezone=False), nullable=False)
    meal_time = Column(String(20), nullable=False)  # 'breakfast', 'lunch', 'dinner'
    taken = Column(Boolean, nullable=False, default=False)
    taken_at = Column(DateTime(timezone=True), nullable=True)
    notes = Column(String(200), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class Appointment(Base):
    __tablename__ = "appointments"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    health_worker_id = Column(String(50), nullable=False, index=True)
    appointment_date = Column(DateTime(timezone=False), nullable=False)
    appointment_time = Column(String(10), nullable=False)  # e.g., "09:00", "14:30"
    duration_minutes = Column(Integer, nullable=False, default=30)
    appointment_type = Column(String(50), nullable=False)  # e.g., "Checkup", "Follow-up", "Consultation"
    status = Column(String(20), nullable=False, default="scheduled")  # "scheduled", "completed", "cancelled"
    notes = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, onupdate=func.now())


class KickSession(Base):
    __tablename__ = "kick_sessions"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    session_date = Column(DateTime(timezone=False), nullable=False)
    kick_count = Column(Integer, nullable=False, default=0)
    duration_minutes = Column(Float, nullable=False, default=0.0)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class DietLog(Base):
    __tablename__ = "diet_logs"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    log_date = Column(DateTime(timezone=False), nullable=False)
    meal_type = Column(String(20), nullable=False)  # 'breakfast', 'lunch', 'dinner', 'snack'
    food_items = Column(String(1000), nullable=False)  # JSON string of food items
    calories = Column(Integer, nullable=False, default=0)
    protein = Column(Float, nullable=False, default=0.0)
    carbs = Column(Float, nullable=False, default=0.0)
    fat = Column(Float, nullable=False, default=0.0)
    notes = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class FetalGrowthData(Base):
    __tablename__ = "fetal_growth_data"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    measurement_date = Column(DateTime(timezone=False), nullable=False)
    pregnant_weeks = Column(Integer, nullable=False)
    fetal_weight_grams = Column(Float, nullable=True)
    fetal_length_cm = Column(Float, nullable=True)
    heart_rate_bpm = Column(Integer, nullable=True)
    fundal_height_cm = Column(Float, nullable=True)
    amniotic_fluid_index = Column(Float, nullable=True)
    femur_length_cm = Column(Float, nullable=True)
    head_circumference_cm = Column(Float, nullable=True)
    notes = Column(String(500), nullable=True)
    measured_by = Column(String(50), nullable=True)  # doctor_id or health_worker_id
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class HydrationLog(Base):
    __tablename__ = "hydration_logs"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    log_date = Column(DateTime(timezone=False), nullable=False)
    water_ml = Column(Float, nullable=False, default=0.0)
    goal_ml = Column(Float, nullable=False, default=2500.0)
    goal_met = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class StepsLog(Base):
    __tablename__ = "steps_logs"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    log_date = Column(DateTime(timezone=False), nullable=False)
    steps_count = Column(Integer, nullable=False, default=0)
    goal_steps = Column(Integer, nullable=False, default=10000)
    goal_met = Column(Boolean, nullable=False, default=False)
    distance_km = Column(Float, nullable=True)
    calories_burned = Column(Integer, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class HealthMetrics(Base):
    __tablename__ = "health_metrics"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    measurement_date = Column(DateTime(timezone=False), nullable=False)
    weight_kg = Column(Float, nullable=True)
    blood_pressure_systolic = Column(Integer, nullable=True)
    blood_pressure_diastolic = Column(Integer, nullable=True)
    heart_rate_bpm = Column(Integer, nullable=True)
    blood_sugar = Column(Float, nullable=True)
    temperature_celsius = Column(Float, nullable=True)
    oxygen_saturation = Column(Float, nullable=True)  # SpO2 %
    fetal_movement = Column(String(30), nullable=True)  # normal | reduced | none
    swelling = Column(String(40), nullable=True)  # none | feet_mild | face_hands_sudden
    notes = Column(String(500), nullable=True)
    measured_by = Column(String(50), nullable=True)  # doctor_id or health_worker_id
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class ChatRoom(Base):
    __tablename__ = "chat_rooms"

    id = Column(Integer, primary_key=True, index=True)
    room_id = Column(String(50), unique=True, nullable=False, index=True)  # e.g., "DOC123_MUM456"
    participant_1_id = Column(String(50), nullable=False, index=True)  # doctor_id
    participant_2_id = Column(String(50), nullable=False, index=True)  # patient_id
    participant_1_type = Column(String(20), nullable=False)  # "doctor"
    participant_2_type = Column(String(20), nullable=False)  # "mother"
    is_active = Column(Boolean, nullable=False, default=True)
    last_message_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(Integer, primary_key=True, index=True)
    room_id = Column(String(50), nullable=False, index=True)
    sender_id = Column(String(50), nullable=False, index=True)
    sender_type = Column(String(20), nullable=False)  # "doctor" or "mother"
    message_text = Column(String(2000), nullable=False)
    message_type = Column(String(20), nullable=False, default="text")  # "text", "image", "file"
    file_url = Column(String(500), nullable=True)  # for images/files
    is_read = Column(Boolean, nullable=False, default=False)
    read_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class ChatNotification(Base):
    __tablename__ = "chat_notifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(50), nullable=False, index=True)
    user_type = Column(String(20), nullable=False)  # "doctor" or "mother"
    room_id = Column(String(50), nullable=False, index=True)
    message_id = Column(Integer, nullable=False, index=True)
    notification_type = Column(String(20), nullable=False, default="new_message")
    is_dismissed = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class SymptomLog(Base):
    __tablename__ = "symptom_logs"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    symptom_text = Column(String(500), nullable=False)
    severity = Column(String(20), nullable=False, default="yellow")  # green | yellow | red | critical
    notes = Column(String(1000), nullable=True)
    logged_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class MoodLog(Base):
    __tablename__ = "mood_logs"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    mood = Column(String(30), nullable=False)
    notes = Column(String(500), nullable=True)
    logged_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class DeliveryRecord(Base):
    __tablename__ = "delivery_records"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    doctor_id = Column(String(50), nullable=False, index=True)
    delivery_date = Column(DateTime(timezone=False), nullable=False)
    delivery_type = Column(String(30), nullable=False)  # vaginal | c_section | assisted | other
    complications = Column(String(2000), nullable=True)
    baby_count = Column(Integer, nullable=False, default=1)
    hospital = Column(String(200), nullable=True)
    notes = Column(String(2000), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class NewbornRecord(Base):
    __tablename__ = "newborn_records"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), unique=True, nullable=False, index=True)  # NB-*
    mother_patient_id = Column(String(50), nullable=False, index=True)
    name = Column(String(120), nullable=True)
    sex = Column(String(20), nullable=True)
    birth_weight_g = Column(Float, nullable=True)
    birth_height_cm = Column(Float, nullable=True)
    apgar_1min = Column(Integer, nullable=True)
    apgar_5min = Column(Integer, nullable=True)
    head_circumference_cm = Column(Float, nullable=True)
    observations = Column(String(2000), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class NewbornVital(Base):
    __tablename__ = "newborn_vitals"

    id = Column(Integer, primary_key=True, index=True)
    newborn_id = Column(Integer, nullable=False, index=True)
    recorded_at = Column(DateTime(timezone=False), nullable=False)
    weight_g = Column(Float, nullable=True)
    height_cm = Column(Float, nullable=True)
    temperature_c = Column(Float, nullable=True)
    jaundice_level = Column(String(50), nullable=True)
    feeding_type = Column(String(50), nullable=True)
    sleep_hours = Column(Float, nullable=True)
    notes = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class NewbornVaccination(Base):
    __tablename__ = "newborn_vaccinations"

    id = Column(Integer, primary_key=True, index=True)
    newborn_id = Column(Integer, nullable=False, index=True)
    vaccine_name = Column(String(200), nullable=False)
    scheduled_date = Column(DateTime(timezone=False), nullable=True)
    given_date = Column(DateTime(timezone=False), nullable=True)
    batch_no = Column(String(80), nullable=True)
    notes = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class EmergencyAlert(Base):
    __tablename__ = "emergency_alerts"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), nullable=False, index=True)
    doctor_id = Column(String(50), nullable=True, index=True)
    raised_by = Column(String(50), nullable=True)
    level = Column(String(20), nullable=False, default="critical")
    source = Column(String(30), nullable=False)  # sos | symptom | metric | missed_med
    summary = Column(String(500), nullable=False)
    status = Column(String(20), nullable=False, default="open")  # open | acknowledged | resolved
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    resolved_at = Column(DateTime(timezone=True), nullable=True)
