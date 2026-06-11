"""Idempotent demo seed for doctor portal (emergency + optional delivery)."""
from __future__ import annotations

import logging
from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from .models import DeliveryRecord, EmergencyAlert, Mother

log = logging.getLogger(__name__)


def seed_doctor_demo(db: Session) -> None:
    if db.query(EmergencyAlert).count() == 0:
        db.add(
            EmergencyAlert(
                patient_id="MUM12345",
                doctor_id="DOC88257",
                raised_by="MUM12345",
                level="critical",
                source="sos",
                summary="Demo emergency — acknowledge or resolve from the doctor portal.",
                status="open",
            )
        )
        db.commit()
        log.info("seed_doctor_demo: inserted demo EmergencyAlert")

    mother = db.query(Mother).filter(Mother.patient_id == "MUM12345").first()
    if not mother:
        return
    if db.query(DeliveryRecord).filter(DeliveryRecord.patient_id == "MUM12345").count() > 0:
        return

    due = mother.due_date
    if due and due < datetime.utcnow():
        db.add(
            DeliveryRecord(
                patient_id="MUM12345",
                doctor_id="DOC88257",
                delivery_date=due + timedelta(days=1),
                delivery_type="vaginal",
                complications=None,
                baby_count=1,
                hospital="Demo Hospital",
                notes="Auto-seeded delivery record for post-due demo mother.",
            )
        )
        db.commit()
        log.info("seed_doctor_demo: inserted demo DeliveryRecord for MUM12345")
