"""
FastAPI endpoints for the Pregnancy Learning Center.

Routes:

| Method | Path                                            | Use                              |
|--------|-------------------------------------------------|----------------------------------|
| GET    | /education/articles                             | List/search articles             |
| GET    | /education/articles/{article_id}                | Read a single article            |
| GET    | /education/articles/recommended/{patient_id}    | Personalised recommendations     |
| POST   | /education/articles                              | Doctor creates an article        |
| POST   | /education/articles/{article_id}/approve         | Doctor approves an article       |
| POST   | /education/articles/{article_id}/bookmark        | Mother bookmarks/unbookmarks     |
| GET    | /education/bookmarks/{user_id}                  | List bookmarks                   |
| POST   | /education/progress                              | Save reading progress            |
| GET    | /education/streak/{user_id}                     | Reading streak (days)            |
| GET    | /education/faqs                                  | List/search FAQs                 |
| POST   | /education/faqs                                  | Doctor creates a FAQ             |
| POST   | /education/ask                                   | FAQ AI assistant                 |
| GET    | /education/tips/today/{patient_id}              | Today's personalised tip         |
"""
from __future__ import annotations

import json
import logging
from typing import Optional

from fastapi import Depends, Form, HTTPException, Query
from sqlalchemy.orm import Session

from .database import get_db
from .education_engine import (
    answer_question,
    build_context,
    recommend_articles,
    reading_streak_days,
    search_faqs,
    todays_tip,
    upsert_reading_progress,
)
from .models import Article, ArticleBookmark, DailyTip, Faq, ReadingProgress

log = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _safe_json_list(value: Optional[str]) -> list:
    if not value:
        return []
    try:
        data = json.loads(value)
    except json.JSONDecodeError:
        return [v.strip() for v in value.split(",") if v.strip()]
    return data if isinstance(data, list) else []


def _serialize_article(a: Article, *, include_body: bool = False) -> dict:
    payload = {
        "id": a.id,
        "title": a.title,
        "summary": a.summary,
        "category": a.category,
        "trimester": a.trimester,
        "week_min": a.week_min,
        "week_max": a.week_max,
        "condition_tags": _safe_json_list(a.condition_tags),
        "tags": _safe_json_list(a.tags),
        "reading_time_min": a.reading_time_min,
        "source": a.source,
        "source_attribution": a.source_attribution,
        "severity": a.severity,
        "doctor_approved": a.doctor_approved,
        "medically_verified": bool(
            a.doctor_approved
            and a.source_attribution
            and (a.source or "").strip().lower() in {"curated", "who", "cdc", "nhs", "paho", "doctor"}
        ),
        "approved_by_doctor_id": a.approved_by_doctor_id,
        "author_id": a.author_id,
        "illustration_url": a.illustration_url,
        "key_takeaways": _safe_json_list(a.key_takeaways),
        "is_published": a.is_published,
        "view_count": a.view_count,
        "bookmark_count": a.bookmark_count,
        "created_at": a.created_at.isoformat() if a.created_at else None,
    }
    if include_body:
        payload["body_markdown"] = a.body_markdown
    return payload


def _serialize_faq(f: Faq) -> dict:
    return {
        "id": f.id,
        "question": f.question,
        "answer_markdown": f.answer_markdown,
        "category": f.category,
        "trimester": f.trimester,
        "keywords": _safe_json_list(f.keywords),
        "severity": f.severity,
        "related_article_ids": _safe_json_list(f.related_article_ids),
        "doctor_approved": f.doctor_approved,
        "source": f.source,
        "view_count": f.view_count,
    }


def _serialize_tip(t: DailyTip) -> dict:
    return {
        "id": t.id,
        "tip_text": t.tip_text,
        "detail_markdown": t.detail_markdown,
        "trimester": t.trimester,
        "week_min": t.week_min,
        "week_max": t.week_max,
        "condition_tags": _safe_json_list(t.condition_tags),
        "category": t.category,
    }


# ---------------------------------------------------------------------------
# Articles
# ---------------------------------------------------------------------------

def list_articles(
    category: Optional[str] = Query(None),
    trimester: Optional[int] = Query(None),
    q: Optional[str] = Query(None),
    severity: Optional[str] = Query(None),
    only_approved: bool = Query(True),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    query = db.query(Article).filter(Article.is_published == True)  # noqa: E712
    if category:
        query = query.filter(Article.category == category.strip().lower())
    if trimester:
        query = query.filter((Article.trimester == trimester) | (Article.trimester.is_(None)))
    if severity:
        query = query.filter(Article.severity == severity.strip().lower())
    if only_approved:
        query = query.filter(Article.doctor_approved == True)  # noqa: E712
    if q:
        like = f"%{q.strip()}%"
        query = query.filter(
            (Article.title.ilike(like))
            | (Article.summary.ilike(like))
            | (Article.tags.ilike(like))
        )
    rows = query.order_by(Article.created_at.desc()).limit(limit).all()
    return [_serialize_article(a) for a in rows]


def get_article(article_id: int, db: Session = Depends(get_db)):
    article = db.query(Article).filter(Article.id == article_id).first()
    if article is None:
        raise HTTPException(status_code=404, detail="Article not found")
    article.view_count = (article.view_count or 0) + 1
    db.commit()
    db.refresh(article)
    return _serialize_article(article, include_body=True)


def recommended_articles(
    patient_id: str,
    limit: int = Query(8, ge=1, le=30),
    db: Session = Depends(get_db),
):
    rows = recommend_articles(db, patient_id, limit=limit)
    ctx = build_context(db, patient_id)
    return {
        "patient_id": ctx.patient_id,
        "trimester": ctx.trimester,
        "conditions": ctx.conditions,
        "articles": [_serialize_article(a) for a in rows],
    }


def create_article(
    title: str = Form(...),
    body_markdown: str = Form(...),
    category: str = Form(...),
    author_id: str = Form(...),
    summary: Optional[str] = Form(None),
    trimester: Optional[int] = Form(None),
    week_min: Optional[int] = Form(None),
    week_max: Optional[int] = Form(None),
    condition_tags: Optional[str] = Form(None),
    tags: Optional[str] = Form(None),
    severity: Optional[str] = Form("info"),
    source_attribution: Optional[str] = Form(None),
    illustration_url: Optional[str] = Form(None),
    key_takeaways: Optional[str] = Form(None),
    reading_time_min: Optional[int] = Form(None),
    db: Session = Depends(get_db),
):
    a = Article(
        title=title.strip(),
        summary=summary,
        body_markdown=body_markdown,
        category=category.strip().lower(),
        trimester=trimester,
        week_min=week_min,
        week_max=week_max,
        condition_tags=json.dumps(_safe_json_list(condition_tags)),
        tags=json.dumps(_safe_json_list(tags)),
        reading_time_min=reading_time_min or max(1, len(body_markdown.split()) // 220),
        source="doctor",
        source_attribution=source_attribution,
        severity=(severity or "info").strip().lower(),
        doctor_approved=False,
        author_id=author_id.strip().upper(),
        illustration_url=illustration_url,
        key_takeaways=json.dumps(_safe_json_list(key_takeaways)),
        is_published=True,
    )
    db.add(a)
    db.commit()
    db.refresh(a)
    return _serialize_article(a, include_body=True)


def approve_article(
    article_id: int,
    doctor_id: str = Form(...),
    db: Session = Depends(get_db),
):
    a = db.query(Article).filter(Article.id == article_id).first()
    if a is None:
        raise HTTPException(status_code=404, detail="Article not found")
    a.doctor_approved = True
    a.approved_by_doctor_id = doctor_id.strip().upper()
    db.commit()
    db.refresh(a)
    return _serialize_article(a)


# ---------------------------------------------------------------------------
# Bookmarks & progress
# ---------------------------------------------------------------------------

def toggle_bookmark(
    article_id: int,
    user_id: str = Form(...),
    db: Session = Depends(get_db),
):
    uid = user_id.strip().upper()
    article = db.query(Article).filter(Article.id == article_id).first()
    if article is None:
        raise HTTPException(status_code=404, detail="Article not found")
    existing = (
        db.query(ArticleBookmark)
        .filter(ArticleBookmark.user_id == uid, ArticleBookmark.article_id == article_id)
        .first()
    )
    if existing is not None:
        db.delete(existing)
        article.bookmark_count = max(0, (article.bookmark_count or 0) - 1)
        db.commit()
        db.refresh(article)
        return {"article_id": article_id, "bookmarked": False, "bookmark_count": article.bookmark_count}
    db.add(ArticleBookmark(user_id=uid, article_id=article_id))
    article.bookmark_count = (article.bookmark_count or 0) + 1
    db.commit()
    db.refresh(article)
    return {"article_id": article_id, "bookmarked": True, "bookmark_count": article.bookmark_count}


def list_bookmarks(user_id: str, db: Session = Depends(get_db)):
    uid = user_id.strip().upper()
    rows = (
        db.query(Article, ArticleBookmark)
        .join(ArticleBookmark, ArticleBookmark.article_id == Article.id)
        .filter(ArticleBookmark.user_id == uid, Article.is_published == True)  # noqa: E712
        .order_by(ArticleBookmark.bookmarked_at.desc())
        .all()
    )
    return [
        _serialize_article(a) | {"bookmarked_at": bm.bookmarked_at.isoformat() if bm.bookmarked_at else None}
        for (a, bm) in rows
    ]


def save_reading_progress(
    user_id: str = Form(...),
    article_id: int = Form(...),
    progress_pct: int = Form(...),
    db: Session = Depends(get_db),
):
    row = upsert_reading_progress(db, user_id=user_id, article_id=article_id, progress_pct=progress_pct)
    return {
        "user_id": row.user_id,
        "article_id": row.article_id,
        "progress_pct": row.progress_pct,
        "completed": row.completed,
        "last_read_at": row.last_read_at.isoformat() if row.last_read_at else None,
    }


def get_reading_streak(user_id: str, db: Session = Depends(get_db)):
    uid = user_id.strip().upper()
    streak = reading_streak_days(db, uid)
    completed = (
        db.query(ReadingProgress)
        .filter(ReadingProgress.user_id == uid, ReadingProgress.completed == True)  # noqa: E712
        .count()
    )
    return {"user_id": uid, "streak_days": streak, "articles_completed": completed}


# ---------------------------------------------------------------------------
# FAQs & AI assistant
# ---------------------------------------------------------------------------

def list_faqs(
    category: Optional[str] = Query(None),
    q: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    if q:
        hits = search_faqs(db, q, category=category, limit=limit)
        return [_serialize_faq(f) | {"score": round(score, 2)} for f, score in hits]
    query = db.query(Faq).filter(Faq.is_published == True)  # noqa: E712
    if category:
        query = query.filter(Faq.category == category.strip().lower())
    rows = query.order_by(Faq.category, Faq.id).limit(limit).all()
    return [_serialize_faq(f) for f in rows]


def create_faq(
    question: str = Form(...),
    answer_markdown: str = Form(...),
    category: str = Form(...),
    trimester: Optional[int] = Form(None),
    keywords: Optional[str] = Form(None),
    severity: Optional[str] = Form("info"),
    related_article_ids: Optional[str] = Form(None),
    db: Session = Depends(get_db),
):
    f = Faq(
        question=question.strip(),
        answer_markdown=answer_markdown,
        category=category.strip().lower(),
        trimester=trimester,
        keywords=json.dumps(_safe_json_list(keywords)),
        severity=(severity or "info").strip().lower(),
        related_article_ids=json.dumps(_safe_json_list(related_article_ids)),
        doctor_approved=True,
        source="doctor",
        is_published=True,
    )
    db.add(f)
    db.commit()
    db.refresh(f)
    return _serialize_faq(f)


def ask_question(
    question: str = Form(...),
    patient_id: Optional[str] = Form(None),
    db: Session = Depends(get_db),
):
    if not question.strip():
        raise HTTPException(status_code=400, detail="question cannot be empty")
    return answer_question(db, patient_id=patient_id, question=question)


# ---------------------------------------------------------------------------
# Daily tip
# ---------------------------------------------------------------------------

def get_today_tip(patient_id: str, db: Session = Depends(get_db)):
    tip = todays_tip(db, patient_id)
    if tip is None:
        return {"tip": None}
    ctx = build_context(db, patient_id)
    return {
        "tip": _serialize_tip(tip),
        "trimester": ctx.trimester,
        "conditions": ctx.conditions,
    }
