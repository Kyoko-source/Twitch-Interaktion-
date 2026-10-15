"""Explicit, restart-safe one-time reset. Run with the old backend stopped.

python -m app.migrate_chickens --apply
"""
import argparse
import json
import math
import os
from pathlib import Path

from .economy import economy, utc_now, PUNISHMENT_CATEGORIES
from .supabase import supabase


def new_price(item):
    old = max(0, int(item.get("price") or 0))
    category = str(item.get("category") or "").strip()
    if category in PUNISHMENT_CATEGORIES:
        return max(150, math.ceil(old * 3 / 50) * 50)
    if category in {"Aufgaben", "Aufgaben Ideen", "Idee Aufgabenrad"}:
        return max(250, math.ceil(old * 3 / 50) * 50)
    return old


def migrate(apply=False):
    store = economy()
    with store.connection() as db:
        if db.execute("SELECT 1 FROM metadata WHERE key='chickens-v1-ready'").fetchone():
            print("Chicken economy already initialized; no balances or prices changed.")
            return
    client = supabase()
    users = client.get("users?select=username,chickens,braincells&order=username.asc")
    items = client.get("shop_items?select=*&order=id.asc")
    if not apply:
        print(json.dumps({"dry_run": True, "users_to_reset": len(users), "prices_to_update": sum(new_price(item) != int(item.get("price") or 0) for item in items)}))
        return
    backup_path = Path(os.getenv("CHICKEN_RESET_BACKUP", "/data/backups/chickens-v1.json"))
    backup_path.parent.mkdir(parents=True, exist_ok=True)
    if backup_path.exists():
        backup = json.loads(backup_path.read_text(encoding="utf-8"))
        if backup.get("migration") != "chickens-v1" or not isinstance(backup.get("users"), list) or not isinstance(backup.get("items"), list):
            raise RuntimeError("Invalid reset backup; refusing to change balances")
    else:
        backup = {"migration": "chickens-v1", "created_at": utc_now(), "users": users, "items": items}
        temporary = backup_path.with_suffix(".tmp")
        descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(backup, handle, ensure_ascii=False, indent=2)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, backup_path)
    # Always derive prices from the backed-up catalog, so a retry cannot triple twice.
    for item in backup["items"]:
        price = new_price(item)
        if price != int(item.get("price") or 0):
            client.patch(f"shop_items?id=eq.{int(item['id'])}", {"price": price})
    client.patch("users?username=not.is.null", {"chickens": 0})
    remaining = client.get("users?select=username,chickens&chickens=neq.0")
    if remaining:
        raise RuntimeError("Not all legacy balances are zero; economy remains disabled")
    store.mark_ready([str(user["username"]) for user in users])
    print(json.dumps({"reset_users": len(users), "backup": str(backup_path), "currency": "Chickens", "ready": True}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="Back up and reset all Chicken balances once")
    migrate(parser.parse_args().apply)
