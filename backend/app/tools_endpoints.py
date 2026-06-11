import os
import shutil
from datetime import datetime
from pathlib import Path
from uuid import uuid4

from fastapi import Depends, FastAPI, File, Form, HTTPException, UploadFile, Body
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from sqlalchemy.orm import Session

from .chat_websocket import broadcast_messages_read, broadcast_new_message
from .database import Base, engine, get_db
from .models import (DietLog, FetalGrowthData, HydrationLog, StepsLog, HealthMetrics, ChatRoom, ChatMessage, ChatNotification, Mother)

# === DIET LOG ENDPOINTS ===

def create_diet_log(
    patient_id: str = Form(...),
    meal_type: str = Form(...),
    food_items: str = Form(...),
    calories: int = Form(0),
    protein: float = Form(0.0),
    carbs: float = Form(0.0),
    fat: float = Form(0.0),
    notes: str = Form(""),
    db: Session = Depends(get_db)
):
    diet_log = DietLog(
        patient_id=patient_id.strip().upper(),
        log_date=datetime.now(),
        meal_type=meal_type,
        food_items=food_items,
        calories=calories,
        protein=protein,
        carbs=carbs,
        fat=fat,
        notes=notes
    )
    db.add(diet_log)
    db.commit()
    db.refresh(diet_log)
    return {"message": "Diet log created successfully", "id": diet_log.id}

def get_diet_logs(patient_id: str, db: Session = Depends(get_db)):
    logs = db.query(DietLog).filter(
        DietLog.patient_id == patient_id.strip().upper()
    ).order_by(DietLog.log_date.desc()).limit(50).all()
    
    return [
        {
            "id": log.id,
            "log_date": log.log_date.isoformat(),
            "meal_type": log.meal_type,
            "food_items": log.food_items,
            "calories": log.calories,
            "protein": log.protein,
            "carbs": log.carbs,
            "fat": log.fat,
            "notes": log.notes,
            "created_at": log.created_at.isoformat() if log.created_at else None,
        }
        for log in logs
    ]


# === FETAL GROWTH ENDPOINTS ===

def create_fetal_growth_data(
    patient_id: str = Form(...),
    pregnant_weeks: int = Form(...),
    fetal_weight_grams: float = Form(None),
    fetal_length_cm: float = Form(None),
    heart_rate_bpm: int = Form(None),
    fundal_height_cm: float = Form(None),
    amniotic_fluid_index: float = Form(None),
    femur_length_cm: float = Form(None),
    head_circumference_cm: float = Form(None),
    notes: str = Form(""),
    measured_by: str = Form(""),
    db: Session = Depends(get_db)
):
    growth_data = FetalGrowthData(
        patient_id=patient_id.strip().upper(),
        measurement_date=datetime.now(),
        pregnant_weeks=pregnant_weeks,
        fetal_weight_grams=fetal_weight_grams,
        fetal_length_cm=fetal_length_cm,
        heart_rate_bpm=heart_rate_bpm,
        fundal_height_cm=fundal_height_cm,
        amniotic_fluid_index=amniotic_fluid_index,
        femur_length_cm=femur_length_cm,
        head_circumference_cm=head_circumference_cm,
        notes=notes,
        measured_by=measured_by
    )
    db.add(growth_data)
    db.commit()
    db.refresh(growth_data)
    return {"message": "Fetal growth data created successfully", "id": growth_data.id}

def get_fetal_growth_data(patient_id: str, db: Session = Depends(get_db)):
    growth_data = db.query(FetalGrowthData).filter(
        FetalGrowthData.patient_id == patient_id.strip().upper()
    ).order_by(FetalGrowthData.measurement_date.desc()).limit(20).all()
    
    return [
        {
            "id": data.id,
            "measurement_date": data.measurement_date.isoformat(),
            "pregnant_weeks": data.pregnant_weeks,
            "fetal_weight_grams": data.fetal_weight_grams,
            "fetal_length_cm": data.fetal_length_cm,
            "heart_rate_bpm": data.heart_rate_bpm,
            "fundal_height_cm": data.fundal_height_cm,
            "amniotic_fluid_index": data.amniotic_fluid_index,
            "femur_length_cm": getattr(data, "femur_length_cm", None),
            "head_circumference_cm": getattr(data, "head_circumference_cm", None),
            "notes": data.notes,
            "measured_by": data.measured_by,
            "created_at": data.created_at.isoformat() if data.created_at else None,
        }
        for data in growth_data
    ]


# === HYDRATION ENDPOINTS ===

def create_hydration_log(
    patient_id: str = Form(...),
    water_ml: float = Form(...),
    goal_ml: float = Form(2500.0),
    db: Session = Depends(get_db)
):
    goal_met = water_ml >= goal_ml
    hydration_log = HydrationLog(
        patient_id=patient_id.strip().upper(),
        log_date=datetime.now(),
        water_ml=water_ml,
        goal_ml=goal_ml,
        goal_met=goal_met
    )
    db.add(hydration_log)
    db.commit()
    db.refresh(hydration_log)
    return {"message": "Hydration log created successfully", "id": hydration_log.id}

def get_hydration_logs(patient_id: str, db: Session = Depends(get_db)):
    logs = db.query(HydrationLog).filter(
        HydrationLog.patient_id == patient_id.strip().upper()
    ).order_by(HydrationLog.log_date.desc()).limit(30).all()
    
    return [
        {
            "id": log.id,
            "log_date": log.log_date.isoformat(),
            "water_ml": log.water_ml,
            "goal_ml": log.goal_ml,
            "goal_met": log.goal_met,
            "created_at": log.created_at.isoformat() if log.created_at else None,
        }
        for log in logs
    ]


# === STEPS ENDPOINTS ===

def create_steps_log(
    patient_id: str = Form(...),
    steps_count: int = Form(...),
    goal_steps: int = Form(10000),
    distance_km: float = Form(None),
    calories_burned: int = Form(None),
    db: Session = Depends(get_db)
):
    goal_met = steps_count >= goal_steps
    steps_log = StepsLog(
        patient_id=patient_id.strip().upper(),
        log_date=datetime.now(),
        steps_count=steps_count,
        goal_steps=goal_steps,
        goal_met=goal_met,
        distance_km=distance_km,
        calories_burned=calories_burned
    )
    db.add(steps_log)
    db.commit()
    db.refresh(steps_log)
    return {"message": "Steps log created successfully", "id": steps_log.id}

def get_steps_logs(patient_id: str, db: Session = Depends(get_db)):
    logs = db.query(StepsLog).filter(
        StepsLog.patient_id == patient_id.strip().upper()
    ).order_by(StepsLog.log_date.desc()).limit(30).all()
    
    return [
        {
            "id": log.id,
            "log_date": log.log_date.isoformat(),
            "steps_count": log.steps_count,
            "goal_steps": log.goal_steps,
            "goal_met": log.goal_met,
            "distance_km": log.distance_km,
            "calories_burned": log.calories_burned,
            "created_at": log.created_at.isoformat() if log.created_at else None,
        }
        for log in logs
    ]


# === HEALTH METRICS ENDPOINTS ===

def create_health_metrics(
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
    notes: str = Form(""),
    measured_by: str = Form(""),
    db: Session = Depends(get_db),
):
    from .clinical_terms import normalize_fetal_movement, normalize_swelling

    fm = normalize_fetal_movement(fetal_movement)
    sw = normalize_swelling(swelling)
    metrics = HealthMetrics(
        patient_id=patient_id.strip().upper(),
        measurement_date=datetime.now(),
        weight_kg=weight_kg,
        blood_pressure_systolic=blood_pressure_systolic,
        blood_pressure_diastolic=blood_pressure_diastolic,
        heart_rate_bpm=heart_rate_bpm,
        blood_sugar=blood_sugar,
        temperature_celsius=temperature_celsius,
        oxygen_saturation=oxygen_saturation,
        fetal_movement=fm,
        swelling=sw,
        notes=notes,
        measured_by=measured_by,
    )
    db.add(metrics)
    db.commit()
    db.refresh(metrics)
    return {"message": "Health metrics created successfully", "id": metrics.id}

def get_health_metrics(patient_id: str, db: Session = Depends(get_db)):
    metrics = db.query(HealthMetrics).filter(
        HealthMetrics.patient_id == patient_id.strip().upper()
    ).order_by(HealthMetrics.measurement_date.desc()).limit(20).all()
    
    return [
        {
            "id": metric.id,
            "measurement_date": metric.measurement_date.isoformat(),
            "weight_kg": metric.weight_kg,
            "blood_pressure_systolic": metric.blood_pressure_systolic,
            "blood_pressure_diastolic": metric.blood_pressure_diastolic,
            "heart_rate_bpm": metric.heart_rate_bpm,
            "blood_sugar": metric.blood_sugar,
            "temperature_celsius": metric.temperature_celsius,
            "oxygen_saturation": metric.oxygen_saturation,
            "fetal_movement": metric.fetal_movement,
            "swelling": metric.swelling,
            "notes": metric.notes,
            "measured_by": metric.measured_by,
            "created_at": metric.created_at.isoformat() if metric.created_at else None,
        }
        for metric in metrics
    ]


# === DASHBOARD DATA FOR DOCTORS ===

def get_patient_dashboard_data(patient_id: str, db: Session = Depends(get_db)):
    """Get all patient data for doctor dashboard"""
    from .models import Mother
    patient_id = patient_id.strip().upper()
    
    # Get basic patient info
    mother = db.query(Mother).filter(Mother.patient_id == patient_id).first()
    if not mother:
        raise HTTPException(status_code=404, detail="Patient not found")
    
    # Get recent data from all tools
    recent_diet = db.query(DietLog).filter(
        DietLog.patient_id == patient_id
    ).order_by(DietLog.log_date.desc()).limit(7).all()
    
    recent_hydration = db.query(HydrationLog).filter(
        HydrationLog.patient_id == patient_id
    ).order_by(HydrationLog.log_date.desc()).limit(7).all()
    
    recent_steps = db.query(StepsLog).filter(
        StepsLog.patient_id == patient_id
    ).order_by(StepsLog.log_date.desc()).limit(7).all()
    
    recent_growth = db.query(FetalGrowthData).filter(
        FetalGrowthData.patient_id == patient_id
    ).order_by(FetalGrowthData.measurement_date.desc()).limit(5).all()
    
    recent_health_metrics = db.query(HealthMetrics).filter(
        HealthMetrics.patient_id == patient_id
    ).order_by(HealthMetrics.measurement_date.desc()).limit(5).all()
    
    return {
        "patient_info": {
            "id": mother.id,
            "patient_id": mother.patient_id,
            "full_name": mother.full_name,
            "age": mother.age,
            "weight_kg": mother.weight_kg,
            "blood_group": mother.blood_group,
            "pregnant_weeks": mother.pregnant_weeks,
            "due_date": mother.due_date.isoformat() if mother.due_date else None,
            "doctor_id": mother.doctor_id,
        },
        "diet_logs": [
            {
                "log_date": log.log_date.isoformat(),
                "meal_type": log.meal_type,
                "calories": log.calories,
                "protein": log.protein,
                "carbs": log.carbs,
                "fat": log.fat,
            }
            for log in recent_diet
        ],
        "hydration_logs": [
            {
                "log_date": log.log_date.isoformat(),
                "water_ml": log.water_ml,
                "goal_ml": log.goal_ml,
                "goal_met": log.goal_met,
            }
            for log in recent_hydration
        ],
        "steps_logs": [
            {
                "log_date": log.log_date.isoformat(),
                "steps_count": log.steps_count,
                "goal_steps": log.goal_steps,
                "goal_met": log.goal_met,
                "distance_km": log.distance_km,
                "calories_burned": log.calories_burned,
            }
            for log in recent_steps
        ],
        "fetal_growth": [
            {
                "measurement_date": data.measurement_date.isoformat(),
                "pregnant_weeks": data.pregnant_weeks,
                "fetal_weight_grams": data.fetal_weight_grams,
                "fetal_length_cm": data.fetal_length_cm,
                "heart_rate_bpm": data.heart_rate_bpm,
                "fundal_height_cm": data.fundal_height_cm,
                "measured_by": data.measured_by,
            }
            for data in recent_growth
        ],
        "health_metrics": [
            {
                "measurement_date": metric.measurement_date.isoformat(),
                "weight_kg": metric.weight_kg,
                "blood_pressure_systolic": metric.blood_pressure_systolic,
                "blood_pressure_diastolic": metric.blood_pressure_diastolic,
                "heart_rate_bpm": metric.heart_rate_bpm,
                "blood_sugar": metric.blood_sugar,
                "temperature_celsius": metric.temperature_celsius,
                "oxygen_saturation": metric.oxygen_saturation,
                "fetal_movement": metric.fetal_movement,
                "swelling": metric.swelling,
                "measured_by": metric.measured_by,
            }
            for metric in recent_health_metrics
        ],
    }


# === CHAT API ENDPOINTS ===

def create_or_get_chat_room(
    doctor_id: str = Form(...),
    patient_id: str = Form(...),
    db: Session = Depends(get_db)
):
    """Create or get existing chat room between doctor and patient"""
    doctor_id = doctor_id.strip().upper()
    patient_id = patient_id.strip().upper()
    
    # Generate room ID
    room_id = f"DOC_{doctor_id}_PAT_{patient_id}"
    
    # Check if room already exists
    existing_room = db.query(ChatRoom).filter(ChatRoom.room_id == room_id).first()
    if existing_room:
        return {
            "room_id": existing_room.room_id,
            "participant_1_id": existing_room.participant_1_id,
            "participant_2_id": existing_room.participant_2_id,
            "is_active": existing_room.is_active,
            "created_at": existing_room.created_at.isoformat() if existing_room.created_at else None,
        }
    
    # Create new room
    chat_room = ChatRoom(
        room_id=room_id,
        participant_1_id=doctor_id,
        participant_2_id=patient_id,
        participant_1_type="doctor",
        participant_2_type="mother",
    )
    db.add(chat_room)
    db.commit()
    db.refresh(chat_room)
    
    return {
        "room_id": chat_room.room_id,
        "participant_1_id": chat_room.participant_1_id,
        "participant_2_id": chat_room.participant_2_id,
        "is_active": chat_room.is_active,
        "created_at": chat_room.created_at.isoformat() if chat_room.created_at else None,
    }

def send_message(
    room_id: str = Form(...),
    sender_id: str = Form(...),
    sender_type: str = Form(...),
    message_text: str = Form(...),
    message_type: str = Form("text"),
    file_url: str = Form(""),
    db: Session = Depends(get_db)
):
    """Send a message in a chat room"""
    # Verify room exists
    room = db.query(ChatRoom).filter(ChatRoom.room_id == room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Chat room not found")
    
    # Create message and flush so that the auto-generated primary key is
    # populated before we reference it from the notification row.
    message = ChatMessage(
        room_id=room_id,
        sender_id=sender_id.strip().upper(),
        sender_type=sender_type,
        message_text=message_text,
        message_type=message_type,
        file_url=file_url if file_url.strip() else None,
    )
    db.add(message)
    db.flush()  # populates message.id without committing the transaction

    # Update room's last message time
    room.last_message_at = datetime.now()

    # Create notification for recipient
    recipient_id = room.participant_2_id if sender_type == "doctor" else room.participant_1_id
    recipient_type = room.participant_2_type if sender_type == "doctor" else room.participant_1_type

    notification = ChatNotification(
        user_id=recipient_id,
        user_type=recipient_type,
        room_id=room_id,
        message_id=message.id,
        notification_type="new_message",
    )
    db.add(notification)

    db.commit()
    db.refresh(message)

    # Fan out to any live WebSocket subscribers for instant delivery.
    broadcast_new_message(room_id, message)

    return {
        "id": message.id,
        "room_id": message.room_id,
        "sender_id": message.sender_id,
        "sender_type": message.sender_type,
        "message_text": message.message_text,
        "message_type": message.message_type,
        "file_url": message.file_url,
        "is_read": message.is_read,
        "created_at": message.created_at.isoformat() if message.created_at else None,
    }

def get_chat_messages(
    room_id: str,
    limit: int = 50,
    db: Session = Depends(get_db)
):
    """Get messages from a chat room"""
    messages = db.query(ChatMessage).filter(
        ChatMessage.room_id == room_id
    ).order_by(ChatMessage.created_at.desc()).limit(limit).all()
    
    return [
        {
            "id": msg.id,
            "room_id": msg.room_id,
            "sender_id": msg.sender_id,
            "sender_type": msg.sender_type,
            "message_text": msg.message_text,
            "message_type": msg.message_type,
            "file_url": msg.file_url,
            "is_read": msg.is_read,
            "read_at": msg.read_at.isoformat() if msg.read_at else None,
            "created_at": msg.created_at.isoformat() if msg.created_at else None,
        }
        for msg in reversed(messages)  # Show in chronological order
    ]

def get_user_chat_rooms(
    user_id: str,
    user_type: str,
    db: Session = Depends(get_db)
):
    """Get all chat rooms for a user"""
    user_id = user_id.strip().upper()
    
    if user_type == "doctor":
        rooms = db.query(ChatRoom).filter(ChatRoom.participant_1_id == user_id).all()
    else:  # mother
        rooms = db.query(ChatRoom).filter(ChatRoom.participant_2_id == user_id).all()
    
    result = []
    for room in rooms:
        # Get last message
        last_message = db.query(ChatMessage).filter(
            ChatMessage.room_id == room.room_id
        ).order_by(ChatMessage.created_at.desc()).first()
        
        # Get unread count
        unread_count = db.query(ChatMessage).filter(
            ChatMessage.room_id == room.room_id,
            ChatMessage.sender_type != user_type,
            ChatMessage.is_read == False
        ).count()
        
        # Get other participant info
        if user_type == "doctor":
            other_participant_id = room.participant_2_id
            mother = db.query(Mother).filter(Mother.patient_id == other_participant_id).first()
            other_participant_name = mother.full_name if mother else "Unknown Patient"
        else:
            other_participant_id = room.participant_1_id
            other_participant_name = "Doctor"  # We don't have doctor details table yet
        
        result.append({
            "room_id": room.room_id,
            "other_participant_id": other_participant_id,
            "other_participant_name": other_participant_name,
            "other_participant_type": room.participant_1_type if user_type == "mother" else room.participant_2_type,
            "is_active": room.is_active,
            "last_message_at": room.last_message_at.isoformat() if room.last_message_at else None,
            "last_message": last_message.message_text if last_message else None,
            "unread_count": unread_count,
            "created_at": room.created_at.isoformat() if room.created_at else None,
        })
    
    # Sort by last message time
    result.sort(key=lambda x: x["last_message_at"] or "", reverse=True)
    return result

def mark_messages_as_read(
    room_id: str = Form(...),
    user_id: str = Form(...),
    db: Session = Depends(get_db)
):
    """Mark all messages in a room as read for a user"""
    user_id = user_id.strip().upper()

    # Collect IDs first so we can broadcast which ones changed.
    unread_query = db.query(ChatMessage).filter(
        ChatMessage.room_id == room_id,
        ChatMessage.sender_id != user_id,
        ChatMessage.is_read == False  # noqa: E712 (SQLAlchemy comparison)
    )
    unread_ids = [row.id for row in unread_query.all()]

    unread_query.update({
        "is_read": True,
        "read_at": datetime.now()
    })

    # Dismiss notifications
    db.query(ChatNotification).filter(
        ChatNotification.user_id == user_id,
        ChatNotification.room_id == room_id,
        ChatNotification.is_dismissed == False  # noqa: E712
    ).update({
        "is_dismissed": True
    })

    db.commit()

    if unread_ids:
        broadcast_messages_read(room_id, user_id, unread_ids)

    return {"message": "Messages marked as read", "read_ids": unread_ids}
