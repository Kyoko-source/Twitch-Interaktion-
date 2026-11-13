import secrets
import sys
from functools import lru_cache
from os import getenv


class Settings:
    def __init__(self) -> None:
        self.supabase_url = self._clean_url(getenv("SUPABASE_URL", ""))
        self.supabase_anon_key = getenv("SUPABASE_ANON_KEY") or getenv("SUPABASE_KEY") or ""
        self.supabase_service_key = (
            getenv("SUPABASE_SERVICE_KEY") or getenv("SUPABASE_KEY") or self.supabase_anon_key
        )
        # No built-in fallbacks: this repository is public, so any default here
        # would be a published password. Without a JWT secret every restart
        # gets a random one (users must log in again); without an admin
        # password the admin area stays locked.
        self.jwt_secret = getenv("AVIARY_JWT_SECRET") or getenv("SECRET_KEY") or ""
        if len(self.jwt_secret) < 16 or self.jwt_secret == "change-me-in-production":
            print("WARNING: AVIARY_JWT_SECRET is missing or too short; using a random per-process secret.", file=sys.stderr)
            self.jwt_secret = secrets.token_urlsafe(48)
        self.admin_password = getenv("AVIARY_ADMIN_PASSWORD") or ""
        if len(self.admin_password) < 12 or self.admin_password in {"einsmarello", "bitte-admin-passwort-setzen"}:
            print("WARNING: AVIARY_ADMIN_PASSWORD is missing, too short or a published default; admin area disabled.", file=sys.stderr)
            self.admin_password = ""
        self.public_base_url = getenv("PUBLIC_BASE_URL") or "http://62.238.49.219"
        self.cors_origins = [
            origin.strip()
            for origin in (getenv("CORS_ORIGINS") or "http://localhost:5173,http://62.238.49.219").split(",")
            if origin.strip()
        ]

    @staticmethod
    def _clean_url(value: str) -> str:
        return value.strip().rstrip("/")


@lru_cache
def get_settings() -> Settings:
    return Settings()
