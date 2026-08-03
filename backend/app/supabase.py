from typing import Any

import requests
from fastapi import HTTPException

from .config import get_settings


class SupabaseClient:
    def __init__(self) -> None:
        settings = get_settings()
        if not settings.supabase_url or not settings.supabase_service_key:
            raise RuntimeError("Supabase is not configured")
        self.base_url = f"{settings.supabase_url}/rest/v1"
        self.headers = {
            "apikey": settings.supabase_service_key,
            "Authorization": f"Bearer {settings.supabase_service_key}",
            "Content-Type": "application/json",
        }

    def request(self, method: str, path: str, **kwargs: Any) -> Any:
        url = f"{self.base_url}/{path.lstrip('/')}"
        headers = {**self.headers, **kwargs.pop("headers", {})}
        try:
            response = requests.request(method, url, headers=headers, timeout=10, **kwargs)
        except requests.RequestException as exc:
            raise HTTPException(status_code=503, detail="Supabase ist gerade nicht erreichbar") from exc

        if response.status_code >= 400:
            raise HTTPException(status_code=response.status_code, detail=response.text)

        if response.status_code == 204 or not response.text:
            return None
        return response.json()

    def get(self, path: str) -> list[dict[str, Any]]:
        data = self.request("GET", path)
        return data if isinstance(data, list) else []

    def post(self, table: str, payload: dict[str, Any], *, returning: bool = True) -> Any:
        headers = {"Prefer": "return=representation" if returning else "return=minimal"}
        return self.request("POST", table, json=payload, headers=headers)

    def patch(self, path: str, payload: dict[str, Any]) -> Any:
        return self.request("PATCH", path, json=payload, headers={"Prefer": "return=representation"})

    def delete(self, path: str) -> None:
        self.request("DELETE", path)


def supabase() -> SupabaseClient:
    return SupabaseClient()
