from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone


TOKEN_TTL_MINUTES = int(os.getenv("AUTH_TOKEN_TTL_MINUTES", "720"))


def _secret_key() -> str:
    secret = os.getenv("AUTH_SECRET_KEY") or os.getenv("JWT_SECRET_KEY")
    if not secret:
        raise RuntimeError("AUTH_SECRET_KEY is required")
    return secret


@dataclass(frozen=True)
class AuthUser:
    user_id: str
    role: str


def _b64encode(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _b64decode(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode((value + padding).encode("ascii"))


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt.encode("utf-8"), 200_000)
    return f"pbkdf2_sha256$200000${salt}${digest.hex()}"


def verify_password(stored_password: str | None, password: str) -> bool:
    if not stored_password:
        return False
    if not stored_password.startswith("pbkdf2_sha256$"):
        return hmac.compare_digest(stored_password, password)
    try:
        _, rounds, salt, digest = stored_password.split("$", 3)
        candidate = hashlib.pbkdf2_hmac(
            "sha256",
            password.encode("utf-8"),
            salt.encode("utf-8"),
            int(rounds),
        ).hex()
    except (TypeError, ValueError):
        return False
    return hmac.compare_digest(candidate, digest)


def needs_password_upgrade(stored_password: str | None) -> bool:
    return bool(stored_password) and not stored_password.startswith("pbkdf2_sha256$")


def create_access_token(user_id: str, role: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": user_id.strip().upper(),
        "role": role,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=TOKEN_TTL_MINUTES)).timestamp()),
    }
    header = {"alg": "HS256", "typ": "JWT"}
    signing_input = ".".join(
        [
            _b64encode(json.dumps(header, separators=(",", ":")).encode("utf-8")),
            _b64encode(json.dumps(payload, separators=(",", ":")).encode("utf-8")),
        ]
    )
    signature = hmac.new(_secret_key().encode("utf-8"), signing_input.encode("ascii"), hashlib.sha256).digest()
    return f"{signing_input}.{_b64encode(signature)}"


def decode_access_token(token: str) -> AuthUser | None:
    try:
        header_b64, payload_b64, signature_b64 = token.split(".", 2)
        signing_input = f"{header_b64}.{payload_b64}"
        expected = hmac.new(_secret_key().encode("utf-8"), signing_input.encode("ascii"), hashlib.sha256).digest()
        actual = _b64decode(signature_b64)
        if not hmac.compare_digest(expected, actual):
            return None
        payload = json.loads(_b64decode(payload_b64).decode("utf-8"))
        if int(payload.get("exp", 0)) < int(datetime.now(timezone.utc).timestamp()):
            return None
        user_id = str(payload.get("sub") or "").strip().upper()
        role = str(payload.get("role") or "").strip().lower()
        if not user_id or role not in {"mother", "doctor", "health_worker"}:
            return None
        return AuthUser(user_id=user_id, role=role)
    except Exception:
        return None


def role_from_user_id(user_id: str) -> str | None:
    uid = user_id.strip().upper()
    if uid.startswith("MUM"):
        return "mother"
    if uid.startswith("DOC"):
        return "doctor"
    if uid.startswith("HWN"):
        return "health_worker"
    return None
