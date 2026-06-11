"""
Pregnancy Learning Center engine: article ranking, daily tip selection
and FAQ keyword/safety matching.

All logic is rule-based and deterministic so the same mother sees a stable
"today's tip" for the day and a consistent recommendation order. A hook is
left for a future LLM "smart Q&A" layer (:func:`llm_answer`) but it is
intentionally inert by default so we never auto-answer pregnancy questions
with hallucinated medical advice.
"""
from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass, field
from datetime import datetime
from typing import Iterable, Optional

from sqlalchemy.orm import Session

from .models import (
    Article,
    DailyTip,
    Faq,
    HealthMetrics,
    LabTest,
    Mother,
    MotherDietProfile,
    ReadingProgress,
)

log = logging.getLogger(__name__)


# Words that mean "stop reading articles and contact a doctor NOW".
_EMERGENCY_KEYWORDS = {
    "bleeding", "blood loss", "severe pain", "severe headache", "blurred vision",
    "no fetal movement", "no kicks", "baby not moving", "stopped moving",
    "fainting", "fainted", "severe swelling", "severe cramping", "labor",
    "labour", "water broke", "leaking fluid", "convulsion", "seizure",
    "chest pain", "shortness of breath", "high fever", "vomiting blood",
}

# Words that mean "warning, recommend caution".
_WARNING_KEYWORDS = {
    "swelling", "headache", "cramps", "dizzy", "nausea", "fever", "spotting",
    "back pain", "tired", "fatigue", "anxious", "depressed", "burning urine",
}


def _safe_json_list(value: Optional[str]) -> list[str]:
    if not value:
        return []
    try:
        data = json.loads(value)
    except json.JSONDecodeError:
        return []
    return [str(v) for v in data] if isinstance(data, list) else []


def _trimester_from_weeks(weeks: Optional[int]) -> int:
    if weeks is None:
        return 1
    if weeks <= 13:
        return 1
    if weeks <= 27:
        return 2
    return 3


# ---------------------------------------------------------------------------
# Personalisation context
# ---------------------------------------------------------------------------

@dataclass
class MotherEduContext:
    patient_id: str
    trimester: int
    week: Optional[int]
    conditions: list[str] = field(default_factory=list)
    rationale: list[str] = field(default_factory=list)


def build_context(db: Session, patient_id: str) -> MotherEduContext:
    pid = patient_id.strip().upper()
    mother = db.query(Mother).filter(Mother.patient_id == pid).first()
    weeks = mother.pregnant_weeks if mother else None
    trimester = _trimester_from_weeks(weeks)
    profile = (
        db.query(MotherDietProfile).filter(MotherDietProfile.patient_id == pid).first()
    )
    conditions = _safe_json_list(profile.medical_conditions) if profile else []
    # Augment with conditions inferred from lab results (so we recommend
    # relevant articles even without an explicit profile entry).
    latest_lab = (
        db.query(LabTest)
        .filter(LabTest.patient_id == pid)
        .order_by(LabTest.test_date.desc())
        .first()
    )
    if latest_lab:
        if latest_lab.hemoglobin is not None and latest_lab.hemoglobin < 11.0:
            conditions.append("anemia")
        if latest_lab.blood_sugar_fasting is not None and latest_lab.blood_sugar_fasting >= 100:
            conditions.append("gestational_diabetes")
    latest_metrics = (
        db.query(HealthMetrics)
        .filter(HealthMetrics.patient_id == pid)
        .order_by(HealthMetrics.measurement_date.desc())
        .first()
    )
    if latest_metrics and latest_metrics.blood_pressure_systolic and latest_metrics.blood_pressure_systolic >= 140:
        conditions.append("high_bp")
    conditions = list(dict.fromkeys(c.lower() for c in conditions if c))
    return MotherEduContext(
        patient_id=pid,
        trimester=trimester,
        week=weeks,
        conditions=conditions,
    )


# ---------------------------------------------------------------------------
# Article ranking
# ---------------------------------------------------------------------------

def _article_relevance(article: Article, ctx: MotherEduContext) -> float:
    score = 0.0
    if article.trimester == ctx.trimester:
        score += 4.0
    elif article.trimester is None:
        score += 1.0
    if (
        ctx.week is not None
        and article.week_min is not None
        and article.week_max is not None
    ):
        if article.week_min <= ctx.week <= article.week_max:
            score += 2.0
    article_conditions = {c.lower() for c in _safe_json_list(article.condition_tags)}
    matched = article_conditions & set(ctx.conditions)
    score += 3.0 * len(matched)
    if article.doctor_approved:
        score += 1.5
    if article.severity == "emergency":
        score += 1.0  # surface emergency-awareness content slightly more
    # Light tie-breaker: more popular articles win marginally.
    score += min(article.view_count, 50) * 0.01
    return score


def recommend_articles(
    db: Session,
    patient_id: str,
    *,
    limit: int = 10,
    category: Optional[str] = None,
) -> list[Article]:
    ctx = build_context(db, patient_id)
    q = db.query(Article).filter(Article.is_published == True)  # noqa: E712
    if category:
        q = q.filter(Article.category == category)
    rows = q.all()
    rows.sort(key=lambda a: _article_relevance(a, ctx), reverse=True)
    return rows[:limit]


# ---------------------------------------------------------------------------
# Daily tip
# ---------------------------------------------------------------------------

def _tip_score(tip: DailyTip, ctx: MotherEduContext) -> float:
    score = 0.0
    if tip.trimester == ctx.trimester:
        score += 3.0
    elif tip.trimester is None:
        score += 0.5
    if (
        ctx.week is not None
        and tip.week_min is not None
        and tip.week_max is not None
        and tip.week_min <= ctx.week <= tip.week_max
    ):
        score += 2.0
    tip_conditions = {c.lower() for c in _safe_json_list(tip.condition_tags)}
    score += 2.0 * len(tip_conditions & set(ctx.conditions))
    return score


def todays_tip(db: Session, patient_id: str, *, target_date: Optional[datetime] = None) -> Optional[DailyTip]:
    ctx = build_context(db, patient_id)
    rows = db.query(DailyTip).filter(DailyTip.is_published == True).all()  # noqa: E712
    if not rows:
        return None
    target_date = target_date or datetime.utcnow()
    seed = int(target_date.strftime("%Y%m%d"))
    # Top-score candidates, then deterministic rotation by date so the tip
    # changes daily but stays stable within a day.
    scored = sorted(rows, key=lambda t: _tip_score(t, ctx), reverse=True)
    top = [t for t in scored if _tip_score(t, scored[0] if False else ctx) >= _tip_score(scored[0], ctx) - 0.5]
    if not top:
        top = scored
    return top[seed % len(top)]


# ---------------------------------------------------------------------------
# FAQ search & safety
# ---------------------------------------------------------------------------

_WORD_RE = re.compile(r"[a-z0-9']+")


def _tokenise(text: str) -> set[str]:
    return set(_WORD_RE.findall(text.lower()))


def classify_question_severity(question: str) -> str:
    lower = question.lower()
    for term in _EMERGENCY_KEYWORDS:
        if term in lower:
            return "emergency"
    for term in _WARNING_KEYWORDS:
        if term in lower:
            return "warning"
    return "info"


def search_faqs(
    db: Session,
    query: str,
    *,
    category: Optional[str] = None,
    limit: int = 10,
) -> list[tuple[Faq, float]]:
    rows = db.query(Faq).filter(Faq.is_published == True)  # noqa: E712
    if category:
        rows = rows.filter(Faq.category == category)
    rows = rows.all()
    tokens = _tokenise(query)
    if not tokens:
        return [(f, 1.0) for f in rows[:limit]]
    results: list[tuple[Faq, float]] = []
    for faq in rows:
        keywords = {k.lower() for k in _safe_json_list(faq.keywords)}
        question_tokens = _tokenise(faq.question)
        score = 3.0 * len(tokens & keywords) + 1.5 * len(tokens & question_tokens)
        if score > 0:
            results.append((faq, score))
    results.sort(key=lambda x: x[1], reverse=True)
    return results[:limit]


def answer_question(
    db: Session,
    *,
    patient_id: Optional[str],
    question: str,
) -> dict:
    """
    Rule-based FAQ assistant:

    - classify emergency / warning keywords first
    - search curated FAQs by keyword overlap
    - return suggested related articles
    - never invent medical advice; if no FAQ matches, return a polite
      "please ask your doctor" payload with the danger classification preserved.
    """
    severity = classify_question_severity(question)
    payload: dict = {
        "question": question,
        "severity": severity,
        "matches": [],
        "related_articles": [],
        "emergency": severity == "emergency",
        "warning": severity == "warning",
        "fallback_message": None,
    }
    if severity == "emergency":
        payload["fallback_message"] = (
            "Your message sounds urgent. Please contact your doctor or go to "
            "the nearest hospital immediately."
        )

    hits = search_faqs(db, question, limit=5)
    payload["matches"] = [
        {
            "id": faq.id,
            "question": faq.question,
            "answer_markdown": faq.answer_markdown,
            "category": faq.category,
            "severity": faq.severity,
            "doctor_approved": faq.doctor_approved,
            "score": round(score, 2),
        }
        for faq, score in hits
    ]

    # Surface related articles: union of "related_article_ids" from top hits
    # plus general recommendations if we have a patient_id.
    related_ids: list[int] = []
    for faq, _ in hits:
        related_ids.extend(int(x) for x in _safe_json_list(faq.related_article_ids))
    related_articles: list[Article] = []
    if related_ids:
        related_articles = (
            db.query(Article)
            .filter(Article.id.in_(related_ids), Article.is_published == True)  # noqa: E712
            .all()
        )
    if patient_id and not related_articles:
        related_articles = recommend_articles(db, patient_id, limit=3)
    payload["related_articles"] = [
        {
            "id": a.id,
            "title": a.title,
            "summary": a.summary,
            "category": a.category,
            "trimester": a.trimester,
            "reading_time_min": a.reading_time_min,
            "doctor_approved": a.doctor_approved,
        }
        for a in related_articles[:5]
    ]

    if not payload["matches"] and severity != "emergency":
        payload["fallback_message"] = (
            "I couldn't find a curated answer. Please ask your doctor for advice "
            "specific to your pregnancy."
        )
    return payload


# Hook for a future LLM "smart Q&A" layer. Intentionally inert.
def llm_answer(_question: str) -> Optional[str]:  # pragma: no cover
    return None


# ---------------------------------------------------------------------------
# Reading progress helpers
# ---------------------------------------------------------------------------

def upsert_reading_progress(
    db: Session,
    *,
    user_id: str,
    article_id: int,
    progress_pct: int,
) -> ReadingProgress:
    uid = user_id.strip().upper()
    progress_pct = max(0, min(100, int(progress_pct)))
    row = (
        db.query(ReadingProgress)
        .filter(ReadingProgress.user_id == uid, ReadingProgress.article_id == article_id)
        .first()
    )
    if row is None:
        row = ReadingProgress(
            user_id=uid,
            article_id=article_id,
            progress_pct=progress_pct,
            completed=(progress_pct >= 100),
        )
        db.add(row)
    else:
        row.progress_pct = max(row.progress_pct, progress_pct)
        if progress_pct >= 100:
            row.completed = True
        row.last_read_at = datetime.utcnow()
    db.commit()
    db.refresh(row)
    return row


def reading_streak_days(db: Session, user_id: str) -> int:
    """Number of consecutive trailing days the user has read at least one article."""
    uid = user_id.strip().upper()
    rows = (
        db.query(ReadingProgress)
        .filter(ReadingProgress.user_id == uid)
        .all()
    )
    if not rows:
        return 0
    days = {r.last_read_at.date() for r in rows if r.last_read_at}
    streak = 0
    cursor = datetime.utcnow().date()
    while cursor in days:
        streak += 1
        cursor = cursor.fromordinal(cursor.toordinal() - 1)
    return streak
