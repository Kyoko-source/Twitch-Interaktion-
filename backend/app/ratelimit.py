"""Small in-memory brute-force guard.

The backend runs as one process behind Caddy and nginx, so a per-process
counter is enough to stop password guessing against login and the admin
header. Caddy replaces any client-sent X-Forwarded-For and nginx appends
Caddy's own address, so the real client is the second-to-last entry.
"""
import time
from collections import deque
from threading import Lock

from fastapi import HTTPException, Request

_lock = Lock()
_hits: dict[tuple[str, str], deque] = {}


def client_ip(request: Request | None) -> str:
    if request is None:
        return "-"
    chain = [part.strip() for part in request.headers.get("x-forwarded-for", "").split(",") if part.strip()]
    if len(chain) >= 2:
        return chain[-2]
    if chain:
        return chain[0]
    return request.client.host if request.client else "-"


def _window(bucket: str, ip: str, seconds: float) -> deque:
    now = time.monotonic()
    hits = _hits.setdefault((bucket, ip), deque())
    while hits and now - hits[0] > seconds:
        hits.popleft()
    if len(_hits) > 50_000:  # never grow without bound under a flood
        for key in [k for k, v in _hits.items() if not v][:25_000]:
            del _hits[key]
    return hits


def check(request: Request | None, bucket: str, limit: int, seconds: float) -> None:
    """Raise 429 once `limit` events were recorded for this IP in the window."""
    ip = client_ip(request)
    with _lock:
        if len(_window(bucket, ip, seconds)) >= limit:
            raise HTTPException(429, "Zu viele Versuche. Bitte warte ein paar Minuten.")


def record(request: Request | None, bucket: str) -> None:
    ip = client_ip(request)
    with _lock:
        _hits.setdefault((bucket, ip), deque()).append(time.monotonic())


def hit(request: Request | None, bucket: str, limit: int, seconds: float) -> None:
    """Count every call (for spam-prone public forms) and enforce the limit."""
    check(request, bucket, limit, seconds)
    record(request, bucket)


def reset() -> None:
    with _lock:
        _hits.clear()
