from datetime import datetime, timedelta, timezone
import hashlib
import secrets
from typing import Any

from fastapi import Depends, Header, HTTPException, Request
from jose import JWTError, jwt
from passlib.hash import pbkdf2_sha256

from .config import get_settings
from .supabase import supabase
from .economy import economy
from . import ratelimit


TOKEN_ALGORITHM = "HS256"
TOKEN_TTL_HOURS = 24 * 7
LEGACY_PASSWORD_SALT = "gehirnzone_guest_auth_salt"


def create_access_token(username: str) -> str:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload = {
        "sub": username,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(hours=TOKEN_TTL_HOURS)).timestamp()),
        "ver": economy().access(username)["session_version"],
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=TOKEN_ALGORITHM)


def verify_password(password: str, password_hash: str | None) -> bool:
    if not password_hash:
        return False
    if password_hash.startswith("$pbkdf2-sha256$"):
        try:
            return pbkdf2_sha256.verify(password, password_hash)
        except ValueError:
            return False
    legacy_hash = hashlib.sha256(f"{password}{LEGACY_PASSWORD_SALT}".encode("utf-8")).hexdigest()
    return secrets.compare_digest(legacy_hash, password_hash)


def needs_rehash(password_hash: str | None) -> bool:
    return bool(password_hash) and not password_hash.startswith("$pbkdf2-sha256$")


def hash_password(password: str) -> str:
    return pbkdf2_sha256.hash(password)


def get_user(username: str) -> dict[str, Any] | None:
    rows = supabase().get(f"users?username=eq.{username}&limit=1")
    return rows[0] if rows else None


def current_user(authorization: str | None = Header(default=None)) -> dict[str, Any]:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Nicht angemeldet")
    token = authorization.split(" ", 1)[1]
    settings = get_settings()
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[TOKEN_ALGORITHM])
    except JWTError as exc:
        raise HTTPException(status_code=401, detail="Session ist ungueltig") from exc
    username = str(payload.get("sub") or "").strip()
    user = get_user(username)
    if not user:
        raise HTTPException(status_code=401, detail="User nicht gefunden")
    access = economy().access(username)
    if access["banned"]:
        raise HTTPException(403, {"code": "account_banned", "message": "Dein Konto wurde gesperrt. Bitte kontaktiere den Support."})
    if payload.get("ver", 0) != access["session_version"]:
        raise HTTPException(401, {"code": "session_revoked", "message": "Deine Sitzung wurde beendet. Bitte melde dich erneut an."})
    return user


ADMIN_FAIL_LIMIT = 8
ADMIN_FAIL_WINDOW = 15 * 60


def require_admin(request: Request, x_admin_password: str | None = Header(default=None)) -> None:
    expected = get_settings().admin_password
    if not expected:
        raise HTTPException(status_code=403, detail="Adminbereich ist auf dem Server nicht eingerichtet")
    ratelimit.check(request, "admin", ADMIN_FAIL_LIMIT, ADMIN_FAIL_WINDOW)
    if not x_admin_password or not secrets.compare_digest(x_admin_password.encode("utf-8"), expected.encode("utf-8")):
        ratelimit.record(request, "admin")
        raise HTTPException(status_code=403, detail="Admin-Passwort falsch")
