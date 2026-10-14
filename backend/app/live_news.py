import json
import logging
import os
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path
from threading import RLock
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from .auth import require_admin


class LiveNewsSettings(BaseModel):
    model_config = ConfigDict(extra="forbid")

    message: str = Field(default="", max_length=1000)
    kind: Literal["breaking", "normal", "community"] = "breaking"
    speed: int = Field(default=90, ge=40, le=220, strict=True)
    enabled: bool = Field(default=False, strict=True)
    playback_mode: Literal["loops", "duration"] = "loops"
    repeat_count: int = Field(default=3, ge=1, le=20, strict=True)
    duration_seconds: int = Field(default=30, ge=5, le=3600, strict=True)
    cycle_seconds: float = Field(default=30, ge=1, le=1800, allow_inf_nan=False, strict=True)
    sound_enabled: bool = Field(default=True, strict=True)
    volume: int = Field(default=70, ge=0, le=100, strict=True)

    @field_validator("message")
    @classmethod
    def normalize_message(cls, value: str) -> str:
        return " ".join(value.split())

    @model_validator(mode="after")
    def check_enabled_message(self):
        if self.enabled and not self.message:
            raise ValueError("Eine Live-Nachricht darf nicht leer sein.")
        return self


class LiveNewsState(LiveNewsSettings):
    revision: int = Field(default=0, ge=0)
    updated_at: str | None = None
    ends_at: str | None = None


class LiveNewsVisibility(BaseModel):
    model_config = ConfigDict(extra="forbid")
    enabled: bool = Field(strict=True)


class LiveNewsStore:
    def __init__(self, path: Path):
        self.path = path
        self.lock = RLock()

    def read(self) -> LiveNewsState:
        with self.lock:
            try:
                state = LiveNewsState.model_validate_json(self.path.read_text(encoding="utf-8"))
            except FileNotFoundError:
                return LiveNewsState()
            if state.enabled:
                # Legacy publications also expire; a browser refresh never restarts a run.
                if not state.ends_at and state.updated_at:
                    start = datetime.fromisoformat(state.updated_at)
                    state.ends_at = (start + timedelta(seconds=self.run_seconds(state))).isoformat()
                if not state.ends_at or datetime.now(timezone.utc) >= datetime.fromisoformat(state.ends_at):
                    state.enabled = False
            return state

    @staticmethod
    def run_seconds(settings: LiveNewsSettings) -> float:
        return settings.duration_seconds if settings.playback_mode == "duration" else settings.cycle_seconds * settings.repeat_count

    def write(self, settings: LiveNewsSettings) -> LiveNewsState:
        with self.lock:
            previous = self.read()
            now = datetime.now(timezone.utc)
            state = LiveNewsState(
                **settings.model_dump(),
                revision=previous.revision + 1,
                updated_at=now.isoformat(),
                ends_at=(now + timedelta(seconds=self.run_seconds(settings))).isoformat() if settings.enabled else None,
            )
            self.path.parent.mkdir(parents=True, exist_ok=True)
            temporary = None
            try:
                # Readers see either the old or the complete new state, never half a write.
                with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=self.path.parent, delete=False) as handle:
                    temporary = Path(handle.name)
                    json.dump(state.model_dump(), handle, ensure_ascii=False)
                    handle.flush()
                    os.fsync(handle.fileno())
                os.replace(temporary, self.path)
            finally:
                if temporary is not None:
                    temporary.unlink(missing_ok=True)
            return state

    def visibility(self, enabled: bool) -> LiveNewsState:
        with self.lock:
            current = self.read()
            if enabled and not current.message:
                raise HTTPException(status_code=422, detail="Zuerst eine Nachricht veroeffentlichen.")
            return self.write(LiveNewsSettings(
                **{**current.model_dump(exclude={"revision", "updated_at", "ends_at"}), "enabled": enabled},
            ))


router = APIRouter()
store = LiveNewsStore(Path(os.getenv("LIVE_NEWS_FILE", "/data/live_news.json")))
logger = logging.getLogger(__name__)


def stored(operation):
    try:
        return operation()
    except (OSError, ValueError):
        logger.exception("Live News storage unavailable")
        raise HTTPException(status_code=503, detail="Live News konnte nicht geladen oder gespeichert werden.") from None


def no_cache(response: Response):
    response.headers["Cache-Control"] = "no-store"


@router.get("/api/live-news", response_model=LiveNewsState)
def public_live_news(response: Response):
    no_cache(response)
    return stored(store.read)


@router.get("/api/admin/live-news", response_model=LiveNewsState, dependencies=[Depends(require_admin)])
def admin_live_news(response: Response):
    no_cache(response)
    return stored(store.read)


@router.put("/api/admin/live-news", response_model=LiveNewsState, dependencies=[Depends(require_admin)])
def publish_live_news(payload: LiveNewsSettings, response: Response):
    no_cache(response)
    return stored(lambda: store.write(payload))


@router.patch("/api/admin/live-news", response_model=LiveNewsState, dependencies=[Depends(require_admin)])
def visibility_live_news(payload: LiveNewsVisibility, response: Response):
    no_cache(response)
    return stored(lambda: store.visibility(payload.enabled))
