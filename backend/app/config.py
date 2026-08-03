from functools import lru_cache
from os import getenv


class Settings:
    def __init__(self) -> None:
        self.supabase_url = self._clean_url(getenv("SUPABASE_URL", ""))
        self.supabase_anon_key = getenv("SUPABASE_ANON_KEY") or getenv("SUPABASE_KEY") or ""
        self.supabase_service_key = (
            getenv("SUPABASE_SERVICE_KEY") or getenv("SUPABASE_KEY") or self.supabase_anon_key
        )
        self.jwt_secret = getenv("AVIARY_JWT_SECRET") or getenv("SECRET_KEY") or "change-me-in-production"
        self.admin_password = getenv("AVIARY_ADMIN_PASSWORD") or "einsmarello"
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
