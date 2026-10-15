from fastapi import APIRouter, Depends, Response
from pydantic import BaseModel, ConfigDict, Field

from .auth import require_admin
from .economy import economy

router = APIRouter()


class AlertSettings(BaseModel):
    model_config = ConfigDict(extra="forbid")
    duration_seconds: int = Field(default=10, ge=5, le=20, strict=True)


@router.get("/api/purchase-alerts")
def purchase_alerts(response: Response):
    response.headers["Cache-Control"] = "no-store"
    return economy().alerts()


@router.get("/api/admin/purchase-alerts", dependencies=[Depends(require_admin)])
def admin_purchase_alerts(response: Response):
    response.headers["Cache-Control"] = "no-store"
    return {"settings": economy().settings(), "purchases": economy().recent_purchases()}


@router.put("/api/admin/purchase-alerts", dependencies=[Depends(require_admin)])
def configure_purchase_alerts(payload: AlertSettings):
    return {"settings": economy().settings(payload.model_dump()), "message": "Anzeigedauer gespeichert."}
