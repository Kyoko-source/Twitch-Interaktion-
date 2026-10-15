"""Disposable, loopback-only browser-test harness. Not copied into product images."""
import os

if os.environ.get("NULLSIGNAL_QA_ONLY") != "loopback-disposable":
    raise RuntimeError("This test harness requires NULLSIGNAL_QA_ONLY=loopback-disposable.")

from fastapi import Header, HTTPException
from app.main import app
from app.auth import current_user
from app.economy import economy


def qa_user(authorization: str | None = Header(default=None)):
    if authorization != "Bearer nullsignal-qa-host":
        raise HTTPException(401, "QA login required")
    return {"username": "NullsignalQA", "role": "member"}


app.dependency_overrides[current_user] = qa_user
economy().mark_ready(["NullsignalQA"])
