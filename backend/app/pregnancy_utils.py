"""Gestational age helpers — weeks advance from due date or registration anchor."""

from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .models import Mother

FULL_TERM_DAYS = 280  # 40 weeks from LMP to due date


def _as_date(value: datetime | date | None) -> date | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    return value


def compute_pregnant_weeks(
    *,
    due_date: datetime | date | None,
    stored_weeks: int | None,
    anchor_date: datetime | date | None = None,
    today: date | None = None,
) -> int | None:
    """Return current gestational week (1–42) from EDD or weeks-at-signup + elapsed time."""
    today = today or date.today()

    due = _as_date(due_date)
    if due is not None:
        days_pregnant = FULL_TERM_DAYS - (due - today).days
        weeks = days_pregnant // 7
        return int(max(1, min(42, weeks)))

    if stored_weeks is not None and anchor_date is not None:
        anchor = _as_date(anchor_date) or today
        elapsed_weeks = (today - anchor).days // 7
        weeks = stored_weeks + elapsed_weeks
        return int(max(1, min(42, weeks)))

    return stored_weeks


def infer_due_date_from_weeks(
    pregnant_weeks: int,
    *,
    anchor: datetime | date | None = None,
) -> datetime:
    """Estimate due date assuming 40-week gestation at ``anchor``."""
    anchor_day = _as_date(anchor) or date.today()
    remaining_days = max(0, (40 - pregnant_weeks) * 7)
    due_day = anchor_day + timedelta(days=remaining_days)
    return datetime.combine(due_day, datetime.min.time())


def current_pregnant_weeks(mother: Mother | None) -> int | None:
    if mother is None:
        return None
    return compute_pregnant_weeks(
        due_date=mother.due_date,
        stored_weeks=mother.pregnant_weeks,
        anchor_date=mother.created_at,
    )


def ensure_due_date_from_weeks(mother: Mother) -> None:
    """Backfill EDD when weeks were saved but due date was not."""
    if mother.due_date is not None or mother.pregnant_weeks is None:
        return
    mother.due_date = infer_due_date_from_weeks(
        mother.pregnant_weeks,
        anchor=mother.created_at,
    )
