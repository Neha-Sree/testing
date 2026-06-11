"""Normalize clinical free-text and map medical terms for risk scoring."""
from __future__ import annotations

import re
from typing import Optional

# Canonical enums used in HealthMetrics
FETAL_MOVEMENT_VALUES = frozenset({"normal", "reduced", "none"})
SWELLING_VALUES = frozenset({"none", "feet_mild", "face_hands_sudden"})

# Symptom severity inference (substring match on lowercased text)
_CRITICAL_SYMPTOM_TERMS = (
    "heavy bleeding",
    "massive bleed",
    "seizure",
    "convulsion",
    "unconscious",
    "faint",
    "fainting",
    "no fetal movement",
    "baby not moving",
    "cannot feel baby",
    "waters broke",
    "water broke",
    "premature rupture",
    "cord prolapse",
    "eclampsia",
)

_RED_SYMPTOM_TERMS = (
    "severe headache",
    "worst headache",
    "migraine with vision",
    "blurred vision",
    "flashing lights",
    "vision changes",
    "pre-eclampsia",
    "preeclampsia",
    "pre eclampsia",
    "high blood pressure",
    "hypertension",
    "reduced movement",
    "less movement",
    "decreased movement",
    "contractions",
    "regular pain",
    "severe abdominal",
    "severe pain",
    "chest pain",
    "shortness of breath",
    "difficulty breathing",
    "can't breathe",
    "vomiting blood",
    "fever",
    "chills",
    "oligohydramnios",
    "polyhydramnios",
    "placenta previa",
    "abruption",
)

_YELLOW_SYMPTOM_TERMS = (
    "headache",
    "dizziness",
    "nausea",
    "vomiting",
    "swelling",
    "oedema",
    "edema",
    "heartburn",
    "back pain",
    "pelvic pain",
    "constipation",
    "fatigue",
    "anxiety",
    "sad",
    "insomnia",
    "spotting",
    "discharge",
    "urinary",
    "uti",
    "infection",
    "cough",
    "cold",
)


def normalize_fetal_movement(value: Optional[str]) -> Optional[str]:
    if not value or not str(value).strip():
        return None
    raw = str(value).strip().lower()
    if raw in FETAL_MOVEMENT_VALUES:
        return raw
    if any(t in raw for t in ("no movement", "not moving", "absent", "none", "no fetal", "decreased markedly")):
        return "none"
    if any(t in raw for t in ("reduced", "decreased", "less", "fewer", "slow", "diminished")):
        return "reduced"
    if any(t in raw for t in ("normal", "active", "good", "present", "adequate")):
        return "normal"
    return None


def normalize_swelling(value: Optional[str]) -> Optional[str]:
    if not value or not str(value).strip():
        return None
    raw = str(value).strip().lower()
    if raw in SWELLING_VALUES:
        return raw
    if any(t in raw for t in ("face", "hand", "facial", "puffiness", "sudden", "pre-eclampsia", "preeclampsia")):
        return "face_hands_sudden"
    if any(t in raw for t in ("feet", "ankle", "leg", "mild", "pedal")):
        return "feet_mild"
    if raw in {"no", "nil", "none", "absent"}:
        return "none"
    return None


def normalize_urine_dipstick(value: Optional[str]) -> Optional[str]:
    if not value or not str(value).strip():
        return None
    raw = str(value).strip().lower()
    if raw in {"neg", "negative", "nil", "absent", "normal"}:
        return "neg"
    if "trace" in raw:
        return "trace"
    if "+++" in raw or "3+" in raw:
        return "+++"
    if "++" in raw or "2+" in raw:
        return "++"
    if "+" in raw or "1+" in raw or "positive" in raw:
        return "+"
    return raw[:20]


def classify_symptom_severity(symptom_text: Optional[str]) -> Optional[str]:
    """Infer yellow/red/critical from free-text symptom when severity not set."""
    if not symptom_text or not symptom_text.strip():
        return None
    low = symptom_text.strip().lower()
    if any(term in low for term in _CRITICAL_SYMPTOM_TERMS):
        return "critical"
    if any(term in low for term in _RED_SYMPTOM_TERMS):
        return "red"
    if any(term in low for term in _YELLOW_SYMPTOM_TERMS):
        return "yellow"
    return None


def infection_indicates_risk(notes: Optional[str]) -> bool:
    if not notes or not notes.strip():
        return False
    low = notes.strip().lower()
    risky = (
        "positive",
        "pus",
        "bacteria",
        "infection",
        "uti",
        "sepsis",
        "fever",
        "leukocytosis",
        "elevated wbc",
        "high wbc",
        "culture positive",
        "nitrite positive",
    )
    return any(term in low for term in risky)


def normalize_placenta_status(value: Optional[str]) -> Optional[str]:
    if not value:
        return None
    return str(value).strip()[:200] or None
