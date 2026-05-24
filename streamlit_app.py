import streamlit as st
import pandas as pd
import requests
import altair as alt
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
import streamlit.components.v1 as components
import hashlib
import re
import urllib.parse
import uuid
import secrets
import string
import html
import textwrap
import json
import math
import base64
import io
from pathlib import Path
from typing import Optional

from PIL import Image

try:
    from streamlit_drawable_canvas import st_canvas
except ImportError:
    st_canvas = None

st.set_page_config(
    page_title="Gehirnzone",
    page_icon="🧠",
    layout="wide"
)

PASSWORD_SALT = "gehirnzone_guest_auth_salt"
REGISTRATION_CODE_SALT = "gehirnzone_registration_code_salt"
DND_LOBBY_PASSWORD_SALT = "gehirnzone_dnd_lobby_salt"

# =========================
# VALIDATION
# =========================

def validate_username(username: str) -> bool:
    """Validate username: not empty, <=50 chars, alphanumeric + _ -"""
    if not username or len(username.strip()) == 0:
        return False
    if len(username) > 50:
        return False
    if not re.match(r'^[a-zA-Z0-9_-]+$', username):
        return False
    return True


def hash_password(password: str) -> str:
    return hashlib.sha256(f"{password}{PASSWORD_SALT}".encode("utf-8")).hexdigest()


def verify_password(password: str, password_hash: str) -> bool:
    return hash_password(password) == password_hash


def hash_registration_code(code: str) -> str:
    normalized_code = code.strip().upper()
    return hashlib.sha256(f"{normalized_code}{REGISTRATION_CODE_SALT}".encode("utf-8")).hexdigest()


def hash_dnd_lobby_password(password: str) -> str:
    return hashlib.sha256(f"{password}{DND_LOBBY_PASSWORD_SALT}".encode("utf-8")).hexdigest()


def verify_dnd_lobby_password(password: str, password_hash: str) -> bool:
    return hash_dnd_lobby_password(password) == password_hash


def generate_registration_code(length: int = 8) -> str:
    alphabet = string.ascii_uppercase + "23456789"
    return "".join(secrets.choice(alphabet) for _ in range(length))


def login_user(username: str, password: str) -> Optional[dict]:
    user = get_user(username)
    if not user:
        return None

    password_hash = user.get("password_hash")
    if not password_hash:
        return None

    return user if verify_password(password, password_hash) else None


def logout_user():
    st.session_state.pop("logged_in_username", None)

# =========================
# SUPABASE
# =========================

try:
    SUPABASE_URL = st.secrets["supabase"]["url"]
    SUPABASE_ANON_KEY = st.secrets["supabase"].get("anon_key") or st.secrets["supabase"].get("key")
    SUPABASE_SERVICE_KEY = st.secrets["supabase"].get("service_key") or st.secrets["supabase"].get("key")
except KeyError:
    st.error("Supabase-Secrets sind nicht konfiguriert. Bitte setze url, anon_key und service_key in den App-Einstellungen.")
    st.stop()

if not SUPABASE_ANON_KEY or not SUPABASE_SERVICE_KEY:
    st.error("Supabase-Secrets sind unvollständig. Bitte setze anon_key und service_key in den App-Einstellungen.")
    st.stop()

HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json"
}

# =========================
# API
# =========================

def show_api_error(response):
    try:
        error = response.json()
    except ValueError:
        error = {"message": response.text}

    message = error.get("message") or response.reason or "Unbekannter Fehler"
    hint = error.get("hint")
    details = error.get("details")

    error_text = f"Datenbank-Fehler ({response.status_code}): {message}"
    if hint:
        error_text += f" Hinweis: {hint}"
    if details:
        error_text += f" Details: {details}"

    st.error(error_text)


def api_get(path):
    response = requests.get(
        f"{SUPABASE_URL}/rest/v1/{path}",
        headers=HEADERS
    )

    if response.status_code >= 400:
        show_api_error(response)
        return []

    return response.json()


def api_get_optional(path):
    response = requests.get(
        f"{SUPABASE_URL}/rest/v1/{path}",
        headers=HEADERS
    )

    if response.status_code >= 400:
        return []

    return response.json()


def api_post(table, payload):
    response = requests.post(
        f"{SUPABASE_URL}/rest/v1/{table}",
        headers={**HEADERS, "Prefer": "return=representation"},
        json=payload
    )

    if response.status_code >= 400:
        show_api_error(response)
        return None

    return response.json()


def api_post_optional(table, payload):
    response = requests.post(
        f"{SUPABASE_URL}/rest/v1/{table}",
        headers={**HEADERS, "Prefer": "return=representation"},
        json=payload
    )

    if response.status_code >= 400:
        return None

    return response.json()


def api_post_optional_with_error(table, payload):
    response = requests.post(
        f"{SUPABASE_URL}/rest/v1/{table}",
        headers={**HEADERS, "Prefer": "return=representation"},
        json=payload
    )

    if response.status_code >= 400:
        try:
            error = response.json()
        except ValueError:
            error = {"message": response.text}
        return None, error

    return response.json(), None


def api_upsert_optional(table_path, payload):
    response = requests.post(
        f"{SUPABASE_URL}/rest/v1/{table_path}",
        headers={**HEADERS, "Prefer": "return=representation,resolution=merge-duplicates"},
        json=payload
    )

    if response.status_code >= 400:
        return None

    return response.json()

def api_patch(path, payload):
    response = requests.patch(
        f"{SUPABASE_URL}/rest/v1/{path}",
        headers=HEADERS,
        json=payload
    )

    if response.status_code >= 400:
        show_api_error(response)
        return False

    return True

def api_delete(path):
    response = requests.delete(
        f"{SUPABASE_URL}/rest/v1/{path}",
        headers=HEADERS
    )

    if response.status_code >= 400:
        show_api_error(response)
        return False

    return True

# =========================
# TWITCH AUTH
# =========================

TWITCH_AUTHORIZE_URL = "https://id.twitch.tv/oauth2/authorize"
TWITCH_TOKEN_URL = "https://id.twitch.tv/oauth2/token"
TWITCH_USER_URL = "https://api.twitch.tv/helix/users"


def get_twitch_config():
    try:
        twitch = st.secrets["twitch"]
        return twitch["client_id"], twitch["client_secret"], twitch["redirect_uri"]
    except KeyError as e:
        return None, None, None


def twitch_oauth_authorize_url():
    client_id, _, redirect_uri = get_twitch_config()

    if not client_id or not redirect_uri:
        return None

    state = str(uuid.uuid4())
    st.session_state["twitch_oauth_state"] = state

    params = {
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": "user:read:email",
        "state": state,
    }

    return f"{TWITCH_AUTHORIZE_URL}?{urllib.parse.urlencode(params)}"


def exchange_twitch_code(code: str) -> Optional[str]:
    client_id, client_secret, redirect_uri = get_twitch_config()

    if not client_id or not client_secret or not redirect_uri:
        return None

    response = requests.post(
        TWITCH_TOKEN_URL,
        data={
            "client_id": client_id,
            "client_secret": client_secret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirect_uri,
        }
    )

    if response.status_code != 200:
        return None

    return response.json().get("access_token")


def fetch_twitch_user(access_token: str) -> Optional[dict]:
    client_id, _, _ = get_twitch_config()

    if not client_id or not access_token:
        return None

    response = requests.get(
        TWITCH_USER_URL,
        headers={
            "Client-ID": client_id,
            "Authorization": f"Bearer {access_token}",
        }
    )

    if response.status_code != 200:
        return None

    data = response.json().get("data")
    return data[0] if data else None


def handle_twitch_callback():
    try:
        params = st.query_params
    except AttributeError:
        # Fallback für ältere Streamlit-Versionen
        try:
            params = st.experimental_get_query_params()
        except:
            return

    if "error" in params:
        st.warning("Twitch-Login wurde abgebrochen oder fehlgeschlagen.")
        st.query_params.clear()
        return

    if "code" not in params:
        return

    code = params["code"] if isinstance(params.get("code"), list) else [params.get("code")]
    code = code[0] if code else None
    
    state = params.get("state")
    state = state[0] if isinstance(state, list) else state

    if not code or state != st.session_state.get("twitch_oauth_state"):
        st.error("Ungültiger Login-Zustand. Bitte versuche es erneut.")
        try:
            st.query_params.clear()
        except:
            st.experimental_set_query_params()
        return

    access_token = exchange_twitch_code(code)

    if not access_token:
        st.error("Twitch-Login fehlgeschlagen. Bitte prüfe die OAuth-Konfiguration.")
        try:
            st.query_params.clear()
        except:
            st.experimental_set_query_params()
        return

    twitch_user = fetch_twitch_user(access_token)

    if not twitch_user:
        st.error("Konnte Twitch-Benutzerdaten nicht abrufen.")
        try:
            st.query_params.clear()
        except:
            st.experimental_set_query_params()
        return

    st.session_state["twitch_user"] = twitch_user
    st.session_state["twitch_access_token"] = access_token
    try:
        st.query_params.clear()
    except:
        st.experimental_set_query_params()
    st.rerun()


def get_logged_in_username():
    if st.session_state.get("logged_in_username"):
        return st.session_state["logged_in_username"]

    twitch_user = st.session_state.get("twitch_user")
    if twitch_user:
        return twitch_user.get("login") or twitch_user.get("display_name")

    return ""


def get_logged_in_display_name():
    if st.session_state.get("logged_in_username"):
        return st.session_state["logged_in_username"]

    twitch_user = st.session_state.get("twitch_user")
    if twitch_user:
        return twitch_user.get("display_name") or twitch_user.get("login")

    return ""


def get_effective_username(input_name: str) -> str:
    logged_in = get_logged_in_username()
    if logged_in:
        return logged_in
    return input_name.strip()

# =========================
# USER
# =========================

def get_user(username: str) -> Optional[dict]:
    if not validate_username(username):
        return None
    username = username.strip()
    data = api_get(f"users?username=eq.{urllib.parse.quote(username)}")
    return data[0] if data else None


def create_user(username, password: Optional[str] = None):
    username = username.strip()

    payload = {
        "username": username,
        "chickens": 0,
        "braincells": 0,
        "created_at": datetime.now().isoformat()
    }

    if password:
        payload["password_hash"] = hash_password(password)

    created = api_post("users", payload)
    return created[0] if created else None


def get_or_create_user(username):
    username = username.strip()

    if username == "":
        username = "gast"

    user = get_user(username)

    if user is None:
        user = create_user(username)

    return user


def update_user(username, chickens, braincells):
    username = username.strip()

    return api_patch(
        f"users?username=eq.{urllib.parse.quote(username)}",
        {
            "chickens": chickens,
            "braincells": braincells
        }
    )


def update_user_profile(username, bio, favorite_game, avatar_url):
    username = username.strip()
    avatar_url = avatar_url.strip()

    if avatar_url and not avatar_url.startswith(("http://", "https://")):
        return False

    return api_patch(
        f"users?username=eq.{urllib.parse.quote(username)}",
        {
            "bio": bio.strip()[:300],
            "favorite_game": favorite_game.strip()[:80],
            "avatar_url": avatar_url[:500]
        }
    )


def get_pending_trades(username):
    username = username.strip()
    return api_get(
        f"chicken_trades?recipient=eq.{urllib.parse.quote(username)}"
        "&status=eq.pending&order=created_at.desc"
    )


def get_outgoing_trades(username):
    username = username.strip()
    return api_get(
        f"chicken_trades?requester=eq.{urllib.parse.quote(username)}"
        "&status=eq.pending&order=created_at.desc"
    )


def create_chicken_trade(requester, recipient, trade_type, amount):
    requester = requester.strip()
    recipient = recipient.strip()
    amount = int(amount)

    if requester == recipient or trade_type not in ("gift", "request") or amount <= 0:
        return None

    return api_post(
        "chicken_trades",
        {
            "requester": requester,
            "recipient": recipient,
            "trade_type": trade_type,
            "amount": amount,
            "status": "pending",
            "created_at": datetime.now().isoformat()
        }
    )


def set_trade_status(trade_id, status):
    return api_patch(
        f"chicken_trades?id=eq.{trade_id}",
        {
            "status": status,
            "responded_at": datetime.now().isoformat()
        }
    )


def accept_chicken_trade(trade):
    amount = int(trade.get("amount") or 0)
    requester = trade.get("requester")
    recipient = trade.get("recipient")
    trade_type = trade.get("trade_type")

    if amount <= 0 or trade.get("status") != "pending":
        return False, "Diese Anfrage ist nicht mehr gültig."

    requester_user = get_user(requester)
    recipient_user = get_user(recipient)

    if not requester_user or not recipient_user:
        return False, "Ein Handelspartner wurde nicht gefunden."

    if trade_type == "gift":
        payer = requester_user
        receiver = recipient_user
    elif trade_type == "request":
        payer = recipient_user
        receiver = requester_user
    else:
        return False, "Unbekannter Handelstyp."

    if int(payer.get("chickens") or 0) < amount:
        return False, f"{payer['username']} hat nicht genug Chickens."

    payer_ok = update_user(
        payer["username"],
        int(payer.get("chickens") or 0) - amount,
        int(payer.get("braincells") or 0)
    )
    receiver_ok = update_user(
        receiver["username"],
        int(receiver.get("chickens") or 0) + amount,
        int(receiver.get("braincells") or 0)
    )

    if not payer_ok or not receiver_ok:
        return False, "Chickens konnten nicht übertragen werden."

    if not set_trade_status(trade["id"], "accepted"):
        return False, "Handel wurde übertragen, aber Status konnte nicht gespeichert werden."

    get_members.clear()
    get_leaderboard.clear()
    return True, "Handel angenommen."


def set_user_password(username, password):
    username = username.strip()

    return api_patch(
        f"users?username=eq.{urllib.parse.quote(username)}",
        {
            "password_hash": hash_password(password)
        }
    )


def get_registration_requests(status: Optional[str] = None):
    path = "registration_requests?select=*&order=created_at.desc"
    if status:
        path = f"registration_requests?select=*&status=eq.{urllib.parse.quote(status)}&order=created_at.desc"
    return api_get_optional(path)


def get_active_registration_request(username: str) -> Optional[dict]:
    username = username.strip()
    rows = api_get_optional(
        "registration_requests?select=*&"
        f"username=eq.{urllib.parse.quote(username)}&"
        "status=in.(pending,approved)&used_at=is.null&order=created_at.desc&limit=1"
    )
    return rows[0] if rows else None


def request_registration(username: str, password: str):
    username = username.strip()
    existing_user = get_user(username)
    if existing_user and existing_user.get("password_hash"):
        return False, "Dieser Name ist bereits registriert."

    existing_request = get_active_registration_request(username)
    if existing_request:
        if existing_request.get("status") == "approved":
            return False, "Diese Anfrage wurde schon genehmigt. Bitte nutze den Code vom Admin."
        return False, "Für diesen Namen wartet bereits eine Anfrage auf Genehmigung."

    created = api_post(
        "registration_requests",
        {
            "id": str(uuid.uuid4()),
            "username": username,
            "password_hash": hash_password(password),
            "status": "pending",
            "created_at": datetime.now().isoformat(),
        }
    )
    if not created:
        return False, "Anfrage konnte nicht erstellt werden. Führe zuerst add_registration_requests_table.sql in Supabase aus."

    return True, "Anfrage gesendet. Ein Admin muss sie jetzt genehmigen."


def approve_registration_request(request_id: str):
    code = generate_registration_code()
    ok = api_patch(
        f"registration_requests?id=eq.{urllib.parse.quote(str(request_id))}",
        {
            "status": "approved",
            "approval_code_hash": hash_registration_code(code),
            "approved_at": datetime.now().isoformat(),
        }
    )
    return code if ok else None


def deny_registration_request(request_id: str):
    return api_patch(
        f"registration_requests?id=eq.{urllib.parse.quote(str(request_id))}",
        {
            "status": "denied",
            "denied_at": datetime.now().isoformat(),
        }
    )


def complete_registration(username: str, password: str, code: str):
    username = username.strip()
    code_hash = hash_registration_code(code)
    requests_for_user = api_get_optional(
        "registration_requests?select=*&"
        f"username=eq.{urllib.parse.quote(username)}&"
        "status=eq.approved&used_at=is.null&order=approved_at.desc"
    )

    approved_request = None
    for request_row in requests_for_user:
        if (
            request_row.get("password_hash") == hash_password(password)
            and request_row.get("approval_code_hash") == code_hash
        ):
            approved_request = request_row
            break

    if not approved_request:
        return None, "Registrierung fehlgeschlagen. Prüfe Name, Passwort und Einmalcode."

    existing_user = get_user(username)
    if existing_user and existing_user.get("password_hash"):
        return None, "Dieser Name ist bereits registriert."

    if existing_user:
        user_ok = set_user_password(username, password)
        user = get_user(username) if user_ok else None
    else:
        user = create_user(username, password)

    if not user:
        return None, "User konnte nicht erstellt werden."

    api_patch(
        f"registration_requests?id=eq.{urllib.parse.quote(str(approved_request.get('id')))}",
        {
            "status": "used",
            "used_at": datetime.now().isoformat(),
        }
    )
    get_members.clear()
    get_leaderboard.clear()
    return user, "Registrierung abgeschlossen. Du bist jetzt angemeldet."


def delete_user(username):
    username = username.strip()

    api_delete(f"event_signups?username=eq.{urllib.parse.quote(username)}")
    api_delete(f"purchases?username=eq.{urllib.parse.quote(username)}")

    return api_delete(f"users?username=eq.{urllib.parse.quote(username)}")


def add_points(username, chickens=0, braincells=0):
    user = get_or_create_user(username)

    if user is None:
        return

    update_user(
        username,
        int(user["chickens"]) + chickens,
        int(user["braincells"]) + braincells
    )


def remove_points(username, chickens=0, braincells=0):
    user = get_or_create_user(username)

    if user is None:
        return

    new_chickens = max(0, int(user["chickens"]) - chickens)
    new_braincells = max(0, int(user["braincells"]) - braincells)

    update_user(username, new_chickens, new_braincells)

@st.cache_data(ttl=300)
def get_leaderboard():
    users = api_get("users?select=*&order=braincells.desc")

    if not users:
        return pd.DataFrame(columns=["Viewer", "Chickens", "Gehirnzellen"])

    df = pd.DataFrame(users)

    df = df.rename(columns={
        "username": "Viewer",
        "chickens": "Chickens",
        "braincells": "Gehirnzellen"
    })

    return df[["Viewer", "Chickens", "Gehirnzellen"]]


@st.cache_data(ttl=300)
def get_members():
    return api_get("users?select=*&order=braincells.desc")


def get_profile_level(points):
    return max(1, int(points) // 100 + 1)


def get_level_progress(points):
    level = get_profile_level(points)
    current_level_start = (level - 1) * 100
    next_level_start = level * 100
    current_xp = max(0, int(points) - current_level_start)
    needed_xp = next_level_start - current_level_start
    progress = int((current_xp / needed_xp) * 100) if needed_xp else 100
    return level, current_xp, needed_xp, min(100, progress), max(0, next_level_start - int(points))


def get_level_title(level):
    if level >= 50:
        return "Endgame Legende"
    if level >= 30:
        return "Gehirnzone Veteran"
    if level >= 20:
        return "Community Champion"
    if level >= 10:
        return "Stammviewer"
    if level >= 5:
        return "Aufsteiger"
    return "Frisch geschlüpft"


def get_avatar_markup(username, avatar_url, size=96):
    safe_name = html.escape(username or "?")
    initials = safe_name[:2].upper()

    if avatar_url and str(avatar_url).startswith(("http://", "https://")):
        safe_url = html.escape(str(avatar_url), quote=True)
        return f'<img class="profile-avatar" src="{safe_url}" alt="{safe_name}" style="width:{size}px;height:{size}px;">'

    return f'<div class="profile-avatar profile-initials" style="width:{size}px;height:{size}px;">{initials}</div>'


@st.cache_data(ttl=120)
def get_chicken_scores(limit=10):
    return api_get_optional(
        f"chicken_scores?select=username,score,level,created_at&order=score.desc,created_at.asc&limit={int(limit)}"
    )


@st.cache_data(ttl=120)
def get_chicken_scores_for_period(period="all", limit=10):
    filters = ""
    if period in {"week", "today"}:
        now = datetime.now(ZoneInfo("Europe/Berlin"))
        if period == "today":
            start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        else:
            start = now - timedelta(days=7)
        filters = f"&created_at=gte.{urllib.parse.quote(start.isoformat())}"

    return api_get_optional(
        "chicken_scores?select=username,score,level,created_at"
        f"{filters}&order=score.desc,created_at.asc&limit={int(limit)}"
    )


@st.cache_data(ttl=120)
def get_user_best_chicken_score(username):
    if not username:
        return None

    scores = api_get_optional(
        "chicken_scores"
        f"?select=username,score,level,created_at&username=eq.{urllib.parse.quote(username)}"
        "&order=score.desc,created_at.asc&limit=1"
    )
    return scores[0] if scores else None


def get_daily_reward_rows(username):
    if not username:
        return []

    return api_get_optional(
        "daily_rewards"
        f"?select=reward_date,created_at&username=eq.{urllib.parse.quote(username)}"
        "&order=reward_date.desc&limit=30"
    )


def get_daily_reward_state(username):
    today = datetime.now(ZoneInfo("Europe/Berlin")).date()
    rows = get_daily_reward_rows(username)
    claimed_dates = set()

    for row in rows:
        try:
            claimed_dates.add(datetime.fromisoformat(str(row.get("reward_date"))).date())
        except ValueError:
            try:
                claimed_dates.add(datetime.strptime(str(row.get("reward_date")), "%Y-%m-%d").date())
            except ValueError:
                pass

    streak = 0
    cursor = today
    while cursor in claimed_dates:
        streak += 1
        cursor = cursor - timedelta(days=1)

    return {
        "claimed_today": today in claimed_dates,
        "streak": streak,
        "today": today.isoformat(),
        "available": bool(rows) or not claimed_dates,
    }


def claim_daily_reward(username):
    if not username:
        return False, "Bitte melde dich zuerst an."

    state = get_daily_reward_state(username)
    if state["claimed_today"]:
        return False, "Du hast deinen Daily Reward heute schon abgeholt."

    reward_chickens = 250 + min(state["streak"], 7) * 50
    reward_braincells = 25

    created = api_post_optional(
        "daily_rewards",
        {
            "username": username,
            "reward_date": state["today"],
            "chickens": reward_chickens,
            "braincells": reward_braincells,
            "created_at": datetime.now(ZoneInfo("Europe/Berlin")).isoformat()
        }
    )

    if not created:
        return False, "Daily-Rewards-Tabelle fehlt wahrscheinlich noch in Supabase."

    add_points(username, chickens=reward_chickens, braincells=reward_braincells)
    get_members.clear()
    get_leaderboard.clear()
    get_chicken_scores.clear()
    return True, f"Daily Reward abgeholt: +{reward_chickens} Chickens und +{reward_braincells} Gehirnzellen."


@st.cache_data(ttl=120)
def get_creative_gallery(limit=30):
    return api_get_optional(
        "creative_gallery"
        f"?select=*&order=created_at.desc&limit={int(limit)}"
    )


@st.cache_data(ttl=120)
def get_creative_gallery_reactions():
    return api_get_optional(
        "creative_gallery_reactions"
        "?select=art_id,username,emoji,created_at&order=created_at.desc&limit=1000"
    )


def format_gallery_timestamp(value):
    if not value:
        return ""

    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=ZoneInfo("UTC"))
        local_time = parsed.astimezone(ZoneInfo("Europe/Berlin"))
        return local_time.strftime("%d.%m.%Y um %H:%M Uhr")
    except ValueError:
        return str(value)


def summarize_gallery_reactions(reactions):
    summary = {}
    for reaction in reactions:
        art_id = str(reaction.get("art_id") or "")
        emoji = str(reaction.get("emoji") or "")
        if not art_id or not emoji:
            continue
        summary.setdefault(art_id, {})
        summary[art_id][emoji] = summary[art_id].get(emoji, 0) + 1
    return summary


def get_user_gallery_reactions(reactions, username):
    if not username:
        return {}
    user_reactions = {}
    for reaction in reactions:
        if str(reaction.get("username") or "") == username:
            user_reactions[str(reaction.get("art_id") or "")] = str(reaction.get("emoji") or "")
    return user_reactions


def get_creative_image_of_week(gallery_items, reactions):
    if not gallery_items:
        return None

    now = datetime.now(ZoneInfo("Europe/Berlin"))
    week_start = (now - timedelta(days=now.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
    weekly_scores = {}

    for reaction in reactions:
        try:
            created_at = datetime.fromisoformat(str(reaction.get("created_at") or "").replace("Z", "+00:00"))
            if created_at.tzinfo is None:
                created_at = created_at.replace(tzinfo=ZoneInfo("UTC"))
            created_at = created_at.astimezone(ZoneInfo("Europe/Berlin"))
        except ValueError:
            continue
        if created_at >= week_start:
            art_id = str(reaction.get("art_id") or "")
            weekly_scores[art_id] = weekly_scores.get(art_id, 0) + 1

    if weekly_scores:
        return max(
            gallery_items,
            key=lambda item: (
                weekly_scores.get(str(item.get("id") or ""), 0),
                str(item.get("created_at") or ""),
            ),
        )

    return gallery_items[0]


def get_user_creative_art(username: str) -> Optional[dict]:
    username = username.strip()
    if not username:
        return None

    rows = api_get_optional(
        "creative_gallery"
        f"?select=*&username=eq.{urllib.parse.quote(username)}&order=created_at.desc&limit=1"
    )
    return rows[0] if rows else None


def canvas_image_to_data_uri(image_data):
    if image_data is None:
        return None

    has_ink = bool((image_data[:, :, :3] != 255).any())
    if not has_ink:
        return None

    image = Image.fromarray(image_data.astype("uint8"), mode="RGBA")
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    encoded = base64.b64encode(buffer.getvalue()).decode("ascii")
    return f"data:image/png;base64,{encoded}"


def uploaded_image_to_data_uri(uploaded_file, max_size=(1600, 1200)):
    if uploaded_file is None:
        return ""

    image = Image.open(uploaded_file)
    image.thumbnail(max_size)
    if image.mode not in ("RGB", "RGBA"):
        image = image.convert("RGB")

    buffer = io.BytesIO()
    image_format = "PNG" if image.mode == "RGBA" else "JPEG"
    save_kwargs = {"format": image_format}
    if image_format == "JPEG":
        save_kwargs["quality"] = 86
    image.save(buffer, **save_kwargs)
    encoded = base64.b64encode(buffer.getvalue()).decode("ascii")
    mime = "image/png" if image_format == "PNG" else "image/jpeg"
    return f"data:{mime};base64,{encoded}"


def create_creative_art(username, title, image_data_uri):
    username = username.strip()
    clean_title = title.strip()[:80]

    if get_user_creative_art(username):
        return False, "Du hast bereits ein Bild in der Hall of Fame."

    created = api_post_optional(
        "creative_gallery",
        {
            "id": str(uuid.uuid4()),
            "username": username,
            "title": clean_title,
            "image_data": image_data_uri,
            "created_at": datetime.now().isoformat(),
        }
    )

    if created:
        get_creative_gallery.clear()
        return True, "Dein Bild ist jetzt in der Hall of Fame."
    return False, "Bild konnte nicht gespeichert werden. Führe add_creative_gallery_table.sql in Supabase aus."


def set_creative_gallery_reaction(art_id, username, emoji):
    if not art_id or not username or emoji not in ["😍", "😂", "🔥", "💜", "👏"]:
        return False

    created = api_upsert_optional(
        "creative_gallery_reactions?on_conflict=art_id,username",
        {
            "art_id": str(art_id),
            "username": username.strip(),
            "emoji": emoji,
            "created_at": datetime.now(ZoneInfo("Europe/Berlin")).isoformat(),
        }
    )
    if created:
        get_creative_gallery_reactions.clear()
        return True
    return False


def delete_creative_art(art_id):
    success = api_delete(f"creative_gallery?id=eq.{urllib.parse.quote(str(art_id))}")
    if success:
        get_creative_gallery.clear()
        get_creative_gallery_reactions.clear()
    return success


def render_creative_gallery(limit=60):
    gallery_items = get_creative_gallery(limit)
    if not gallery_items:
        st.info("Noch keine Bilder in der Hall of Fame.")
        return

    reactions = get_creative_gallery_reactions()
    reaction_summary = summarize_gallery_reactions(reactions)
    user_reactions = get_user_gallery_reactions(reactions, get_logged_in_username())
    reaction_emojis = ["😍", "😂", "🔥", "💜", "👏"]
    gallery_notice = None

    for row_start in range(0, len(gallery_items), 3):
        columns = st.columns(3)
        for column, item in zip(columns, gallery_items[row_start:row_start + 3]):
            art_id = str(item.get("id") or "")
            title = str(item.get("title") or "").strip()
            username = html.escape(str(item.get("username") or "Unbekannt"))
            created_at = html.escape(format_gallery_timestamp(item.get("created_at")))
            image_data = str(item.get("image_data") or "")
            title_html = f"<h3>{html.escape(title)}</h3>" if title else ""
            counts = reaction_summary.get(art_id, {})
            selected_emoji = user_reactions.get(art_id)
            reaction_text = " ".join(
                f'<span class="creative-reaction-count {"active" if selected_emoji == emoji else ""}">{emoji} {counts.get(emoji, 0)}</span>'
                for emoji in reaction_emojis
            )
            with column:
                selector_key = f"show_reactions_{art_id}"
                image_html = (
                    f'<img src="{html.escape(image_data, quote=True)}" alt="{html.escape(title or "Hall of Fame Bild", quote=True)}">'
                    if image_data else ""
                )
                st.markdown(
                    '<article class="creative-art-card">'
                    f'{image_html}'
                    f'{title_html}'
                    f'<span>von {username}</span>'
                    f'<span class="creative-date">{created_at}</span>'
                    f'<div class="creative-reaction-row">{reaction_text}</div>'
                    '</article>',
                    unsafe_allow_html=True,
                )
                if st.button("Reaktion", key=f"toggle_reactions_{art_id}", use_container_width=True):
                    st.session_state[selector_key] = not st.session_state.get(selector_key, False)

                if st.session_state.get(selector_key, False):
                    st.markdown('<div class="creative-reaction-picker">', unsafe_allow_html=True)
                    button_cols = st.columns(len(reaction_emojis))
                    for button_col, emoji in zip(button_cols, reaction_emojis):
                        with button_col:
                            if st.button(emoji, key=f"react_{art_id}_{emoji}", use_container_width=True):
                                current_user = get_logged_in_username()
                                if not current_user:
                                    gallery_notice = "Bitte melde dich an, um auf Bilder zu reagieren."
                                elif set_creative_gallery_reaction(art_id, current_user, emoji):
                                    st.session_state[selector_key] = False
                                    st.rerun()
                                else:
                                    gallery_notice = "Reaktionen sind noch nicht aktiviert. Ein Admin muss die Supabase-Migration für Hall-of-Fame-Reaktionen einmal ausführen."
                    st.markdown('</div>', unsafe_allow_html=True)

    if gallery_notice:
        st.warning(gallery_notice)


def render_auto_gazette(members, recent_purchases, scores, creative_items):
    top_member = max(members, key=lambda member: int(member.get("braincells") or 0), default=None)
    richest_member = max(members, key=lambda member: int(member.get("chickens") or 0), default=None)
    latest_purchase = recent_purchases[0] if recent_purchases else None
    top_score = scores[0] if scores else None
    latest_art = creative_items[0] if creative_items else None

    cards = [
        (
            "Top Viewer",
            str(top_member.get("username") or "Noch niemand") if top_member else "Noch niemand",
            f'{int(top_member.get("braincells") or 0)} Gehirnzellen' if top_member else "Warte auf den ersten Eintrag",
        ),
        (
            "Chicken Konto",
            str(richest_member.get("username") or "Noch niemand") if richest_member else "Noch niemand",
            f'{int(richest_member.get("chickens") or 0)} Chickens' if richest_member else "Noch kein Vermoegen",
        ),
        (
            "Shop-Ticker",
            str(latest_purchase.get("reward_name") or "Noch kein Kauf") if latest_purchase else "Noch kein Kauf",
            f'von {latest_purchase.get("username")}' if latest_purchase else "Sobald jemand kauft, steht es hier",
        ),
        (
            "Chicken Jump",
            f'{top_score.get("username")} - {int(top_score.get("score") or 0)}' if top_score else "Noch kein Score",
            "Aktueller Topscore" if top_score else "Scoreboard wartet",
        ),
        (
            "Hall of Fame",
            str(latest_art.get("title") or "Neues Kunstwerk") if latest_art else "Noch kein Bild",
            f'von {latest_art.get("username")}' if latest_art else "Kreativwand ist bereit",
        ),
    ]

    card_html = ""
    for label, title, detail in cards:
        card_html += (
            '<article class="gazette-card">'
            f'<div class="newspaper-label">{html.escape(label)}</div>'
            f'<h3>{html.escape(title)}</h3>'
            f'<p>{html.escape(detail)}</p>'
            '</article>'
        )

    st.markdown(
        '<div class="gazette-live">'
        '<div>'
        '<div class="section-kicker">Automatische Ausgabe</div>'
        '<h2>Stream-Ticker</h2>'
        '<p>Aktuelle Highlights aus Community, Shop, Minigames und Hall of Fame.</p>'
        '</div>'
        f'<div class="gazette-card-grid">{card_html}</div>'
        '</div>',
        unsafe_allow_html=True,
    )


def render_dnd_page():
    logged_in_username = get_logged_in_username()

    st.markdown('<div class="section-kicker">Tabletop Lobby</div>', unsafe_allow_html=True)
    st.markdown("## Dungeons and Dragons")
    st.markdown("""
    <div class="dnd-hero">
        <div>
            <div class="section-kicker">Abenteuerbrett</div>
            <h2>Ein Spieltisch für Party, Szene und Würfel</h2>
            <p>Lobbys, Charakterbögen, Kreaturen, Questlog und Wurfchronik sind jetzt wie ein Session-Dashboard aufgebaut: oben die Runde, darunter die Werkzeuge.</p>
        </div>
        <div class="dnd-rule-grid">
            <div class="dnd-panel"><div class="dnd-pill">Session</div><p>Szene und Questlog bleiben sichtbar, ohne den Rest zu überladen.</p></div>
            <div class="dnd-panel"><div class="dnd-pill">Party</div><p>HP, AC, Initiative und Attribute direkt als scanbare Karten.</p></div>
            <div class="dnd-panel"><div class="dnd-pill">Würfel</div><p>d4 bis d100, Vorteil, Nachteil und Chronik für die ganze Runde.</p></div>
        </div>
    </div>
    """, unsafe_allow_html=True)

    if not logged_in_username:
        st.warning("Bitte melde dich zuerst an, um Lobbys zu erstellen oder beizutreten.")
        if st.button("Zum Login", key="dnd_login_cta", use_container_width=True):
            st.session_state["app_menu"] = "🔑 Login"
            st.rerun()
        st.stop()

    create_col, lobby_col = st.columns([0.8, 1.2])

    with create_col:
        st.markdown("### Lobby eröffnen")
        with st.form("create_dnd_lobby_form"):
            lobby_name = st.text_input("Lobby-Name", max_chars=80, placeholder="Die Mine der verlorenen Chickens")
            lobby_description = st.text_area(
                "Beschreibung",
                max_chars=500,
                height=120,
                placeholder="Kurzer Pitch, Levelbereich, Stimmung oder wer Spielleitung macht..."
            )
            lobby_password = st.text_input("Passwort optional", type="password", help="Leer lassen für eine offene Lobby.")
            creator_role_label = st.radio(
                "Deine Rolle",
                ["Dungeon Master", "Spieler"],
                horizontal=True,
                key="dnd_create_role",
            )
            creator_character_name = ""
            creator_character_class = DND_CLASSES[0]
            if creator_role_label == "Spieler":
                creator_cols = st.columns(2)
                with creator_cols[0]:
                    creator_character_name = st.text_input("Dein Charaktername", max_chars=80, placeholder="Marello der Mutige")
                with creator_cols[1]:
                    creator_character_class = st.selectbox("Deine Klasse", DND_CLASSES, key="dnd_create_character_class")
            create_lobby = st.form_submit_button("Lobby eröffnen")

        if create_lobby:
            created_lobby = create_dnd_lobby(
                lobby_name,
                lobby_description,
                logged_in_username,
                lobby_password,
                "dm" if creator_role_label == "Dungeon Master" else "player",
                creator_character_name,
                creator_character_class,
            )
            if created_lobby:
                st.session_state["dnd_lobby_id"] = str(created_lobby.get("id"))
                st.success("Lobby eröffnet.")
                st.rerun()
            else:
                detail = st.session_state.pop("dnd_last_create_error", "")
                if detail:
                    st.error(f"Lobby konnte nicht erstellt werden: {detail}")
                else:
                    st.error("Lobby konnte nicht erstellt werden. Führe add_dnd_tables.sql in Supabase aus.")

    with lobby_col:
        st.markdown("### Aktive Lobbys")
        lobbies = get_dnd_lobbies()
        if not lobbies:
            st.info("Noch keine DnD-Lobby offen.")
        else:
            lobby_cards = ""
            for lobby in lobbies:
                status_class = "private" if lobby.get("is_private") else ""
                status_text = "Geschlossen" if lobby.get("is_private") else "Offen"
                dm_name = get_dnd_dm_username(lobby)
                dm_text = dm_name if dm_name else "Wartet auf DM"
                lobby_cards += (
                    '<article class="dnd-lobby-card">'
                    f'<span class="dnd-pill {status_class}">{status_text}</span>'
                    f'<h3>{html.escape(str(lobby.get("name") or "Unbenannte Lobby"))}</h3>'
                    f'<p>{html.escape(str(lobby.get("description") or "Kein Beschreibungstext."))}</p>'
                    f'<div class="admin-muted">DM: {html.escape(dm_text)} · Erstellt von {html.escape(str(lobby.get("owner") or "Unbekannt"))}</div>'
                    '</article>'
                )
            st.markdown(f'<div class="dnd-lobby-grid">{lobby_cards}</div>', unsafe_allow_html=True)

    lobbies = get_dnd_lobbies()
    if lobbies:
        st.markdown('<div class="dnd-section-title"><h3>Lobby beitreten</h3><span class="admin-muted">Charakter wählen und direkt an den Tisch</span></div>', unsafe_allow_html=True)
        selected_lobby_id = st.selectbox(
            "Lobby auswählen",
            [str(lobby.get("id")) for lobby in lobbies],
            format_func=lambda lobby_id: next(
                (str(lobby.get("name") or "Unbenannte Lobby") for lobby in lobbies if str(lobby.get("id")) == str(lobby_id)),
                "Lobby",
            ),
            key="dnd_lobby_select",
        )
        selected_lobby = get_dnd_lobby(selected_lobby_id)
        selected_dm_username = get_dnd_dm_username(selected_lobby) if selected_lobby else ""

        with st.form("join_dnd_lobby_form"):
            if selected_dm_username:
                st.caption(f"Dungeon Master ist bereits gesetzt: {selected_dm_username}. Neue Beitritte sind Spieler.")
                join_role_label = "Spieler"
            else:
                join_role_label = st.radio(
                    "Deine Rolle",
                    ["Dungeon Master", "Spieler"],
                    horizontal=True,
                    key="dnd_join_role",
                )
            join_cols = st.columns([1, 1, 1, 1])
            with join_cols[0]:
                character_name = st.text_input(
                    "Charaktername",
                    max_chars=80,
                    placeholder="Marello der Mutige",
                    disabled=join_role_label == "Dungeon Master",
                )
            with join_cols[1]:
                character_class = st.selectbox("Klasse", DND_CLASSES, disabled=join_role_label == "Dungeon Master")
            with join_cols[2]:
                join_password = st.text_input("Lobby-Passwort", type="password")
            with join_cols[3]:
                st.write("")
                st.write("")
                join_lobby = st.form_submit_button("Beitreten")

        if join_lobby:
            success, message = join_dnd_lobby(
                selected_lobby,
                logged_in_username,
                character_name,
                character_class,
                join_password,
                "dm" if join_role_label == "Dungeon Master" else "player",
            )
            if success:
                st.success(message)
                st.rerun()
            else:
                st.error(message)

    active_lobby_id = st.session_state.get("dnd_lobby_id")
    active_lobby = get_dnd_lobby(active_lobby_id) if active_lobby_id else None

    if active_lobby:
        players = get_dnd_players(active_lobby_id)
        creatures = get_dnd_creatures(active_lobby_id)
        current_player = next(
            (player for player in players if str(player.get("username")) == str(logged_in_username)),
            None,
        )
        dm_username = get_dnd_dm_username(active_lobby)
        is_dnd_dm = bool(dm_username) and dm_username == logged_in_username
        is_lobby_owner = str(active_lobby.get("owner") or "") == str(logged_in_username)

        scene_text = str(active_lobby.get("scene") or "Die Party steht am Rand eines unbekannten Ortes. Der Dungeon Master kann hier die Szene setzen.")
        quest_text = str(active_lobby.get("quest_log") or "Noch keine Quest aktiv.")
        initiative_entries = build_dnd_initiative(players, creatures)
        active_turn_key = str(active_lobby.get("active_turn_key") or "")
        if not active_turn_key and initiative_entries:
            active_turn_key = initiative_entries[0]["key"]
        round_number = max(1, int(active_lobby.get("round_number") or 1))
        dnd_logs = get_dnd_logs(active_lobby_id)
        dnd_maps = get_dnd_maps(active_lobby_id)
        last_roll = st.session_state.get("dnd_last_roll")
        last_roll_total = "-"
        if last_roll and str(last_roll.get("lobby_id")) == str(active_lobby_id):
            last_roll_total = str(int(last_roll.get("total") or 0))

        st.markdown(
            '<div class="dnd-session-bar">'
            '<div class="dnd-session-title">'
            '<div class="section-kicker">Aktive Runde</div>'
            f'<h3>{html.escape(str(active_lobby.get("name") or "Unbenannte Lobby"))}</h3>'
            f'<div class="admin-muted">DM: {html.escape(dm_username or "Noch offen")} · Deine Rolle: {html.escape("Dungeon Master" if is_dnd_dm else "Spieler" if current_player else "Zuschauer")}</div>'
            '</div>'
            f'<div class="dnd-session-stat"><strong>{len(players)}</strong><span>Charaktere</span></div>'
            f'<div class="dnd-session-stat"><strong>{len(creatures)}</strong><span>Kreaturen</span></div>'
            f'<div class="dnd-session-stat"><strong>{round_number}</strong><span>Runde</span></div>'
            f'<div class="dnd-session-stat"><strong>{html.escape(last_roll_total)}</strong><span>Letzter Wurf</span></div>'
            '</div>',
            unsafe_allow_html=True,
        )

        st.markdown(
            '<div class="dnd-hero">'
            '<div>'
            '<div class="section-kicker">Aktuelle Szene</div>'
            f'<h2>{html.escape(scene_text[:120])}</h2>'
            f'<p>{html.escape(scene_text)}</p>'
            '</div>'
            '<div class="dnd-panel">'
            '<div class="dnd-pill">Questlog</div>'
            f'<p>{html.escape(quest_text)}</p>'
            '</div>'
            '</div>',
            unsafe_allow_html=True,
        )

        if is_dnd_dm:
            st.markdown('<div class="dnd-section-title"><h3>DM Bereich</h3><span class="admin-muted">Szene, Questlog und Kreaturen steuern</span></div>', unsafe_allow_html=True)
            with st.expander("Dungeon Master Bereich"):
                with st.form("dnd_dm_notes_form"):
                    new_scene = st.text_area("Aktuelle Szene", value=scene_text, height=140, max_chars=1200)
                    new_quest = st.text_area("Questlog", value=quest_text, height=120, max_chars=1200)
                    if st.form_submit_button("Szene speichern"):
                        if update_dnd_lobby_notes(active_lobby_id, new_scene, new_quest):
                            st.success("Szene aktualisiert.")
                            st.rerun()
                        else:
                            st.error("Szene konnte nicht gespeichert werden. Führe die aktualisierte add_dnd_tables.sql aus.")

                st.markdown("##### Premade Maps")
                map_preview_html = ""
                for preset_name, preset_map in DND_PRESET_MAPS.items():
                    map_preview_html += (
                        '<div class="dnd-premade-map">'
                        f'<div class="dnd-premade-thumb" style="background-image:url(&quot;{html.escape(preset_map["image"], quote=True)}&quot;);"></div>'
                        f'<strong>{html.escape(preset_name)}</strong>'
                        f'<span>{int(preset_map["grid_width"])}x{int(preset_map["grid_height"])} Grid</span>'
                        '</div>'
                    )
                st.markdown(f'<div class="dnd-premade-grid">{map_preview_html}</div>', unsafe_allow_html=True)
                premade_cols = st.columns(3)
                for premade_col, preset_name in zip(premade_cols, DND_PRESET_MAPS.keys()):
                    with premade_col:
                        if st.button(f"{preset_name} laden", key=f"dnd_apply_builtin_{preset_name}", use_container_width=True):
                            preset_map = DND_PRESET_MAPS[preset_name]
                            map_ok = update_dnd_lobby_map(active_lobby_id, preset_map["image"], preset_map["grid_width"], preset_map["grid_height"])
                            tools_ok = update_dnd_lobby_board_tools(
                                active_lobby_id,
                                False,
                                0,
                                preset_map["marker_notes"],
                                preset_map["name"],
                            )
                            if map_ok and tools_ok:
                                st.success(f"{preset_name} geladen.")
                                st.rerun()
                            else:
                                st.error("Premade Map konnte nicht geladen werden.")

                st.markdown("##### Spielbrett bearbeiten")
                with st.form("dnd_map_form"):
                    map_name = st.text_input("Kartenname", value=str(active_lobby.get("map_name") or "Karte"), max_chars=80)
                    preset_map_name = st.selectbox(
                        "Premade Map",
                        ["Eigene Karte", "Dungeon", "Wald", "Strand"],
                        key="dnd_builtin_map_select",
                    )
                    current_map_url = str(active_lobby.get("map_image_url") or "")
                    map_url = st.text_input(
                        "Battlemap Bild-URL",
                        value=current_map_url if current_map_url.startswith(("http://", "https://")) else "",
                        placeholder="https://... oder Bild hochladen",
                    )
                    uploaded_map = st.file_uploader("Bild hochladen", type=["png", "jpg", "jpeg", "webp"], key="dnd_map_upload")
                    map_cols = st.columns(2)
                    with map_cols[0]:
                        grid_width = st.number_input("Grid Breite", min_value=4, max_value=40, value=int(active_lobby.get("map_grid_width") or 12), step=1)
                    with map_cols[1]:
                        grid_height = st.number_input("Grid Höhe", min_value=4, max_value=30, value=int(active_lobby.get("map_grid_height") or 8), step=1)
                    fog_enabled = st.checkbox("Fog of War aktivieren", value=bool(active_lobby.get("map_fog_enabled")))
                    fog_opacity = st.slider("Fog-Stärke", min_value=0, max_value=95, value=int(active_lobby.get("map_fog_opacity") or 55), step=5)
                    marker_notes = st.text_area(
                        "Marker / Notizen auf der Karte",
                        value=str(active_lobby.get("map_marker_notes") or ""),
                        height=90,
                        max_chars=1200,
                        placeholder="Eine Notiz pro Zeile, z.B. Tür, Falle, Schatz, Questziel...",
                    )
                    if st.form_submit_button("Spielbrett speichern"):
                        if preset_map_name in DND_PRESET_MAPS:
                            preset_map = DND_PRESET_MAPS[preset_map_name]
                            final_map_url = preset_map["image"]
                            final_grid_width = preset_map["grid_width"]
                            final_grid_height = preset_map["grid_height"]
                            final_marker_notes = marker_notes or preset_map["marker_notes"]
                            final_map_name = preset_map["name"]
                        else:
                            final_map_url = uploaded_image_to_data_uri(uploaded_map) if uploaded_map else map_url
                            final_grid_width = grid_width
                            final_grid_height = grid_height
                            final_marker_notes = marker_notes
                            final_map_name = map_name
                        map_ok = update_dnd_lobby_map(active_lobby_id, final_map_url, final_grid_width, final_grid_height)
                        tools_ok = update_dnd_lobby_board_tools(active_lobby_id, fog_enabled, fog_opacity, final_marker_notes, final_map_name)
                        if map_ok and tools_ok:
                            st.success("Spielbrett aktualisiert.")
                            st.rerun()
                        else:
                            st.error("Spielbrett konnte nicht gespeichert werden. Führe die aktualisierte add_dnd_tables.sql aus.")

                st.markdown("##### Map-Vorlagen")
                preset_cols = st.columns(2)
                with preset_cols[0]:
                    if st.button("Aktuelle Karte als Vorlage speichern", key="dnd_save_map_preset", use_container_width=True):
                        if save_dnd_map_preset(
                            active_lobby_id,
                            active_lobby.get("map_name") or "Karte",
                            active_lobby.get("map_image_url") or "",
                            active_lobby.get("map_grid_width") or 12,
                            active_lobby.get("map_grid_height") or 8,
                            active_lobby.get("map_marker_notes") or "",
                        ):
                            st.success("Map-Vorlage gespeichert.")
                            st.rerun()
                        else:
                            st.error("Map-Vorlage konnte nicht gespeichert werden.")
                with preset_cols[1]:
                    if dnd_maps:
                        selected_map_id = st.selectbox(
                            "Vorlage laden",
                            [str(row.get("id")) for row in dnd_maps],
                            format_func=lambda map_id: next((str(row.get("name") or "Karte") for row in dnd_maps if str(row.get("id")) == str(map_id)), "Karte"),
                            key="dnd_map_preset_select",
                        )
                        if st.button("Vorlage anwenden", key="dnd_apply_map_preset", use_container_width=True):
                            preset = next((row for row in dnd_maps if str(row.get("id")) == str(selected_map_id)), None)
                            if preset and apply_dnd_map_preset(active_lobby_id, preset):
                                st.success("Map-Vorlage geladen.")
                                st.rerun()
                            else:
                                st.error("Map-Vorlage konnte nicht geladen werden.")
                    else:
                        st.caption("Noch keine Map-Vorlagen.")

                st.markdown("##### Kreatur erstellen")
                with st.form("dnd_create_creature_form"):
                    creature_cols = st.columns([1.2, 1, 0.7, 0.7, 0.7])
                    with creature_cols[0]:
                        creature_name = st.text_input("Name", max_chars=80, placeholder="Goblin-Hauptmann")
                    with creature_cols[1]:
                        creature_type = st.text_input("Typ", max_chars=80, placeholder="Humanoid, Untoter, Drache...")
                    with creature_cols[2]:
                        creature_hp = st.number_input("HP", min_value=1, max_value=999, value=12, step=1)
                    with creature_cols[3]:
                        creature_ac = st.number_input("AC", min_value=1, max_value=40, value=13, step=1)
                    with creature_cols[4]:
                        creature_init = st.number_input("Initiative", min_value=-20, max_value=30, value=0, step=1)
                    creature_notes = st.text_area("Notizen/Fähigkeiten", max_chars=500, height=90, placeholder="Angriff, Besonderheiten, Verhalten...")
                    if st.form_submit_button("Kreatur hinzufügen"):
                        if create_dnd_creature(active_lobby_id, creature_name, creature_type, creature_hp, creature_ac, creature_init, creature_notes):
                            st.success("Kreatur erstellt.")
                            st.rerun()
                        else:
                            st.error("Kreatur konnte nicht erstellt werden. Führe die aktualisierte add_dnd_tables.sql aus.")

        st.markdown('<div class="dnd-section-title"><h3>Spielbrett</h3><span class="admin-muted">Tokens auf dem Raster platzieren</span></div>', unsafe_allow_html=True)
        st.markdown(render_dnd_battlemap(active_lobby, players, creatures), unsafe_allow_html=True)

        st.markdown('<div class="dnd-section-title"><h3>Initiative</h3><span class="admin-muted">Turn-Reihenfolge und aktueller Zug</span></div>', unsafe_allow_html=True)
        st.markdown(render_dnd_initiative_tracker(initiative_entries, active_turn_key), unsafe_allow_html=True)
        if is_dnd_dm and initiative_entries:
            turn_cols = st.columns([1, 1, 1])
            current_index = next((index for index, entry in enumerate(initiative_entries) if entry["key"] == active_turn_key), 0)
            with turn_cols[0]:
                selected_turn = st.selectbox(
                    "Aktiver Zug",
                    [entry["key"] for entry in initiative_entries],
                    index=current_index,
                    format_func=lambda key: next((entry["name"] for entry in initiative_entries if entry["key"] == key), key),
                )
                if st.button("Zug setzen", key="dnd_set_turn", use_container_width=True):
                    if set_dnd_turn(active_lobby_id, selected_turn, round_number):
                        st.rerun()
            with turn_cols[1]:
                if st.button("Nächster Zug", key="dnd_next_turn", use_container_width=True):
                    next_index = (current_index + 1) % len(initiative_entries)
                    next_round = round_number + 1 if next_index == 0 else round_number
                    if set_dnd_turn(active_lobby_id, initiative_entries[next_index]["key"], next_round):
                        st.rerun()
            with turn_cols[2]:
                new_round = st.number_input("Runde", min_value=1, max_value=999, value=round_number, step=1)
                if st.button("Runde speichern", key="dnd_save_round", use_container_width=True):
                    if set_dnd_turn(active_lobby_id, active_turn_key, new_round):
                        st.rerun()

        if is_dnd_dm:
            with st.expander("DM: Tokens und HP steuern", expanded=False):
                grid_width = max(4, min(int(active_lobby.get("map_grid_width") or 12), 40))
                grid_height = max(4, min(int(active_lobby.get("map_grid_height") or 8), 30))
                token_options = [f"player:{player.get('id')}" for player in players] + [f"creature:{creature.get('id')}" for creature in creatures]
                if token_options:
                    selected_token = st.selectbox(
                        "Figur auswählen",
                        token_options,
                        format_func=lambda key: (
                            next((f"Spieler: {player.get('character_name')}" for player in players if key == f"player:{player.get('id')}"), None)
                            or next((f"Kreatur: {creature.get('name')}" for creature in creatures if key == f"creature:{creature.get('id')}"), key)
                        ),
                    )
                    selected_entity = None
                    selected_type, selected_id = selected_token.split(":", 1)
                    if selected_type == "player":
                        selected_entity = next((player for player in players if str(player.get("id")) == selected_id), None)
                    else:
                        selected_entity = next((creature for creature in creatures if str(creature.get("id")) == selected_id), None)
                    if selected_entity:
                        with st.form("dnd_dm_token_move_form"):
                            move_cols = st.columns([1, 1, 1])
                            with move_cols[0]:
                                move_x = st.number_input("X", min_value=1, max_value=grid_width, value=max(1, min(int(selected_entity.get("token_x") or 1), grid_width)), step=1)
                            with move_cols[1]:
                                move_y = st.number_input("Y", min_value=1, max_value=grid_height, value=max(1, min(int(selected_entity.get("token_y") or 1), grid_height)), step=1)
                            with move_cols[2]:
                                move_color = st.color_picker("Farbe", value=str(selected_entity.get("token_color") or ("#ff54a0" if selected_type == "creature" else "#7CFFB2")))
                            if st.form_submit_button("Token bewegen"):
                                ok = (
                                    update_dnd_player_token(selected_entity.get("id"), move_x, move_y, move_color)
                                    if selected_type == "player"
                                    else update_dnd_creature_token(selected_entity.get("id"), move_x, move_y, move_color)
                                )
                                if ok:
                                    st.success("Token aktualisiert.")
                                    st.rerun()
                                else:
                                    st.error("Token konnte nicht gespeichert werden.")

                hp_targets = [f"player:{player.get('id')}" for player in players] + [f"creature:{creature.get('id')}" for creature in creatures]
                if hp_targets:
                    hp_target = st.selectbox(
                        "HP Ziel",
                        hp_targets,
                        format_func=lambda key: (
                            next((f"Spieler: {player.get('character_name')}" for player in players if key == f"player:{player.get('id')}"), None)
                            or next((f"Kreatur: {creature.get('name')}" for creature in creatures if key == f"creature:{creature.get('id')}"), key)
                        ),
                        key="dnd_hp_target",
                    )
                    hp_type, hp_id = hp_target.split(":", 1)
                    hp_entity = next((row for row in (players if hp_type == "player" else creatures) if str(row.get("id")) == hp_id), None)
                    if hp_entity:
                        hp_cols = st.columns(4)
                        for hp_col, delta, label in zip(hp_cols, [-5, -1, 1, 5], ["-5", "-1", "+1", "+5"]):
                            with hp_col:
                                if st.button(label, key=f"dnd_hp_{hp_target}_{label}", use_container_width=True):
                                    ok = adjust_dnd_player_hp(hp_entity, delta) if hp_type == "player" else adjust_dnd_creature_hp(hp_entity, delta)
                                    if ok:
                                        create_dnd_log(active_lobby_id, logged_in_username, "HP", f"{hp_entity.get('character_name') or hp_entity.get('name')} {label} HP")
                                        st.rerun()

        party_html = ""
        for player in players:
            max_hp = max(1, int(player.get("max_hp") or 10))
            current_hp = max(0, int(player.get("current_hp") or max_hp))
            hp_percent = min(100, int((current_hp / max_hp) * 100))
            armor_class = int(player.get("armor_class") or 10)
            initiative = int(player.get("initiative") or 0)
            str_mod = format_modifier(ability_modifier(int(player.get("strength") or 10)))
            dex_mod = format_modifier(ability_modifier(int(player.get("dexterity") or 10)))
            con_mod = format_modifier(ability_modifier(int(player.get("constitution") or 10)))
            int_mod = format_modifier(ability_modifier(int(player.get("intelligence") or 10)))
            wis_mod = format_modifier(ability_modifier(int(player.get("wisdom") or 10)))
            cha_mod = format_modifier(ability_modifier(int(player.get("charisma") or 10)))
            party_html += (
                '<div class="dnd-panel dnd-character-card">'
                f'<div class="dnd-pill">{html.escape(str(player.get("character_class") or "Abenteurer"))}</div>'
                f'<h3>{html.escape(str(player.get("character_name") or "Unbekannt"))}</h3>'
                f'<p>{html.escape(str(player.get("race") or "Mensch"))} · Level {int(player.get("level") or 1)} · {html.escape(str(player.get("username") or ""))}</p>'
                '<div class="profile-progress-track">'
                f'<div class="profile-progress-fill" style="width:{hp_percent}%;"></div>'
                '</div>'
                f'<div class="admin-muted">HP {current_hp}/{max_hp} · AC {armor_class} · Initiative {initiative:+d}</div>'
                '<div class="dnd-stat-row">'
                f'<div class="dnd-stat"><strong>{str_mod}</strong><span>STR</span></div>'
                f'<div class="dnd-stat"><strong>{dex_mod}</strong><span>DEX</span></div>'
                f'<div class="dnd-stat"><strong>{con_mod}</strong><span>CON</span></div>'
                f'<div class="dnd-stat"><strong>{int_mod}</strong><span>INT</span></div>'
                f'<div class="dnd-stat"><strong>{wis_mod}</strong><span>WIS</span></div>'
                f'<div class="dnd-stat"><strong>{cha_mod}</strong><span>CHA</span></div>'
                '</div>'
                '<div class="dnd-sheet-notes">'
                f'<span><b>Inventar:</b> {html.escape(str(player.get("inventory") or "Leer"))}</span>'
                f'<span><b>Zauber:</b> {html.escape(str(player.get("spells") or "Keine"))}</span>'
                '</div>'
                '</div>'
            )
        st.markdown('<div class="dnd-section-title"><h3>Charaktere</h3><span class="admin-muted">Party-Status auf einen Blick</span></div>', unsafe_allow_html=True)
        if not party_html:
            party_html = '<div class="dnd-panel"><p>Noch keine Party.</p></div>'
        st.markdown(f'<div class="dnd-party-grid">{party_html}</div>', unsafe_allow_html=True)

        if creatures:
            creature_html = ""
            for creature in creatures:
                max_hp = max(1, int(creature.get("max_hp") or 1))
                current_hp = max(0, int(creature.get("current_hp") or max_hp))
                hp_percent = min(100, int((current_hp / max_hp) * 100))
                creature_html += (
                    '<div class="dnd-panel dnd-creature-card">'
                    f'<div class="dnd-pill private">{html.escape(str(creature.get("creature_type") or "Kreatur"))}</div>'
                    f'<h3>{html.escape(str(creature.get("name") or "Kreatur"))}</h3>'
                    '<div class="profile-progress-track">'
                    f'<div class="profile-progress-fill" style="width:{hp_percent}%;"></div>'
                    '</div>'
                    f'<div class="admin-muted">HP {current_hp}/{max_hp} · AC {int(creature.get("armor_class") or 10)} · Initiative {int(creature.get("initiative") or 0):+d}</div>'
                    f'<p>{html.escape(str(creature.get("notes") or ""))}</p>'
                    '</div>'
                )
            st.markdown('<div class="dnd-section-title"><h3>Kreaturen</h3><span class="admin-muted">Initiative, HP und Notizen</span></div>', unsafe_allow_html=True)
            st.markdown(f'<div class="dnd-party-grid">{creature_html}</div>', unsafe_allow_html=True)

            if is_dnd_dm:
                with st.expander("Kreaturen verwalten"):
                    for creature in creatures:
                        creature_id = str(creature.get("id"))
                        creature_cols = st.columns([1.4, 1, 1])
                        with creature_cols[0]:
                            st.markdown(f"**{creature.get('name')}**")
                            st.caption(f"Max HP {int(creature.get('max_hp') or 1)}")
                        with creature_cols[1]:
                            new_hp = st.number_input(
                                "Aktuelle HP",
                                min_value=0,
                                max_value=int(creature.get("max_hp") or 1),
                                value=int(creature.get("current_hp") or 0),
                                step=1,
                                key=f"dnd_creature_hp_{creature_id}",
                            )
                            if st.button("HP speichern", key=f"dnd_save_creature_hp_{creature_id}"):
                                if update_dnd_creature_hp(creature_id, new_hp):
                                    st.success("Kreatur aktualisiert.")
                                    st.rerun()
                                else:
                                    st.error("Kreatur konnte nicht aktualisiert werden.")
                        with creature_cols[2]:
                            st.write("")
                            st.write("")
                            if st.button("Entfernen", key=f"dnd_delete_creature_{creature_id}"):
                                if delete_dnd_creature(creature_id):
                                    st.success("Kreatur entfernt.")
                                    st.rerun()
                                else:
                                    st.error("Kreatur konnte nicht entfernt werden.")

        last_roll = st.session_state.get("dnd_last_roll")
        if last_roll and str(last_roll.get("lobby_id")) == str(active_lobby_id):
            render_dnd_dice_result_component(last_roll)

        if current_player:
            st.markdown('<div class="dnd-section-title"><h3>Spieler Bereich</h3><span class="admin-muted">Charakterbogen und Proben</span></div>', unsafe_allow_html=True)
            with st.expander("Figur auf dem Spielbrett platzieren", expanded=True):
                grid_width = max(4, min(int(active_lobby.get("map_grid_width") or 12), 40))
                grid_height = max(4, min(int(active_lobby.get("map_grid_height") or 8), 30))
                with st.form("dnd_token_position_form"):
                    token_cols = st.columns([1, 1, 0.8])
                    with token_cols[0]:
                        token_x = st.number_input(
                            "X Feld",
                            min_value=1,
                            max_value=grid_width,
                            value=max(1, min(int(current_player.get("token_x") or 1), grid_width)),
                            step=1,
                        )
                    with token_cols[1]:
                        token_y = st.number_input(
                            "Y Feld",
                            min_value=1,
                            max_value=grid_height,
                            value=max(1, min(int(current_player.get("token_y") or 1), grid_height)),
                            step=1,
                        )
                    with token_cols[2]:
                        token_color = st.color_picker("Token-Farbe", value=str(current_player.get("token_color") or "#7CFFB2"))
                    if st.form_submit_button("Figur platzieren"):
                        if update_dnd_player_token(current_player.get("id"), token_x, token_y, token_color):
                            st.success("Figur platziert.")
                            st.rerun()
                        else:
                            st.error("Figur konnte nicht gespeichert werden. Führe die aktualisierte add_dnd_tables.sql aus.")

            with st.expander("HP schnell ändern", expanded=False):
                st.caption(f"Aktuelle HP: {int(current_player.get('current_hp') or 0)}/{int(current_player.get('max_hp') or 1)}")
                hp_cols = st.columns(4)
                for hp_col, delta, label in zip(hp_cols, [-5, -1, 1, 5], ["-5", "-1", "+1", "+5"]):
                    with hp_col:
                        if st.button(label, key=f"dnd_player_hp_{label}", use_container_width=True):
                            if adjust_dnd_player_hp(current_player, delta):
                                create_dnd_log(active_lobby_id, logged_in_username, "HP", f"{current_player.get('character_name')} {label} HP")
                                st.rerun()

            with st.expander("Charakterbogen bearbeiten", expanded=False):
                with st.form("dnd_character_sheet_form"):
                    sheet_top = st.columns([1.2, 1, 0.7, 0.7, 0.7, 0.7])
                    with sheet_top[0]:
                        sheet_name = st.text_input("Charaktername", value=str(current_player.get("character_name") or ""), max_chars=80)
                    with sheet_top[1]:
                        current_class = str(current_player.get("character_class") or DND_CLASSES[0])
                        sheet_class = st.selectbox(
                            "Klasse",
                            DND_CLASSES,
                            index=DND_CLASSES.index(current_class) if current_class in DND_CLASSES else 0,
                        )
                    with sheet_top[2]:
                        current_race = str(current_player.get("race") or DND_RACES[0])
                        sheet_race = st.selectbox(
                            "Volk",
                            DND_RACES,
                            index=DND_RACES.index(current_race) if current_race in DND_RACES else 0,
                        )
                    with sheet_top[3]:
                        sheet_level = st.number_input("Level", min_value=1, max_value=20, value=int(current_player.get("level") or 1), step=1)
                    with sheet_top[4]:
                        sheet_ac = st.number_input("AC", min_value=1, max_value=40, value=int(current_player.get("armor_class") or 10), step=1)
                    with sheet_top[5]:
                        sheet_init = st.number_input("Init", min_value=-20, max_value=30, value=int(current_player.get("initiative") or 0), step=1)

                    hp_cols = st.columns(2)
                    with hp_cols[0]:
                        sheet_current_hp = st.number_input("Aktuelle HP", min_value=0, max_value=999, value=int(current_player.get("current_hp") or 10), step=1)
                    with hp_cols[1]:
                        sheet_max_hp = st.number_input("Max HP", min_value=1, max_value=999, value=int(current_player.get("max_hp") or 10), step=1)

                    ability_cols = st.columns(6)
                    ability_values = {}
                    for ability_col, (ability_key, ability_label) in zip(ability_cols, DND_ABILITIES):
                        with ability_col:
                            score = st.number_input(
                                ability_label,
                                min_value=1,
                                max_value=30,
                                value=int(current_player.get(ability_key) or 10),
                                step=1,
                                key=f"dnd_sheet_{ability_key}",
                            )
                            ability_values[ability_key] = score
                            st.caption(f"Mod {format_modifier(ability_modifier(score))}")

                    notes_cols = st.columns(3)
                    with notes_cols[0]:
                        sheet_inventory = st.text_area("Inventar", value=str(current_player.get("inventory") or ""), height=120, max_chars=1200)
                    with notes_cols[1]:
                        sheet_spells = st.text_area("Zauber/Fähigkeiten", value=str(current_player.get("spells") or ""), height=120, max_chars=1200)
                    with notes_cols[2]:
                        sheet_notes = st.text_area("Notizen", value=str(current_player.get("notes") or ""), height=120, max_chars=1200)

                    if st.form_submit_button("Charakterbogen speichern"):
                        payload = {
                            "character_name": sheet_name,
                            "character_class": sheet_class,
                            "race": sheet_race,
                            "level": sheet_level,
                            "armor_class": sheet_ac,
                            "initiative": sheet_init,
                            "current_hp": sheet_current_hp,
                            "max_hp": sheet_max_hp,
                            "inventory": sheet_inventory,
                            "spells": sheet_spells,
                            "notes": sheet_notes,
                            **ability_values,
                        }
                        if update_dnd_player_sheet(current_player.get("id"), payload):
                            st.success("Charakterbogen gespeichert.")
                            st.rerun()
                        else:
                            st.error("Charakterbogen konnte nicht gespeichert werden. Führe die aktualisierte add_dnd_tables.sql aus.")

            st.markdown('<div class="dnd-section-title"><h3>Charakter-Proben</h3><span class="admin-muted">Attribut wählen, Bonus setzen, Wurf speichern</span></div>', unsafe_allow_html=True)
            check_cols = st.columns([1, 1, 1, 1.4])
            with check_cols[0]:
                check_ability_key = st.selectbox(
                    "Attribut",
                    [key for key, _ in DND_ABILITIES],
                    format_func=lambda key: next(label for ability_key, label in DND_ABILITIES if ability_key == key),
                    key="dnd_check_ability",
                )
            with check_cols[1]:
                check_mode = st.selectbox("Probe-Modus", ["Normal", "Vorteil", "Nachteil"], key="dnd_check_mode")
            with check_cols[2]:
                proficiency_bonus = st.number_input("Übungsbonus", min_value=0, max_value=10, value=0, step=1, key="dnd_check_prof")
            with check_cols[3]:
                check_reason = st.text_input("Probe", max_chars=140, placeholder="z.B. Wahrnehmung, Athletik, Überreden", key="dnd_check_reason")

            ability_score = int(current_player.get(check_ability_key) or 10)
            check_modifier = ability_modifier(ability_score) + int(proficiency_bonus)
            if st.button(f"Probe würfeln ({format_modifier(check_modifier)})", key="dnd_ability_check", use_container_width=True):
                rolls, total, kept = roll_dice(1, 20, check_modifier, check_mode)
                ability_label = next(label for ability_key, label in DND_ABILITIES if ability_key == check_ability_key)
                notation = f"{check_mode} d20{format_modifier(check_modifier)}" if check_mode != "Normal" else f"d20{format_modifier(check_modifier)}"
                reason = check_reason or f"{ability_label}-Probe"
                save_dnd_roll(active_lobby_id, logged_in_username, current_player.get("character_name"), notation, reason, rolls, total)
                create_dnd_log(active_lobby_id, logged_in_username, "Wurf", f"{reason}: {total} ({rolls})")
                st.session_state["dnd_last_roll"] = {
                    "lobby_id": active_lobby_id,
                    "total": total,
                    "notation": notation,
                    "title": reason,
                    "detail": f"Rohwürfe: {rolls}",
                    "theme": DND_DICE_THEMES.get(st.session_state.get("dnd_dice_theme", "Eis Würfel"), "ice"),
                    "sides": 20,
                }
                st.success(f"{reason}: {total} ({rolls})")
                st.rerun()

        st.markdown('<div class="dnd-section-title"><h3>Würfelroller</h3><span class="admin-muted">Freie Würfe für Angriffe, Checks und Schaden</span></div>', unsafe_allow_html=True)
        roll_cols = st.columns([1, 1, 1, 1, 1, 1.4])
        with roll_cols[0]:
            roll_count = st.number_input("Anzahl", min_value=1, max_value=20, value=1, step=1, key="dnd_roll_count")
        with roll_cols[1]:
            roll_sides = st.selectbox("Würfel", DND_DICE, index=DND_DICE.index(20), format_func=lambda sides: f"d{sides}")
        with roll_cols[2]:
            roll_modifier = st.number_input("Modifikator", min_value=-30, max_value=30, value=0, step=1, key="dnd_roll_modifier")
        with roll_cols[3]:
            roll_mode = st.selectbox("Modus", ["Normal", "Vorteil", "Nachteil"])
        with roll_cols[4]:
            dice_theme_label = st.selectbox("Design", list(DND_DICE_THEMES.keys()), key="dnd_dice_theme")
        with roll_cols[5]:
            roll_reason = st.text_input("Grund", max_chars=140, placeholder="Angriff, Wahrnehmung, Schaden...")

        if st.button("Würfeln", key="dnd_roll_button", use_container_width=True):
            rolls, total, kept = roll_dice(roll_count, roll_sides, roll_modifier, roll_mode)
            mod_text = f"{roll_modifier:+d}" if roll_modifier else ""
            notation = f"{int(roll_count)}d{int(roll_sides)}{mod_text}"
            if roll_mode in ("Vorteil", "Nachteil") and int(roll_sides) == 20 and int(roll_count) == 1:
                notation = f"{roll_mode} d20{mod_text}"
            character_for_roll = current_player.get("character_name") if current_player else logged_in_username
            save_dnd_roll(active_lobby_id, logged_in_username, character_for_roll, notation, roll_reason, rolls, total)
            create_dnd_log(active_lobby_id, logged_in_username, "Wurf", f"{character_for_roll}: {notation} = {total}")
            detail = f"Rohwürfe: {rolls}"
            if kept:
                detail += f" | Gewertet: {kept}"
            st.session_state["dnd_last_roll"] = {
                "lobby_id": active_lobby_id,
                "total": total,
                "notation": notation,
                "title": roll_reason or "Würfelwurf",
                "detail": detail,
                "theme": DND_DICE_THEMES.get(dice_theme_label, "ice"),
                "sides": int(roll_sides),
            }
            st.success(f"{notation} = {total}. {detail}")
            st.rerun()

        roll_history = get_dnd_rolls(active_lobby_id)
        if roll_history:
            roll_html = ""
            for roll in roll_history[:12]:
                roll_html += (
                    '<article class="dnd-roll-card">'
                    f'<div class="dnd-pill">{html.escape(str(roll.get("notation") or ""))}</div>'
                    f'<strong>{int(roll.get("total") or 0)}</strong>'
                    f'<h3>{html.escape(str(roll.get("character_name") or roll.get("username") or ""))}</h3>'
                    f'<p>{html.escape(str(roll.get("reason") or "Wurf"))}</p>'
                    f'<div class="admin-muted">{html.escape(str(roll.get("rolls") or ""))}</div>'
                    '</article>'
                )
            st.markdown('<div class="dnd-section-title"><h3>Wurfchronik</h3><span class="admin-muted">Die letzten Ergebnisse dieser Lobby</span></div>', unsafe_allow_html=True)
            st.markdown(f'<div class="dnd-roll-grid">{roll_html}</div>', unsafe_allow_html=True)

        st.markdown('<div class="dnd-section-title"><h3>Kampflog</h3><span class="admin-muted">Aktionen, Schaden, Hinweise und Würfe</span></div>', unsafe_allow_html=True)
        with st.form("dnd_log_form"):
            log_cols = st.columns([0.8, 2.2, 0.7])
            with log_cols[0]:
                log_type = st.selectbox("Typ", ["Aktion", "Dialog", "HP", "Loot", "Notiz"], key="dnd_log_type")
            with log_cols[1]:
                log_message = st.text_input("Eintrag", max_chars=800, placeholder="Was passiert gerade?")
            with log_cols[2]:
                st.write("")
                st.write("")
                submit_log = st.form_submit_button("Eintragen")
        if submit_log:
            if create_dnd_log(active_lobby_id, logged_in_username, log_type, log_message):
                st.success("Log gespeichert.")
                st.rerun()
            else:
                st.error("Log konnte nicht gespeichert werden. Führe die aktualisierte add_dnd_tables.sql aus.")
        if dnd_logs:
            log_html = ""
            for entry in dnd_logs[:16]:
                log_html += (
                    '<div class="dnd-log-row">'
                    f'<strong>{html.escape(str(entry.get("entry_type") or "Aktion"))}</strong>'
                    f'<span>{html.escape(str(entry.get("username") or ""))}: {html.escape(str(entry.get("message") or ""))}</span>'
                    '</div>'
                )
            st.markdown(f'<div class="dnd-log-list">{log_html}</div>', unsafe_allow_html=True)

        if is_dnd_dm or is_lobby_owner:
            if st.button("Lobby schliessen", key="close_dnd_lobby", type="primary"):
                if close_dnd_lobby(active_lobby_id):
                    st.session_state.pop("dnd_lobby_id", None)
                    st.success("Lobby geschlossen.")
                    st.rerun()
                else:
                    st.error("Lobby konnte nicht geschlossen werden.")


def build_achievements(user, rank_position=None, best_score=None, daily_state=None):
    braincells = int(user.get("braincells") or 0)
    chickens = int(user.get("chickens") or 0)
    bio = str(user.get("bio") or "").strip()
    favorite_game = str(user.get("favorite_game") or "").strip()
    avatar_url = str(user.get("avatar_url") or "").strip()
    score = int(best_score.get("score") or 0) if best_score else 0
    streak = int(daily_state.get("streak") or 0) if daily_state else 0
    level = get_profile_level(braincells)
    bio_length = len(bio)
    has_rank = isinstance(rank_position, int)

    achievements = [
        ("Profil-Profi", "Bio, Lieblingsspiel und Avatar gesetzt", bool(bio and favorite_game and avatar_url)),
        ("Chicken Sammler", "Mindestens 1.000 Chickens besitzen", chickens >= 1000),
        ("Gehirntraining", "Mindestens 500 Gehirnzellen gesammelt", braincells >= 500),
        ("Top 3 Energie", "In der Rangliste unter den Top 3", isinstance(rank_position, int) and rank_position <= 3),
        ("Jump Talent", "Chicken Jump Score von 10+ erreicht", score >= 10),
        ("Daily Streak", "3 Tage Daily Reward in Folge", streak >= 3),
        ("Erste Gehirnzelle", "Mindestens 1 Gehirnzelle gesammelt", braincells >= 1),
        ("Gedankenstarter", "Mindestens 100 Gehirnzellen gesammelt", braincells >= 100),
        ("Kopfkino", "Mindestens 250 Gehirnzellen gesammelt", braincells >= 250),
        ("Synapsensturm", "Mindestens 1.000 Gehirnzellen gesammelt", braincells >= 1000),
        ("Denkmaschine", "Mindestens 2.000 Gehirnzellen gesammelt", braincells >= 2000),
        ("Overclock Warmup", "Mindestens 3.500 Gehirnzellen gesammelt", braincells >= 3500),
        ("Neuronennetz", "Mindestens 5.000 Gehirnzellen gesammelt", braincells >= 5000),
        ("Brain Boss", "Mindestens 7.500 Gehirnzellen gesammelt", braincells >= 7500),
        ("Gigadenker", "Mindestens 10.000 Gehirnzellen gesammelt", braincells >= 10000),
        ("Galaxiekopf", "Mindestens 25.000 Gehirnzellen gesammelt", braincells >= 25000),
        ("Endboss Mind", "Mindestens 50.000 Gehirnzellen gesammelt", braincells >= 50000),
        ("Erstes Ei", "Mindestens 1 Chicken besitzen", chickens >= 1),
        ("Chicken Polster", "Mindestens 100 Chickens besitzen", chickens >= 100),
        ("Chicken Beutel", "Mindestens 250 Chickens besitzen", chickens >= 250),
        ("Hühnerhort", "Mindestens 500 Chickens besitzen", chickens >= 500),
        ("Chicken Tresor", "Mindestens 2.500 Chickens besitzen", chickens >= 2500),
        ("Goldene Feder", "Mindestens 5.000 Chickens besitzen", chickens >= 5000),
        ("Chicken Imperium", "Mindestens 10.000 Chickens besitzen", chickens >= 10000),
        ("Hühnerbaron", "Mindestens 25.000 Chickens besitzen", chickens >= 25000),
        ("Erster Sprung", "Chicken Jump Score von 1+ erreicht", score >= 1),
        ("Hopser", "Chicken Jump Score von 5+ erreicht", score >= 5),
        ("Jump Profi", "Chicken Jump Score von 15+ erreicht", score >= 15),
        ("Arcade Ass", "Chicken Jump Score von 25+ erreicht", score >= 25),
        ("Zaunflieger", "Chicken Jump Score von 40+ erreicht", score >= 40),
        ("Chicken Pilot", "Chicken Jump Score von 60+ erreicht", score >= 60),
        ("Pixel Legende", "Chicken Jump Score von 100+ erreicht", score >= 100),
        ("Tagesfunke", "1 Tag Daily Reward Streak", streak >= 1),
        ("Wochenrhythmus", "5 Tage Daily Reward Streak", streak >= 5),
        ("Sieben Tage Stark", "7 Tage Daily Reward Streak", streak >= 7),
        ("Zwei Wochen Fokus", "14 Tage Daily Reward Streak", streak >= 14),
        ("Drei Wochen Dran", "21 Tage Daily Reward Streak", streak >= 21),
        ("Monatsmaschine", "30 Tage Daily Reward Streak", streak >= 30),
        ("Streak Fanatiker", "50 Tage Daily Reward Streak", streak >= 50),
        ("Hundert Tage Kopf", "100 Tage Daily Reward Streak", streak >= 100),
        ("Rang sichtbar", "In der Rangliste unter den Top 50", has_rank and rank_position <= 50),
        ("Top 25 Signal", "In der Rangliste unter den Top 25", has_rank and rank_position <= 25),
        ("Top 10 Fokus", "In der Rangliste unter den Top 10", has_rank and rank_position <= 10),
        ("Top 5 Leuchten", "In der Rangliste unter den Top 5", has_rank and rank_position <= 5),
        ("Nummer 1", "Platz 1 in der Rangliste erreicht", has_rank and rank_position == 1),
        ("Bio Starter", "Eine Bio im Profil eingetragen", bool(bio)),
        ("Bio Erzähler", "Bio mit mindestens 80 Zeichen", bio_length >= 80),
        ("Bio Roman", "Bio mit mindestens 200 Zeichen", bio_length >= 200),
        ("Lieblingsspiel gesetzt", "Ein Lieblingsspiel im Profil eingetragen", bool(favorite_game)),
        ("Avatar Glanz", "Ein Profilbild gesetzt", bool(avatar_url)),
        ("Level 2 erreicht", "Profil-Level 2 erreicht", level >= 2),
        ("Level 5 erreicht", "Profil-Level 5 erreicht", level >= 5),
        ("Level 10 erreicht", "Profil-Level 10 erreicht", level >= 10),
        ("Level 20 erreicht", "Profil-Level 20 erreicht", level >= 20),
        ("Level 30 erreicht", "Profil-Level 30 erreicht", level >= 30),
        ("Level 50 erreicht", "Profil-Level 50 erreicht", level >= 50),
    ]

    return achievements

# =========================
# RÄNGE
# =========================

def get_rank(points):
    ranks = [
        ("🥔 Kartoffelhirn", 0, 100),
        ("🤖 NPC-Gehirn", 100, 500),
        ("🧪 Laborhirn", 500, 2000),
        ("🧠 Großhirn", 2000, 5000),
        ("⚡ Overclocked Brain", 5000, 10000),
        ("👑 Gigagehirn", 10000, 25000),
        ("🌌 Galaxiehirn", 25000, 50000),
        ("🧬 Endboss-Gehirn", 50000, 999999999)
    ]

    for name, minimum, next_level in ranks:
        if minimum <= points < next_level:
            return name, minimum, next_level

    return "🧬 Endboss-Gehirn", 50000, 999999999

def get_progress(points):
    rank_name, minimum, next_level = get_rank(points)

    if next_level >= 999999999:
        return rank_name, 100, "Max-Level erreicht"

    needed = next_level - minimum
    current = points - minimum
    progress = int((current / needed) * 100)
    missing = next_level - points

    return rank_name, progress, f"{missing} Gehirnzellen bis zum nächsten Rang"

# =========================
# EVENTS
# =========================

SHOP_CATEGORIES = [
    "In Stream Rewards",
    "Bestrafungs Ideen",
    "Aufgaben",
    "Out of Stream Rewards",
]

PUNISHMENT_WHEEL_CATEGORIES = [
    "Bestrafungs Ideen",
    "Idee Bestrafungsrad",
]

TASK_WHEEL_CATEGORIES = [
    "Aufgaben",
    "Aufgaben Ideen",
    "Idee Aufgabenrad",
]

WHEEL_REWARD_CATEGORIES = set(PUNISHMENT_WHEEL_CATEGORIES + TASK_WHEEL_CATEGORIES)

DND_DICE = [4, 6, 8, 10, 12, 20, 100]
DND_CLASSES = [
    "Barbar",
    "Barde",
    "Kleriker",
    "Druide",
    "Kämpfer",
    "Mönch",
    "Paladin",
    "Waldläufer",
    "Schurke",
    "Zauberer",
    "Hexenmeister",
    "Magier",
]
DND_RACES = [
    "Mensch",
    "Elf",
    "Zwerg",
    "Halbling",
    "Gnom",
    "Halbelf",
    "Halbork",
    "Tiefling",
    "Drachenblütiger",
]
DND_ABILITIES = [
    ("strength", "Stärke"),
    ("dexterity", "Geschick"),
    ("constitution", "Konstitution"),
    ("intelligence", "Intelligenz"),
    ("wisdom", "Weisheit"),
    ("charisma", "Charisma"),
]
DND_DICE_THEMES = {
    "Eis Würfel": "ice",
    "Feuer Würfel": "fire",
    "Funken Würfel": "spark",
    "Wasser Würfel": "water",
    "Erd Würfel": "earth",
}


def svg_data_uri(svg):
    return "data:image/svg+xml," + urllib.parse.quote(svg.strip())


DND_PRESET_MAPS = {
    "Dungeon": {
        "name": "Dungeon",
        "grid_width": 12,
        "grid_height": 8,
        "marker_notes": "Steintor im Westen\nAltar im Norden\nGeheimer Gang bei X10/Y6",
        "image": svg_data_uri("""
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 800">
          <defs>
            <linearGradient id="dungeonBg" x1="0" x2="1" y1="0" y2="1"><stop stop-color="#151821"/><stop offset="1" stop-color="#33283b"/></linearGradient>
            <filter id="rough"><feTurbulence type="fractalNoise" baseFrequency=".035" numOctaves="4"/><feColorMatrix values=".25 0 0 0 0 .25 0 0 0 0 .3 0 0 0 0 0 0 0 .34 0"/></filter>
          </defs>
          <rect width="1200" height="800" fill="url(#dungeonBg)"/>
          <rect width="1200" height="800" filter="url(#rough)" opacity=".7"/>
          <g fill="#3d4150" stroke="#11151d" stroke-width="10">
            <rect x="70" y="70" width="340" height="250" rx="10"/>
            <rect x="470" y="70" width="290" height="190" rx="10"/>
            <rect x="820" y="90" width="300" height="290" rx="10"/>
            <rect x="120" y="420" width="410" height="250" rx="10"/>
            <rect x="610" y="360" width="470" height="310" rx="10"/>
          </g>
          <g stroke="#6b7180" stroke-width="38" stroke-linecap="round" opacity=".78">
            <path d="M400 190h95M720 210h130M335 315v130M530 520h105"/>
          </g>
          <g fill="#b58a44" opacity=".9"><circle cx="235" cy="185" r="34"/><circle cx="935" cy="230" r="42"/><rect x="780" y="482" width="92" height="64" rx="8"/></g>
          <g stroke="#ffffff" stroke-opacity=".12" stroke-width="2"><path d="M0 100h1200M0 200h1200M0 300h1200M0 400h1200M0 500h1200M0 600h1200M0 700h1200M100 0v800M200 0v800M300 0v800M400 0v800M500 0v800M600 0v800M700 0v800M800 0v800M900 0v800M1000 0v800M1100 0v800"/></g>
        </svg>
        """),
    },
    "Wald": {
        "name": "Wald",
        "grid_width": 12,
        "grid_height": 8,
        "marker_notes": "Lichtung in der Mitte\nBachlauf im Osten\nDichter Nebel im Süden",
        "image": svg_data_uri("""
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 800">
          <defs><linearGradient id="forestBg" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#16341f"/><stop offset=".55" stop-color="#245431"/><stop offset="1" stop-color="#102817"/></linearGradient></defs>
          <rect width="1200" height="800" fill="url(#forestBg)"/>
          <path d="M980 0C840 190 980 330 820 500c-80 86-84 175-40 300h420V0z" fill="#245d6b" opacity=".55"/>
          <ellipse cx="570" cy="380" rx="230" ry="150" fill="#7ca85b" opacity=".38"/>
          <g fill="#0d2414" opacity=".95">
            <circle cx="120" cy="120" r="70"/><circle cx="280" cy="95" r="54"/><circle cx="430" cy="145" r="76"/><circle cx="720" cy="95" r="66"/><circle cx="1040" cy="145" r="86"/>
            <circle cx="130" cy="560" r="82"/><circle cx="330" cy="660" r="74"/><circle cx="560" cy="635" r="60"/><circle cx="900" cy="620" r="86"/><circle cx="1100" cy="545" r="70"/>
          </g>
          <g fill="#2f7a3d" opacity=".85">
            <circle cx="210" cy="255" r="46"/><circle cx="385" cy="385" r="50"/><circle cx="695" cy="330" r="48"/><circle cx="835" cy="455" r="52"/><circle cx="1010" cy="350" r="42"/>
          </g>
          <path d="M0 740C180 650 300 690 430 610c140-85 250-70 360-145 135-92 235-88 410-175" fill="none" stroke="#5f4426" stroke-width="64" stroke-linecap="round" opacity=".72"/>
          <g stroke="#ffffff" stroke-opacity=".12" stroke-width="2"><path d="M0 100h1200M0 200h1200M0 300h1200M0 400h1200M0 500h1200M0 600h1200M0 700h1200M100 0v800M200 0v800M300 0v800M400 0v800M500 0v800M600 0v800M700 0v800M800 0v800M900 0v800M1000 0v800M1100 0v800"/></g>
        </svg>
        """),
    },
    "Strand": {
        "name": "Strand",
        "grid_width": 12,
        "grid_height": 8,
        "marker_notes": "Boot am Steg\nFelsen im Wasser\nPalmenlinie im Süden",
        "image": svg_data_uri("""
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 800">
          <defs><linearGradient id="sea" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#1fa7c9"/><stop offset="1" stop-color="#0f5e87"/></linearGradient><linearGradient id="sand" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#f4d799"/><stop offset="1" stop-color="#c99b5a"/></linearGradient></defs>
          <rect width="1200" height="800" fill="url(#sand)"/>
          <path d="M0 0h1200v405C1020 340 840 455 650 385C420 300 220 415 0 330z" fill="url(#sea)"/>
          <path d="M0 320C220 410 420 300 650 385c190 70 370-45 550 20" fill="none" stroke="#eafcff" stroke-width="34" opacity=".8"/>
          <g fill="#8b6840" opacity=".85"><ellipse cx="165" cy="640" rx="76" ry="34"/><ellipse cx="960" cy="580" rx="90" ry="42"/><rect x="505" y="435" width="180" height="36" rx="8"/></g>
          <g fill="#267a3e"><circle cx="95" cy="520" r="44"/><circle cx="190" cy="490" r="36"/><circle cx="1030" cy="700" r="48"/><circle cx="1105" cy="660" r="36"/></g>
          <g stroke="#ffffff" stroke-opacity=".13" stroke-width="2"><path d="M0 100h1200M0 200h1200M0 300h1200M0 400h1200M0 500h1200M0 600h1200M0 700h1200M100 0v800M200 0v800M300 0v800M400 0v800M500 0v800M600 0v800M700 0v800M800 0v800M900 0v800M1000 0v800M1100 0v800"/></g>
        </svg>
        """),
    },
}

MARKET_SPREAD = 0.12
MARKET_DAILY_BUY_LIMIT = 25
MARKET_DAILY_SELL_LIMIT = 25

MARKET_ITEMS = [
    {"key": "weizen", "name": "Weizen", "emoji": "🌾", "base": 90, "volatility": 0.07},
    {"key": "mond", "name": "Mond", "emoji": "🌙", "base": 1800, "volatility": 0.10},
    {"key": "stein", "name": "Stein", "emoji": "🪨", "base": 45, "volatility": 0.05},
    {"key": "glitzer", "name": "Glitzer", "emoji": "✨", "base": 220, "volatility": 0.08},
    {"key": "drachenEi", "name": "Drachen-Ei", "emoji": "🥚", "base": 950, "volatility": 0.09},
    {"key": "blitz", "name": "Blitz", "emoji": "⚡", "base": 640, "volatility": 0.10},
    {"key": "kristall", "name": "Kristall", "emoji": "💎", "base": 1200, "volatility": 0.08},
    {"key": "pizza", "name": "Pizza-Aktie", "emoji": "🍕", "base": 310, "volatility": 0.07},
    {"key": "portal", "name": "Portalstaub", "emoji": "🌀", "base": 760, "volatility": 0.09},
    {"key": "krone", "name": "Krone", "emoji": "👑", "base": 2100, "volatility": 0.08},
    {"key": "frosch", "name": "Froschcoin", "emoji": "🐸", "base": 130, "volatility": 0.11},
    {"key": "stern", "name": "Sternsplitter", "emoji": "🌟", "base": 520, "volatility": 0.07},
    {"key": "kaffee", "name": "Kaffee-Future", "emoji": "☕", "base": 270, "volatility": 0.07},
]


def get_default_shop_category():
    return SHOP_CATEGORIES[0]


def is_wheel_reward_category(category):
    return str(category or "").strip() in WHEEL_REWARD_CATEGORIES


@st.cache_data(ttl=180)
def get_news_posts():
    return api_get_optional("news_posts?select=*&active=eq.true&order=published_at.desc,created_at.desc&limit=20")


def create_news_post(title, body, image_url):
    if not str(title).strip() or not str(body).strip():
        return None

    if image_url and not str(image_url).startswith(("http://", "https://")):
        image_url = ""

    created = api_post_optional(
        "news_posts",
        {
            "title": str(title).strip()[:140],
            "body": str(body).strip()[:2500],
            "image_url": str(image_url).strip()[:700],
            "active": True,
            "published_at": datetime.now(ZoneInfo("Europe/Berlin")).isoformat(),
            "created_at": datetime.now(ZoneInfo("Europe/Berlin")).isoformat(),
        }
    )
    get_news_posts.clear()
    return created


def delete_news_post(post_id):
    success = api_patch(f"news_posts?id=eq.{post_id}", {"active": False})
    get_news_posts.clear()
    return success


@st.cache_data(ttl=60)
def get_support_messages(status: Optional[str] = None):
    path = "support_messages?select=*&order=created_at.desc&limit=100"
    if status:
        path = (
            "support_messages?select=*&"
            f"status=eq.{urllib.parse.quote(status)}&order=created_at.desc&limit=100"
        )
    return api_get_optional(path)


def create_support_message(username, category, title, message):
    clean_title = str(title).strip()
    clean_message = str(message).strip()
    clean_username = str(username or "").strip() or "Gast"
    clean_category = str(category or "Problem").strip()[:40]

    if not clean_title or not clean_message:
        return False, "Bitte gib einen Titel und eine Beschreibung ein."

    created = api_post_optional(
        "support_messages",
        {
            "id": str(uuid.uuid4()),
            "username": clean_username[:80],
            "category": clean_category,
            "title": clean_title[:140],
            "message": clean_message[:2500],
            "status": "open",
            "created_at": datetime.now(ZoneInfo("Europe/Berlin")).isoformat(),
        }
    )

    if created:
        get_support_messages.clear()
        return True, "Danke, deine Meldung ist im Support angekommen."
    return False, "Support konnte nicht gespeichert werden. Führe zuerst add_support_tables.sql in Supabase aus."


def set_support_message_status(message_id, status):
    if status not in {"open", "done"}:
        return False
    success = api_patch(
        f"support_messages?id=eq.{urllib.parse.quote(str(message_id))}",
        {
            "status": status,
            "resolved_at": datetime.now(ZoneInfo("Europe/Berlin")).isoformat() if status == "done" else None,
        }
    )
    if success:
        get_support_messages.clear()
    return success


@st.cache_data(ttl=60)
def get_wish_posts():
    return api_get_optional(
        "wish_posts?select=*&active=eq.true&order=created_at.desc&limit=100"
    )


@st.cache_data(ttl=60)
def get_wish_reactions():
    return api_get_optional(
        "wish_reactions?select=wish_id,username,reaction,created_at&order=created_at.desc&limit=2000"
    )


def create_wish_post(username, title, description):
    clean_title = str(title).strip()
    clean_description = str(description).strip()
    clean_username = str(username or "").strip() or "Gast"

    if not clean_title or not clean_description:
        return False, "Bitte gib einen Titel und eine Beschreibung ein."

    created = api_post_optional(
        "wish_posts",
        {
            "id": str(uuid.uuid4()),
            "username": clean_username[:80],
            "title": clean_title[:140],
            "description": clean_description[:1800],
            "active": True,
            "created_at": datetime.now(ZoneInfo("Europe/Berlin")).isoformat(),
        }
    )

    if created:
        get_wish_posts.clear()
        return True, "Dein Wunsch ist veröffentlicht."
    return False, "Wunsch konnte nicht gespeichert werden. Führe zuerst add_support_tables.sql in Supabase aus."


def summarize_wish_reactions(reactions):
    summary = {}
    for reaction in reactions:
        wish_id = str(reaction.get("wish_id") or "")
        reaction_value = str(reaction.get("reaction") or "")
        if not wish_id or reaction_value not in {"up", "down"}:
            continue
        summary.setdefault(wish_id, {"up": 0, "down": 0})
        summary[wish_id][reaction_value] += 1
    return summary


def get_user_wish_reactions(reactions, username):
    if not username:
        return {}
    return {
        str(reaction.get("wish_id") or ""): str(reaction.get("reaction") or "")
        for reaction in reactions
        if str(reaction.get("username") or "") == username
    }


def set_wish_reaction(wish_id, username, reaction):
    if not wish_id or not username or reaction not in {"up", "down"}:
        return False

    created = api_upsert_optional(
        "wish_reactions?on_conflict=wish_id,username",
        {
            "wish_id": str(wish_id),
            "username": username.strip()[:80],
            "reaction": reaction,
            "created_at": datetime.now(ZoneInfo("Europe/Berlin")).isoformat(),
        }
    )
    if created:
        get_wish_reactions.clear()
        return True
    return False


def delete_wish_post(wish_id):
    success = api_patch(
        f"wish_posts?id=eq.{urllib.parse.quote(str(wish_id))}",
        {"active": False}
    )
    if success:
        get_wish_posts.clear()
        get_wish_reactions.clear()
    return success


@st.cache_data(ttl=45)
def get_recent_purchases(limit=8):
    return api_get_optional(
        "purchases?select=id,username,reward_name,reward_category,status,created_at"
        f"&order=created_at.desc&limit={int(limit)}"
    )


@st.cache_data(ttl=90)
def get_wheel_entries(categories_key):
    categories = list(categories_key)
    encoded_categories = ",".join(urllib.parse.quote(category) for category in categories)
    return api_get_optional(
        "purchases?select=id,username,reward_name,reward_category,status,created_at"
        f"&reward_category=in.({encoded_categories})&status=eq.open&order=created_at.asc"
    )


def get_punishment_wheel_entries():
    return get_wheel_entries(tuple(PUNISHMENT_WHEEL_CATEGORIES))


def get_task_wheel_entries():
    return get_wheel_entries(tuple(TASK_WHEEL_CATEGORIES))


def mark_wheel_entry_done(purchase_id):
    success = api_patch(
        f"purchases?id=eq.{purchase_id}",
        {"status": "done", "resolved_at": datetime.now(ZoneInfo("Europe/Berlin")).isoformat()}
    )
    get_wheel_entries.clear()
    return success


def mark_punishment_done(purchase_id):
    return mark_wheel_entry_done(purchase_id)


@st.cache_data(ttl=60)
def get_dnd_lobbies():
    return api_get_optional("dnd_lobbies?select=*&active=eq.true&order=created_at.desc&limit=50")


def get_dnd_lobby(lobby_id):
    rows = api_get_optional(f"dnd_lobbies?select=*&id=eq.{urllib.parse.quote(str(lobby_id))}&limit=1")
    return rows[0] if rows else None


@st.cache_data(ttl=30)
def get_dnd_players(lobby_id):
    return api_get_optional(
        f"dnd_players?select=*&lobby_id=eq.{urllib.parse.quote(str(lobby_id))}&active=eq.true&order=created_at.asc"
    )


@st.cache_data(ttl=20)
def get_dnd_rolls(lobby_id):
    return api_get_optional(
        f"dnd_rolls?select=*&lobby_id=eq.{urllib.parse.quote(str(lobby_id))}&order=created_at.desc&limit=25"
    )


@st.cache_data(ttl=20)
def get_dnd_creatures(lobby_id):
    return api_get_optional(
        f"dnd_creatures?select=*&lobby_id=eq.{urllib.parse.quote(str(lobby_id))}&active=eq.true&order=initiative.desc,created_at.asc"
    )


@st.cache_data(ttl=20)
def get_dnd_logs(lobby_id):
    return api_get_optional(
        f"dnd_logs?select=*&lobby_id=eq.{urllib.parse.quote(str(lobby_id))}&order=created_at.desc&limit=40"
    )


@st.cache_data(ttl=30)
def get_dnd_maps(lobby_id):
    return api_get_optional(
        f"dnd_maps?select=*&lobby_id=eq.{urllib.parse.quote(str(lobby_id))}&order=created_at.desc&limit=20"
    )


def get_dnd_dm_username(lobby):
    if "dm_username" in lobby:
        return str(lobby.get("dm_username") or "").strip()
    return str(lobby.get("owner") or "").strip()


def create_dnd_player(lobby_id, username, character_name, character_class):
    clean_username = str(username).strip()[:50]
    color_seed = hashlib.sha256(clean_username.encode("utf-8")).hexdigest()
    token_color = f"#{color_seed[:6]}"
    base_payload = {
        "lobby_id": int(lobby_id),
        "username": clean_username,
        "character_name": str(character_name).strip()[:80],
        "character_class": str(character_class).strip()[:40],
        "active": True,
        "created_at": datetime.now(ZoneInfo("Europe/Berlin")).isoformat(),
    }
    extended_payload = {
        **base_payload,
        "token_x": 1,
        "token_y": 1,
        "token_color": token_color,
        "race": "Mensch",
        "level": 1,
        "max_hp": 10,
        "current_hp": 10,
        "armor_class": 10,
        "initiative": 0,
        "strength": 10,
        "dexterity": 10,
        "constitution": 10,
        "intelligence": 10,
        "wisdom": 10,
        "charisma": 10,
        "inventory": "",
        "spells": "",
        "notes": "",
    }
    created, error = api_post_optional_with_error("dnd_players", extended_payload)
    if created:
        return created

    fallback_created, fallback_error = api_post_optional_with_error("dnd_players", base_payload)
    if fallback_error:
        st.session_state["dnd_last_create_error"] = fallback_error.get("message") or str(fallback_error)
    elif error:
        st.session_state["dnd_last_create_error"] = error.get("message") or str(error)
    return fallback_created


def create_dnd_lobby(name, description, owner, password, creator_role="dm", character_name="", character_class=None):
    clean_name = str(name).strip()[:80]
    clean_description = str(description).strip()[:500]
    clean_owner = str(owner).strip()[:50]
    if not clean_name or not clean_owner:
        return None
    creator_role = "dm" if creator_role == "dm" else "player"
    if creator_role == "player" and not str(character_name).strip():
        return None

    clean_password = str(password or "").strip()
    base_payload = {
        "name": clean_name,
        "description": clean_description,
        "owner": clean_owner,
        "is_private": bool(clean_password),
        "password_hash": hash_dnd_lobby_password(clean_password) if clean_password else "",
        "active": True,
        "created_at": datetime.now(ZoneInfo("Europe/Berlin")).isoformat(),
    }
    extended_payload = {
        **base_payload,
        "dm_username": clean_owner if creator_role == "dm" else "",
        "map_image_url": "",
        "map_name": "Startkarte",
        "map_grid_width": 12,
        "map_grid_height": 8,
        "map_fog_enabled": False,
        "map_fog_opacity": 55,
        "map_marker_notes": "",
        "active_turn_key": "",
        "round_number": 1,
    }
    created, error = api_post_optional_with_error("dnd_lobbies", extended_payload)
    if not created:
        created, fallback_error = api_post_optional_with_error("dnd_lobbies", base_payload)
        if fallback_error:
            st.session_state["dnd_last_create_error"] = fallback_error.get("message") or str(fallback_error)
        elif error:
            st.session_state["dnd_last_create_error"] = error.get("message") or str(error)
    if not created:
        return None

    lobby = created[0]
    if creator_role == "player":
        player_created = create_dnd_player(
            lobby.get("id"),
            clean_owner,
            character_name,
            character_class or DND_CLASSES[0],
        )
        if not player_created:
            close_dnd_lobby(lobby.get("id"))
            return None

    get_dnd_lobbies.clear()
    get_dnd_players.clear()
    return lobby


def close_dnd_lobby(lobby_id):
    success = api_patch(f"dnd_lobbies?id=eq.{urllib.parse.quote(str(lobby_id))}", {"active": False})
    get_dnd_lobbies.clear()
    return success


def update_dnd_lobby_notes(lobby_id, scene, quest_log):
    success = api_patch(
        f"dnd_lobbies?id=eq.{urllib.parse.quote(str(lobby_id))}",
        {
            "scene": str(scene).strip()[:1200],
            "quest_log": str(quest_log).strip()[:1200],
        }
    )
    get_dnd_lobbies.clear()
    return success


def update_dnd_lobby_map(lobby_id, map_image_url, grid_width, grid_height):
    clean_url = str(map_image_url or "").strip()
    if clean_url and not clean_url.startswith(("http://", "https://", "data:image/")):
        return False

    success = api_patch(
        f"dnd_lobbies?id=eq.{urllib.parse.quote(str(lobby_id))}",
        {
            "map_image_url": clean_url[:500000],
            "map_grid_width": max(4, min(int(grid_width), 40)),
            "map_grid_height": max(4, min(int(grid_height), 30)),
        }
    )
    get_dnd_lobbies.clear()
    return success


def update_dnd_lobby_board_tools(lobby_id, fog_enabled, fog_opacity, marker_notes, map_name=""):
    success = api_patch(
        f"dnd_lobbies?id=eq.{urllib.parse.quote(str(lobby_id))}",
        {
            "map_fog_enabled": bool(fog_enabled),
            "map_fog_opacity": max(0, min(int(fog_opacity), 95)),
            "map_marker_notes": str(marker_notes or "").strip()[:1200],
            "map_name": str(map_name or "").strip()[:80],
        }
    )
    get_dnd_lobbies.clear()
    return success


def set_dnd_turn(lobby_id, active_turn_key, round_number):
    success = api_patch(
        f"dnd_lobbies?id=eq.{urllib.parse.quote(str(lobby_id))}",
        {
            "active_turn_key": str(active_turn_key or "").strip()[:80],
            "round_number": max(1, int(round_number)),
        }
    )
    get_dnd_lobbies.clear()
    return success


def create_dnd_creature(lobby_id, name, creature_type, max_hp, armor_class, initiative, notes):
    clean_name = str(name).strip()[:80]
    if not clean_name:
        return None

    created = api_post_optional(
        "dnd_creatures",
        {
            "lobby_id": int(lobby_id),
            "name": clean_name,
            "creature_type": str(creature_type).strip()[:80] or "Kreatur",
            "max_hp": int(max_hp),
            "current_hp": int(max_hp),
            "armor_class": int(armor_class),
            "initiative": int(initiative),
            "token_x": 1,
            "token_y": 1,
            "token_color": "#ff54a0",
            "notes": str(notes).strip()[:500],
            "active": True,
            "created_at": datetime.now(ZoneInfo("Europe/Berlin")).isoformat(),
        }
    )
    get_dnd_creatures.clear()
    return created


def update_dnd_creature_hp(creature_id, current_hp):
    success = api_patch(
        f"dnd_creatures?id=eq.{urllib.parse.quote(str(creature_id))}",
        {"current_hp": int(current_hp)}
    )
    get_dnd_creatures.clear()
    return success


def update_dnd_player_hp(player_id, current_hp):
    success = api_patch(
        f"dnd_players?id=eq.{urllib.parse.quote(str(player_id))}",
        {"current_hp": max(0, min(int(current_hp), 999))}
    )
    get_dnd_players.clear()
    return success


def adjust_dnd_player_hp(player, delta):
    current_hp = int(player.get("current_hp") or 0)
    max_hp = int(player.get("max_hp") or 1)
    return update_dnd_player_hp(player.get("id"), max(0, min(current_hp + int(delta), max_hp)))


def adjust_dnd_creature_hp(creature, delta):
    current_hp = int(creature.get("current_hp") or 0)
    max_hp = int(creature.get("max_hp") or 1)
    return update_dnd_creature_hp(creature.get("id"), max(0, min(current_hp + int(delta), max_hp)))


def delete_dnd_creature(creature_id):
    success = api_patch(
        f"dnd_creatures?id=eq.{urllib.parse.quote(str(creature_id))}",
        {"active": False}
    )
    get_dnd_creatures.clear()
    return success


def update_dnd_creature_token(creature_id, token_x, token_y, token_color):
    clean_color = str(token_color or "#ff54a0").strip()
    if not re.match(r"^#[0-9a-fA-F]{6}$", clean_color):
        clean_color = "#ff54a0"

    success = api_patch(
        f"dnd_creatures?id=eq.{urllib.parse.quote(str(creature_id))}",
        {
            "token_x": max(1, min(int(token_x), 40)),
            "token_y": max(1, min(int(token_y), 30)),
            "token_color": clean_color,
        }
    )
    get_dnd_creatures.clear()
    return success


def update_dnd_player_token(player_id, token_x, token_y, token_color):
    clean_color = str(token_color or "#7CFFB2").strip()
    if not re.match(r"^#[0-9a-fA-F]{6}$", clean_color):
        clean_color = "#7CFFB2"

    success = api_patch(
        f"dnd_players?id=eq.{urllib.parse.quote(str(player_id))}",
        {
            "token_x": max(1, min(int(token_x), 40)),
            "token_y": max(1, min(int(token_y), 30)),
            "token_color": clean_color,
        }
    )
    get_dnd_players.clear()
    return success


def save_dnd_map_preset(lobby_id, name, map_image_url, grid_width, grid_height, marker_notes):
    clean_name = str(name or "").strip()[:80] or "Karte"
    created = api_post_optional(
        "dnd_maps",
        {
            "lobby_id": int(lobby_id),
            "name": clean_name,
            "map_image_url": str(map_image_url or "").strip()[:500000],
            "map_grid_width": max(4, min(int(grid_width), 40)),
            "map_grid_height": max(4, min(int(grid_height), 30)),
            "marker_notes": str(marker_notes or "").strip()[:1200],
            "created_at": datetime.now(ZoneInfo("Europe/Berlin")).isoformat(),
        }
    )
    get_dnd_maps.clear()
    return bool(created)


def apply_dnd_map_preset(lobby_id, preset):
    success = api_patch(
        f"dnd_lobbies?id=eq.{urllib.parse.quote(str(lobby_id))}",
        {
            "map_name": str(preset.get("name") or "Karte")[:80],
            "map_image_url": str(preset.get("map_image_url") or "")[:500000],
            "map_grid_width": int(preset.get("map_grid_width") or 12),
            "map_grid_height": int(preset.get("map_grid_height") or 8),
            "map_marker_notes": str(preset.get("marker_notes") or "")[:1200],
        }
    )
    get_dnd_lobbies.clear()
    return success


def create_dnd_log(lobby_id, username, entry_type, message):
    clean_message = str(message or "").strip()
    if not clean_message:
        return False
    created = api_post_optional(
        "dnd_logs",
        {
            "lobby_id": int(lobby_id),
            "username": str(username or "").strip()[:50],
            "entry_type": str(entry_type or "Aktion").strip()[:40],
            "message": clean_message[:800],
            "created_at": datetime.now(ZoneInfo("Europe/Berlin")).isoformat(),
        }
    )
    get_dnd_logs.clear()
    return bool(created)


def build_dnd_initiative(players, creatures):
    entries = []
    for player in players:
        entries.append({
            "key": f"player:{player.get('id')}",
            "name": str(player.get("character_name") or player.get("username") or "Spieler"),
            "type": "Spieler",
            "initiative": int(player.get("initiative") or 0),
            "hp": int(player.get("current_hp") or 0),
            "max_hp": int(player.get("max_hp") or 1),
        })
    for creature in creatures:
        entries.append({
            "key": f"creature:{creature.get('id')}",
            "name": str(creature.get("name") or "Kreatur"),
            "type": "Kreatur",
            "initiative": int(creature.get("initiative") or 0),
            "hp": int(creature.get("current_hp") or 0),
            "max_hp": int(creature.get("max_hp") or 1),
        })
    return sorted(entries, key=lambda entry: entry["initiative"], reverse=True)


def render_dnd_initiative_tracker(entries, active_turn_key):
    if not entries:
        return '<div class="dnd-panel"><p>Noch keine Initiative vorhanden.</p></div>'
    html_rows = ""
    for entry in entries:
        active_class = " active" if entry["key"] == active_turn_key else ""
        html_rows += (
            f'<div class="dnd-turn-row{active_class}">'
            f'<strong>{html.escape(entry["name"])}</strong>'
            f'<span>{html.escape(entry["type"])} · Init {entry["initiative"]:+d} · HP {entry["hp"]}/{entry["max_hp"]}</span>'
            '</div>'
        )
    return f'<div class="dnd-turn-tracker">{html_rows}</div>'


def render_dnd_dice(total, theme_key, sides=20):
    safe_theme = theme_key if theme_key in set(DND_DICE_THEMES.values()) else "ice"
    die_sides = int(sides) if int(sides) in DND_DICE else 20
    visual_sides = 10 if die_sides == 100 else die_sides
    facet_count = {4: 3, 6: 5, 8: 6, 10: 7, 12: 8, 20: 10}.get(visual_sides, 7)
    facet_html = "".join(
        f'<span style="--i:{index};"></span>'
        for index in range(facet_count)
    )
    particles = "".join('<span></span>' for _ in range(8))
    return (
        f'<div class="dice-scene dice-theme-{safe_theme} dice-shape-d{visual_sides}">'
        f'<div class="dice-particles">{particles}</div>'
        f'<div class="dice-polyhedron">{facet_html}<strong>{html.escape(str(total))}</strong><small>d{die_sides}</small></div>'
        '</div>'
    )


def render_dnd_dice_result_component(last_roll):
    total = int(last_roll.get("total") or 0)
    theme_key = str(last_roll.get("theme") or "ice")
    safe_theme = theme_key if theme_key in set(DND_DICE_THEMES.values()) else "ice"
    sides = int(last_roll.get("sides") or 20)
    die_sides = sides if sides in DND_DICE else 20
    visual_sides = 10 if die_sides == 100 else die_sides
    facet_count = {4: 3, 6: 5, 8: 6, 10: 7, 12: 8, 20: 10}.get(visual_sides, 7)
    facet_html = "".join(f'<span style="--i:{index};"></span>' for index in range(facet_count))
    particles = "".join('<i></i>' for _ in range(8))
    notation = html.escape(str(last_roll.get("notation") or "Wurf"))
    title = html.escape(str(last_roll.get("title") or "Würfelwurf"))
    detail = html.escape(str(last_roll.get("detail") or ""))

    components.html(f"""
    <div class="dice-result dice-theme-{safe_theme} dice-shape-d{visual_sides}">
      <style>
        .dice-result {{
          --dice-a:#effcff; --dice-b:#7CFFB2; --dice-c:#00f5ff; --dice-glow:rgba(124,255,178,.62);
          min-height:176px; display:grid; grid-template-columns:180px 1fr; gap:18px; align-items:center;
          padding:18px; border-radius:10px; color:#effcff; font-family:Inter,system-ui,Segoe UI,sans-serif;
          background:linear-gradient(145deg,rgba(124,255,178,.12),rgba(0,245,255,.08)),rgba(10,14,22,.82);
          border:1px solid rgba(124,255,178,.22); overflow:hidden;
        }}
        .dice-theme-ice {{ --dice-a:#f7fdff; --dice-b:#99e8ff; --dice-c:#4b8dff; --dice-glow:rgba(153,232,255,.72); }}
        .dice-theme-fire {{ --dice-a:#fff0c2; --dice-b:#ff8a00; --dice-c:#ff245f; --dice-glow:rgba(255,90,30,.78); }}
        .dice-theme-spark {{ --dice-a:#fff7c8; --dice-b:#ffe66d; --dice-c:#b66dff; --dice-glow:rgba(255,230,109,.78); }}
        .dice-theme-water {{ --dice-a:#e8ffff; --dice-b:#38d9ff; --dice-c:#1464d2; --dice-glow:rgba(56,217,255,.76); }}
        .dice-theme-earth {{ --dice-a:#e6f6bd; --dice-b:#8fb85a; --dice-c:#6b4a2b; --dice-glow:rgba(143,184,90,.70); }}
        .scene {{ position:relative; width:156px; height:156px; perspective:760px; contain:layout paint; }}
        .die {{ position:absolute; left:50%; top:50%; width:126px; height:126px; display:grid; place-items:center; transform-style:preserve-3d; animation:tumble 1.05s cubic-bezier(.18,.78,.24,1) both; will-change:transform; }}
        .die::before {{ content:""; position:absolute; inset:0; background:radial-gradient(circle at 32% 24%,rgba(255,255,255,.92),transparent 18%),linear-gradient(145deg,var(--dice-a),var(--dice-b) 54%,var(--dice-c)); border:2px solid rgba(255,255,255,.58); box-shadow:inset -12px -16px 26px rgba(0,0,0,.18),0 18px 34px rgba(0,0,0,.3); }}
        .die span {{ position:absolute; left:50%; top:50%; width:52%; height:40%; transform-origin:0 0; transform:rotate(calc(var(--i) * 24deg)) skewY(-18deg); background:rgba(255,255,255,.12); border-left:1px solid rgba(255,255,255,.22); opacity:.62; }}
        .die strong {{ position:relative; z-index:2; color:#061015; font-size:34px; line-height:1; font-weight:950; text-shadow:0 1px 0 rgba(255,255,255,.45); }}
        .die small {{ position:absolute; z-index:2; bottom:28px; color:rgba(6,16,21,.76); font-size:12px; font-weight:950; }}
        .dice-shape-d4 .die::before {{ clip-path:polygon(50% 3%,96% 92%,4% 92%); }}
        .dice-shape-d6 .die::before {{ clip-path:polygon(15% 10%,82% 4%,98% 72%,52% 100%,4% 70%); border-radius:18px; }}
        .dice-shape-d8 .die::before {{ clip-path:polygon(50% 0%,92% 28%,82% 78%,50% 100%,18% 78%,8% 28%); }}
        .dice-shape-d10 .die::before {{ clip-path:polygon(50% 0%,86% 17%,100% 52%,72% 100%,28% 100%,0% 52%,14% 17%); }}
        .dice-shape-d12 .die::before {{ clip-path:polygon(50% 0%,80% 8%,100% 34%,96% 66%,76% 92%,50% 100%,24% 92%,4% 66%,0% 34%,20% 8%); }}
        .dice-shape-d20 .die::before {{ clip-path:polygon(50% 0%,72% 12%,95% 18%,100% 50%,90% 78%,65% 92%,50% 100%,35% 92%,10% 78%,0% 50%,5% 18%,28% 12%); }}
        .sparks {{ position:absolute; inset:0; pointer-events:none; }}
        .sparks i {{ position:absolute; left:50%; top:50%; width:7px; height:7px; border-radius:999px; background:var(--dice-b); box-shadow:0 0 10px var(--dice-glow); animation:spark 1.05s ease-out both; }}
        .sparks i:nth-child(1) {{ --x:-74px; --y:-44px; animation-delay:.05s; }} .sparks i:nth-child(2) {{ --x:70px; --y:-52px; animation-delay:.12s; }}
        .sparks i:nth-child(3) {{ --x:-64px; --y:48px; animation-delay:.18s; }} .sparks i:nth-child(4) {{ --x:76px; --y:40px; animation-delay:.24s; }}
        .sparks i:nth-child(5) {{ --x:-24px; --y:-86px; animation-delay:.08s; }} .sparks i:nth-child(6) {{ --x:28px; --y:84px; animation-delay:.15s; }}
        .sparks i:nth-child(7) {{ --x:-94px; --y:2px; animation-delay:.22s; }} .sparks i:nth-child(8) {{ --x:94px; --y:-4px; animation-delay:.28s; }}
        .label {{ color:#ff7ad9; font-size:12px; font-weight:950; text-transform:uppercase; letter-spacing:.08em; }}
        h3 {{ margin:4px 0 8px; font-size:30px; color:#fff; }} p {{ margin:0; color:#eadcff; font-weight:800; }}
        @keyframes tumble {{ 0% {{ transform:translate3d(-50%,-76%,0) rotateX(-160deg) rotateY(110deg) rotateZ(18deg) scale(.82); opacity:.82; }} 58% {{ transform:translate3d(-50%,-46%,0) rotateX(34deg) rotateY(38deg) rotateZ(-7deg) scale(1.06); opacity:1; }} 100% {{ transform:translate3d(-50%,-50%,0) rotateX(0deg) rotateY(0deg) rotateZ(0deg) scale(1); opacity:1; }} }}
        @keyframes spark {{ 0% {{ transform:translate3d(-50%,-50%,0) scale(.25); opacity:0; }} 25% {{ opacity:1; }} 100% {{ transform:translate3d(calc(-50% + var(--x)),calc(-50% + var(--y)),0) scale(.08); opacity:0; }} }}
      </style>
      <div class="scene"><div class="sparks">{particles}</div><div class="die">{facet_html}<strong>{total}</strong><small>d{die_sides}</small></div></div>
      <div><div class="label">{notation}</div><h3>{title}</h3><p>{detail}</p></div>
    </div>
    """, height=196)


def render_dnd_battlemap(lobby, players, creatures):
    grid_width = max(4, min(int(lobby.get("map_grid_width") or 12), 40))
    grid_height = max(4, min(int(lobby.get("map_grid_height") or 8), 30))
    map_image_url = str(lobby.get("map_image_url") or "").strip()
    map_layer = (
        f"url('{html.escape(map_image_url, quote=True)}')"
        if map_image_url
        else "linear-gradient(135deg, rgba(22,31,44,0.92), rgba(48,30,57,0.90))"
    )
    board_background = (
        "linear-gradient(rgba(255,255,255,0.20) 1px, transparent 1px),"
        "linear-gradient(90deg, rgba(255,255,255,0.20) 1px, transparent 1px),"
        f"{map_layer}"
    )
    tokens_html = ""
    all_tokens = []
    for player in players:
        all_tokens.append({
            "x": player.get("token_x"),
            "y": player.get("token_y"),
            "color": player.get("token_color") or "#7CFFB2",
            "name": str(player.get("character_name") or player.get("username") or "?"),
            "class": "player",
        })
    for creature in creatures:
        all_tokens.append({
            "x": creature.get("token_x"),
            "y": creature.get("token_y"),
            "color": creature.get("token_color") or "#ff54a0",
            "name": str(creature.get("name") or "Kreatur"),
            "class": "creature",
        })

    for token in all_tokens:
        token_x = max(1, min(int(token.get("x") or 1), grid_width))
        token_y = max(1, min(int(token.get("y") or 1), grid_height))
        left = ((token_x - 0.5) / grid_width) * 100
        top = ((token_y - 0.5) / grid_height) * 100
        color = str(token.get("color") or "#7CFFB2")
        if not re.match(r"^#[0-9a-fA-F]{6}$", color):
            color = "#7CFFB2"
        character_name = str(token.get("name") or "?")
        initials = "".join(part[:1] for part in character_name.split()[:2]).upper() or "?"
        tokens_html += (
            f'<div class="dnd-map-token {html.escape(str(token.get("class") or ""))}" '
            f'style="left:{left:.3f}%;top:{top:.3f}%;--token-color:{html.escape(color)};" '
            f'title="{html.escape(character_name, quote=True)}">'
            f'<span>{html.escape(initials[:2])}</span>'
            f'<small>{html.escape(character_name[:18])}</small>'
            '</div>'
        )

    fog_html = ""
    if bool(lobby.get("map_fog_enabled")):
        fog_opacity = max(0, min(int(lobby.get("map_fog_opacity") or 55), 95)) / 100
        fog_html = f'<div class="dnd-map-fog" style="opacity:{fog_opacity:.2f};"></div>'

    marker_notes = [
        note.strip()
        for note in str(lobby.get("map_marker_notes") or "").splitlines()
        if note.strip()
    ][:6]
    marker_html = "".join(f'<li>{html.escape(note)}</li>' for note in marker_notes)
    marker_block = f'<ul class="dnd-map-markers">{marker_html}</ul>' if marker_html else ""

    return (
        '<div class="dnd-map-shell">'
        '<div class="dnd-map-board" '
        f'style="--grid-width:{grid_width};--grid-height:{grid_height};background-image:{board_background};">'
        f'{fog_html}'
        f'{tokens_html}'
        '</div>'
        f'{marker_block}'
        '</div>'
    )


def join_dnd_lobby(lobby, username, character_name, character_class, password, requested_role="player"):
    if not lobby or not str(username).strip():
        return False, "Bitte melde dich zuerst an."

    if lobby.get("is_private"):
        password_hash = str(lobby.get("password_hash") or "")
        if not verify_dnd_lobby_password(str(password or ""), password_hash):
            return False, "Passwort für diese Lobby ist falsch."

    lobby_id = str(lobby.get("id"))
    username = str(username).strip()[:50]
    dm_username = get_dnd_dm_username(lobby)
    role = "dm" if requested_role == "dm" and not dm_username else "player"

    if role == "dm":
        success = api_patch(
            f"dnd_lobbies?id=eq.{urllib.parse.quote(lobby_id)}",
            {"dm_username": username}
        )
        get_dnd_lobbies.clear()
        if success:
            st.session_state["dnd_lobby_id"] = lobby_id
            return True, "Du bist jetzt Dungeon Master dieser Lobby."
        return False, "DM-Rolle konnte nicht gespeichert werden. Führe die aktualisierte add_dnd_tables.sql aus."

    if not str(character_name).strip():
        return False, "Bitte trage einen Charakternamen ein."

    existing = api_get_optional(
        "dnd_players?select=id"
        f"&lobby_id=eq.{urllib.parse.quote(lobby_id)}"
        f"&username=eq.{urllib.parse.quote(username)}"
        "&active=eq.true&limit=1"
    )
    if existing:
        st.session_state["dnd_lobby_id"] = lobby_id
        return True, "Du bist bereits in dieser Lobby."

    created = create_dnd_player(lobby_id, username, character_name, character_class)
    get_dnd_players.clear()
    if created:
        st.session_state["dnd_lobby_id"] = lobby_id
        return True, "Lobby betreten."
    return False, "Lobby konnte nicht betreten werden. Führe add_dnd_tables.sql in Supabase aus."


def ability_modifier(score):
    return math.floor((int(score) - 10) / 2)


def format_modifier(value):
    return f"{int(value):+d}"


def update_dnd_player_sheet(player_id, payload):
    clean_payload = {
        "character_name": str(payload.get("character_name") or "").strip()[:80],
        "character_class": str(payload.get("character_class") or "").strip()[:40],
        "race": str(payload.get("race") or "").strip()[:40],
        "level": int(payload.get("level") or 1),
        "max_hp": int(payload.get("max_hp") or 1),
        "current_hp": int(payload.get("current_hp") or 0),
        "armor_class": int(payload.get("armor_class") or 10),
        "initiative": int(payload.get("initiative") or 0),
        "strength": int(payload.get("strength") or 10),
        "dexterity": int(payload.get("dexterity") or 10),
        "constitution": int(payload.get("constitution") or 10),
        "intelligence": int(payload.get("intelligence") or 10),
        "wisdom": int(payload.get("wisdom") or 10),
        "charisma": int(payload.get("charisma") or 10),
        "inventory": str(payload.get("inventory") or "").strip()[:1200],
        "spells": str(payload.get("spells") or "").strip()[:1200],
        "notes": str(payload.get("notes") or "").strip()[:1200],
    }
    if not clean_payload["character_name"]:
        return False

    success = api_patch(f"dnd_players?id=eq.{urllib.parse.quote(str(player_id))}", clean_payload)
    get_dnd_players.clear()
    return success


def roll_dice(count, sides, modifier=0, mode="Normal"):
    count = max(1, min(int(count), 20))
    sides = int(sides)
    modifier = int(modifier)

    if mode in ("Vorteil", "Nachteil") and sides == 20 and count == 1:
        rolls = [secrets.randbelow(20) + 1, secrets.randbelow(20) + 1]
        kept = max(rolls) if mode == "Vorteil" else min(rolls)
        return rolls, kept + modifier, kept

    rolls = [secrets.randbelow(sides) + 1 for _ in range(count)]
    return rolls, sum(rolls) + modifier, None


def save_dnd_roll(lobby_id, username, character_name, notation, reason, rolls, total):
    created = api_post_optional(
        "dnd_rolls",
        {
            "lobby_id": int(lobby_id),
            "username": str(username).strip()[:50],
            "character_name": str(character_name).strip()[:80],
            "notation": str(notation).strip()[:40],
            "reason": str(reason).strip()[:140],
            "rolls": json.dumps(rolls),
            "total": int(total),
            "created_at": datetime.now(ZoneInfo("Europe/Berlin")).isoformat(),
        }
    )
    get_dnd_rolls.clear()
    return bool(created)


def get_market_item(item_key):
    return next((item for item in MARKET_ITEMS if item["key"] == item_key), None)


def get_market_price(item_key, target_date=None):
    item = get_market_item(item_key)
    if not item:
        return 0

    if target_date is None:
        target_date = datetime.now(ZoneInfo("Europe/Berlin")).date()

    day_number = target_date.toordinal()
    seed = int(hashlib.sha256(f"{item_key}:{target_date.isoformat()}".encode("utf-8")).hexdigest()[:8], 16)
    daily_wave = math.sin(day_number / 2.7 + seed % 31) * item["volatility"]
    chaos = ((seed % 1000) / 1000 - 0.5) * item["volatility"] * 0.8
    trend = math.sin(day_number / 17 + len(item_key)) * 0.025
    multiplier = max(0.70, min(1.35, 1 + daily_wave + chaos + trend))
    return max(1, int(round(item["base"] * multiplier)))


def get_market_buy_price(item_key):
    return int(math.ceil(get_market_price(item_key) * (1 + MARKET_SPREAD)))


def get_market_sell_price(item_key):
    return max(1, int(math.floor(get_market_price(item_key) * (1 - MARKET_SPREAD))))


def get_market_daily_trade_amount(username, item_key, action):
    today = datetime.now(ZoneInfo("Europe/Berlin")).date().isoformat()
    trades = api_get_optional(
        "market_trades"
        f"?select=quantity&username=eq.{urllib.parse.quote(username)}"
        f"&item_key=eq.{urllib.parse.quote(item_key)}"
        f"&action=eq.{urllib.parse.quote(action)}"
        f"&created_at=gte.{today}T00:00:00%2B00:00"
    )
    return sum(int(trade.get("quantity") or 0) for trade in trades)


def get_market_history(item_key, days=30):
    today = datetime.now(ZoneInfo("Europe/Berlin")).date()
    return [
        {
            "Datum": today - timedelta(days=offset),
            "Preis": max(1, int(math.floor(get_market_price(item_key, today - timedelta(days=offset)) * (1 - MARKET_SPREAD)))),
        }
        for offset in range(days - 1, -1, -1)
    ]


@st.cache_data(ttl=90)
def get_market_inventory(username):
    if not username:
        return []

    return api_get_optional(
        "market_inventory"
        f"?select=*&username=eq.{urllib.parse.quote(username)}"
        "&order=item_key.asc"
    )


def get_market_quantity(username, item_key):
    inventory = get_market_inventory(username)
    for row in inventory:
        if row.get("item_key") == item_key:
            return int(row.get("quantity") or 0)
    return 0


def set_market_quantity(username, item_key, quantity):
    username = username.strip()
    item = get_market_item(item_key)
    if not username or not item:
        return False

    existing = api_get_optional(
        "market_inventory"
        f"?select=id,quantity&username=eq.{urllib.parse.quote(username)}"
        f"&item_key=eq.{urllib.parse.quote(item_key)}"
        "&limit=1"
    )
    payload = {
        "username": username,
        "item_key": item_key,
        "quantity": int(quantity),
        "updated_at": datetime.now(ZoneInfo("Europe/Berlin")).isoformat(),
    }

    if existing:
        success = api_patch(f"market_inventory?id=eq.{existing[0]['id']}", payload)
    else:
        success = bool(api_post_optional("market_inventory", payload))

    get_market_inventory.clear()
    return success


def log_market_trade(username, item_key, action, quantity, price):
    api_post_optional(
        "market_trades",
        {
            "username": username,
            "item_key": item_key,
            "action": action,
            "quantity": int(quantity),
            "price": int(price),
            "created_at": datetime.now(ZoneInfo("Europe/Berlin")).isoformat(),
        }
    )


def buy_market_item(username, item_key, quantity):
    user = get_user(username)
    item = get_market_item(item_key)
    quantity = int(quantity)
    if not user or not item or quantity <= 0:
        return False, "Ungültiger Kauf."

    already_bought = get_market_daily_trade_amount(username, item_key, "buy")
    if already_bought + quantity > MARKET_DAILY_BUY_LIMIT:
        remaining = max(0, MARKET_DAILY_BUY_LIMIT - already_bought)
        return False, f"Tageslimit erreicht. Du kannst heute noch {remaining}x davon kaufen."

    price = get_market_buy_price(item_key)
    total = price * quantity
    chickens = int(user.get("chickens") or 0)
    if chickens < total:
        return False, "Nicht genug Chickens für diesen Kauf."

    current_qty = get_market_quantity(username, item_key)
    if not update_user(username, chickens - total, int(user.get("braincells") or 0)):
        return False, "Chickens konnten nicht abgezogen werden."
    if not set_market_quantity(username, item_key, current_qty + quantity):
        update_user(username, chickens, int(user.get("braincells") or 0))
        return False, "Inventar konnte nicht aktualisiert werden."

    log_market_trade(username, item_key, "buy", quantity, price)
    get_members.clear()
    get_leaderboard.clear()
    return True, f"{quantity}x {item['emoji']} {item['name']} gekauft."


def sell_market_item(username, item_key, quantity):
    user = get_user(username)
    item = get_market_item(item_key)
    quantity = int(quantity)
    if not user or not item or quantity <= 0:
        return False, "Ungültiger Verkauf."

    current_qty = get_market_quantity(username, item_key)
    if current_qty < quantity:
        return False, "Du besitzt nicht genug davon."

    already_sold = get_market_daily_trade_amount(username, item_key, "sell")
    if already_sold + quantity > MARKET_DAILY_SELL_LIMIT:
        remaining = max(0, MARKET_DAILY_SELL_LIMIT - already_sold)
        return False, f"Tageslimit erreicht. Du kannst heute noch {remaining}x davon verkaufen."

    price = get_market_sell_price(item_key)
    total = price * quantity
    if not update_user(username, int(user.get("chickens") or 0) + total, int(user.get("braincells") or 0)):
        return False, "Chickens konnten nicht gutgeschrieben werden."
    if not set_market_quantity(username, item_key, current_qty - quantity):
        return False, "Inventar konnte nicht aktualisiert werden."

    log_market_trade(username, item_key, "sell", quantity, price)
    get_members.clear()
    get_leaderboard.clear()
    return True, f"{quantity}x {item['emoji']} {item['name']} verkauft."

@st.cache_data(ttl=300)
def get_events():
    return api_get("events?select=*&order=id.desc")

def create_event(title, description, event_date):
    return api_post(
        "events",
        {
            "title": title,
            "description": description,
            "event_date": event_date,
            "created_at": datetime.now().isoformat()
        }
    )

def delete_event(event_id):
    api_delete(f"event_signups?event_id=eq.{event_id}")
    return api_delete(f"events?id=eq.{event_id}")

def get_event_signups(event_id):
    return api_get(f"event_signups?event_id=eq.{event_id}&select=*")

def is_signed_up(event_id, username):
    username = username.strip()
    data = api_get(f"event_signups?event_id=eq.{event_id}&username=eq.{urllib.parse.quote(username)}")
    return len(data) > 0

def signup_event(event_id, username):
    username = username.strip()

    if username == "":
        return False

    if is_signed_up(event_id, username):
        return False

    get_or_create_user(username)

    api_post(
        "event_signups",
        {
            "event_id": event_id,
            "username": username,
            "created_at": datetime.now().isoformat()
        }
    )

    return True

def leave_event(event_id, username):
    username = username.strip()
    return api_delete(f"event_signups?event_id=eq.{event_id}&username=eq.{urllib.parse.quote(username)}")

# =========================
# SHOP
# =========================

DEFAULT_REWARDS = [
    {
        "name": "⭐ 1 Woche VIP",
        "price": 10000,
        "desc": "VIP für 1 Woche",
        "category": "In Stream Rewards"
    },
    {
        "name": "🎮 Steam Random Key",
        "price": 50000,
        "desc": "Zufälliger Steam Key",
        "category": "Out of Stream Rewards"
    },
    {
        "name": "💬 Discord Frage",
        "price": 5000,
        "desc": "Frage im Discord stellen",
        "category": "In Stream Rewards"
    },
    {
        "name": "🖼️ Zuschauerbild neben Facecam",
        "price": 2500,
        "desc": "Bild neben der Facecam",
        "category": "In Stream Rewards"
    }
]


@st.cache_data(ttl=300)
def get_shop_items():
    items = api_get_optional("shop_items?select=*&active=eq.true&order=price.asc")

    if not items:
        return DEFAULT_REWARDS

    return [
        {
            "id": item.get("id"),
            "name": item.get("name"),
            "price": int(item.get("price") or 0),
            "desc": item.get("description") or "",
            "category": item.get("category") or get_default_shop_category()
        }
        for item in items
    ]


def create_shop_item(name, description, price, category=None):
    if not name.strip() or int(price) <= 0:
        return None

    category = category if category in SHOP_CATEGORIES else get_default_shop_category()
    created = api_post(
        "shop_items",
        {
            "name": name.strip()[:100],
            "description": description.strip()[:300],
            "price": int(price),
            "category": category,
            "active": True,
            "created_at": datetime.now().isoformat()
        }
    )
    get_shop_items.clear()
    return created


def delete_shop_item(item_id):
    success = api_patch(
        f"shop_items?id=eq.{item_id}",
        {"active": False}
    )
    get_shop_items.clear()
    return success


def update_shop_item(item_id, name, description, price, category=None):
    if not item_id or not str(name).strip() or int(price) <= 0:
        return False

    category = category if category in SHOP_CATEGORIES else get_default_shop_category()
    success = api_patch(
        f"shop_items?id=eq.{item_id}",
        {
            "name": str(name).strip()[:100],
            "description": str(description).strip()[:300],
            "price": int(price),
            "category": category,
        }
    )
    get_shop_items.clear()
    return success


def buy_reward(username, reward):
    user = get_user(username)

    if user is None:
        return False, "User konnte nicht geladen werden."

    current = int(user["chickens"])

    if current < reward["price"]:
        return False, "Nicht genug Chickens."

    reward_category = reward.get("category") or get_default_shop_category()
    is_wheel_reward = is_wheel_reward_category(reward_category)

    if not update_user(
        username,
        current - reward["price"],
        int(user["braincells"])
    ):
        return False, "Chickens konnten nicht abgezogen werden."

    extended_purchase = api_post_optional(
        "purchases",
        {
            "username": username,
            "reward_name": reward["name"],
            "price": reward["price"],
            "reward_category": reward_category,
            "status": "open",
            "created_at": datetime.now().isoformat()
        }
    )
    if not extended_purchase:
        if is_wheel_reward:
            update_user(username, current, int(user["braincells"]))
            get_leaderboard.clear()
            get_members.clear()
            return False, "Kauf abgebrochen: Damit Bestrafungen und Aufgaben im Rad landen, muss in Supabase die Purchases-Migration mit reward_category und status aktiv sein."
        fallback_purchase = api_post(
            "purchases",
            {
                "username": username,
                "reward_name": reward["name"],
                "price": reward["price"],
                "created_at": datetime.now().isoformat()
            }
        )
        if not fallback_purchase:
            update_user(username, current, int(user["braincells"]))
            get_leaderboard.clear()
            get_members.clear()
            return False, "Kauf konnte nicht gespeichert werden."

    get_leaderboard.clear()
    get_members.clear()
    get_wheel_entries.clear()
    return True, "Gekauft! Der Eintrag ist im Rad gelandet." if is_wheel_reward else "Gekauft!"


PATCH_NOTES = [
    {
        "version": "Patch 1.0",
        "title": "Chicken Jump, Shop und Rangliste",
        "date": "16.05.2026",
        "changes": [
            "Chicken Jump optisch überarbeitet mit neuem Hintergrund, Holz-Zäunen, Partikeln und MP3-Musik.",
            "Chicken Jump Steuerung verbessert: kurzer Tap für kurzen Sprung, gedrückt halten für höheren Sprung.",
            "Chicken Jump Schwierigkeit angepasst, damit der Anfang leichter ist und später fair schwerer wird.",
            "Chicken-Jump-Scoreboard zeigt pro Namen nur noch den höchsten Score.",
            "Ranglisten-Tab als Dashboard mit Podium, Nummer-1-Highlight und Ranking-Karten neu gestaltet.",
            "Shop und Admin-Bereich um übersichtlichere Dashboard-Infos erweitert.",
            "Profil mit Level-System und Events als Ticket-Karten ergänzt.",
        ],
    },
]


@st.cache_data(ttl=180)
def get_patch_notes():
    rows = api_get_optional(
        "patch_notes?select=*&active=eq.true&order=published_at.desc,created_at.desc&limit=30"
    )
    if not rows:
        return PATCH_NOTES

    notes = []
    for row in rows:
        changes = [
            line.strip()
            for line in str(row.get("changes") or "").splitlines()
            if line.strip()
        ]
        if not changes:
            continue

        published_at = str(row.get("published_at") or row.get("created_at") or "")
        date_text = published_at[:10]
        try:
            date_text = datetime.fromisoformat(published_at.replace("Z", "+00:00")).strftime("%d.%m.%Y")
        except ValueError:
            pass

        notes.append(
            {
                "version": str(row.get("version") or "Patch"),
                "title": str(row.get("title") or "Update"),
                "date": date_text,
                "changes": changes,
                "id": row.get("id"),
            }
        )

    return notes or PATCH_NOTES


def create_patch_note(version, title, changes, published_date):
    clean_changes = "\n".join(
        line.strip()
        for line in str(changes).splitlines()
        if line.strip()
    )
    if not str(version).strip() or not str(title).strip() or not clean_changes:
        return None

    published_at = datetime.combine(
        published_date,
        datetime.now(ZoneInfo("Europe/Berlin")).time(),
        tzinfo=ZoneInfo("Europe/Berlin"),
    ).isoformat()

    created = api_post(
        "patch_notes",
        {
            "version": str(version).strip()[:80],
            "title": str(title).strip()[:160],
            "changes": clean_changes[:4000],
            "active": True,
            "published_at": published_at,
            "created_at": datetime.now(ZoneInfo("Europe/Berlin")).isoformat(),
        }
    )
    get_patch_notes.clear()
    return created


def delete_patch_note(note_id):
    success = api_patch(f"patch_notes?id=eq.{urllib.parse.quote(str(note_id))}", {"active": False})
    get_patch_notes.clear()
    return success

# =========================
# DESIGN
# =========================

st.markdown("""
<style>

.stApp {
    background:
    radial-gradient(circle at 12% 16%, rgba(199,125,255,0.24), transparent 28%),
    radial-gradient(circle at 86% 8%, rgba(255,84,160,0.18), transparent 24%),
    radial-gradient(circle at 72% 78%, rgba(123,44,191,0.22), transparent 32%),
    linear-gradient(145deg, #07070d 0%, #160d22 48%, #090712 100%);
    color: white;
    animation: glowmove 12s infinite alternate;
}

@keyframes glowmove {
    0% {
        background-position: 0% 0%;
    }

    100% {
        background-position: 100% 100%;
    }
}

.block-container {
    max-width: 1320px;
    padding-top: 1.9rem;
    padding-bottom: 3rem;
}

h1 {
    text-align: left;
    font-size: clamp(46px, 7vw, 88px) !important;
    line-height: 0.9;
    color: #ffffff;
    margin: 12px 0 20px !important;
    text-shadow: 0 0 34px rgba(255,84,160,0.24);
}

h1::after {
    content: "Community Control, Rewards und Rankings";
    display: block;
    margin-top: 14px;
    color: #f0c9ff;
    font-size: 16px;
    font-weight: 800;
    letter-spacing: 0;
    text-shadow: none;
}

.topbar {
    background:
        linear-gradient(135deg, rgba(199,125,255,0.16), rgba(255,84,160,0.08)),
        rgba(8,10,18,0.72);
    border-radius: 14px;
    padding: 12px 14px;
    margin-bottom: 10px;
    border: 1px solid rgba(255,255,255,0.13);
    backdrop-filter: blur(14px);
    min-height: 62px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
    position: relative;
    z-index: 1000;
    overflow: visible;
    box-shadow: 0 18px 50px rgba(0,0,0,0.30);
}

.topbar-brand {
    display: inline-flex;
    align-items: center;
    gap: 12px;
    color: #ffffff;
    font-size: 18px;
    font-weight: 950;
}

.topbar-brand-icon {
    width: 40px;
    height: 40px;
    border-radius: 12px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    background: rgba(255,84,160,0.14);
    border: 1px solid rgba(255,84,160,0.42);
    box-shadow: 0 0 28px rgba(255,84,160,0.30);
}

.topbar-right {
    display: inline-flex;
    align-items: center;
    gap: 10px;
}

.topbar-login-state {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    max-width: min(64vw, 420px);
    padding: 8px 11px;
    border-radius: 999px;
    color: #ffffff;
    background: rgba(8,14,18,0.62);
    border: 1px solid rgba(82,185,160,0.28);
    font-size: 13px;
    font-weight: 850;
    white-space: nowrap;
}

.topbar-login-state span {
    color: #c8fff1;
    overflow: hidden;
    text-overflow: ellipsis;
}

.topbar-login-state.is-guest {
    border-color: rgba(255,193,94,0.28);
}

.topbar-login-state.is-guest span {
    color: #ffe0aa;
}

.topbar-menu-slot {
    width: 52px;
}

.topbar h2 {
    margin: 0;
}

.topbar-stat {
    text-align: center;
    color: #e9ddff;
    font-weight: 900;
}

.topbar-user {
    text-align: right;
    color: #c77dff;
    font-size: 14px;
    font-weight: 800;
    margin-bottom: 8px;
}

.topbar-actions {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
    flex-wrap: wrap;
}

.topbar-actions .stButton > button,
.topbar-actions [data-testid="stPopover"] button {
    min-height: 36px;
    padding: 0.45rem 0.8rem;
    border-radius: 999px;
    font-size: 13px;
}

.topbar-actions [data-testid="stPopover"] {
    display: flex;
    justify-content: flex-end;
}

.account-menu {
    position: relative;
    z-index: 2000;
}

.account-menu summary {
    width: 44px;
    height: 38px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    list-style: none;
    cursor: pointer;
    color: #ffffff;
    font-weight: 900;
    background: rgba(255,255,255,0.075);
    border: 1px solid rgba(255,255,255,0.16);
}

.account-menu summary::-webkit-details-marker {
    display: none;
}

.account-dropdown {
    position: absolute;
    top: 46px;
    right: 0;
    z-index: 3000;
    min-width: 190px;
    border-radius: 14px;
    padding: 8px;
    background: rgba(13,16,26,0.98);
    border: 1px solid rgba(199,125,255,0.30);
    box-shadow: 0 24px 55px rgba(0,0,0,0.45);
}

.account-dropdown a,
.account-dropdown .account-status {
    display: block;
    padding: 10px 12px;
    border-radius: 10px;
    color: #ffffff;
    text-decoration: none;
    font-weight: 850;
}

.account-dropdown .account-status {
    color: #c77dff;
    border-bottom: 1px solid rgba(255,255,255,0.08);
    margin-bottom: 6px;
}

.account-dropdown a:hover {
    background: rgba(199,125,255,0.16);
}

.card,
.metric-card,
.reward-card,
.event-card,
.profile-card {
    background: linear-gradient(180deg, rgba(255,255,255,0.075), rgba(255,255,255,0.038));
    border: 1px solid rgba(255,255,255,0.12);
    border-radius: 14px;
    padding: 24px;
    transition: all 0.25s ease;
    backdrop-filter: blur(12px);
    box-shadow: 0 20px 55px rgba(0,0,0,0.22);
}

.card:hover,
.metric-card:hover,
.reward-card:hover,
.event-card:hover,
.profile-card:hover {
    transform: translateY(-5px);
    box-shadow: 0 22px 65px rgba(255,84,160,0.20);
    border-color: rgba(255,84,160,0.42);
}

.metric-card {
    text-align: left;
    min-height: 128px;
}

.metric-number {
    font-size: 42px;
    font-weight: 950;
}

.metric-label {
    color: #e7c9ff;
    font-weight: 800;
}

.podium-grid,
.arcade-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 16px;
    margin: 18px 0 26px;
}

.podium-card,
.arcade-card {
    background: rgba(255,255,255,0.055);
    border: 1px solid rgba(255,255,255,0.10);
    border-radius: 18px;
    padding: 20px;
    text-align: center;
    box-shadow: 0 18px 45px rgba(0,0,0,0.22);
}

.podium-card.gold {
    border-color: rgba(255,215,0,0.70);
    box-shadow: 0 0 34px rgba(255,215,0,0.20);
}

.podium-rank {
    font-size: 34px;
    font-weight: 900;
}

.podium-name {
    margin-top: 8px;
    font-size: 22px;
    font-weight: 900;
    color: #ffffff;
    word-break: break-word;
}

.podium-score {
    margin-top: 8px;
    color: #c77dff;
    font-weight: 800;
}

.leaderboard-hero {
    display: grid;
    grid-template-columns: minmax(0, 1.35fr) minmax(260px, 0.65fr);
    gap: 16px;
    align-items: stretch;
    margin: 12px 0 18px;
}

.leaderboard-panel,
.leaderboard-focus {
    border-radius: 18px;
    padding: 24px;
    background:
        linear-gradient(135deg, rgba(199,125,255,0.16), rgba(255,84,160,0.10)),
        rgba(255,255,255,0.055);
    border: 1px solid rgba(255,255,255,0.13);
    box-shadow: 0 24px 70px rgba(0,0,0,0.28);
}

.leaderboard-panel h2,
.leaderboard-focus h3 {
    margin: 6px 0 8px;
}

.leaderboard-stats {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 10px;
    margin-top: 16px;
}

.leaderboard-stat {
    border-radius: 12px;
    padding: 14px;
    background: rgba(8,14,18,0.56);
    border: 1px solid rgba(255,255,255,0.09);
}

.leaderboard-stat strong {
    display: block;
    color: #ffffff;
    font-size: 24px;
    line-height: 1;
}

.leaderboard-stat span {
    display: block;
    margin-top: 7px;
    color: #d8ccff;
    font-size: 13px;
    font-weight: 800;
}

.podium-card.gold {
    transform: translateY(-10px);
}

.podium-card.silver,
.podium-card.bronze {
    margin-top: 22px;
}

.rank-list {
    display: grid;
    gap: 10px;
    margin: 14px 0 26px;
}

.rank-row {
    display: grid;
    grid-template-columns: 76px minmax(0, 1fr) minmax(180px, 0.38fr);
    gap: 14px;
    align-items: center;
    border-radius: 14px;
    padding: 14px;
    background: rgba(255,255,255,0.052);
    border: 1px solid rgba(255,255,255,0.10);
    box-shadow: 0 16px 42px rgba(0,0,0,0.20);
}

.rank-row.top {
    border-color: rgba(255,215,0,0.28);
    background:
        linear-gradient(135deg, rgba(255,215,0,0.08), rgba(255,84,160,0.08)),
        rgba(255,255,255,0.055);
}

.rank-badge {
    width: 56px;
    height: 56px;
    border-radius: 16px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #061015;
    background: linear-gradient(135deg, #c77dff, #ff54a0);
    font-size: 20px;
    font-weight: 950;
}

.rank-main strong {
    display: block;
    color: #ffffff;
    font-size: 19px;
    word-break: break-word;
}

.rank-main span,
.rank-side span {
    display: block;
    margin-top: 5px;
    color: #cfc6e8;
    font-weight: 780;
}

.rank-progress {
    height: 9px;
    border-radius: 999px;
    overflow: hidden;
    background: rgba(255,255,255,0.10);
    margin-top: 10px;
}

.rank-progress div {
    height: 100%;
    border-radius: inherit;
    background: linear-gradient(90deg, #c77dff, #ff54a0, #00f5ff);
}

.rank-side {
    text-align: right;
}

.rank-side strong {
    display: block;
    color: #ffffff;
    font-size: 18px;
}

.section-kicker {
    color: #ff7ad9;
    font-size: 13px;
    font-weight: 900;
    letter-spacing: 0.06em;
    text-transform: uppercase;
}

.arcade-card {
    text-align: left;
}

.arcade-card strong {
    display: block;
    margin-bottom: 6px;
    font-size: 18px;
}

.arcade-card span {
    color: #cfc6e8;
}

.profile-hero,
.member-card {
    background:
        linear-gradient(150deg, rgba(199,125,255,0.14), rgba(255,84,160,0.09)),
        rgba(255,255,255,0.055);
    border: 1px solid rgba(255,255,255,0.13);
    border-radius: 14px;
    padding: 22px;
    box-shadow: 0 18px 45px rgba(0,0,0,0.25);
}

.profile-hero {
    display: grid;
    grid-template-columns: auto 1fr;
    gap: 18px;
    align-items: center;
    margin-bottom: 18px;
}

.profile-avatar {
    border-radius: 22px;
    object-fit: cover;
    border: 2px solid rgba(255,84,160,0.55);
    box-shadow: 0 0 30px rgba(255,84,160,0.24);
    background: linear-gradient(135deg, #7b2cbf, #c77dff, #ff54a0);
}

.profile-initials {
    display: flex;
    align-items: center;
    justify-content: center;
    color: #05050a;
    font-size: 30px;
    font-weight: 900;
}

.profile-name {
    font-size: 30px;
    font-weight: 900;
    line-height: 1.1;
}

.profile-meta {
    margin-top: 8px;
    color: #d8ccff;
    font-weight: 800;
}

.profile-bio {
    margin-top: 12px;
    color: #f3ecff;
    line-height: 1.55;
}

.members-dashboard {
    position: relative;
    overflow: hidden;
    margin: 4px 0 24px;
    padding: 28px;
    border-radius: 10px;
    background:
        radial-gradient(circle at 80% 18%, rgba(255,84,160,0.22), transparent 28%),
        radial-gradient(circle at 14% 78%, rgba(199,125,255,0.18), transparent 30%),
        linear-gradient(145deg, rgba(8,8,22,0.96), rgba(16,8,34,0.94));
    border: 1px solid rgba(255,255,255,0.12);
    box-shadow: 0 30px 90px rgba(0,0,0,0.42);
}

.members-dashboard::before {
    content: "";
    position: absolute;
    inset: 0;
    background:
        linear-gradient(rgba(255,255,255,0.025) 1px, transparent 1px),
        linear-gradient(90deg, rgba(255,255,255,0.025) 1px, transparent 1px);
    background-size: 42px 42px;
    pointer-events: none;
}

.members-dashboard > * {
    position: relative;
    z-index: 1;
}

.members-hero {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(260px, 0.36fr);
    gap: 18px;
    align-items: stretch;
}

.members-hero-main,
.members-spotlight {
    border-radius: 8px;
    padding: 24px;
    background: rgba(8,14,24,0.62);
    border: 1px solid rgba(255,255,255,0.11);
    box-shadow: 0 18px 44px rgba(0,0,0,0.24);
}

.members-hero-main h2 {
    margin: 8px 0 10px;
    font-size: clamp(36px, 5vw, 66px);
    line-height: 0.96;
    letter-spacing: 0;
    background: linear-gradient(135deg, #ffffff, #c77dff 44%, #ff54a0);
    -webkit-background-clip: text;
    color: transparent;
}

.members-hero-main p,
.members-spotlight p {
    color: #d8ccff;
    font-weight: 760;
    line-height: 1.55;
}

.members-stat-row {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 12px;
    margin-top: 20px;
}

.members-stat {
    border-radius: 8px;
    padding: 14px;
    background: rgba(255,255,255,0.055);
    border: 1px solid rgba(255,255,255,0.10);
}

.members-stat strong {
    display: block;
    color: #ffffff;
    font-size: 26px;
    line-height: 1;
}

.members-stat span {
    display: block;
    margin-top: 8px;
    color: #ff9ee4;
    font-weight: 850;
}

.members-spotlight {
    background:
        radial-gradient(circle at 80% 18%, rgba(255,84,160,0.22), transparent 30%),
        rgba(8,14,24,0.68);
}

.members-spotlight h3 {
    margin: 8px 0 6px;
    color: #ffffff;
    font-size: 30px;
    line-height: 1;
    word-break: break-word;
}

.members-spotlight-score {
    display: inline-flex;
    gap: 8px;
    margin-top: 10px;
    padding: 8px 11px;
    border-radius: 999px;
    color: #ffd6f0;
    background: rgba(255,84,160,0.14);
    border: 1px solid rgba(255,84,160,0.28);
    font-weight: 950;
}

.member-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 16px;
    margin-top: 18px;
}

.member-card {
    min-height: 330px;
    position: relative;
    overflow: hidden;
    border-radius: 10px;
    padding: 18px;
    background:
        radial-gradient(circle at 84% 12%, rgba(255,84,160,0.16), transparent 30%),
        linear-gradient(145deg, rgba(199,125,255,0.10), rgba(255,84,160,0.06)),
        rgba(8,14,24,0.74);
    border: 1px solid rgba(255,255,255,0.12);
    box-shadow: 0 22px 60px rgba(0,0,0,0.30);
}

.member-card::before {
    content: "";
    position: absolute;
    inset: 0 0 auto 0;
    height: 4px;
    background: linear-gradient(90deg, #7b2cbf, #c77dff, #ff54a0);
    box-shadow: 0 0 22px rgba(255,84,160,0.52);
}

.member-card::after {
    content: "";
    position: absolute;
    right: -70px;
    top: -70px;
    width: 160px;
    height: 160px;
    border-radius: 999px;
    background: rgba(255,84,160,0.12);
    filter: blur(10px);
    pointer-events: none;
}

.member-rank-pill {
    position: absolute;
    top: 14px;
    right: 14px;
    padding: 7px 10px;
    border-radius: 999px;
    color: #061015;
    background: linear-gradient(135deg, #c77dff, #ff54a0);
    font-size: 12px;
    font-weight: 950;
    box-shadow: 0 12px 26px rgba(255,84,160,0.22);
}

.member-mini-progress {
    height: 10px;
    margin-top: 16px;
    border-radius: 999px;
    overflow: hidden;
    background: rgba(255,255,255,0.10);
    border: 1px solid rgba(255,255,255,0.08);
}

.member-mini-progress div {
    height: 100%;
    border-radius: inherit;
    background: linear-gradient(90deg, #7b2cbf, #c77dff, #ff54a0);
    box-shadow: 0 0 18px rgba(255,84,160,0.36);
}

.member-card .profile-avatar {
    margin-bottom: 12px;
    box-shadow: 0 0 32px rgba(255,84,160,0.28);
}

.member-card .profile-name {
    padding-right: 54px;
}

.member-stat-strip {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 8px;
    margin-top: 14px;
}

.member-stat-chip {
    border-radius: 8px;
    padding: 10px;
    background: rgba(255,255,255,0.06);
    border: 1px solid rgba(255,255,255,0.09);
}

.member-stat-chip strong {
    display: block;
    color: #ffffff;
    font-size: 18px;
}

.member-stat-chip span {
    color: #ff9ee4;
    font-size: 12px;
    font-weight: 850;
}

.member-favorite {
    margin-top: 12px;
    color: #ff9ee4;
    font-weight: 850;
}

.profile-shell {
    display: grid;
    grid-template-columns: minmax(0, 1.25fr) minmax(280px, 0.75fr);
    gap: 18px;
    align-items: stretch;
    margin-top: 12px;
}

.profile-showcase {
    position: relative;
    overflow: hidden;
    min-height: 360px;
    border-radius: 18px;
    padding: 30px;
    background:
        linear-gradient(135deg, rgba(123,44,191,0.24), rgba(199,125,255,0.16), rgba(255,84,160,0.18)),
        rgba(255,255,255,0.06);
    border: 1px solid rgba(255,255,255,0.16);
    box-shadow: 0 28px 80px rgba(0,0,0,0.38);
}

.profile-showcase::before {
    content: "";
    position: absolute;
    inset: -45% -20% auto auto;
    width: 420px;
    height: 420px;
    background: radial-gradient(circle, rgba(255,84,160,0.22), transparent 62%);
    pointer-events: none;
}

.profile-showcase-inner {
    position: relative;
    z-index: 1;
    display: grid;
    grid-template-columns: auto 1fr;
    gap: 24px;
    align-items: center;
}

.profile-rank-badge {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    width: fit-content;
    margin-bottom: 14px;
    padding: 8px 12px;
    border-radius: 999px;
    color: #061015;
    background: linear-gradient(135deg, #c77dff, #ff54a0);
    font-size: 13px;
    font-weight: 950;
}

.profile-big-name {
    font-size: clamp(38px, 6vw, 72px);
    line-height: 0.95;
    font-weight: 950;
    margin-bottom: 12px;
    text-shadow: 0 0 30px rgba(255,84,160,0.20);
}

.profile-bio-large {
    max-width: 680px;
    color: #f5efff;
    font-size: 17px;
    line-height: 1.65;
}

.profile-chip-row {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
    margin-top: 18px;
}

.profile-chip {
    padding: 9px 12px;
    border-radius: 999px;
    color: #effcff;
    background: rgba(199,125,255,0.10);
    border: 1px solid rgba(255,84,160,0.20);
    font-weight: 850;
}

.profile-side-panel,
.admin-panel {
    border-radius: 14px;
    padding: 22px;
    background: rgba(8,14,18,0.78);
    border: 1px solid rgba(255,255,255,0.13);
    box-shadow: 0 18px 50px rgba(0,0,0,0.26);
}

.profile-stat-grid,
.admin-stat-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 12px;
    margin: 18px 0;
}

.profile-stat,
.admin-stat {
    min-height: 92px;
    border-radius: 12px;
    padding: 16px;
    background: rgba(255,255,255,0.065);
    border: 1px solid rgba(255,255,255,0.10);
}

.profile-stat strong,
.admin-stat strong {
    display: block;
    font-size: 28px;
    line-height: 1;
    color: #ffffff;
}

.profile-stat span,
.admin-stat span {
    display: block;
    margin-top: 8px;
    color: #cfc6e8;
    font-size: 13px;
    font-weight: 800;
}

.profile-progress-track {
    height: 16px;
    border-radius: 999px;
    overflow: hidden;
    background: rgba(255,255,255,0.10);
    border: 1px solid rgba(255,255,255,0.08);
    margin: 14px 0 10px;
}

.profile-progress-fill {
    height: 100%;
    border-radius: inherit;
    background: linear-gradient(90deg, #7b2cbf, #c77dff, #ff54a0);
    box-shadow: 0 0 24px rgba(255,84,160,0.32);
}

.profile-level-card {
    margin: 14px 0 16px;
    border-radius: 14px;
    padding: 16px;
    background:
        linear-gradient(135deg, rgba(199,125,255,0.14), rgba(255,84,160,0.09)),
        rgba(255,255,255,0.055);
    border: 1px solid rgba(255,255,255,0.12);
}

.profile-level-top {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 12px;
    margin-bottom: 12px;
}

.profile-level-top strong {
    display: block;
    color: #ffffff;
    font-size: 24px;
    line-height: 1;
}

.profile-level-top span {
    color: #cfc6e8;
    font-weight: 800;
}

.profile-level-badge {
    flex: 0 0 auto;
    padding: 7px 10px;
    border-radius: 999px;
    background: rgba(255,84,160,0.16);
    border: 1px solid rgba(255,84,160,0.30);
    color: #ffd6f0;
    font-size: 12px;
    font-weight: 950;
}

.profile-xp-row {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    margin-top: 10px;
    color: #d8ccff;
    font-size: 13px;
    font-weight: 800;
}

.event-ticket {
    display: grid;
    grid-template-columns: 118px minmax(0, 1fr) minmax(150px, 0.32fr);
    gap: 16px;
    align-items: stretch;
    margin: 16px 0 10px;
    border-radius: 16px;
    overflow: hidden;
    background: rgba(255,255,255,0.055);
    border: 1px solid rgba(255,255,255,0.13);
    box-shadow: 0 20px 55px rgba(0,0,0,0.24);
}

.event-ticket-date {
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    min-height: 150px;
    background: linear-gradient(135deg, rgba(199,125,255,0.24), rgba(255,84,160,0.16));
    border-right: 1px dashed rgba(255,255,255,0.22);
}

.event-ticket-date strong {
    color: #ffffff;
    font-size: 26px;
    line-height: 1;
}

.event-ticket-date span {
    margin-top: 8px;
    color: #f0c9ff;
    font-weight: 900;
}

.event-ticket-main {
    padding: 20px 0;
}

.event-ticket-main h3 {
    margin: 0 0 8px;
    color: #ffffff;
    font-size: 24px;
}

.event-ticket-main p {
    margin: 0;
    color: #d8ccff;
    line-height: 1.55;
}

.event-ticket-side {
    display: flex;
    flex-direction: column;
    justify-content: center;
    gap: 8px;
    padding: 18px;
    background: rgba(8,14,18,0.42);
}

.event-ticket-status {
    width: fit-content;
    padding: 7px 10px;
    border-radius: 999px;
    color: #061015;
    background: linear-gradient(135deg, #c77dff, #ff54a0);
    font-size: 12px;
    font-weight: 950;
}

.event-ticket-status.joined {
    background: linear-gradient(135deg, #7CFFB2, #00f5ff);
}

.event-ticket-count {
    color: #ffffff;
    font-size: 28px;
    font-weight: 950;
}

.patch-notes-shell {
    display: grid;
    gap: 16px;
    margin: 18px 0 30px;
}

.patch-note-card {
    border-radius: 18px;
    padding: 24px;
    background:
        linear-gradient(135deg, rgba(199,125,255,0.16), rgba(255,84,160,0.10)),
        rgba(255,255,255,0.055);
    border: 1px solid rgba(255,255,255,0.13);
    box-shadow: 0 24px 70px rgba(0,0,0,0.28);
}

.patch-note-head {
    display: flex;
    justify-content: space-between;
    gap: 14px;
    align-items: flex-start;
    margin-bottom: 14px;
}

.patch-note-head h3 {
    margin: 4px 0 0;
    color: #ffffff;
}

.patch-version {
    width: fit-content;
    padding: 7px 11px;
    border-radius: 999px;
    color: #061015;
    background: linear-gradient(135deg, #c77dff, #ff54a0);
    font-size: 12px;
    font-weight: 950;
}

.patch-date {
    color: #cfc6e8;
    font-weight: 850;
    white-space: nowrap;
}

.patch-change-list {
    margin: 0;
    padding-left: 20px;
    color: #f3ecff;
    line-height: 1.65;
}

.profile-edit-wrap {
    margin-top: 18px;
    padding: 22px;
    border-radius: 18px;
    background: rgba(255,255,255,0.045);
    border: 1px solid rgba(255,255,255,0.09);
}

.admin-hero {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    gap: 18px;
    margin: 10px 0 18px;
    padding: 26px;
    border-radius: 22px;
    background:
        linear-gradient(135deg, rgba(199,125,255,0.18), rgba(255,84,160,0.12)),
        rgba(255,255,255,0.05);
    border: 1px solid rgba(255,255,255,0.11);
}

.admin-hero h2 {
    margin: 4px 0 0;
    font-size: 36px;
}

.admin-list-item {
    padding: 14px 0;
    border-bottom: 1px solid rgba(255,255,255,0.08);
}

.admin-list-item:last-child {
    border-bottom: 0;
}

.admin-muted {
    color: #cfc6e8;
    font-weight: 750;
}

.support-shell {
    display: grid;
    grid-template-columns: minmax(0, 0.9fr) minmax(320px, 1.1fr);
    gap: 18px;
    align-items: start;
    margin: 12px 0 26px;
}

.support-intro,
.wish-card {
    border-radius: 10px;
    padding: 22px;
    background: rgba(8,14,18,0.74);
    border: 1px solid rgba(255,255,255,0.12);
    box-shadow: 0 18px 48px rgba(0,0,0,0.24);
}

.support-intro h2,
.wish-card h3 {
    margin: 6px 0 10px;
    color: #ffffff;
}

.support-intro p,
.wish-card p {
    color: #d8ccff;
    line-height: 1.55;
}

.wish-list {
    display: grid;
    gap: 14px;
    margin-top: 16px;
}

.wish-meta {
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
    color: #cfc6e8;
    font-size: 13px;
    font-weight: 800;
}

.wish-score-row {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
    margin-top: 14px;
}

.wish-score-pill {
    padding: 8px 11px;
    border-radius: 999px;
    color: #effcff;
    background: rgba(255,255,255,0.075);
    border: 1px solid rgba(255,255,255,0.12);
    font-weight: 900;
}

.home-dashboard {
    position: relative;
    overflow: hidden;
    margin: 4px 0 28px;
    padding: 28px;
    border-radius: 10px;
    background:
        radial-gradient(circle at 68% 18%, rgba(255,84,160,0.25), transparent 28%),
        radial-gradient(circle at 30% 88%, rgba(123,44,191,0.18), transparent 30%),
        linear-gradient(145deg, rgba(8,8,22,0.96), rgba(16,8,34,0.94));
    border: 1px solid rgba(255,255,255,0.12);
    box-shadow: 0 30px 90px rgba(0,0,0,0.42);
}

.home-dashboard::before {
    content: "";
    position: absolute;
    inset: 0;
    background:
        linear-gradient(rgba(255,255,255,0.025) 1px, transparent 1px),
        linear-gradient(90deg, rgba(255,255,255,0.025) 1px, transparent 1px);
    background-size: 42px 42px;
    mask-image: linear-gradient(180deg, rgba(0,0,0,0.95), transparent 82%);
    pointer-events: none;
}

.home-dashboard > * {
    position: relative;
    z-index: 1;
}

.home-hero {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(280px, 0.34fr);
    gap: 20px;
    align-items: stretch;
    margin: 12px 0 18px;
}

.home-spotlight {
    position: relative;
    overflow: hidden;
    border-radius: 8px;
    min-height: 360px;
    padding: 38px;
    background:
        radial-gradient(circle at 88% 44%, rgba(255,84,160,0.24), transparent 30%),
        radial-gradient(circle at 78% 58%, rgba(199,125,255,0.18), transparent 26%),
        linear-gradient(135deg, rgba(199,125,255,0.10), rgba(255,84,160,0.06)),
        rgba(255,255,255,0.035);
    border: 1px solid rgba(255,255,255,0.11);
    box-shadow: 0 18px 44px rgba(0,0,0,0.24);
    display: flex;
    flex-direction: column;
    justify-content: space-between;
}

.home-spotlight::before {
    content: "";
    position: absolute;
    inset: 0 auto 0 0;
    width: 62%;
    background: linear-gradient(90deg, rgba(8,8,22,0.82), rgba(8,8,22,0.46) 64%, transparent);
    z-index: 1;
    pointer-events: none;
}

.home-spotlight::after {
    content: "";
    position: absolute;
    right: -130px;
    top: 36px;
    width: 390px;
    height: 260px;
    border-radius: 999px;
    background:
        radial-gradient(circle at 52% 46%, rgba(255,84,160,0.34), transparent 38%),
        radial-gradient(circle at 66% 60%, rgba(199,125,255,0.24), transparent 34%);
    filter: blur(8px);
    opacity: 0.58;
    z-index: 0;
}

.home-brain-visual {
    position: absolute;
    right: -52px;
    top: 42px;
    width: clamp(230px, 26vw, 360px);
    max-width: 38%;
    aspect-ratio: 1.25 / 1;
    pointer-events: none;
    z-index: 1;
    opacity: 0.72;
    filter:
        drop-shadow(0 0 16px rgba(255,255,255,0.20))
        drop-shadow(0 0 34px rgba(255,84,160,0.58))
        drop-shadow(0 0 68px rgba(199,125,255,0.44));
}

.home-brain-visual svg {
    width: 100%;
    height: 100%;
    overflow: visible;
}

.home-brain-fill {
    fill: url(#homeBrainFill);
    opacity: 0.42;
}

.home-brain-line {
    fill: none;
    stroke: url(#homeBrainStroke);
    stroke-width: 7;
    stroke-linecap: round;
    stroke-linejoin: round;
    opacity: 0.96;
}

.home-brain-spark {
    fill: #ffd6f0;
    filter: drop-shadow(0 0 12px rgba(255,84,160,0.72));
}

.home-spotlight h2 {
    position: relative;
    z-index: 3;
    max-width: 540px;
    margin: 8px 0 14px;
    font-size: clamp(42px, 6vw, 86px);
    line-height: 0.92;
    letter-spacing: 0;
    background: linear-gradient(135deg, #ffffff, #c77dff 42%, #ff54a0);
    -webkit-background-clip: text;
    color: transparent;
}

.home-spotlight p,
.daily-card p {
    position: relative;
    z-index: 3;
    max-width: 560px;
    color: #d8ccff;
    font-weight: 760;
    font-size: 16px;
}

.home-actions {
    position: relative;
    z-index: 3;
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 12px;
    margin: 24px 0 0;
    max-width: 720px;
}

.home-action-card {
    min-height: 98px;
    border-radius: 8px;
    padding: 16px;
    background: rgba(8,14,24,0.64);
    border: 1px solid rgba(255,255,255,0.12);
    box-shadow: inset 0 0 24px rgba(255,84,160,0.06);
}

.home-action-card strong {
    display: block;
    color: #ffffff;
    font-size: 28px;
    line-height: 1;
    margin-bottom: 8px;
}

.home-action-card span {
    color: #e7c9ff;
    font-weight: 760;
}

.daily-card {
    position: relative;
    overflow: hidden;
    border-radius: 8px;
    min-height: 100%;
    padding: 24px;
    display: flex;
    flex-direction: column;
    justify-content: center;
    background:
        radial-gradient(circle at 78% 12%, rgba(255,84,160,0.22), transparent 24%),
        linear-gradient(135deg, rgba(255,84,160,0.16), rgba(199,125,255,0.10)),
        rgba(255,255,255,0.055);
    border: 1px solid rgba(255,255,255,0.14);
    box-shadow: 0 18px 44px rgba(0,0,0,0.24);
}

.daily-card h3 {
    margin: 6px 0 8px;
    font-size: 30px;
    line-height: 1.08;
}

.daily-card .section-kicker {
    color: #c8fff1;
}

.daily-claim-shell {
    margin: -96px 24px 36px auto;
    max-width: 280px;
    position: relative;
    z-index: 3;
}

.daily-claim-shell .stButton > button {
    min-height: 64px;
    border-radius: 8px;
    border: 1px solid rgba(255,255,255,0.22);
    background: linear-gradient(135deg, #52b9a0, #ff54a0);
    color: #05050a;
    font-size: 17px;
    font-weight: 950;
    box-shadow: 0 18px 42px rgba(255,84,160,0.24);
}

.daily-claim-shell .stButton > button:hover {
    border-color: rgba(255,255,255,0.42);
    transform: translateY(-1px);
    box-shadow: 0 24px 52px rgba(82,185,160,0.22);
}

.home-login-actions {
    margin: -86px 24px 36px auto;
    max-width: 320px;
    position: relative;
    z-index: 3;
}

.home-login-actions .stButton > button {
    min-height: 52px;
    border-radius: 8px;
    font-weight: 950;
}

.home-status-pill {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 8px 10px;
    border-radius: 999px;
    background: rgba(82,185,160,0.16);
    color: #c8fff1;
    border: 1px solid rgba(82,185,160,0.30);
    font-weight: 950;
}

.home-status-pill.is-guest {
    background: rgba(255,193,94,0.14);
    color: #ffe0aa;
    border-color: rgba(255,193,94,0.28);
}

.home-week-art {
    display: grid;
    grid-template-columns: minmax(220px, 0.34fr) minmax(0, 1fr);
    gap: 16px;
    align-items: center;
    margin: 18px 0 0;
    border-radius: 8px;
    padding: 18px;
    background:
        linear-gradient(135deg, rgba(255,84,160,0.10), rgba(199,125,255,0.10)),
        rgba(8,14,24,0.56);
    border: 1px solid rgba(255,255,255,0.12);
    box-shadow: 0 18px 44px rgba(0,0,0,0.24);
}

.home-week-art img {
    width: 100%;
    aspect-ratio: 4 / 3;
    object-fit: contain;
    background: #ffffff;
    border-radius: 6px;
    border: 1px solid rgba(255,255,255,0.16);
}

.home-week-art h3 {
    margin: 6px 0 8px;
    color: #ffffff;
    font-size: 28px;
}

.home-week-art p {
    color: #e5f8ff;
    font-weight: 760;
}

.daily-streak {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    margin: 12px 0;
    padding: 9px 12px;
    border-radius: 999px;
    background: rgba(255,84,160,0.16);
    color: #ffd6f0;
    border: 1px solid rgba(255,84,160,0.30);
    font-weight: 950;
}

.achievement-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 14px;
    margin: 16px 0 8px;
}

.achievement-card {
    position: relative;
    overflow: hidden;
    min-height: 142px;
    border-radius: 10px;
    padding: 18px;
    background:
        radial-gradient(circle at 86% 12%, rgba(255,84,160,0.12), transparent 32%),
        linear-gradient(145deg, rgba(199,125,255,0.09), rgba(255,84,160,0.045)),
        rgba(8,14,24,0.72);
    border: 1px solid rgba(255,255,255,0.11);
    box-shadow: 0 18px 44px rgba(0,0,0,0.26);
}

.achievement-card::before {
    content: "";
    position: absolute;
    inset: 0 0 auto 0;
    height: 3px;
    background: linear-gradient(90deg, #7b2cbf, #c77dff, #ff54a0);
    opacity: 0.55;
}

.achievement-card::after {
    content: "";
    position: absolute;
    right: -42px;
    bottom: -42px;
    width: 110px;
    height: 110px;
    border-radius: 999px;
    background: rgba(255,84,160,0.10);
    filter: blur(8px);
}

.achievement-card.unlocked {
    background:
        radial-gradient(circle at 86% 12%, rgba(255,84,160,0.22), transparent 32%),
        linear-gradient(145deg, rgba(199,125,255,0.18), rgba(255,84,160,0.13)),
        rgba(255,255,255,0.07);
    border-color: rgba(255,84,160,0.36);
    box-shadow: 0 20px 58px rgba(255,84,160,0.14), 0 18px 44px rgba(0,0,0,0.26);
}

.achievement-card.unlocked::before {
    opacity: 1;
    box-shadow: 0 0 18px rgba(255,84,160,0.55);
}

.achievement-card.locked {
    opacity: 0.64;
    filter: grayscale(0.35);
}

.achievement-card strong {
    position: relative;
    z-index: 1;
    display: block;
    margin-bottom: 8px;
    color: #ffffff;
    font-size: 18px;
}

.achievement-card span {
    position: relative;
    z-index: 1;
    color: #d8ccff;
    font-weight: 760;
}

.achievement-card .admin-muted {
    position: relative;
    z-index: 1;
    width: fit-content;
    padding: 6px 9px;
    border-radius: 999px;
    background: rgba(255,255,255,0.055);
    border: 1px solid rgba(255,255,255,0.08);
}

.achievement-card.unlocked .admin-muted {
    color: #ffd6f0;
    border-color: rgba(255,84,160,0.24);
    background: rgba(255,84,160,0.12);
}

.achievement-shell {
    position: relative;
    overflow: hidden;
    margin-top: 12px;
    padding: 18px;
    border-radius: 10px;
    background:
        radial-gradient(circle at 88% 8%, rgba(255,84,160,0.18), transparent 26%),
        linear-gradient(145deg, rgba(8,8,22,0.92), rgba(16,8,34,0.88));
    border: 1px solid rgba(255,255,255,0.11);
    box-shadow: 0 24px 70px rgba(0,0,0,0.32);
}

.achievement-summary {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 14px;
    flex-wrap: wrap;
    margin-bottom: 14px;
}

.achievement-summary h3 {
    margin: 4px 0 0;
    color: #ffffff;
}

.achievement-summary p {
    margin: 0;
    color: #d8ccff;
    font-weight: 760;
}

.achievement-count-pill {
    flex: 0 0 auto;
    padding: 10px 13px;
    border-radius: 999px;
    color: #061015;
    background: linear-gradient(135deg, #c77dff, #ff54a0);
    font-weight: 950;
    box-shadow: 0 14px 32px rgba(255,84,160,0.22);
}

.score-strip {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 12px;
    margin: 16px 0 24px;
}

.score-card {
    border-radius: 14px;
    padding: 16px;
    background: rgba(8,14,18,0.72);
    border: 1px solid rgba(255,255,255,0.11);
}

.score-card strong {
    display: block;
    color: #ffffff;
    font-size: 20px;
}

.score-card span {
    display: block;
    margin-top: 6px;
    color: #f0c9ff;
    font-weight: 800;
}

.creative-shell {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(280px, 0.36fr);
    gap: 16px;
    align-items: start;
    margin: 16px 0 24px;
}

.creative-panel,
.creative-art-card {
    border-radius: 8px;
    padding: 18px;
    background: rgba(8,14,18,0.72);
    border: 1px solid rgba(255,255,255,0.11);
}

.creative-panel h3,
.creative-art-card h3 {
    margin: 6px 0 8px;
}

.creative-toolbar {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 10px;
    margin-top: 12px;
}

.creative-gallery-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 16px;
    margin: 16px 0 28px;
}

.creative-art-card {
    padding: 14px;
}

.creative-art-card img {
    width: 100%;
    aspect-ratio: 4 / 3;
    object-fit: contain;
    background: #ffffff;
    border-radius: 6px;
    border: 1px solid rgba(255,255,255,0.14);
}

.creative-art-card span {
    display: block;
    color: #cfc6e8;
    font-weight: 780;
}

.creative-date {
    width: fit-content;
    margin-top: 8px;
    padding: 7px 10px;
    border-radius: 999px;
    color: #ffd6f0 !important;
    background: rgba(255,84,160,0.14);
    border: 1px solid rgba(255,84,160,0.28);
    font-size: 13px;
}

.creative-reaction-row {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    margin-top: 12px;
}

.creative-reaction-count {
    display: inline-flex !important;
    width: fit-content;
    padding: 6px 8px;
    border-radius: 999px;
    background: rgba(255,255,255,0.075);
    border: 1px solid rgba(255,255,255,0.10);
    color: #ffffff !important;
    font-size: 13px;
}

.creative-reaction-count.active {
    background: rgba(82,185,160,0.18);
    border-color: rgba(82,185,160,0.36);
}

.creative-reaction-picker {
    margin-top: 8px;
    padding: 8px;
    border-radius: 10px;
    background: rgba(8,14,24,0.68);
    border: 1px solid rgba(255,255,255,0.10);
}

.chicken-scoreboard-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 14px;
    margin: 14px 0 26px;
}

.chicken-scoreboard-panel {
    border-radius: 8px;
    padding: 16px;
    background: rgba(8,14,18,0.72);
    border: 1px solid rgba(255,255,255,0.11);
}

.chicken-scoreboard-panel h3 {
    margin: 4px 0 12px;
}

.chicken-score-row {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    padding: 9px 0;
    border-bottom: 1px solid rgba(255,255,255,0.08);
}

.chicken-score-row:last-child {
    border-bottom: 0;
}

.chicken-score-row strong,
.chicken-score-row span {
    color: #ffffff;
    font-weight: 850;
}

.newspaper-grid {
    display: grid;
    grid-template-columns: minmax(0, 1.3fr) minmax(280px, 0.7fr);
    gap: 18px;
    align-items: start;
}

.newspaper-lead,
.news-card {
    background: #f5ecdf;
    color: #161016;
    border: 1px solid rgba(255,255,255,0.18);
    box-shadow: 0 24px 70px rgba(0,0,0,0.32);
}

.newspaper-lead {
    border-radius: 12px;
    padding: 28px;
}

.newspaper-label {
    display: inline-block;
    margin-bottom: 14px;
    padding: 7px 10px;
    border-radius: 999px;
    background: #161016;
    color: #ff7ad9;
    font-size: 12px;
    font-weight: 950;
    text-transform: uppercase;
}

.newspaper-lead h2 {
    color: #161016;
    font-family: Georgia, serif;
    font-size: clamp(34px, 5vw, 66px);
    line-height: 0.95;
    margin: 0 0 16px;
}

.newspaper-lead p,
.news-card p {
    color: #302634;
    font-family: Georgia, serif;
    font-size: 18px;
    line-height: 1.65;
}

.news-image {
    width: 100%;
    aspect-ratio: 16 / 9;
    object-fit: cover;
    border-radius: 8px;
    margin-bottom: 18px;
    border: 1px solid rgba(0,0,0,0.12);
}

.news-stack {
    display: grid;
    gap: 14px;
}

.news-card {
    border-radius: 10px;
    padding: 18px;
}

.news-card h3 {
    color: #161016;
    font-family: Georgia, serif;
    margin: 0 0 10px;
}

.gazette-live {
    margin: 0 0 24px;
    padding: 22px;
    border-radius: 12px;
    background: #f7f0df;
    color: #161016;
    border: 1px solid rgba(255,255,255,0.16);
    box-shadow: 0 24px 70px rgba(0,0,0,0.24);
}

.gazette-live h2 {
    margin: 4px 0 8px;
    color: #161016;
    font-family: Georgia, serif;
}

.gazette-live p {
    color: #403545;
    font-weight: 760;
}

.gazette-card-grid {
    display: grid;
    grid-template-columns: repeat(5, minmax(0, 1fr));
    gap: 12px;
    margin-top: 16px;
}

.gazette-card {
    min-height: 132px;
    padding: 14px;
    border-radius: 8px;
    border: 1px solid rgba(22,16,22,0.16);
    background: rgba(255,255,255,0.54);
}

.gazette-card h3 {
    margin: 8px 0 8px;
    color: #161016;
    font-size: 18px;
    line-height: 1.1;
    font-family: Georgia, serif;
}

.gazette-card p {
    margin: 0;
    font-size: 13px;
}

.dnd-hero,
.dnd-panel,
.dnd-lobby-card,
.dnd-roll-card,
.dnd-session-bar {
    border-radius: 10px;
    border: 1px solid rgba(255,255,255,0.14);
    background: rgba(10,14,22,0.74);
    box-shadow: 0 22px 70px rgba(0,0,0,0.30);
}

.dnd-hero {
    position: relative;
    overflow: hidden;
    padding: 30px;
    margin: 0 0 20px;
    display: grid;
    grid-template-columns: minmax(0, 1.15fr) minmax(280px, 0.85fr);
    gap: 20px;
    align-items: stretch;
    background:
        linear-gradient(115deg, rgba(8,13,24,0.98), rgba(39,18,54,0.90) 52%, rgba(82,28,48,0.78)),
        rgba(10,14,22,0.90);
}

.dnd-hero::before {
    content: "";
    position: absolute;
    inset: 0;
    background:
        linear-gradient(rgba(255,255,255,0.035) 1px, transparent 1px),
        linear-gradient(90deg, rgba(255,255,255,0.035) 1px, transparent 1px);
    background-size: 36px 36px;
    mask-image: linear-gradient(90deg, rgba(0,0,0,0.88), transparent 78%);
    pointer-events: none;
}

.dnd-hero > * {
    position: relative;
    z-index: 1;
}

.dnd-hero h2 {
    max-width: 760px;
    margin: 6px 0 10px;
    font-size: 44px;
    line-height: 1.02;
    color: #ffffff;
}

.dnd-hero p,
.dnd-panel p,
.dnd-lobby-card p {
    color: #e9e2f8;
    font-weight: 760;
    line-height: 1.5;
}

.dnd-rule-grid,
.dnd-lobby-grid,
.dnd-party-grid,
.dnd-roll-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 12px;
}

.dnd-rule-grid {
    grid-template-columns: 1fr;
}

.dnd-panel,
.dnd-lobby-card,
.dnd-roll-card {
    padding: 18px;
}

.dnd-panel {
    background:
        linear-gradient(145deg, rgba(255,255,255,0.075), rgba(255,255,255,0.035)),
        rgba(10,14,22,0.68);
}

.dnd-lobby-card {
    min-height: 176px;
    background:
        linear-gradient(145deg, rgba(124,255,178,0.08), rgba(255,255,255,0.035)),
        rgba(10,14,22,0.72);
}

.dnd-lobby-card h3,
.dnd-roll-card h3,
.dnd-panel h3 {
    margin: 8px 0 8px;
    color: #ffffff;
}

.dnd-pill {
    display: inline-flex;
    align-items: center;
    width: max-content;
    border-radius: 999px;
    padding: 6px 10px;
    color: #071016;
    background: linear-gradient(135deg, #7CFFB2, #00f5ff);
    font-weight: 950;
    font-size: 12px;
}

.dnd-pill.private {
    background: linear-gradient(135deg, #ff8fab, #ff54a0);
}

.dnd-session-bar {
    display: grid;
    grid-template-columns: minmax(0, 1fr) repeat(4, minmax(110px, 0.16fr));
    gap: 14px;
    align-items: stretch;
    margin: 16px 0;
    padding: 18px;
    background:
        linear-gradient(135deg, rgba(0,245,255,0.08), rgba(255,84,160,0.08)),
        rgba(10,14,22,0.78);
}

.dnd-session-title h3 {
    margin: 4px 0 6px;
    font-size: 28px;
    color: #ffffff;
}

.dnd-session-stat {
    display: grid;
    align-content: center;
    min-height: 86px;
    padding: 14px;
    border-radius: 8px;
    background: rgba(255,255,255,0.065);
    border: 1px solid rgba(255,255,255,0.10);
}

.dnd-session-stat strong {
    color: #7CFFB2;
    font-size: 30px;
    line-height: 1;
}

.dnd-session-stat span {
    margin-top: 6px;
    color: #cfc6e8;
    font-size: 12px;
    font-weight: 900;
}

.dnd-section-title {
    display: flex;
    align-items: end;
    justify-content: space-between;
    gap: 12px;
    margin: 24px 0 10px;
}

.dnd-section-title h3 {
    margin: 0;
    color: #ffffff;
}

.dnd-premade-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 12px;
    margin: 10px 0 12px;
}

.dnd-premade-map {
    overflow: hidden;
    border-radius: 10px;
    background: rgba(255,255,255,0.06);
    border: 1px solid rgba(255,255,255,0.11);
}

.dnd-premade-thumb {
    min-height: 116px;
    background-size: cover;
    background-position: center;
    border-bottom: 1px solid rgba(255,255,255,0.12);
}

.dnd-premade-map strong,
.dnd-premade-map span {
    display: block;
    padding: 10px 12px 0;
}

.dnd-premade-map strong {
    color: #ffffff;
}

.dnd-premade-map span {
    padding-top: 3px;
    padding-bottom: 12px;
    color: #cfc6e8;
    font-size: 12px;
    font-weight: 850;
}

.dnd-map-shell {
    margin: 12px 0 22px;
    padding: 14px;
    border-radius: 10px;
    background:
        linear-gradient(135deg, rgba(0,245,255,0.07), rgba(124,255,178,0.06)),
        rgba(10,14,22,0.78);
    border: 1px solid rgba(255,255,255,0.13);
    box-shadow: 0 22px 70px rgba(0,0,0,0.30);
}

.dnd-map-board {
    position: relative;
    overflow: hidden;
    width: 100%;
    aspect-ratio: var(--grid-width) / var(--grid-height);
    min-height: 360px;
    border-radius: 8px;
    background-size:
        calc(100% / var(--grid-width)) calc(100% / var(--grid-height)),
        calc(100% / var(--grid-width)) calc(100% / var(--grid-height)),
        cover;
    background-position:
        0 0,
        0 0,
        center;
    border: 1px solid rgba(255,255,255,0.15);
}

.dnd-map-board::before {
    content: "";
    position: absolute;
    inset: 0;
    background: radial-gradient(circle at 50% 50%, transparent 48%, rgba(0,0,0,0.24));
    pointer-events: none;
}

.dnd-map-fog {
    position: absolute;
    inset: 0;
    z-index: 1;
    background:
        radial-gradient(circle at 38% 42%, transparent 0 18%, rgba(0,0,0,0.38) 28%, rgba(0,0,0,0.92) 72%),
        rgba(0,0,0,0.84);
    pointer-events: none;
}

.dnd-map-token {
    position: absolute;
    z-index: 3;
    display: grid;
    place-items: center;
    width: clamp(34px, calc(70vw / var(--grid-width)), 58px);
    height: clamp(34px, calc(70vw / var(--grid-width)), 58px);
    transform: translate(-50%, -50%);
    border-radius: 999px;
    background: var(--token-color);
    color: #061015;
    border: 3px solid rgba(255,255,255,0.86);
    box-shadow: 0 10px 24px rgba(0,0,0,0.36);
    font-weight: 950;
}

.dnd-map-token.creature {
    border-color: rgba(255,214,223,0.92);
}

.dnd-map-token span {
    font-size: 14px;
    line-height: 1;
}

.dnd-map-token small {
    position: absolute;
    left: 50%;
    top: calc(100% + 5px);
    transform: translateX(-50%);
    max-width: 120px;
    padding: 3px 6px;
    border-radius: 999px;
    color: #effcff;
    background: rgba(6,10,16,0.84);
    border: 1px solid rgba(255,255,255,0.18);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    font-size: 11px;
}

.dnd-map-markers {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 8px;
    margin: 12px 0 0;
    padding: 0;
    list-style: none;
}

.dnd-map-markers li {
    padding: 9px 11px;
    border-radius: 8px;
    color: #effcff;
    background: rgba(255,255,255,0.075);
    border: 1px solid rgba(255,255,255,0.10);
    font-size: 13px;
    font-weight: 800;
}

.dnd-turn-tracker,
.dnd-log-list {
    display: grid;
    gap: 8px;
    margin: 10px 0 18px;
}

.dnd-turn-row,
.dnd-log-row {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    align-items: center;
    padding: 12px 14px;
    border-radius: 8px;
    background: rgba(255,255,255,0.055);
    border: 1px solid rgba(255,255,255,0.09);
}

.dnd-turn-row.active {
    background: linear-gradient(135deg, rgba(124,255,178,0.18), rgba(0,245,255,0.09));
    border-color: rgba(124,255,178,0.35);
}

.dnd-turn-row strong,
.dnd-log-row strong {
    color: #ffffff;
}

.dnd-turn-row span,
.dnd-log-row span {
    color: #cfc6e8;
    font-weight: 800;
    text-align: right;
}

.dnd-roll-card {
    background:
        linear-gradient(145deg, rgba(0,245,255,0.09), rgba(199,125,255,0.06)),
        rgba(10,14,22,0.72);
}

.dnd-roll-card strong {
    display: block;
    margin: 10px 0 4px;
    font-size: 42px;
    color: #7CFFB2;
    line-height: 1;
}

.dnd-character-card {
    position: relative;
    overflow: hidden;
    min-height: 210px;
}

.dnd-character-card::before {
    content: "";
    position: absolute;
    inset: 0;
    background:
        linear-gradient(90deg, rgba(124,255,178,0.13), transparent 38%),
        linear-gradient(180deg, rgba(255,255,255,0.055), transparent 58%);
    pointer-events: none;
}

.dnd-character-card > * {
    position: relative;
    z-index: 1;
}

.dnd-stat-row {
    display: grid;
    grid-template-columns: repeat(6, minmax(0, 1fr));
    gap: 8px;
    margin-top: 14px;
}

.dnd-stat {
    min-height: 62px;
    padding: 10px;
    border-radius: 8px;
    background: rgba(255,255,255,0.075);
    border: 1px solid rgba(255,255,255,0.10);
}

.dnd-stat strong {
    display: block;
    color: #00f5ff;
    font-size: 18px;
}

.dnd-stat span {
    color: #cfc6e8;
    font-size: 12px;
    font-weight: 850;
}

.dnd-sheet-notes {
    display: grid;
    gap: 7px;
    margin-top: 12px;
    padding-top: 12px;
    border-top: 1px solid rgba(255,255,255,0.10);
}

.dnd-sheet-notes span {
    color: #eadcff;
    font-size: 13px;
    font-weight: 760;
    line-height: 1.35;
}

.dnd-creature-card {
    background:
        linear-gradient(145deg, rgba(255,84,160,0.13), rgba(255,255,255,0.035)),
        rgba(20,10,18,0.80);
    border-color: rgba(255,122,154,0.24);
}

.dnd-creature-card h3 {
    color: #ffd6df;
}

.dice-result-stage {
    display: grid;
    grid-template-columns: minmax(190px, 0.34fr) minmax(0, 1fr);
    gap: 20px;
    align-items: center;
    margin: 16px 0;
    padding: 22px;
    border-radius: 10px;
    background:
        linear-gradient(145deg, rgba(124,255,178,0.12), rgba(0,245,255,0.08)),
        rgba(10,14,22,0.80);
    border: 1px solid rgba(124,255,178,0.22);
}

.dice-scene {
    --dice-a: #effcff;
    --dice-b: #7CFFB2;
    --dice-c: #00f5ff;
    --dice-glow: rgba(124,255,178,0.62);
    position: relative;
    width: 156px;
    height: 156px;
    margin: 0 auto;
    perspective: 720px;
    contain: layout paint;
}

.dice-polyhedron {
    position: absolute;
    left: 50%;
    top: 50%;
    width: 126px;
    height: 126px;
    transform: translate(-50%, -50%);
    transform-style: preserve-3d;
    display: grid;
    place-items: center;
    animation: dice-tumble .92s cubic-bezier(.18,.78,.24,1) both;
    will-change: transform;
}

.dice-polyhedron::before {
    content: "";
    position: absolute;
    inset: 0;
    color: #061015;
    background:
        radial-gradient(circle at 32% 24%, rgba(255,255,255,0.92), transparent 18%),
        linear-gradient(145deg, var(--dice-a), var(--dice-b) 54%, var(--dice-c));
    border: 2px solid rgba(255,255,255,0.58);
    box-shadow: inset -12px -16px 26px rgba(0,0,0,0.18), 0 18px 34px rgba(0,0,0,0.30);
    will-change: clip-path;
}

.dice-polyhedron span {
    position: absolute;
    left: 50%;
    top: 50%;
    width: 52%;
    height: 40%;
    transform-origin: 0 0;
    transform: rotate(calc(var(--i) * 24deg)) skewY(-18deg);
    background: rgba(255,255,255,0.12);
    border-left: 1px solid rgba(255,255,255,0.22);
    opacity: .62;
}

.dice-polyhedron strong,
.dice-polyhedron small {
    position: relative;
    z-index: 2;
    text-shadow: 0 1px 0 rgba(255,255,255,0.45);
}

.dice-polyhedron strong {
    color: #061015;
    font-size: 34px;
    line-height: 1;
    font-weight: 950;
}

.dice-polyhedron small {
    position: absolute;
    bottom: 28px;
    color: rgba(6,16,21,0.76);
    font-size: 12px;
    font-weight: 950;
}

.dice-shape-d4 .dice-polyhedron::before {
    clip-path: polygon(50% 3%, 96% 92%, 4% 92%);
}

.dice-shape-d4 .dice-polyhedron small {
    bottom: 34px;
}

.dice-shape-d6 .dice-polyhedron::before {
    clip-path: polygon(15% 10%, 82% 4%, 98% 72%, 52% 100%, 4% 70%);
    border-radius: 18px;
}

.dice-shape-d8 .dice-polyhedron::before {
    clip-path: polygon(50% 0%, 92% 28%, 82% 78%, 50% 100%, 18% 78%, 8% 28%);
}

.dice-shape-d10 .dice-polyhedron::before {
    clip-path: polygon(50% 0%, 86% 17%, 100% 52%, 72% 100%, 28% 100%, 0% 52%, 14% 17%);
}

.dice-shape-d12 .dice-polyhedron::before {
    clip-path: polygon(50% 0%, 80% 8%, 100% 34%, 96% 66%, 76% 92%, 50% 100%, 24% 92%, 4% 66%, 0% 34%, 20% 8%);
}

.dice-shape-d20 .dice-polyhedron::before {
    clip-path: polygon(50% 0%, 72% 12%, 95% 18%, 100% 50%, 90% 78%, 65% 92%, 50% 100%, 35% 92%, 10% 78%, 0% 50%, 5% 18%, 28% 12%);
}

.dice-particles {
    position: absolute;
    inset: 0;
    pointer-events: none;
}

.dice-particles span {
    position: absolute;
    left: 50%;
    top: 50%;
    width: 7px;
    height: 7px;
    border-radius: 999px;
    background: var(--dice-b);
    box-shadow: 0 0 10px var(--dice-glow);
    animation: dice-spark .92s ease-out both;
    will-change: transform, opacity;
}

.dice-particles span:nth-child(1) { --x:-74px; --y:-44px; animation-delay:.05s; }
.dice-particles span:nth-child(2) { --x:70px; --y:-52px; animation-delay:.12s; }
.dice-particles span:nth-child(3) { --x:-64px; --y:48px; animation-delay:.18s; }
.dice-particles span:nth-child(4) { --x:76px; --y:40px; animation-delay:.24s; }
.dice-particles span:nth-child(5) { --x:-24px; --y:-86px; animation-delay:.08s; }
.dice-particles span:nth-child(6) { --x:28px; --y:84px; animation-delay:.15s; }
.dice-particles span:nth-child(7) { --x:-94px; --y:2px; animation-delay:.22s; }
.dice-particles span:nth-child(8) { --x:94px; --y:-4px; animation-delay:.28s; }
.dice-theme-ice {
    --dice-a: #f7fdff;
    --dice-b: #99e8ff;
    --dice-c: #4b8dff;
    --dice-glow: rgba(153,232,255,0.72);
}

.dice-theme-fire {
    --dice-a: #fff0c2;
    --dice-b: #ff8a00;
    --dice-c: #ff245f;
    --dice-glow: rgba(255,90,30,0.78);
}

.dice-theme-spark {
    --dice-a: #fff7c8;
    --dice-b: #ffe66d;
    --dice-c: #b66dff;
    --dice-glow: rgba(255,230,109,0.78);
}

.dice-theme-water {
    --dice-a: #e8ffff;
    --dice-b: #38d9ff;
    --dice-c: #1464d2;
    --dice-glow: rgba(56,217,255,0.76);
}

.dice-theme-earth {
    --dice-a: #e6f6bd;
    --dice-b: #8fb85a;
    --dice-c: #6b4a2b;
    --dice-glow: rgba(143,184,90,0.70);
}

.dice-result-stage h3 {
    margin: 0 0 8px;
    font-size: 30px;
}

.dice-result-stage p {
    margin: 0;
    color: #eadcff;
    font-weight: 800;
}

@keyframes dice-tumble {
    0% { transform: translate3d(-50%, -76%, 0) rotateX(-160deg) rotateY(110deg) rotateZ(18deg) scale(.82); opacity: .82; }
    58% { transform: translate3d(-50%, -46%, 0) rotateX(34deg) rotateY(38deg) rotateZ(-7deg) scale(1.06); opacity: 1; }
    100% { transform: translate3d(-50%, -50%, 0) rotateX(0deg) rotateY(0deg) rotateZ(0deg) scale(1); opacity: 1; }
}

@keyframes dice-spark {
    0% { transform: translate3d(-50%, -50%, 0) scale(.25); opacity: 0; }
    25% { opacity: 1; }
    100% { transform: translate3d(calc(-50% + var(--x)), calc(-50% + var(--y)), 0) scale(.08); opacity: 0; }
}

.shop-category-title {
    margin: 24px 0 12px;
    color: #ff7ad9;
}

.wheel-shell {
    display: grid;
    grid-template-columns: minmax(320px, 0.75fr) minmax(0, 1fr);
    gap: 18px;
    align-items: center;
}

.wheel-stage {
    position: relative;
    width: min(420px, 100%);
    aspect-ratio: 1;
    margin: 0 auto;
}

.punishment-wheel {
    width: 100%;
    height: 100%;
    border-radius: 50%;
    border: 10px solid rgba(255,255,255,0.14);
    background: conic-gradient(#7b2cbf 0 60deg, #ff54a0 60deg 120deg, #c77dff 120deg 180deg, #7b2cbf 180deg 240deg, #ff54a0 240deg 300deg, #c77dff 300deg 360deg);
    box-shadow: 0 28px 80px rgba(0,0,0,0.38), inset 0 0 40px rgba(0,0,0,0.26);
    transition: transform 3.2s cubic-bezier(.12,.76,.18,1);
}

.wheel-pointer {
    position: absolute;
    left: 50%;
    top: -4px;
    width: 0;
    height: 0;
    transform: translateX(-50%);
    border-left: 18px solid transparent;
    border-right: 18px solid transparent;
    border-top: 34px solid #ffffff;
    filter: drop-shadow(0 8px 12px rgba(0,0,0,0.25));
}

.wheel-center {
    position: absolute;
    inset: 38%;
    border-radius: 50%;
    background: #130b1d;
    border: 4px solid rgba(255,255,255,0.18);
}

.market-grid,
.market-holdings {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 14px;
    margin: 18px 0;
}

.market-card,
.holding-card {
    border-radius: 14px;
    padding: 18px;
    background: rgba(255,255,255,0.06);
    border: 1px solid rgba(255,255,255,0.11);
    box-shadow: 0 18px 45px rgba(0,0,0,0.22);
}

.market-card strong,
.holding-card strong {
    display: block;
    color: #ffffff;
    font-size: 22px;
}

.market-price {
    margin: 12px 0;
    color: #ff7ad9;
    font-size: 30px;
    font-weight: 950;
}

.market-delta.up {
    color: #7CFFB2;
}

.market-delta.down {
    color: #ff7a9a;
}

.shop-dashboard {
    display: grid;
    grid-template-columns: minmax(0, 1.25fr) minmax(260px, 0.75fr);
    gap: 16px;
    align-items: stretch;
    margin: 14px 0 18px;
}

.shop-wallet,
.shop-signal,
.admin-control-card {
    border-radius: 14px;
    padding: 20px;
    background: rgba(255,255,255,0.055);
    border: 1px solid rgba(255,255,255,0.11);
    box-shadow: 0 18px 45px rgba(0,0,0,0.22);
}

.shop-wallet h2,
.shop-signal h3,
.admin-control-card h3 {
    margin: 4px 0 8px;
}

.shop-wallet h2 {
    font-size: 42px;
}

.shop-status-row,
.admin-control-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 10px;
    margin-top: 12px;
}

.shop-status-pill {
    min-height: 72px;
    border-radius: 12px;
    padding: 12px;
    background: rgba(8,14,18,0.58);
    border: 1px solid rgba(255,255,255,0.09);
}

.shop-status-pill strong {
    display: block;
    color: #ffffff;
    font-size: 18px;
}

.shop-status-pill span {
    display: block;
    margin-top: 4px;
    color: #cfc6e8;
    font-weight: 760;
    font-size: 13px;
}

.shop-item-shell {
    min-height: 100%;
    border-radius: 14px;
    padding: 18px;
    background: rgba(255,255,255,0.052);
    border: 1px solid rgba(255,255,255,0.10);
}

.shop-item-shell.available {
    border-color: rgba(124,255,178,0.30);
}

.shop-item-shell.locked {
    opacity: 0.72;
    border-color: rgba(255,122,154,0.24);
}

.shop-badge {
    display: inline-flex;
    width: fit-content;
    margin-bottom: 10px;
    padding: 6px 10px;
    border-radius: 999px;
    background: rgba(199,125,255,0.14);
    color: #f0c9ff;
    font-size: 12px;
    font-weight: 900;
}

.shop-badge.available {
    background: rgba(124,255,178,0.13);
    color: #baffd4;
}

.shop-badge.locked {
    background: rgba(255,122,154,0.13);
    color: #ffc7d2;
}

.shop-item-shell h3 {
    margin: 0 0 8px;
}

.shop-item-shell p {
    min-height: 46px;
    color: #d8ccff;
}

.shop-price {
    margin-top: 12px;
    color: #ff7ad9;
    font-size: 22px;
    font-weight: 950;
}

.admin-control-grid {
    grid-template-columns: repeat(4, minmax(0, 1fr));
}

.admin-control-card {
    min-height: 136px;
}

.admin-danger-panel {
    border-radius: 14px;
    padding: 20px;
    background: rgba(255,122,154,0.08);
    border: 1px solid rgba(255,122,154,0.22);
}

.stForm {
    margin-top: 12px;
    padding: 18px;
    border-radius: 18px;
    background: rgba(255,255,255,0.04);
    border: 1px solid rgba(255,255,255,0.09);
}

@media (max-width: 780px) {
    .podium-grid,
    .arcade-grid,
    .member-grid,
    .profile-shell,
    .profile-showcase-inner,
    .home-hero,
    .home-actions,
    .members-hero,
    .members-stat-row,
    .home-compact-grid,
    .home-week-art,
    .creative-shell,
    .creative-gallery-grid,
    .chicken-scoreboard-grid,
    .achievement-grid,
    .dnd-hero,
    .dnd-rule-grid,
    .dnd-lobby-grid,
    .dnd-party-grid,
    .dnd-roll-grid,
    .dnd-session-bar,
    .dnd-map-markers,
    .dnd-premade-grid,
    .gazette-card-grid,
    .score-strip,
    .newspaper-grid,
    .wheel-shell,
    .market-grid,
    .market-holdings,
    .shop-dashboard,
    .shop-status-row,
    .support-shell,
    .admin-control-grid,
    .leaderboard-hero,
    .leaderboard-stats,
    .rank-row,
    .profile-hero {
        grid-template-columns: 1fr;
    }

    .rank-side {
        text-align: left;
    }

    .home-brain-visual {
        right: -90px;
        top: 96px;
        width: 260px;
        max-width: none;
        opacity: 0.28;
    }

    .profile-stat-grid,
    .admin-stat-grid {
        grid-template-columns: 1fr;
    }

    .event-ticket {
        grid-template-columns: 1fr;
    }

    .event-ticket-date {
        min-height: auto;
        padding: 18px;
        border-right: 0;
        border-bottom: 1px dashed rgba(255,255,255,0.22);
    }

    .event-ticket-main {
        padding: 18px;
    }

    .admin-hero {
        display: block;
    }
}

.progress-bg {
    width: 100%;
    height: 18px;
    background: rgba(255,255,255,0.09);
    border-radius: 999px;
    overflow: hidden;
    margin-top: 15px;
}

.progress-fill {
    height: 100%;
    background: linear-gradient(90deg, #9d4edd, #00f5ff);
    border-radius: 999px;
    box-shadow: 0 0 18px rgba(0,245,255,0.5);
}

.stButton > button {
    background: linear-gradient(135deg, #c77dff, #ff54a0);
    border: 1px solid rgba(255,255,255,0.18);
    border-radius: 12px;
    color: #061015;
    font-weight: 900;
    padding: 0.6rem 1rem;
    box-shadow: 0 12px 30px rgba(0,0,0,0.18);
}

.stButton > button:hover {
    transform: translateY(-2px);
    box-shadow: 0 18px 42px rgba(255,84,160,0.24);
}

.stRadio {
    width: 100%;
    max-width: 100%;
    margin: 6px auto 34px auto;
    position: relative;
    z-index: 2;
    pointer-events: none;
}

.stRadio > div {
    width: fit-content;
    max-width: min(100%, 1120px);
    margin: 0 auto;
    justify-content: center;
    background: rgba(8,10,18,0.58);
    border: 1px solid rgba(199,125,255,0.22);
    border-radius: 999px;
    padding: 6px;
    box-shadow: 0 16px 38px rgba(0,0,0,0.22);
    backdrop-filter: blur(16px);
    overflow-x: auto;
    scrollbar-width: none;
    pointer-events: auto;
}

.stRadio > div::-webkit-scrollbar {
    display: none;
}

.stRadio [role="radiogroup"] {
    display: flex;
    flex-wrap: nowrap;
    justify-content: center;
    gap: 6px;
    width: max-content;
}

.stRadio [role="radiogroup"] label {
    min-height: 40px;
    border-radius: 999px;
    padding: 0 16px;
    border: 1px solid rgba(255,255,255,0.06);
    background: rgba(255,255,255,0.025);
    transition: all 0.18s ease;
    white-space: nowrap;
    flex: 0 0 auto;
    display: flex;
    align-items: center;
    justify-content: center;
}

.stRadio [role="radiogroup"] label > div:first-child {
    display: none;
}

.stRadio [role="radiogroup"] label > div:last-child {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 100%;
    min-height: 100%;
    padding: 0;
}

.stRadio [role="radiogroup"] label:hover {
    border-color: rgba(199,125,255,0.55);
    background: rgba(199,125,255,0.10);
}

.stRadio [role="radiogroup"] label:has(input:checked) {
    background: linear-gradient(135deg, rgba(199,125,255,0.20), rgba(255,84,160,0.16));
    border-color: rgba(255,84,160,0.36);
    box-shadow: inset 0 -2px 0 #ff54a0, 0 10px 26px rgba(255,84,160,0.18);
}

.stRadio [role="radiogroup"] label:has(input:checked) p {
    color: #ffffff !important;
    font-weight: 900;
}

.stRadio [role="radiogroup"] label p {
    font-weight: 850;
    font-size: 13px;
    line-height: 1.1;
    white-space: nowrap;
    margin: 0;
    width: 100%;
    text-align: center;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 5px;
}

.small {
    color: #aaa;
}

iframe {
    border-radius: 20px;
}

</style>
""", unsafe_allow_html=True)

# =========================
# HEADER
# =========================

leaderboard = get_leaderboard()

total_users = len(leaderboard)
total_chickens = int(leaderboard["Chickens"].sum()) if not leaderboard.empty else 0
total_braincells = int(leaderboard["Gehirnzellen"].sum()) if not leaderboard.empty else 0

handle_twitch_callback()

logged_in_username = get_logged_in_username()
twitch_display_name = get_logged_in_display_name()

twitch_auth_url = twitch_oauth_authorize_url()

MAIN_MENU_OPTIONS = [
    "🏠 Home",
    "📰 News",
    "👥 Mitglieder",
    "👤 Profil",
    "🛒 Shop",
    "🏆 Rangliste",
    "⚡ Events",
    "🎮 Minispiele",
    "🏛️ Hall of Fame",
]

if "app_menu" not in st.session_state:
    st.session_state["app_menu"] = "🏠 Home"

if "main_nav" not in st.session_state:
    st.session_state["main_nav"] = "🏠 Home"

topbar_account_label = logged_in_username or twitch_display_name
topbar_account_html = (
    f'<div class="topbar-login-state">Eingeloggt als: <span>{html.escape(str(topbar_account_label))}</span></div>'
    if topbar_account_label
    else '<div class="topbar-login-state is-guest">Status: <span>Nicht eingeloggt</span></div>'
)
st.markdown(
    '<div class="topbar">'
    '<div class="topbar-brand"><span class="topbar-brand-icon">🧠</span><span>Gehirnzone</span></div>'
    f'<div class="topbar-right">{topbar_account_html}<div class="topbar-menu-slot"></div></div>'
    '</div>',
    unsafe_allow_html=True,
)
_, account_col = st.columns([10, 1])

with account_col:
    with st.popover("☰", use_container_width=True):
        if logged_in_username:
            st.caption(f"✅ {logged_in_username}")
        elif twitch_display_name:
            st.caption(f"✅ {twitch_display_name}")

        if st.button("🔑 Login", key="account_login", use_container_width=True):
            st.session_state["app_menu"] = "🔑 Login"
            st.rerun()

        if st.button("👤 Profil", key="account_profile", use_container_width=True):
            st.session_state["app_menu"] = "👤 Profil"
            st.session_state["main_nav"] = "👤 Profil"
            st.rerun()

        if st.button("🔐 Admin", key="account_admin", use_container_width=True):
            st.session_state["app_menu"] = "🔐 Admin"
            st.rerun()

        if st.button("Patch Notes", key="account_patch_notes", use_container_width=True):
            st.session_state["app_menu"] = "Patch Notes"
            st.rerun()

        if st.button("🛟 Support", key="account_support", use_container_width=True):
            st.session_state["app_menu"] = "🛟 Support"
            st.rerun()

        if logged_in_username or twitch_display_name:
            st.divider()
            if st.button("Logout", key="account_logout", use_container_width=True):
                logout_user()
                st.session_state.pop("twitch_user", None)
                st.session_state.pop("twitch_access_token", None)
                st.session_state["app_menu"] = "🏠 Home"
                st.session_state["main_nav"] = "🏠 Home"
                st.rerun()

if False and twitch_auth_url:
    st.markdown(
        f'<a href="{twitch_auth_url}" target="_self" style="text-decoration:none;"><button style="background: linear-gradient(135deg, #9d4edd, #c77dff); border: none; border-radius: 14px; color: black; font-weight: 900; padding: 0.6rem 1rem; cursor: pointer;">Mit Twitch verbinden</button></a>',
        unsafe_allow_html=True
    )
elif False:
    client_id, _, _ = get_twitch_config()
    if not client_id:
        st.warning("⚠️ Twitch-OAuth ist nicht konfiguriert. Prüfe deine Streamlit-Cloud-Secrets!")
    else:
        st.info(f"🔗 OAuth URL: {twitch_auth_url}")

current_menu = st.session_state["app_menu"]
if current_menu in MAIN_MENU_OPTIONS:
    st.session_state["main_nav"] = current_menu

nav_fallback = st.session_state.get("main_nav", "🏠 Home")
if nav_fallback not in MAIN_MENU_OPTIONS:
    nav_fallback = "🏠 Home"

selected_nav = st.radio(
    "Hauptnavigation",
    MAIN_MENU_OPTIONS,
    index=MAIN_MENU_OPTIONS.index(nav_fallback),
    horizontal=True,
    label_visibility="collapsed",
)

if selected_nav != st.session_state.get("main_nav"):
    st.session_state["app_menu"] = selected_nav
    st.session_state["main_nav"] = selected_nav
    st.rerun()

menu = st.session_state["app_menu"]

logged_in_username = get_logged_in_username()

if logged_in_username:
    incoming_trades = get_pending_trades(logged_in_username)
    if incoming_trades:
        st.warning(f"Du hast {len(incoming_trades)} offene Chicken-Handelsanfrage(n).")
        with st.expander("Chicken-Handel prüfen", expanded=True):
            for trade in incoming_trades:
                amount = int(trade.get("amount") or 0)
                requester = trade.get("requester")
                trade_type = trade.get("trade_type")

                if trade_type == "gift":
                    trade_text = f"{requester} möchte dir {amount} Chicken(s) schenken."
                else:
                    trade_text = f"{requester} fragt {amount} Chicken(s) von dir an."

                st.markdown(f"**{trade_text}**")
                accept_col, reject_col = st.columns(2)

                with accept_col:
                    if st.button("Annehmen", key=f"accept_trade_{trade['id']}"):
                        success, message = accept_chicken_trade(trade)
                        if success:
                            st.success(message)
                        else:
                            st.error(message)
                        st.rerun()

                with reject_col:
                    if st.button("Ablehnen", key=f"reject_trade_{trade['id']}"):
                        if set_trade_status(trade["id"], "rejected"):
                            st.info("Handel abgelehnt.")
                        else:
                            st.error("Handel konnte nicht abgelehnt werden.")
                        st.rerun()

if menu != "🏠 Home":
    st.markdown("<h1>Gehirnzone</h1>", unsafe_allow_html=True)

# =========================
# HOME
# =========================

if menu == "🏠 Home":

    spotlight_title = "Willkommen in der Gehirnzone"
    spotlight_copy = "Community, Rewards und Rankings für die schlauesten Köpfe."
    daily_html = (
        '<div class="section-kicker">Daily Reward</div>'
        '<h3>Heute wartet dein Bonus</h3>'
        '<p>Melde dich an und hol dir Chickens plus Gehirnzellen für den Stream.</p>'
    )
    daily_state = None
    if logged_in_username:
        daily_state = get_daily_reward_state(logged_in_username)
        reward_preview = 250 + min(int(daily_state["streak"]), 7) * 50
        claim_text = "Heute schon abgeholt" if daily_state["claimed_today"] else f"+{reward_preview} Chickens bereit"
        daily_html = (
            '<div class="section-kicker">Daily Reward</div>'
            f'<h3>{claim_text}</h3>'
            f'<div class="daily-streak">{int(daily_state["streak"])} Tage Streak</div>'
            '<p>Streak halten, Bonus abholen und Gehirnzellen stapeln.</p>'
        )

    home_html = (
        '<div class="home-dashboard">'
        '<div class="home-hero">'
        '<div class="home-spotlight">'
        '''
        <div class="home-brain-visual" aria-hidden="true">
            <svg viewBox="0 0 420 320" role="img">
                <defs>
                    <linearGradient id="homeBrainFill" x1="72" y1="42" x2="340" y2="276" gradientUnits="userSpaceOnUse">
                        <stop offset="0" stop-color="#ffd1f1"/>
                        <stop offset="0.42" stop-color="#ff54c7"/>
                        <stop offset="1" stop-color="#8b5cff"/>
                    </linearGradient>
                    <linearGradient id="homeBrainStroke" x1="64" y1="40" x2="360" y2="284" gradientUnits="userSpaceOnUse">
                        <stop offset="0" stop-color="#ffffff"/>
                        <stop offset="0.28" stop-color="#ff9ee4"/>
                        <stop offset="0.72" stop-color="#ff54a0"/>
                        <stop offset="1" stop-color="#c77dff"/>
                    </linearGradient>
                    <filter id="homeBrainGlow" x="-40%" y="-40%" width="180%" height="180%">
                        <feGaussianBlur stdDeviation="7" result="blur"/>
                        <feColorMatrix in="blur" type="matrix" values="1 0 0 0 1  0 0 0 0 0.18  0 0 0 0 0.72  0 0 0 0.86 0" result="pinkGlow"/>
                        <feMerge>
                            <feMergeNode in="pinkGlow"/>
                            <feMergeNode in="SourceGraphic"/>
                        </feMerge>
                    </filter>
                </defs>
                <path class="home-brain-fill" filter="url(#homeBrainGlow)" d="M207 58c28-34 84-26 100 14 34 1 61 27 62 61 26 16 36 50 22 79-11 25-35 41-63 42h-26v35c0 11-13 16-21 8l-45-43H130c-39 0-71-30-73-68-27-20-31-61-7-87 2-40 40-70 79-58 18-23 56-25 78 17z"/>
                <path class="home-brain-line" d="M129 58c-39-12-77 18-79 58-24 26-20 67 7 87 2 38 34 68 73 68h106l45 43c8 8 21 3 21-8v-35h26c28-1 52-17 63-42 14-29 4-63-22-79-1-34-28-60-62-61-16-40-72-48-100-14-22-42-60-40-78-17z"/>
                <path class="home-brain-line" d="M130 87c-20 6-33 22-35 42m29 93c-20-1-38-15-42-35m54-25c-19 4-38-8-43-27m99-60c-19 8-30 24-28 45m43-45c22 3 37 19 39 40m-82 5c-5 24 8 43 31 49m51-54c-21 3-38 18-42 39m43 41c-20 1-37-10-43-27m99-79c22 10 32 34 23 57m-54-10c21 7 34 26 32 48m-100 7c21 2 38 15 44 36m-102-38c-2 22-17 39-39 43"/>
                <circle class="home-brain-spark" cx="88" cy="80" r="5"/>
                <circle class="home-brain-spark" cx="340" cy="70" r="4"/>
                <circle class="home-brain-spark" cx="372" cy="208" r="4"/>
            </svg>
        </div>
        '''
        '<div>'
        '<div class="section-kicker">Gehirnzone</div>'
        f'<h2>{html.escape(spotlight_title)}</h2>'
        f'<p>{html.escape(spotlight_copy)}</p>'
        '</div>'
        '<div class="home-actions">'
        f'<div class="home-action-card"><strong>{total_braincells}</strong><span>Gehirnzellen gesamt</span></div>'
        f'<div class="home-action-card"><strong>{total_chickens}</strong><span>Chickens im Umlauf</span></div>'
        f'<div class="home-action-card"><strong>{total_users}</strong><span>Mitglieder in der Zone</span></div>'
        '</div>'
        '</div>'
        f'<div class="daily-card">{daily_html}</div>'
        '</div>'
        '</div>'
    )
    st.markdown(home_html, unsafe_allow_html=True)

    if logged_in_username:
        if daily_state and daily_state["claimed_today"]:
            st.success("Daily Reward ist heute erledigt.")
        else:
            st.markdown('<div class="daily-claim-shell">', unsafe_allow_html=True)
            if st.button("Daily Reward abholen", key="claim_daily_reward", use_container_width=True):
                success, message = claim_daily_reward(logged_in_username)
                if success:
                    st.success(message)
                    st.rerun()
                else:
                    st.error(message)
            st.markdown('</div>', unsafe_allow_html=True)
    else:
        st.markdown('<div class="home-login-actions">', unsafe_allow_html=True)
        if st.button("Einloggen und Daily Reward holen", key="home_login_cta", use_container_width=True):
            st.session_state["app_menu"] = "\U0001f511 Login"
            st.rerun()
        st.markdown('</div>', unsafe_allow_html=True)

    creative_items = get_creative_gallery(30)
    creative_reactions = get_creative_gallery_reactions()
    week_art = get_creative_image_of_week(creative_items, creative_reactions)
    if week_art:
        week_title = str(week_art.get("title") or "").strip()
        week_heading = week_title or "Bild der Woche"
        week_image = html.escape(str(week_art.get("image_data") or ""), quote=True)
        week_artist = html.escape(str(week_art.get("username") or "Unbekannt"))
        week_date = html.escape(format_gallery_timestamp(week_art.get("created_at")))
        week_art_html = (
            '<div class="home-week-art">'
            f'<img src="{week_image}" alt="{html.escape(week_heading, quote=True)}">'
            '<div>'
            '<div class="section-kicker">Bild der Woche</div>'
            f'<h3>{html.escape(week_heading)}</h3>'
            f'<p>Aus der Hall of Fame von {week_artist}.</p>'
            f'<span class="creative-date">{week_date}</span>'
            '</div>'
            '</div>'
        )
    else:
        week_art_html = (
            '<div class="home-week-art">'
            '<div>'
            '<div class="section-kicker">Bild der Woche</div>'
            '<h3>Hall of Fame wartet</h3>'
            '<p>Sobald ein Bild veröffentlicht wurde, bekommt es hier seinen Platz auf der Startseite.</p>'
            '</div>'
            '</div>'
        )
    st.markdown(week_art_html, unsafe_allow_html=True)
    if st.button("Zur Hall of Fame", key="home_hof_cta", use_container_width=True):
        st.session_state["app_menu"] = "🏛️ Hall of Fame"
        st.rerun()

# =========================
# LOGIN
# =========================

elif menu == "Patch Notes":

    st.markdown('<div class="section-kicker">Update Verlauf</div>', unsafe_allow_html=True)
    st.markdown("## Patch Notes")
    st.markdown("Hier stehen kurz die wichtigsten Änderungen an der Seite.")

    patch_cards = ""
    for patch in get_patch_notes():
        change_items = "".join(
            f"<li>{html.escape(change)}</li>"
            for change in patch["changes"]
        )
        patch_cards += f"""
        <article class="patch-note-card">
            <div class="patch-note-head">
                <div>
                    <div class="patch-version">{html.escape(patch["version"])}</div>
                    <h3>{html.escape(patch["title"])}</h3>
                </div>
                <div class="patch-date">{html.escape(patch["date"])}</div>
            </div>
            <ul class="patch-change-list">{change_items}</ul>
        </article>
        """

    st.markdown(f'<div class="patch-notes-shell">{patch_cards}</div>', unsafe_allow_html=True)

elif menu == "🔑 Login":

    logged_in_username = get_logged_in_username()

    if logged_in_username:
        st.success(f"Angemeldet als **{logged_in_username}**")
        if st.button("Abmelden", key="logout_button"):
            logout_user()
            st.rerun()
    else:
        st.markdown("## Anmeldung oder Registrierung")
        st.markdown("Gib deinen Twitch-Namen exakt so ein, wie er auf Twitch geschrieben ist.")

        login_tab, request_tab, complete_tab = st.tabs(["Anmelden", "Registrierung anfragen", "Code einlösen"])

        with login_tab:
            login_name = st.text_input("Twitch-Name", key="login_name")
            login_password = st.text_input("Passwort", type="password", key="login_password")

            if st.button("Anmelden", key="login_submit"):
                if not validate_username(login_name):
                    st.error("Ungültiger Twitch-Name. Nur Buchstaben, Zahlen, - und _ sind erlaubt.")
                else:
                    user = login_user(login_name, login_password)
                    if user:
                        st.session_state["logged_in_username"] = user["username"]
                        st.success("Erfolgreich angemeldet.")
                        st.rerun()
                    else:
                        st.error("Login fehlgeschlagen. Prüfe deinen Namen und dein Passwort.")

        with request_tab:
            request_name = st.text_input("Twitch-Name", key="registration_request_name")
            request_password = st.text_input("Passwort", type="password", key="registration_request_password")
            request_confirm = st.text_input("Passwort bestätigen", type="password", key="registration_request_confirm")

            if st.button("Anfragen", key="registration_request_submit"):
                if not validate_username(request_name):
                    st.error("Ungültiger Twitch-Name. Nur Buchstaben, Zahlen, - und _ sind erlaubt.")
                elif request_password == "":
                    st.error("Bitte gib ein Passwort ein.")
                elif request_password != request_confirm:
                    st.error("Die Passwörter stimmen nicht überein.")
                else:
                    success, message = request_registration(request_name, request_password)
                    if success:
                        st.success(message)
                    else:
                        st.error(message)

        with complete_tab:
            complete_name = st.text_input("Twitch-Name", key="registration_complete_name")
            complete_password = st.text_input("Passwort", type="password", key="registration_complete_password")
            complete_code = st.text_input("Einmalcode vom Admin", key="registration_complete_code")

            if st.button("Registrierung abschliessen", key="registration_complete_submit"):
                if not validate_username(complete_name):
                    st.error("Ungültiger Twitch-Name. Nur Buchstaben, Zahlen, - und _ sind erlaubt.")
                elif complete_password == "":
                    st.error("Bitte gib dein Passwort ein.")
                elif complete_code.strip() == "":
                    st.error("Bitte gib den Einmalcode ein.")
                else:
                    user, message = complete_registration(complete_name, complete_password, complete_code)
                    if user:
                        st.session_state["logged_in_username"] = user["username"]
                        st.success(message)
                        st.rerun()
                    else:
                        st.error(message)

# =========================
# PROFIL
# =========================

elif menu == "👤 Profil":

    logged_in_username = get_logged_in_username()

    if not logged_in_username:
        st.warning("Bitte melde dich zuerst im Login-Bereich mit deinem Twitch-Namen und Passwort an.")
        st.stop()

    st.markdown('<div class="section-kicker">Profilzentrum</div>', unsafe_allow_html=True)
    st.markdown("## Dein Profil")

    with st.spinner("Lade Benutzerdaten..."):
        user = get_or_create_user(logged_in_username)

    if user:
        braincells = int(user["braincells"])
        chickens = int(user["chickens"])

        rank_name, rank_progress, progress_text = get_progress(braincells)
        level, level_xp, level_needed_xp, level_progress, points_to_level = get_level_progress(braincells)
        level_title = get_level_title(level)
        bio = user.get("bio") or "Noch keine Bio eingetragen."
        favorite_game = user.get("favorite_game") or "Noch nicht gesetzt"
        avatar_url = user.get("avatar_url") or ""
        avatar_markup = get_avatar_markup(user["username"], avatar_url, 136)
        members = get_members()
        sorted_members = sorted(members, key=lambda member: int(member.get("braincells") or 0), reverse=True)
        rank_position = next(
            (index + 1 for index, member in enumerate(sorted_members) if member.get("username") == logged_in_username),
            "-"
        )
        best_score = get_user_best_chicken_score(logged_in_username)
        daily_state = get_daily_reward_state(logged_in_username)
        achievements = build_achievements(user, rank_position, best_score, daily_state)
        unlocked_count = sum(1 for _, _, unlocked in achievements if unlocked)
        completed_fields = sum([
            bool(str(user.get("bio") or "").strip()),
            bool(str(user.get("favorite_game") or "").strip()),
            bool(str(user.get("avatar_url") or "").strip()),
        ])
        completion = int((completed_fields / 3) * 100)
        st.markdown(f"""
        <div class="profile-shell">
            <div class="profile-showcase">
                <div class="profile-showcase-inner">
                    {avatar_markup}
                    <div>
                        <div class="profile-rank-badge">Level {level} · {html.escape(level_title)}</div>
                        <div class="profile-big-name">{html.escape(user["username"])}</div>
                        <div class="profile-bio-large">{html.escape(bio)}</div>
                        <div class="profile-chip-row">
                            <div class="profile-chip">Lieblingsspiel: {html.escape(favorite_game)}</div>
                            <div class="profile-chip">Rang #{rank_position}</div>
                            <div class="profile-chip">{html.escape(rank_name)}</div>
                            <div class="profile-chip">{completion}% Profil</div>
                            <div class="profile-chip">{unlocked_count}/{len(achievements)} Achievements</div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="profile-side-panel">
                <div class="section-kicker">Fortschritt</div>
                <h3>Level-Fortschritt</h3>
                <div class="profile-level-card">
                    <div class="profile-level-top">
                        <div>
                            <strong>Level {level}</strong>
                            <span>{html.escape(level_title)}</span>
                        </div>
                        <div class="profile-level-badge">Nächstes Level {level + 1}</div>
                    </div>
                    <div class="profile-progress-track">
                        <div class="profile-progress-fill" style="width:{level_progress}%;"></div>
                    </div>
                    <div class="profile-xp-row">
                        <span>{level_xp}/{level_needed_xp} XP</span>
                        <span>{points_to_level} Gehirnzellen fehlen</span>
                    </div>
                </div>
                <div class="profile-progress-track">
                    <div class="profile-progress-fill" style="width:{rank_progress}%;"></div>
                </div>
                <div class="admin-muted">Rang: {rank_progress}% · {html.escape(progress_text)}</div>
                <div class="profile-stat-grid">
                    <div class="profile-stat"><strong>{braincells}</strong><span>Gehirnzellen</span></div>
                    <div class="profile-stat"><strong>{chickens}</strong><span>Chickens</span></div>
                    <div class="profile-stat"><strong>{points_to_level}</strong><span>Bis Level {level + 1}</span></div>
                </div>
            </div>
        </div>
        """, unsafe_allow_html=True)

        achievement_html = ""
        for title, description, unlocked in achievements:
            state_class = "unlocked" if unlocked else "locked"
            status = "Freigeschaltet" if unlocked else "Noch offen"
            achievement_html += (
                f'<div class="achievement-card {state_class}">'
                f'<strong>{html.escape(title)}</strong>'
                f'<span>{html.escape(description)}</span>'
                f'<div class="admin-muted" style="margin-top:10px;">{status}</div>'
                '</div>'
            )

        with st.expander(f"Achievements anzeigen ({unlocked_count}/{len(achievements)} freigeschaltet)", expanded=False):
            st.markdown(
                '<div class="achievement-shell">'
                '<div class="achievement-summary">'
                '<div><div class="section-kicker">Profil-Trophäen</div><h3>Achievement-Sammlung</h3>'
                '<p>Freigeschaltete Karten leuchten, offene Ziele bleiben gedimmt.</p></div>'
                f'<div class="achievement-count-pill">{unlocked_count}/{len(achievements)}</div>'
                '</div>'
                f'<div class="achievement-grid">{achievement_html}</div>'
                '</div>',
                unsafe_allow_html=True,
            )

        best_score_text = "Noch kein Score gespeichert"
        if best_score:
            best_score_text = f'{int(best_score.get("score") or 0)} Punkte · Level {int(best_score.get("level") or 1)}'

        st.markdown(f"""
        <div class="score-strip">
            <div class="score-card"><strong>{best_score_text}</strong><span>Persönlicher Chicken-Jump-Bestwert</span></div>
            <div class="score-card"><strong>{int(daily_state["streak"])}</strong><span>Daily-Reward-Streak</span></div>
            <div class="score-card"><strong>{unlocked_count}/{len(achievements)}</strong><span>Achievements freigeschaltet</span></div>
        </div>
        """, unsafe_allow_html=True)

        if st.button("Kreativwand öffnen", key="profile_creative_wall", use_container_width=True):
            st.session_state["app_menu"] = "🎨 Kreativwand"
            st.rerun()

        inventory = [row for row in get_market_inventory(logged_in_username) if int(row.get("quantity") or 0) > 0]
        if inventory:
            holding_html = ""
            for row in inventory:
                item = get_market_item(row.get("item_key"))
                if not item:
                    continue
                quantity = int(row.get("quantity") or 0)
                price = get_market_sell_price(item["key"])
                holding_html += (
                    '<div class="holding-card">'
                    f'<strong>{item["emoji"]} {html.escape(item["name"])}</strong>'
                    f'<div class="market-price">{quantity}x</div>'
                    f'<span class="admin-muted">Aktueller Wert: {quantity * price} Chickens</span>'
                    '</div>'
                )
            st.markdown("### Markt-Inventar")
            st.markdown(f'<div class="market-holdings">{holding_html}</div>', unsafe_allow_html=True)

        if daily_state["claimed_today"]:
            st.info("Daily Reward ist heute schon abgeholt.")
        elif st.button("Daily Reward im Profil abholen", key="profile_daily_claim", use_container_width=True):
            success, message = claim_daily_reward(logged_in_username)
            if success:
                st.success(message)
                st.rerun()
            else:
                st.error(message)

        st.markdown("### Profil bearbeiten")

        with st.form("profile_form"):
            profile_bio = st.text_area(
                "Biografie",
                value=user.get("bio") or "",
                max_chars=300,
                placeholder="Erzähl kurz, wer du bist oder was du gerne spielst..."
            )
            profile_favorite = st.text_input(
                "Lieblingsspiel",
                value=user.get("favorite_game") or "",
                max_chars=80,
                placeholder="z.B. Minecraft, Valorant, Sims, Elden Ring..."
            )
            profile_avatar = st.text_input(
                "Profilbild-URL",
                value=user.get("avatar_url") or "",
                max_chars=500,
                placeholder="https://..."
            )

            if st.form_submit_button("Profil speichern"):
                if update_user_profile(logged_in_username, profile_bio, profile_favorite, profile_avatar):
                    get_members.clear()
                    get_leaderboard.clear()
                    st.success("Profil gespeichert.")
                    st.rerun()
                else:
                    st.error("Profil konnte nicht gespeichert werden. Prüfe die URL oder die Supabase-Spalten.")

# =========================
# SUPPORT
# =========================

elif menu == "🛟 Support":

    logged_in_username = get_logged_in_username()
    display_name = get_logged_in_display_name() or logged_in_username

    st.markdown('<div class="section-kicker">Support & Wünsche</div>', unsafe_allow_html=True)
    st.markdown("## Support")

    st.markdown(
        """
        <div class="support-shell">
            <div class="support-intro">
                <div class="section-kicker">Problem melden</div>
                <h2>Etwas hakt?</h2>
                <p>Schick eine kurze Meldung an den Adminbereich. Beschreibe am besten, was du geklickt hast und was stattdessen passiert ist.</p>
            </div>
            <div class="support-intro">
                <div class="section-kicker">Wünsche</div>
                <h2>Community-Ideen</h2>
                <p>Wünsche sind öffentlich sichtbar. Andere können mit Daumen hoch oder runter abstimmen.</p>
            </div>
        </div>
        """,
        unsafe_allow_html=True,
    )

    problem_tab, wish_tab = st.tabs(["Problem melden", "Wünsche"])

    with problem_tab:
        with st.form("support_problem_form"):
            if logged_in_username:
                st.caption(f"Absender: {display_name}")
                support_name = logged_in_username
            else:
                support_name = st.text_input("Dein Name", placeholder="Twitch-Name oder Gast")
            support_category = st.selectbox("Kategorie", ["Problem", "Bug", "Login", "Shop", "Sonstiges"])
            support_title = st.text_input("Titel", max_chars=140)
            support_message = st.text_area("Beschreibung", height=180, max_chars=2500)
            submit_support = st.form_submit_button("Problem senden")

        if submit_support:
            success, message = create_support_message(
                support_name,
                support_category,
                support_title,
                support_message,
            )
            if success:
                st.success(message)
            else:
                st.error(message)

    with wish_tab:
        with st.form("create_wish_form"):
            if logged_in_username:
                st.caption(f"Wunsch von: {display_name}")
                wish_name = logged_in_username
            else:
                wish_name = st.text_input("Dein Name", placeholder="Twitch-Name oder Gast")
            wish_title = st.text_input("Wunsch-Titel", max_chars=140)
            wish_description = st.text_area("Wunsch beschreiben", height=140, max_chars=1800)
            submit_wish = st.form_submit_button("Wunsch veröffentlichen")

        if submit_wish:
            success, message = create_wish_post(wish_name, wish_title, wish_description)
            if success:
                st.success(message)
                st.rerun()
            else:
                st.error(message)

        wishes = get_wish_posts()
        reactions = get_wish_reactions()
        reaction_summary = summarize_wish_reactions(reactions)
        user_reactions = get_user_wish_reactions(reactions, logged_in_username)

        st.markdown("### Eingereichte Wünsche")
        if not wishes:
            st.info("Noch keine Wünsche vorhanden.")
        else:
            st.markdown('<div class="wish-list">', unsafe_allow_html=True)
            for wish in wishes:
                wish_id = str(wish.get("id") or "")
                title = str(wish.get("title") or "Wunsch")
                description = str(wish.get("description") or "")
                username = str(wish.get("username") or "Gast")
                created_at = format_gallery_timestamp(wish.get("created_at"))
                counts = reaction_summary.get(wish_id, {"up": 0, "down": 0})
                current_vote = user_reactions.get(wish_id)
                vote_text = "👍" if current_vote == "up" else "👎" if current_vote == "down" else "offen"

                st.markdown(
                    '<div class="wish-card">'
                    f'<div class="wish-meta"><span>von {html.escape(username)}</span><span>{html.escape(created_at)}</span></div>'
                    f'<h3>{html.escape(title)}</h3>'
                    f'<p>{html.escape(description)}</p>'
                    '<div class="wish-score-row">'
                    f'<div class="wish-score-pill">👍 {int(counts.get("up") or 0)}</div>'
                    f'<div class="wish-score-pill">👎 {int(counts.get("down") or 0)}</div>'
                    f'<div class="wish-score-pill">Deine Stimme: {html.escape(vote_text)}</div>'
                    '</div>'
                    '</div>',
                    unsafe_allow_html=True,
                )

                vote_col_a, vote_col_b = st.columns(2)
                with vote_col_a:
                    if st.button("👍", key=f"wish_up_{wish_id}", use_container_width=True):
                        if not logged_in_username:
                            st.warning("Bitte melde dich zum Abstimmen zuerst an.")
                        elif set_wish_reaction(wish_id, logged_in_username, "up"):
                            st.rerun()
                        else:
                            st.error("Stimme konnte nicht gespeichert werden.")
                with vote_col_b:
                    if st.button("👎", key=f"wish_down_{wish_id}", use_container_width=True):
                        if not logged_in_username:
                            st.warning("Bitte melde dich zum Abstimmen zuerst an.")
                        elif set_wish_reaction(wish_id, logged_in_username, "down"):
                            st.rerun()
                        else:
                            st.error("Stimme konnte nicht gespeichert werden.")
            st.markdown('</div>', unsafe_allow_html=True)

# =========================
# NEWS
# =========================

elif menu == "📰 News":

    st.markdown('<div class="section-kicker">Gehirnzone Gazette</div>', unsafe_allow_html=True)
    st.markdown("## News")

    posts = get_news_posts()
    render_auto_gazette(
        get_members(),
        get_recent_purchases(6),
        get_chicken_scores(5),
        get_creative_gallery(3),
    )

    if not posts:
        st.info("Noch keine News vorhanden. Im Admin-Bereich kannst du die erste Ausgabe erstellen.")
    else:
        lead = posts[0]
        lead_image = str(lead.get("image_url") or "")
        lead_img_html = f'<img class="news-image" src="{html.escape(lead_image, quote=True)}" alt="News Bild">' if lead_image else ""
        lead_date = str(lead.get("published_at") or lead.get("created_at") or "")[:10]

        side_html = ""
        for post in posts[1:6]:
            image_url = str(post.get("image_url") or "")
            image_html = f'<img class="news-image" src="{html.escape(image_url, quote=True)}" alt="News Bild">' if image_url else ""
            side_html += (
                '<article class="news-card">'
                f'{image_html}'
                f'<div class="newspaper-label">{html.escape(str(post.get("published_at") or post.get("created_at") or "")[:10])}</div>'
                f'<h3>{html.escape(str(post.get("title") or ""))}</h3>'
                f'<p>{html.escape(str(post.get("body") or ""))}</p>'
                '</article>'
            )

        st.markdown(
            '<div class="newspaper-grid">'
            '<article class="newspaper-lead">'
            f'{lead_img_html}'
            f'<div class="newspaper-label">{html.escape(lead_date)} · Heute in den Nachrichten</div>'
            f'<h2>{html.escape(str(lead.get("title") or ""))}</h2>'
            f'<p>{html.escape(str(lead.get("body") or ""))}</p>'
            '</article>'
            f'<div class="news-stack">{side_html}</div>'
            '</div>',
            unsafe_allow_html=True
        )

# =========================
# MITGLIEDER
# =========================

elif menu == "👥 Mitglieder":

    members = get_members()

    if not members:
        st.info("Noch keine Mitglieder vorhanden.")
    else:
        ranked_members = sorted(members, key=lambda member: int(member.get("braincells") or 0), reverse=True)
        top_member = ranked_members[0] if ranked_members else None
        member_count = len(ranked_members)
        member_braincells = sum(int(member.get("braincells") or 0) for member in ranked_members)
        member_chickens = sum(int(member.get("chickens") or 0) for member in ranked_members)
        average_braincells = int(member_braincells / member_count) if member_count else 0
        top_name = str(top_member.get("username") or "Noch niemand") if top_member else "Noch niemand"
        top_braincells = int(top_member.get("braincells") or 0) if top_member else 0
        top_rank = get_rank(top_braincells)[0] if top_member else "Rang offen"

        st.markdown(
            '<div class="members-dashboard">'
            '<div class="members-hero">'
            '<div class="members-hero-main">'
            '<div class="section-kicker">Community</div>'
            '<h2>Mitglieder der Gehirnzone</h2>'
            '<p>Alle Viewer, Profile und Rangfortschritte an einem Ort. Finde Namen, vergleiche Gehirnzellen und entdecke, wer gerade vorne leuchtet.</p>'
            '<div class="members-stat-row">'
            f'<div class="members-stat"><strong>{member_count}</strong><span>Mitglieder</span></div>'
            f'<div class="members-stat"><strong>{member_braincells}</strong><span>Gehirnzellen</span></div>'
            f'<div class="members-stat"><strong>{member_chickens}</strong><span>Chickens</span></div>'
            '</div>'
            '</div>'
            '<aside class="members-spotlight">'
            '<div class="section-kicker">Top Signal</div>'
            f'<h3>{html.escape(top_name)}</h3>'
            f'<p>{html.escape(top_rank)} mit durchschnittlich {average_braincells} Gehirnzellen in der Community.</p>'
            f'<div class="members-spotlight-score">🧠 {top_braincells} · #1</div>'
            '</aside>'
            '</div>'
            '</div>',
            unsafe_allow_html=True,
        )

        search_member = st.text_input("Mitglied suchen", placeholder="Name eingeben...")
        rank_lookup = {
            str(member.get("username") or ""): index
            for index, member in enumerate(ranked_members, start=1)
        }
        if search_member:
            members = [
                member for member in ranked_members
                if search_member.lower() in str(member.get("username", "")).lower()
            ]
        else:
            members = ranked_members

        if not members:
            st.info("Keine Mitglieder für diese Suche gefunden.")
            st.stop()

        members_html = '<div class="member-grid">'
        for member in members:
            username = str(member.get("username") or "Unbekannt")
            braincells = int(member.get("braincells") or 0)
            chickens = int(member.get("chickens") or 0)
            rank_name, member_progress, _ = get_progress(braincells)
            level = get_profile_level(braincells)
            bio = member.get("bio") or "Noch keine Bio."
            favorite_game = member.get("favorite_game") or "Nicht gesetzt"
            avatar_markup = get_avatar_markup(username, member.get("avatar_url") or "", 94)

            members_html += (
                '<div class="member-card">'
                f'<div class="member-rank-pill">#{rank_lookup.get(username, "-")}</div>'
                f'{avatar_markup}'
                f'<div class="profile-name">{html.escape(username)}</div>'
                f'<div class="profile-meta">Level {level} · {html.escape(rank_name)}</div>'
                '<div class="member-stat-strip">'
                f'<div class="member-stat-chip"><strong>🧠 {braincells}</strong><span>Gehirnzellen</span></div>'
                f'<div class="member-stat-chip"><strong>🥚 {chickens}</strong><span>Chickens</span></div>'
                '</div>'
                f'<div class="member-mini-progress"><div style="width:{member_progress}%;"></div></div>'
                f'<div class="member-favorite">Lieblingsspiel: {html.escape(str(favorite_game))}</div>'
                f'<div class="profile-bio">{html.escape(str(bio))}</div>'
                '</div>'
            )
        members_html += "</div>"

        st.markdown(members_html, unsafe_allow_html=True)

# =========================
# SHOP
# =========================

elif menu == "🛒 Shop":

    logged_in_username = get_logged_in_username()

    if not logged_in_username:
        st.warning("Bitte melde dich zuerst im Login-Bereich an, um im Shop einzukaufen.")
        st.stop()

    username = st.text_input(
        "Dein Twitch-Name",
        value=logged_in_username,
        disabled=True
    )

    effective_username = logged_in_username

    with st.spinner("Lade Shop-Daten..."):
        user = get_or_create_user(effective_username)

    if user:
        st.markdown(f"""
        <div class="card">
            <h2>🥚 {user["chickens"]}</h2>
            <p>Chickens verfügbar</p>
        </div>
        """, unsafe_allow_html=True)

    st.markdown("## Shop")

    shop_items = get_shop_items()
    wallet_chickens = int(user.get("chickens") or 0) if user else 0
    affordable_items = sum(1 for reward in shop_items if wallet_chickens >= int(reward.get("price") or 0))
    inventory_rows = [row for row in get_market_inventory(logged_in_username) if int(row.get("quantity") or 0) > 0]
    inventory_count = sum(int(row.get("quantity") or 0) for row in inventory_rows)
    outgoing_trades = get_outgoing_trades(logged_in_username)

    st.markdown(f"""
    <div class="shop-dashboard">
        <div class="shop-wallet">
            <div class="section-kicker">Dein Inventar</div>
            <h2>🥚 {wallet_chickens}</h2>
            <div class="admin-muted">Chickens verfügbar für Rewards, Handel und Marktitems.</div>
            <div class="shop-status-row">
                <div class="shop-status-pill"><strong>{affordable_items}</strong><span>Items kaufbar</span></div>
                <div class="shop-status-pill"><strong>{inventory_count}</strong><span>Marktbestand</span></div>
                <div class="shop-status-pill"><strong>{len(outgoing_trades)}</strong><span>Offene Anfragen</span></div>
            </div>
        </div>
        <div class="shop-signal">
            <div class="section-kicker">Marktstatus</div>
            <h3>{len(MARKET_ITEMS)} Trading-Items</h3>
            <div class="admin-muted">Kurse ändern sich täglich. Im Trading Shop kannst du kaufen, halten und verkaufen.</div>
        </div>
    </div>
    """, unsafe_allow_html=True)

    with st.expander("Chicken-Handel", expanded=False):
        members = get_members()
        trade_targets = [
            str(member.get("username"))
            for member in members
            if str(member.get("username")) != logged_in_username
        ]

        if not trade_targets:
            st.info("Es gibt aktuell keine anderen Mitglieder zum Handeln.")
        else:
            with st.form("chicken_trade_form"):
                target_user = st.selectbox("Mitglied auswählen", trade_targets)
                trade_action = st.radio(
                    "Aktion",
                    ["Chickens verschenken", "Chickens anfordern"],
                    horizontal=True
                )
                trade_amount = st.number_input(
                    "Menge",
                    min_value=1,
                    max_value=999999,
                    step=1
                )
                submitted = st.form_submit_button("Handelsanfrage senden")

            if submitted:
                trade_type = "gift" if trade_action == "Chickens verschenken" else "request"
                current_user = get_user(logged_in_username)

                if trade_type == "gift" and current_user and int(current_user.get("chickens") or 0) < int(trade_amount):
                    st.error("Du hast nicht genug Chickens, um diese Menge zu verschenken.")
                else:
                    created = create_chicken_trade(
                        logged_in_username,
                        target_user,
                        trade_type,
                        int(trade_amount)
                    )
                    if created:
                        st.success("Handelsanfrage gesendet.")
                    else:
                        st.error("Handelsanfrage konnte nicht erstellt werden.")

        if outgoing_trades:
            st.markdown("#### Deine offenen Handelsanfragen")
            for trade in outgoing_trades:
                amount = int(trade.get("amount") or 0)
                recipient = trade.get("recipient")
                if trade.get("trade_type") == "gift":
                    st.write(f"Du möchtest {recipient} {amount} Chicken(s) schenken.")
                else:
                    st.write(f"Du fragst {amount} Chicken(s) von {recipient} an.")

    for category in SHOP_CATEGORIES:
        category_rewards = [reward for reward in shop_items if reward.get("category") == category]

        with st.expander(f"{category} ({len(category_rewards)})", expanded=False):
            if not category_rewards:
                st.info("In dieser Kategorie gibt es aktuell keine Artikel.")
            else:
                for reward in category_rewards:
                    price = int(reward.get("price") or 0)
                    can_afford = wallet_chickens >= price
                    state_class = "available" if can_afford else "locked"
                    state_text = "Kaufbar" if can_afford else "Zu teuer"

                    col1, col2 = st.columns([4, 1])

                    with col1:
                        st.markdown(f"""
                            <div class="reward-card shop-item-shell {state_class}">
                                <span class="shop-badge {state_class}">{state_text}</span>
                                <div class="section-kicker">{html.escape(category)}</div>
                                <h3>{html.escape(str(reward["name"]))}</h3>
                                <p>{html.escape(str(reward["desc"]))}</p>
                                <b>🥚 {reward["price"]} Chickens</b>
                            </div>
                            """, unsafe_allow_html=True)

                    with col2:
                        st.write("")

                        if st.button("Kaufen", key=f"buy_{category}_{reward['name']}", disabled=not can_afford):
                            success, message = buy_reward(effective_username, reward)

                            if success:
                                st.success(message)
                                st.rerun()
                            else:
                                st.error(message)

    with st.expander("Kurs", expanded=False):
        st.markdown("Täglicher Kursverlauf der Trading-Items. Kaufen und verkaufen findest du im Dropdown **Trading Shop**.")

        selected_item_name = st.selectbox(
            "Gegenstand auswählen",
            [f'{item["emoji"]} {item["name"]}' for item in MARKET_ITEMS],
            key="shop_market_chart_item",
        )
        selected_item = MARKET_ITEMS[[f'{item["emoji"]} {item["name"]}' for item in MARKET_ITEMS].index(selected_item_name)]
        history = get_market_history(selected_item["key"], days=30)
        chart_df = pd.DataFrame(history)
        chart_df["Datum"] = pd.to_datetime(chart_df["Datum"])
        min_price = int(chart_df["Preis"].min())
        max_price = int(chart_df["Preis"].max())
        price_padding = max(1, int(math.ceil((max_price - min_price) * 0.1)))
        chart_min_price = max(0, min_price - price_padding)
        chart_max_price = max_price + price_padding
        chart_range = max(1, chart_max_price - chart_min_price)
        chart_width = 1120
        chart_height = 320
        plot_left = 58
        plot_right = 24
        plot_top = 16
        plot_bottom = 46
        plot_width = chart_width - plot_left - plot_right
        plot_height = chart_height - plot_top - plot_bottom

        def chart_x(index):
            return plot_left + (index * plot_width / max(1, len(chart_df) - 1))

        def chart_y(price):
            return plot_top + ((chart_max_price - price) * plot_height / chart_range)

        point_coords = [
            (chart_x(index), chart_y(int(row["Preis"])), row)
            for index, row in chart_df.iterrows()
        ]
        line_points = " ".join(f"{x:.1f},{y:.1f}" for x, y, _ in point_coords)
        point_nodes = "\n".join(
            f'<circle cx="{x:.1f}" cy="{y:.1f}" r="3.2"><title>{html.escape(row["Datum"].strftime("%d.%m.%Y"))}: {int(row["Preis"])}</title></circle>'
            for x, y, row in point_coords
        )
        y_tick_values = [
            chart_min_price + round(index * chart_range / 4)
            for index in range(5)
        ]
        y_grid_nodes = "\n".join(
            f'<line x1="{plot_left}" y1="{chart_y(value):.1f}" x2="{chart_width - plot_right}" y2="{chart_y(value):.1f}" />'
            f'<text x="{plot_left - 16}" y="{chart_y(value) + 4:.1f}" text-anchor="end">{value}</text>'
            for value in y_tick_values
        )
        x_label_indexes = sorted(set(list(range(0, len(chart_df), 4)) + [len(chart_df) - 1]))
        x_label_nodes = "\n".join(
            f'<text x="{chart_x(index):.1f}" y="{chart_height - 18}" text-anchor="middle">{html.escape(chart_df.iloc[index]["Datum"].strftime("%d.%m."))}</text>'
            for index in x_label_indexes
        )
        chart_svg = textwrap.dedent(f"""
            <div class="static-market-chart">
                <svg viewBox="0 0 {chart_width} {chart_height}" role="img" aria-label="Kursverlauf">
                    <rect x="0" y="0" width="{chart_width}" height="{chart_height}" rx="0" />
                    <g class="grid">{y_grid_nodes}</g>
                    <g class="axis">
                        <line x1="{plot_left}" y1="{plot_top}" x2="{plot_left}" y2="{chart_height - plot_bottom}" />
                        <line x1="{plot_left}" y1="{chart_height - plot_bottom}" x2="{chart_width - plot_right}" y2="{chart_height - plot_bottom}" />
                        {x_label_nodes}
                        <text x="{chart_width / 2:.1f}" y="{chart_height - 2}" text-anchor="middle">Datum</text>
                        <text x="12" y="{chart_height / 2:.1f}" text-anchor="middle" transform="rotate(-90 12 {chart_height / 2:.1f})">Verkaufspreis</text>
                    </g>
                    <polyline class="price-line" points="{line_points}" />
                    <g class="points">{point_nodes}</g>
                </svg>
            </div>
        """)
        chart_style = textwrap.dedent("""
            <style>
            .static-market-chart {
                width: 100%;
                overflow: hidden;
                background: #0f1118;
                border: 1px solid rgba(255,255,255,0.08);
            }
            .static-market-chart svg {
                display: block;
                width: 100%;
                height: 320px;
            }
            .static-market-chart rect {
                fill: #0f1118;
            }
            .static-market-chart .grid line {
                stroke: rgba(255,255,255,0.16);
                stroke-width: 1;
            }
            .static-market-chart .grid text,
            .static-market-chart .axis text {
                fill: #ffffff;
                font-size: 12px;
                font-weight: 600;
            }
            .static-market-chart .axis line {
                stroke: rgba(255,255,255,0.20);
                stroke-width: 1;
            }
            .static-market-chart .price-line {
                fill: none;
                stroke: #ff54a0;
                stroke-width: 2.2;
            }
            .static-market-chart .points circle {
                fill: #7bc4ff;
                stroke: #0f1118;
                stroke-width: 1;
            }
            </style>
        """)
        components.html(
            chart_style + chart_svg,
            height=330,
            scrolling=False,
        )

    with st.expander("Trading Shop", expanded=False):
        st.markdown("Kaufe Marktgegenstände mit Chickens, halte sie im Profil und verkaufe sie, wenn der Kurs stimmt.")

        market_cards = ""
        for item in MARKET_ITEMS:
            sell_price = get_market_sell_price(item["key"])
            buy_price = get_market_buy_price(item["key"])
            yesterday_price = int(math.floor(get_market_price(item["key"], datetime.now(ZoneInfo("Europe/Berlin")).date() - timedelta(days=1)) * (1 - MARKET_SPREAD)))
            delta = sell_price - yesterday_price
            delta_class = "up" if delta >= 0 else "down"
            sign = "+" if delta >= 0 else ""
            quantity = get_market_quantity(logged_in_username, item["key"]) if logged_in_username else 0
            market_cards += (
                '<div class="market-card">'
                f'<strong>{item["emoji"]} {html.escape(item["name"])}</strong>'
                f'<div class="market-price">{sell_price} 🥚</div>'
                f'<div class="market-delta {delta_class}">{sign}{delta} Verkaufspreis heute</div>'
                f'<div class="admin-muted">Kaufen: {buy_price} 🥚 · Verkaufen: {sell_price} 🥚</div>'
                f'<div class="admin-muted">Du besitzt: {quantity}</div>'
                '</div>'
            )
        st.markdown(f'<div class="market-grid">{market_cards}</div>', unsafe_allow_html=True)

        trade_col_a, trade_col_b = st.columns(2)
        with trade_col_a:
            with st.form("market_buy_form"):
                buy_label = st.selectbox("Kaufen", [f'{item["emoji"]} {item["name"]}' for item in MARKET_ITEMS], key="market_buy_item")
                buy_item = MARKET_ITEMS[[f'{item["emoji"]} {item["name"]}' for item in MARKET_ITEMS].index(buy_label)]
                buy_quantity = st.number_input("Anzahl kaufen", min_value=1, max_value=999, step=1)
                buy_total = get_market_buy_price(buy_item["key"]) * int(buy_quantity)
                st.caption(f"Kosten: {buy_total} Chickens · Tageslimit: {MARKET_DAILY_BUY_LIMIT} pro Item")
                if st.form_submit_button("Kaufen"):
                    success, message = buy_market_item(logged_in_username, buy_item["key"], buy_quantity)
                    if success:
                        st.success(message)
                        st.rerun()
                    else:
                        st.error(message)

        with trade_col_b:
            inventory = [row for row in get_market_inventory(logged_in_username) if int(row.get("quantity") or 0) > 0]
            with st.form("market_sell_form"):
                if inventory:
                    sell_options = []
                    for row in inventory:
                        item = get_market_item(row.get("item_key"))
                    if item:
                        sell_options.append((item, int(row.get("quantity") or 0)))
                    sell_label = st.selectbox(
                        "Verkaufen",
                        [f'{item["emoji"]} {item["name"]} ({qty}x)' for item, qty in sell_options],
                        key="market_sell_item",
                    )
                    selected_index = [f'{item["emoji"]} {item["name"]} ({qty}x)' for item, qty in sell_options].index(sell_label)
                    sell_item, max_qty = sell_options[selected_index]
                    sell_quantity = st.number_input("Anzahl verkaufen", min_value=1, max_value=max_qty, step=1)
                    sell_total = get_market_sell_price(sell_item["key"]) * int(sell_quantity)
                    st.caption(f"Erlös: {sell_total} Chickens · Tageslimit: {MARKET_DAILY_SELL_LIMIT} pro Item")
                    submit_sell = st.form_submit_button("Verkaufen")
                    if submit_sell:
                        success, message = sell_market_item(logged_in_username, sell_item["key"], sell_quantity)
                        if success:
                            st.success(message)
                            st.rerun()
                        else:
                            st.error(message)
                else:
                    st.caption("Du besitzt aktuell keine Marktgegenstände.")
                    st.form_submit_button("Verkaufen", disabled=True)

# =========================
# LEADERBOARD
# =========================

elif menu == "🏆 Rangliste":

    st.markdown('<div class="section-kicker">Community Ranking</div>', unsafe_allow_html=True)
    st.markdown("## Rangliste")

    search = st.text_input("Suche nach Viewer", placeholder="Gib einen Namen ein...")

    if leaderboard.empty:
        st.info("Keine Daten vorhanden.")

    else:
        leader = leaderboard.iloc[0]
        average_braincells = int(leaderboard["Gehirnzellen"].mean()) if not leaderboard.empty else 0
        st.markdown(f"""
        <div class="leaderboard-hero">
            <div class="leaderboard-panel">
                <div class="section-kicker">Leaderboard Arena</div>
                <h2>Top Viewer der Gehirnzone</h2>
                <div class="admin-muted">Vergleiche Gehirnzellen, Chickens und Rangfortschritt der Community.</div>
                <div class="leaderboard-stats">
                    <div class="leaderboard-stat"><strong>{len(leaderboard)}</strong><span>Viewer</span></div>
                    <div class="leaderboard-stat"><strong>{total_braincells}</strong><span>Gehirnzellen gesamt</span></div>
                    <div class="leaderboard-stat"><strong>{average_braincells}</strong><span>Ø Gehirnzellen</span></div>
                </div>
            </div>
            <div class="leaderboard-focus">
                <div class="section-kicker">Aktuelle Nummer 1</div>
                <h3>{html.escape(str(leader["Viewer"]))}</h3>
                <div class="podium-score">🧠 {int(leader["Gehirnzellen"])} · 🥚 {int(leader["Chickens"])}</div>
            </div>
        </div>
        """, unsafe_allow_html=True)

        top_viewers = leaderboard.head(3).to_dict("records")
        podium_slots = [
            ("2", "silver", top_viewers[1] if len(top_viewers) > 1 else None),
            ("1", "gold", top_viewers[0] if len(top_viewers) > 0 else None),
            ("3", "bronze", top_viewers[2] if len(top_viewers) > 2 else None),
        ]

        podium_cards = []
        for place, style, viewer in podium_slots:
            if viewer:
                viewer_name = html.escape(str(viewer["Viewer"]))
                podium_cards.append(
                    f'<div class="podium-card {style}">'
                    f'<div class="podium-rank">#{place}</div>'
                    f'<div class="podium-name">{viewer_name}</div>'
                    f'<div class="podium-score">🧠 {int(viewer["Gehirnzellen"])} · 🥚 {int(viewer["Chickens"])}</div>'
                    f'</div>'
                )
            else:
                podium_cards.append(
                    f'<div class="podium-card {style}">'
                    f'<div class="podium-rank">#{place}</div>'
                    f'<div class="podium-name">Noch frei</div>'
                    f'<div class="podium-score">Werde sichtbar</div>'
                    f'</div>'
                )

        podium_html = f'<div class="podium-grid">{"".join(podium_cards)}</div>'
        st.markdown(podium_html, unsafe_allow_html=True)

        ranked = leaderboard.copy().reset_index(drop=True)
        ranked["Rangplatz"] = ranked.index + 1

        if search:
            ranked = ranked[ranked["Viewer"].str.contains(search, case=False, na=False)]

        ranked["Rang"] = ranked["Gehirnzellen"].apply(
            lambda x: get_rank(int(x))[0]
        )

        if ranked.empty:
            st.info("Keine Viewer für diese Suche gefunden.")
        else:
            max_braincells = max(1, int(leaderboard["Gehirnzellen"].max()))
            rank_rows = ""
            for index, viewer in ranked.reset_index(drop=True).iterrows():
                braincells = int(viewer["Gehirnzellen"])
                chickens = int(viewer["Chickens"])
                rank_name, rank_progress, _ = get_progress(braincells)
                total_progress = min(100, int((braincells / max_braincells) * 100))
                rank_place = int(viewer["Rangplatz"])
                row_class = "top" if rank_place <= 3 else ""
                rank_rows += (
                    f'<div class="rank-row {row_class}">'
                    f'<div class="rank-badge">#{rank_place}</div>'
                    '<div class="rank-main">'
                    f'<strong>{html.escape(str(viewer["Viewer"]))}</strong>'
                    f'<span>{html.escape(rank_name)} · Rangfortschritt {rank_progress}%</span>'
                    f'<div class="rank-progress"><div style="width:{total_progress}%;"></div></div>'
                    '</div>'
                    '<div class="rank-side">'
                    f'<strong>🧠 {braincells}</strong>'
                    f'<span>🥚 {chickens} Chickens</span>'
                    '</div>'
                    '</div>'
                )

            st.markdown("### Ranking")
            st.markdown(f'<div class="rank-list">{rank_rows}</div>', unsafe_allow_html=True)

    st.markdown("### Chicken Jump Scoreboards")
    scoreboard_panels = []
    for period_key, period_title in [("all", "All-Time"), ("week", "Diese Woche"), ("today", "Heute")]:
        period_scores = get_chicken_scores_for_period(period_key, 100)
        best_by_user = {}
        for score in period_scores:
            username = str(score.get("username") or "Unbekannt")
            current_score = int(score.get("score") or 0)
            existing = best_by_user.get(username)
            if not existing or current_score > int(existing.get("score") or 0):
                best_by_user[username] = score

        rows = ""
        top_scores = sorted(
            best_by_user.values(),
            key=lambda item: int(item.get("score") or 0),
            reverse=True,
        )[:5]
        for index, score in enumerate(top_scores, start=1):
            rows += (
                '<div class="chicken-score-row">'
                f'<strong>#{index} {html.escape(str(score.get("username") or "Unbekannt"))}</strong>'
                f'<span>{int(score.get("score") or 0)} Punkte · Level {int(score.get("level") or 1)}</span>'
                '</div>'
            )
        if not rows:
            rows = '<div class="admin-muted">Noch keine Scores.</div>'

        scoreboard_panels.append(
            '<section class="chicken-scoreboard-panel">'
            f'<div class="section-kicker">Chicken Jump</div><h3>{period_title}</h3>'
            f'{rows}'
            '</section>'
        )

    st.markdown(
        f'<div class="chicken-scoreboard-grid">{"".join(scoreboard_panels)}</div>',
        unsafe_allow_html=True,
    )

# =========================
# EVENTS
# =========================

elif menu == "⚡ Events":

    logged_in_username = get_logged_in_username()

    if not logged_in_username:
        st.warning("Bitte melde dich zuerst im Login-Bereich an, um dich für Events an- oder abzumelden.")
        st.stop()

    viewer_name = st.text_input(
        "Dein Twitch-Name",
        value=logged_in_username,
        disabled=True
    )

    effective_viewer_name = logged_in_username

    with st.spinner("Lade Events..."):
        events = get_events()

    if not events:
        st.info("Keine Events vorhanden.")

    else:
        for event in events:

            event_id = event["id"]

            signups = get_event_signups(event_id)

            signed_up = is_signed_up(event_id, effective_viewer_name)
            event_date_text = str(event.get("event_date") or "")
            event_date_parts = event_date_text.split(" ", 1)
            event_day = event_date_parts[0] if event_date_parts else "TBA"
            event_time = event_date_parts[1] if len(event_date_parts) > 1 else "Uhrzeit offen"
            status_text = "Angemeldet" if signed_up else "Offen"
            status_class = "joined" if signed_up else ""

            st.markdown(f"""
            <div class="event-ticket">
                <div class="event-ticket-date">
                    <strong>{html.escape(event_day)}</strong>
                    <span>{html.escape(event_time)}</span>
                </div>
                <div class="event-ticket-main">
                    <div class="section-kicker">Community Event</div>
                    <h3>{html.escape(str(event["title"]))}</h3>
                    <p>{html.escape(str(event["description"]))}</p>
                </div>
                <div class="event-ticket-side">
                    <div class="event-ticket-status {status_class}">{status_text}</div>
                    <div class="event-ticket-count">{len(signups)}</div>
                    <div class="admin-muted">Anmeldung(en)</div>
                </div>
            </div>
            """, unsafe_allow_html=True)

            col1, col2 = st.columns([1, 4])

            with col1:
                if not signed_up:
                    if st.button("Anmelden", key=f"join_{event_id}"):
                        signup_event(event_id, effective_viewer_name)
                        st.success("Angemeldet")
                        st.rerun()
                else:
                    if st.button("Abmelden", key=f"leave_{event_id}"):
                        leave_event(event_id, effective_viewer_name)
                        st.warning("Abgemeldet")
                        st.rerun()

            with col2:
                if signups:
                    names = ", ".join([s["username"] for s in signups])
                    st.caption(f"Angemeldet: {names}")

            st.write("---")

# =========================
# KREATIVWAND
# =========================

elif menu == "🎨 Kreativwand":

    logged_in_username = get_logged_in_username()

    st.markdown('<div class="section-kicker">Kreativwand</div>', unsafe_allow_html=True)
    st.markdown("## Leinwand")

    if not logged_in_username:
        st.warning("Bitte melde dich zuerst an, um ein Bild zu veröffentlichen.")
        if st.button("Zum Login", key="creative_login_cta", use_container_width=True):
            st.session_state["app_menu"] = "🔑 Login"
            st.rerun()
    elif st_canvas is None:
        st.error("Die Zeichen-Komponente ist noch nicht installiert. Warte auf den nächsten Deploy oder prüfe requirements.txt.")
    else:
        existing_art = get_user_creative_art(logged_in_username)
        if existing_art:
            st.info("Du hast bereits ein Bild in der Hall of Fame. Pro Profil ist nur ein Bild erlaubt.")
            existing_title = str(existing_art.get("title") or "").strip()
            st.image(existing_art.get("image_data"), caption=existing_title if existing_title else None)
        else:
            st.markdown("""
            <div class="creative-shell">
                <div class="creative-panel">
                    <div class="section-kicker">Weisse Leinwand</div>
                    <h3>Zeichne dein Meisterwerk</h3>
                    <p>Wähle Farbe, Strichstärke und Modus. Danach kannst du dein Bild in die Hall of Fame stellen.</p>
                </div>
                <div class="creative-panel">
                    <div class="section-kicker">Signatur</div>
                    <h3>Dein Name steht dabei</h3>
                    <p>Gespeichert wird mit deinem eingeloggten Account.</p>
                </div>
            </div>
            """, unsafe_allow_html=True)

            title = st.text_input("Titel", max_chars=80, placeholder="Mein Kunstwerk")
            tool_col, color_col, width_col = st.columns([1, 1, 1])
            with tool_col:
                drawing_mode = st.selectbox("Werkzeug", ["freedraw", "line", "rect", "circle"], format_func={
                    "freedraw": "Stift",
                    "line": "Linie",
                    "rect": "Rechteck",
                    "circle": "Kreis",
                }.get)
            with color_col:
                selected_stroke_color = st.color_picker("Farbe", "#1f2937")
            with width_col:
                stroke_width = st.slider("Strichstärke", 1, 28, 6)

            stroke_color_key = f"creative_canvas_color_{logged_in_username}"
            if stroke_color_key not in st.session_state:
                st.session_state[stroke_color_key] = selected_stroke_color
            if selected_stroke_color != st.session_state[stroke_color_key]:
                st.session_state[stroke_color_key] = selected_stroke_color
            stroke_color = st.session_state[stroke_color_key]

            canvas_result = st_canvas(
                fill_color="rgba(255, 255, 255, 0)",
                stroke_width=stroke_width,
                stroke_color=stroke_color,
                background_color="#FFFFFF",
                width=820,
                height=560,
                drawing_mode=drawing_mode,
                key="creative_canvas",
                update_streamlit=True,
            )

            if st.button("In Hall of Fame veröffentlichen", key="publish_creative_art", use_container_width=True):
                image_data_uri = canvas_image_to_data_uri(canvas_result.image_data)
                if not image_data_uri:
                    st.error("Die Leinwand ist noch leer.")
                else:
                    success, message = create_creative_art(logged_in_username, title, image_data_uri)
                    if success:
                        st.success(message)
                        st.rerun()
                    else:
                        st.error(message)

elif menu == "🏛️ Hall of Fame":

    st.markdown('<div class="section-kicker">Kreativwand</div>', unsafe_allow_html=True)
    st.markdown("## Hall of Fame")
    render_creative_gallery(60)

# =========================
# CHICKEN JUMP
# =========================

elif menu.endswith("Minispiele"):

    if st.session_state.get("minigame_view") == "dnd":
        if st.button("Zurück zu den Minispielen", key="back_to_minigames", use_container_width=True):
            st.session_state["minigame_view"] = "overview"
            st.rerun()
        render_dnd_page()
        st.stop()

    st.markdown('<div class="section-kicker">Arcade</div>', unsafe_allow_html=True)
    st.markdown("## Chicken Jump")
    st.markdown("""
    <div class="arcade-grid">
        <div class="arcade-card">
            <strong>Saison-Jagd</strong>
            <span>Spiele um Tages-, Wochen- und All-Time-Platzierungen.</span>
        </div>
        <div class="arcade-card">
            <strong>Skill statt Zufall</strong>
            <span>Je länger du überlebst, desto schneller wird das Spiel.</span>
        </div>
        <div class="arcade-card">
            <strong>Globales Scoreboard</strong>
            <span>Gespeicherte Scores sind für alle Viewer sichtbar.</span>
        </div>
    </div>
    """, unsafe_allow_html=True)

    chicken_theme_data_uri = ""
    chicken_theme_path = Path(__file__).parent / "assets" / "chicken_theme.mp3"
    if chicken_theme_path.exists():
        chicken_theme_data_uri = (
            "data:audio/mpeg;base64,"
            + base64.b64encode(chicken_theme_path.read_bytes()).decode("ascii")
        )

    components.html("""
    <html>
    <head>
    <style>
        * { box-sizing: border-box; }
        body {
            margin: 0;
            min-height: 820px;
            background:
                radial-gradient(circle at 16% 10%, rgba(255, 214, 102, 0.16), transparent 24%),
                radial-gradient(circle at 82% 16%, rgba(0, 245, 255, 0.18), transparent 24%),
                radial-gradient(circle at 50% 86%, rgba(255, 84, 160, 0.16), transparent 32%),
                linear-gradient(180deg, #050816 0%, #13091f 52%, #070711 100%);
            color: white;
            font-family: Inter, Segoe UI, Arial, sans-serif;
            overflow: auto;
        }
        .shell { width: min(100%, 1080px); margin: 0 auto; padding: 16px; }
        .game-panel {
            position: relative;
            overflow: hidden;
            border: 1px solid rgba(255,255,255,0.16);
            border-radius: 24px;
            background:
                linear-gradient(135deg, rgba(255,255,255,0.10), rgba(255,255,255,0.035)),
                rgba(5, 8, 16, 0.78);
            box-shadow:
                0 30px 90px rgba(0,0,0,0.48),
                0 0 0 1px rgba(199,125,255,0.08) inset;
        }
        .game-panel::before {
            content: "";
            position: absolute;
            inset: 0;
            pointer-events: none;
            background:
                linear-gradient(90deg, rgba(255,255,255,0.08), transparent 20%, transparent 80%, rgba(255,255,255,0.05)),
                radial-gradient(circle at 50% 0%, rgba(255,255,255,0.16), transparent 38%);
            z-index: 1;
        }
        canvas {
            display: block;
            width: 100%;
            aspect-ratio: 16 / 8;
            background: #081020;
        }
        .overlay {
            position: absolute;
            inset: 0;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 22px;
            background:
                radial-gradient(circle at 50% 34%, rgba(255,214,102,0.14), transparent 26%),
                linear-gradient(180deg, rgba(7,9,18,0.30), rgba(7,9,18,0.86));
            z-index: 2;
        }
        .menu-card {
            width: min(520px, 92%);
            border: 1px solid rgba(255,255,255,0.16);
            border-radius: 22px;
            padding: 28px;
            text-align: center;
            background:
                linear-gradient(135deg, rgba(255,255,255,0.12), rgba(255,255,255,0.045)),
                rgba(12, 14, 24, 0.90);
            box-shadow:
                0 0 48px rgba(157,78,221,0.26),
                0 24px 70px rgba(0,0,0,0.38);
            backdrop-filter: blur(10px);
        }
        .menu-card h1 { margin: 0 0 8px; font-size: 46px; line-height: 1; }
        .menu-card p { margin: 8px auto 18px; color: #d7c8ff; line-height: 1.45; }
        .actions { display: flex; gap: 10px; justify-content: center; flex-wrap: wrap; }
        button {
            border: 0;
            border-radius: 999px;
            padding: 12px 18px;
            color: #05050a;
            cursor: pointer;
            font-weight: 900;
            background: linear-gradient(135deg, #c77dff, #00d4ff);
            box-shadow: 0 12px 28px rgba(0,212,255,0.20);
        }
        button:hover { transform: translateY(-1px); filter: brightness(1.08); }
        button.secondary {
            color: #fff;
            background: rgba(255,255,255,0.10);
            border: 1px solid rgba(255,255,255,0.16);
            box-shadow: none;
        }
        button.sound-toggle {
            color: #fff;
            background: rgba(255,255,255,0.08);
            border: 1px solid rgba(255,255,255,0.16);
            box-shadow: none;
        }
        .menu-options {
            display: grid;
            grid-template-columns: repeat(3, minmax(0, 1fr));
            gap: 8px;
            margin: 16px 0 4px;
        }
        .menu-option {
            min-height: 70px;
            border: 1px solid rgba(255,255,255,0.12);
            border-radius: 14px;
            padding: 10px;
            background: rgba(255,255,255,0.06);
            color: #fff;
            box-shadow: none;
        }
        .menu-option strong {
            display: block;
            font-size: 13px;
            margin-bottom: 4px;
        }
        .menu-option span {
            display: block;
            color: #cfc6e8;
            font-size: 12px;
            font-weight: 800;
        }
        .menu-option.off {
            opacity: 0.62;
            background: rgba(255,255,255,0.035);
        }
        .menu-info {
            display: grid;
            grid-template-columns: repeat(3, minmax(0, 1fr));
            gap: 8px;
            margin-top: 14px;
            text-align: left;
        }
        .menu-info div {
            border-radius: 12px;
            padding: 10px;
            background: rgba(0,0,0,0.18);
            border: 1px solid rgba(255,255,255,0.08);
        }
        .menu-info strong {
            display: block;
            margin-bottom: 4px;
            font-size: 12px;
            color: #ffe66d;
        }
        .menu-info span {
            color: #cfc6e8;
            font-size: 12px;
            font-weight: 750;
            line-height: 1.35;
        }
        .hud { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-top: 12px; }
        .hud-card {
            min-height: 74px;
            padding: 13px 14px;
            border: 1px solid rgba(255,255,255,0.11);
            border-radius: 16px;
            background:
                linear-gradient(135deg, rgba(255,255,255,0.08), rgba(255,255,255,0.035)),
                rgba(255,255,255,0.045);
            box-shadow: 0 16px 38px rgba(0,0,0,0.20);
        }
        .hud-card span {
            display: block;
            color: #aeb6d9;
            font-size: 12px;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.06em;
        }
        .hud-card strong { display: block; margin-top: 4px; font-size: 26px; }
        .scores {
            margin-top: 12px;
            border: 1px solid rgba(199,125,255,0.20);
            border-radius: 18px;
            padding: 14px;
            background:
                linear-gradient(135deg, rgba(255,255,255,0.07), rgba(255,255,255,0.035)),
                rgba(255,255,255,0.045);
            overflow: hidden;
        }
        .scores h3 { margin: 0 0 10px; font-size: 18px; }
        .score-tabs { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 12px; }
        .score-tabs button {
            padding: 8px 12px;
            color: #fff;
            background: rgba(255,255,255,0.08);
            border: 1px solid rgba(255,255,255,0.14);
            box-shadow: none;
        }
        .score-tabs button.active {
            color: #05050a;
            background: linear-gradient(135deg, #c77dff, #00d4ff);
        }
        .scores ol {
            margin: 0;
            padding: 0;
            color: #e9ddff;
            list-style: none;
            max-height: 220px;
            overflow-y: auto;
        }
        .scores li {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 12px;
            margin: 7px 0;
            padding: 9px 11px;
            border-radius: 10px;
            background: rgba(255,255,255,0.055);
            border: 1px solid rgba(255,255,255,0.07);
        }
        .hint-strip {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            margin: 10px 0 0;
            color: #aeb6d9;
            font-size: 12px;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.06em;
        }
        .hint-strip span {
            padding: 6px 10px;
            border-radius: 999px;
            background: rgba(255,255,255,0.06);
            border: 1px solid rgba(255,255,255,0.08);
        }
        @media (max-width: 720px) {
            body { min-height: 900px; }
            .hud { grid-template-columns: 1fr; }
            .scores li { align-items: flex-start; flex-direction: column; }
            .menu-card h1 { font-size: 34px; }
            .menu-options,
            .menu-info { grid-template-columns: 1fr; }
        }
    </style>
    </head>
    <body>
    <div class="shell">
        <audio id="bgMusic" src="__CHICKEN_THEME_SRC__" loop preload="auto"></audio>
        <div class="game-panel">
            <canvas id="game" width="1000" height="500"></canvas>
            <div id="overlay" class="overlay">
                <div class="menu-card">
                    <h1 id="menuTitle">Chicken Jump</h1>
                    <p id="menuText">Spring über Zäune, sammle Gehirnzellen und halte so lange wie möglich durch.</p>
                    <div class="actions">
                        <button id="startBtn">Spiel starten</button>
                        <button id="scoreBtn" class="secondary">Score speichern</button>
                    </div>
                    <div class="menu-options">
                        <button id="soundBtn" class="menu-option"><strong>Sound</strong><span>An</span></button>
                        <button id="musicBtn" class="menu-option"><strong>Musik</strong><span>Cozy Loop</span></button>
                        <button id="sfxBtn" class="menu-option"><strong>SFX</strong><span>Plings</span></button>
                    </div>
                    <div class="menu-info">
                        <div><strong>Steuerung</strong><span>Space, Enter oder Klick.</span></div>
                        <div><strong>Musik</strong><span>Startet erst nach Spielstart.</span></div>
                        <div><strong>Ziel</strong><span>Timing halten, Zäune überspringen.</span></div>
                    </div>
                </div>
            </div>
        </div>

        <div class="hud">
            <div class="hud-card"><span>Score</span><strong id="scoreValue">0</strong></div>
            <div class="hud-card"><span>Tempo</span><strong id="speedValue">1.0x</strong></div>
            <div class="hud-card"><span>Level</span><strong id="levelValue">1</strong></div>
        </div>
        <div class="hint-strip"><span>Space / Klick zum Springen</span><span>Timing ist alles</span></div>

        <div class="scores">
            <h3>Scoreboard</h3>
            <div class="score-tabs">
                <button class="active" data-score-filter="all">All-Time</button>
                <button data-score-filter="week">Diese Woche</button>
                <button data-score-filter="today">Heute</button>
            </div>
            <ol id="scores"></ol>
        </div>
    </div>

    <script>
    const canvas = document.getElementById("game");
    const ctx = canvas.getContext("2d");
    const overlay = document.getElementById("overlay");
    const menuTitle = document.getElementById("menuTitle");
    const menuText = document.getElementById("menuText");
    const startBtn = document.getElementById("startBtn");
    const scoreBtn = document.getElementById("scoreBtn");
    const soundBtn = document.getElementById("soundBtn");
    const musicBtn = document.getElementById("musicBtn");
    const sfxBtn = document.getElementById("sfxBtn");
    const scoreValue = document.getElementById("scoreValue");
    const speedValue = document.getElementById("speedValue");
    const levelValue = document.getElementById("levelValue");
    const bgMusic = document.getElementById("bgMusic");
    const SUPABASE_URL = "__SUPABASE_URL__";
    const SUPABASE_KEY = "__SUPABASE_KEY__";
    const SCOREBOARD_ENDPOINT = SUPABASE_URL + "/rest/v1/chicken_scores";

    let chicken = { x: 120, y: 338, w: 54, h: 46, vy: 0, jumping: false };
    const groundY = 390;
    let gravity = 0.82;
    let fences = [];
    let clouds = [];
    let particles = [];
    let scorePops = [];
    const START_SPEED = 4.35;
    const MAX_SPEED = 10.4;
    let speed = START_SPEED;
    let score = 0;
    let level = 1;
    let state = "menu";
    let frame = 0;
    let savedCurrentScore = false;
    let currentScoreFilter = "all";
    let jumpHeld = false;
    let jumpHoldFrames = 0;
    let audioCtx = null;
    let musicTimer = null;
    let musicStep = 0;
    let soundEnabled = true;
    let musicEnabled = true;
    let sfxEnabled = true;
    const melody = [
        {note: 659.25, bass: 164.81},
        {note: 783.99, bass: 164.81},
        {note: 880.00, bass: 220.00},
        {note: 783.99, bass: 220.00},
        {note: 659.25, bass: 196.00},
        {note: 587.33, bass: 196.00},
        {note: 659.25, bass: 246.94},
        {note: 493.88, bass: 246.94}
    ];

    function ensureAudio() {
        if (!soundEnabled) return null;
        if (!audioCtx) {
            audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        }
        if (audioCtx.state === "suspended") audioCtx.resume();
        return audioCtx;
    }

    function playTone(freq, duration, type, volume, when = 0, pan = 0) {
        const ctxAudio = ensureAudio();
        if (!ctxAudio) return;
        const start = ctxAudio.currentTime + when;
        const osc = ctxAudio.createOscillator();
        const gain = ctxAudio.createGain();
        const panner = ctxAudio.createStereoPanner ? ctxAudio.createStereoPanner() : null;
        osc.type = type;
        osc.frequency.setValueAtTime(freq, start);
        gain.gain.setValueAtTime(0.0001, start);
        gain.gain.exponentialRampToValueAtTime(volume, start + 0.018);
        gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);
        if (panner) {
            panner.pan.setValueAtTime(pan, start);
            osc.connect(gain).connect(panner).connect(ctxAudio.destination);
        } else {
            osc.connect(gain).connect(ctxAudio.destination);
        }
        osc.start(start);
        osc.stop(start + duration + 0.04);
    }

    function playNoise(duration, volume) {
        const ctxAudio = ensureAudio();
        if (!ctxAudio) return;
        const buffer = ctxAudio.createBuffer(1, ctxAudio.sampleRate * duration, ctxAudio.sampleRate);
        const data = buffer.getChannelData(0);
        for (let i = 0; i < data.length; i++) {
            data[i] = (Math.random() * 2 - 1) * (1 - i / data.length);
        }
        const source = ctxAudio.createBufferSource();
        const gain = ctxAudio.createGain();
        source.buffer = buffer;
        gain.gain.setValueAtTime(volume, ctxAudio.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.0001, ctxAudio.currentTime + duration);
        source.connect(gain).connect(ctxAudio.destination);
        source.start();
    }

    function playJumpSound() {
        if (!sfxEnabled) return;
        playTone(520, 0.09, "triangle", 0.08, 0, -0.15);
        playTone(760, 0.13, "sine", 0.055, 0.035, 0.12);
    }

    function playScoreSound() {
        if (!sfxEnabled) return;
        playTone(880, 0.08, "sine", 0.08, 0, -0.1);
        playTone(1174.66, 0.12, "sine", 0.07, 0.065, 0.15);
    }

    function playCrashSound() {
        if (!sfxEnabled) return;
        playTone(180, 0.18, "sawtooth", 0.08, 0, 0);
        playNoise(0.18, 0.05);
    }

    function playButtonSound() {
        if (!sfxEnabled) return;
        playTone(659.25, 0.06, "triangle", 0.055);
    }

    function musicTick() {
        if (!soundEnabled || !musicEnabled || state !== "playing") return;
        const step = melody[musicStep % melody.length];
        const lift = Math.min(level - 1, 8) * 8;
        playTone(step.bass, 0.22, "sine", 0.032, 0, -0.25);
        playTone(step.note + lift, 0.18, "triangle", 0.035, 0.02, 0.18);
        if (musicStep % 2 === 0) playTone(step.note * 1.5 + lift, 0.10, "sine", 0.018, 0.09, 0.35);
        musicStep++;
    }

    function startMusic() {
        if (!soundEnabled || !musicEnabled) return;
        ensureAudio();
        stopMusic();
        if (bgMusic && bgMusic.getAttribute("src")) {
            bgMusic.volume = 0.34;
            bgMusic.currentTime = 0;
            bgMusic.play().catch(() => {});
            return;
        }
        musicStep = 0;
        musicTick();
        musicTimer = setInterval(musicTick, 360);
    }

    function stopMusic() {
        if (musicTimer) clearInterval(musicTimer);
        musicTimer = null;
        if (bgMusic) {
            bgMusic.pause();
            bgMusic.currentTime = 0;
        }
    }

    function updateSoundButton() {
        soundBtn.querySelector("span").textContent = soundEnabled ? "An" : "Aus";
        musicBtn.querySelector("span").textContent = musicEnabled ? "MP3 Loop" : "Aus";
        sfxBtn.querySelector("span").textContent = sfxEnabled ? "Plings" : "Aus";
        soundBtn.classList.toggle("off", !soundEnabled);
        musicBtn.classList.toggle("off", !musicEnabled || !soundEnabled);
        sfxBtn.classList.toggle("off", !sfxEnabled || !soundEnabled);
    }

    function showMenu(title, text, primaryText) {
        menuTitle.textContent = title;
        menuText.textContent = text;
        startBtn.textContent = primaryText;
        scoreBtn.style.display = state === "gameover" && score > 0 && !savedCurrentScore ? "inline-block" : "none";
        overlay.style.display = "flex";
    }

    function hideMenu() {
        overlay.style.display = "none";
    }

    function jump() {
        if (state === "menu") {
            startGame();
            return;
        }
        if (state === "gameover") return;
        if (!chicken.jumping) {
            playJumpSound();
            chicken.vy = -12.8;
            chicken.jumping = true;
            jumpHoldFrames = 0;
            for (let i = 0; i < 10; i++) {
                particles.push({
                    x: chicken.x + 12 + Math.random() * 18,
                    y: groundY - 10 + Math.random() * 8,
                    vx: -1.5 - Math.random() * 2.2,
                    vy: -0.8 - Math.random() * 1.8,
                    r: 2 + Math.random() * 3,
                    color: Math.random() > 0.5 ? "255, 230, 109" : "0, 212, 255",
                    life: 18 + Math.random() * 10,
                    maxLife: 28
                });
            }
        }
    }

    startBtn.addEventListener("click", function() {
        playButtonSound();
        startGame();
    });
    scoreBtn.addEventListener("click", saveScore);
    soundBtn.addEventListener("click", function() {
        soundEnabled = !soundEnabled;
        if (!soundEnabled) stopMusic();
        else if (state === "playing") startMusic();
        updateSoundButton();
        playButtonSound();
    });
    musicBtn.addEventListener("click", function() {
        musicEnabled = !musicEnabled;
        if (!musicEnabled) stopMusic();
        else if (state === "playing") startMusic();
        playButtonSound();
        updateSoundButton();
    });
    sfxBtn.addEventListener("click", function() {
        sfxEnabled = !sfxEnabled;
        playButtonSound();
        updateSoundButton();
    });
    canvas.addEventListener("pointerdown", function() {
        jumpHeld = true;
        jump();
    });
    canvas.addEventListener("pointerup", function() {
        jumpHeld = false;
    });
    canvas.addEventListener("pointerleave", function() {
        jumpHeld = false;
    });
    document.querySelectorAll("[data-score-filter]").forEach(button => {
        button.addEventListener("click", async function() {
            currentScoreFilter = this.dataset.scoreFilter;
            document.querySelectorAll("[data-score-filter]").forEach(item => item.classList.remove("active"));
            this.classList.add("active");
            await renderScores();
        });
    });
    document.addEventListener("keydown", function(e) {
        if (e.code === "Space") {
            e.preventDefault();
            jumpHeld = true;
            if (!e.repeat) jump();
        } else if (e.code === "Enter" && state !== "playing") {
            startGame();
        }
    });
    document.addEventListener("keyup", function(e) {
        if (e.code === "Space") jumpHeld = false;
    });

    function spawnFence() {
        const earlyGame = score < 6;
        const midGame = score < 16;
        const height = earlyGame
            ? 34 + Math.random() * 16
            : midGame
                ? 42 + Math.random() * 22
                : 48 + Math.random() * 30;
        fences.push({
            x: canvas.width + 40,
            y: groundY - height,
            w: earlyGame ? 24 + Math.random() * 9 : 30 + Math.random() * 14,
            h: height,
            passed: false
        });
    }

    function getSpawnInterval() {
        const baseInterval = 166 - score * 1.45 - speed * 3.2;
        return Math.max(72, Math.floor(baseInterval));
    }

    function spawnCloud() {
        clouds.push({
            x: canvas.width + 90,
            y: 45 + Math.random() * 120,
            w: 80 + Math.random() * 90,
            speed: 0.45 + Math.random() * 0.55
        });
    }

    function roundedRect(x, y, w, h, r) {
        r = Math.max(0, Math.min(r, w / 2, h / 2));
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.lineTo(x + w - r, y);
        ctx.quadraticCurveTo(x + w, y, x + w, y + r);
        ctx.lineTo(x + w, y + h - r);
        ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
        ctx.lineTo(x + r, y + h);
        ctx.quadraticCurveTo(x, y + h, x, y + h - r);
        ctx.lineTo(x, y + r);
        ctx.quadraticCurveTo(x, y, x + r, y);
        ctx.fill();
    }

    function drawBackground() {
        const sky = ctx.createLinearGradient(0, 0, 0, canvas.height);
        sky.addColorStop(0, "#071a33");
        sky.addColorStop(0.42, "#17113a");
        sky.addColorStop(0.74, "#321145");
        sky.addColorStop(1, "#190b24");
        ctx.fillStyle = sky;
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        const moon = ctx.createRadialGradient(810, 86, 4, 810, 86, 86);
        moon.addColorStop(0, "rgba(255, 245, 204, 0.92)");
        moon.addColorStop(0.22, "rgba(255, 245, 204, 0.42)");
        moon.addColorStop(1, "rgba(255, 245, 204, 0)");
        ctx.fillStyle = moon;
        ctx.beginPath();
        ctx.arc(810, 86, 86, 0, Math.PI * 2);
        ctx.fill();

        ctx.fillStyle = "rgba(255,255,255,0.35)";
        for (let i = 0; i < 42; i++) {
            const x = (i * 137 + frame * 0.18) % canvas.width;
            const y = 18 + (i * 53) % 190;
            ctx.fillRect(x, y, 2, 2);
        }

        drawHills(0.20, 318, "#1f2555", 58);
        drawHills(0.38, 350, "#251346", 78);
        drawHills(0.62, 378, "#32163c", 54);

        if (frame % 180 === 0) spawnCloud();
        clouds.forEach(c => {
            c.x -= c.speed;
            ctx.fillStyle = "rgba(255,255,255,0.15)";
            roundedRect(c.x, c.y, c.w, 22, 999);
            roundedRect(c.x + c.w * 0.18, c.y - 12, c.w * 0.45, 28, 999);
            roundedRect(c.x + c.w * 0.52, c.y - 6, c.w * 0.35, 22, 999);
        });
        clouds = clouds.filter(c => c.x + c.w > -120);
    }

    function drawHills(rate, baseY, color, height) {
        const offset = (frame * speed * rate) % 260;
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.moveTo(-260 - offset, canvas.height);
        for (let x = -260 - offset; x <= canvas.width + 260; x += 130) {
            ctx.quadraticCurveTo(x + 65, baseY - height, x + 130, baseY);
        }
        ctx.lineTo(canvas.width + 260, canvas.height);
        ctx.closePath();
        ctx.fill();
    }

    function drawGround() {
        const ground = ctx.createLinearGradient(0, groundY, 0, canvas.height);
        ground.addColorStop(0, "#3a1e52");
        ground.addColorStop(0.45, "#22122f");
        ground.addColorStop(1, "#110713");
        ctx.fillStyle = ground;
        ctx.fillRect(0, groundY, canvas.width, canvas.height - groundY);

        ctx.fillStyle = "rgba(124,255,178,0.34)";
        for (let i = 0; i < canvas.width + 80; i += 20) {
            const x = i - (frame * speed * 0.65 % 20);
            ctx.fillRect(x, groundY - 7, 3, 12);
        }

        ctx.fillStyle = "#00d4ff";
        for (let i = 0; i < canvas.width + 60; i += 44) {
            roundedRect(i - (frame * speed % 44), groundY + 12, 22, 4, 4);
        }

        ctx.fillStyle = "rgba(255,255,255,0.08)";
        for (let i = 0; i < canvas.width + 120; i += 86) {
            roundedRect(i - (frame * speed * 1.4 % 86), groundY + 58, 44, 5, 5);
        }
    }

    function drawChicken() {
        const bob = Math.sin(frame / 8) * 2;
        ctx.save();
        ctx.translate(chicken.x, chicken.y + bob);
        ctx.fillStyle = "rgba(0,0,0,0.25)";
        ctx.beginPath();
        ctx.ellipse(28, 54, 30, 8, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = "rgba(255,255,255,0.18)";
        ctx.beginPath();
        ctx.ellipse(24, 29, 22, 17, -0.45, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = "#ffd43b";
        roundedRect(0, 5, chicken.w, chicken.h, 14);
        ctx.fillStyle = "#ffe66d";
        roundedRect(16, -8, 32, 30, 14);
        ctx.fillStyle = "rgba(255,255,255,0.35)";
        roundedRect(18, 2, 16, 8, 8);
        ctx.fillStyle = "#ff922b";
        ctx.beginPath();
        ctx.moveTo(48, 4);
        ctx.lineTo(68, 13);
        ctx.lineTo(48, 21);
        ctx.fill();
        ctx.fillStyle = "#080808";
        ctx.beginPath();
        ctx.arc(39, 2, 4, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = "#ffffff";
        ctx.beginPath();
        ctx.arc(40, 0, 1.4, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = "#ff6b6b";
        roundedRect(18, -18, 20, 12, 5);
        ctx.fillStyle = "#f03e3e";
        roundedRect(25, -24, 12, 10, 6);
        ctx.strokeStyle = "#ff922b";
        ctx.lineWidth = 4;
        ctx.beginPath();
        const legSwing = chicken.jumping ? 0 : Math.sin(frame / 5) * 4;
        ctx.moveTo(17, 47);
        ctx.lineTo(13 + legSwing, 58);
        ctx.moveTo(38, 47);
        ctx.lineTo(42 - legSwing, 58);
        ctx.stroke();
        ctx.restore();
    }

    function drawFence(fence) {
        const wood = ctx.createLinearGradient(fence.x, fence.y, fence.x, fence.y + fence.h);
        wood.addColorStop(0, "#c88742");
        wood.addColorStop(0.45, "#9a5a28");
        wood.addColorStop(1, "#5d341c");
        const railWood = ctx.createLinearGradient(fence.x, fence.y, fence.x, fence.y + 18);
        railWood.addColorStop(0, "#d69a55");
        railWood.addColorStop(1, "#7a421f");
        ctx.shadowColor = "rgba(0,0,0,0.34)";
        ctx.shadowBlur = 10;
        ctx.shadowOffsetY = 4;
        ctx.fillStyle = wood;
        roundedRect(fence.x, fence.y, fence.w, fence.h, 5);
        ctx.fillStyle = railWood;
        roundedRect(fence.x - 13, fence.y + fence.h * 0.25, fence.w + 26, 9, 4);
        roundedRect(fence.x - 13, fence.y + fence.h * 0.62, fence.w + 26, 9, 4);
        ctx.shadowBlur = 0;
        ctx.shadowOffsetY = 0;
        ctx.fillStyle = "rgba(255,230,180,0.28)";
        roundedRect(fence.x + 5, fence.y + 8, Math.max(4, fence.w * 0.18), fence.h - 16, 4);
        ctx.fillStyle = "rgba(58,31,14,0.46)";
        for (let i = 0; i < 3; i++) {
            const grainY = fence.y + 12 + i * (fence.h - 24) / 3;
            roundedRect(fence.x + fence.w * 0.45, grainY, Math.max(5, fence.w * 0.34), 2, 2);
        }
        ctx.fillStyle = "#3d210f";
        ctx.beginPath();
        ctx.arc(fence.x + fence.w * 0.5, fence.y + fence.h * 0.18, 2.5, 0, Math.PI * 2);
        ctx.arc(fence.x + fence.w * 0.5, fence.y + fence.h * 0.78, 2.5, 0, Math.PI * 2);
        ctx.fill();
    }

    function collision(a, b) {
        const body = {x: a.x + 6, y: a.y + 4, w: a.w - 10, h: a.h - 2};
        return (
            body.x < b.x + b.w &&
            body.x + body.w > b.x &&
            body.y < b.y + b.h &&
            body.y + body.h > b.y
        );
    }

    function drawParticles() {
        particles.forEach(p => {
            p.life -= 1;
            p.x += (p.vx || -speed * 0.25);
            p.y += (p.vy || 0.4);
            p.vy = (p.vy || 0) + 0.08;
            const alpha = Math.max(p.life / (p.maxLife || 18), 0);
            ctx.fillStyle = "rgba(" + (p.color || "255, 230, 109") + "," + alpha + ")";
            ctx.beginPath();
            ctx.arc(p.x, p.y, p.r || 3, 0, Math.PI * 2);
            ctx.fill();
        });
        particles = particles.filter(p => p.life > 0);

        scorePops.forEach(pop => {
            pop.life -= 1;
            pop.y -= 0.8;
            ctx.fillStyle = "rgba(255, 230, 109," + Math.max(pop.life / 34, 0) + ")";
            ctx.font = "900 22px Inter, Arial";
            ctx.fillText("+1", pop.x, pop.y);
        });
        scorePops = scorePops.filter(pop => pop.life > 0);
    }

    function drawUI() {
        scoreValue.textContent = score;
        speedValue.textContent = (speed / START_SPEED).toFixed(1) + "x";
        levelValue.textContent = level;
    }

    function startGame() {
        ensureAudio();
        chicken.y = groundY - chicken.h - 6;
        chicken.vy = 0;
        chicken.jumping = false;
        jumpHeld = false;
        jumpHoldFrames = 0;
        fences = [];
        particles = [];
        scorePops = [];
        speed = START_SPEED;
        score = 0;
        level = 1;
        frame = 0;
        savedCurrentScore = false;
        state = "playing";
        hideMenu();
        startMusic();
    }

    function endGame() {
        state = "gameover";
        stopMusic();
        playCrashSound();
        showMenu("Game Over", "Score: " + score + " | Level: " + level, "Nochmal spielen");
    }

    async function saveScore() {
        if (savedCurrentScore || score <= 0) return;
        let name = prompt("Dein Twitch-Name für das Scoreboard:");
        if (!name) return;
        name = name.trim().slice(0, 50);
        if (!name) return;

        try {
            const response = await fetch(SCOREBOARD_ENDPOINT, {
                method: "POST",
                headers: {
                    "apikey": SUPABASE_KEY,
                    "Authorization": "Bearer " + SUPABASE_KEY,
                    "Content-Type": "application/json",
                    "Prefer": "return=minimal"
                },
                body: JSON.stringify({
                    username: name,
                    score: score,
                    level: level
                })
            });

            if (!response.ok) {
                const errorText = await response.text();
                throw new Error(errorText || ("HTTP " + response.status));
            }

            savedCurrentScore = true;
            await renderScores();
            showMenu("Score gespeichert", "Dein Score ist jetzt für alle sichtbar.", "Nochmal spielen");
        } catch (error) {
            console.error(error);
            const message = String(error && error.message ? error.message : error).slice(0, 240);
            showMenu("Speichern fehlgeschlagen", message || "Supabase hat den Score abgelehnt.", "Nochmal spielen");
        }
    }

    function escapeHtml(value) {
        const div = document.createElement("div");
        div.textContent = value;
        return div.innerHTML;
    }

    async function renderScores() {
        let box = document.getElementById("scores");
        box.innerHTML = "<li>Lade globale Scores...</li>";

        try {
            let query = "?select=username,score,level,created_at&order=score.desc,created_at.asc&limit=100";
            if (currentScoreFilter !== "all") {
                const now = new Date();
                const from = new Date(now);
                if (currentScoreFilter === "today") {
                    from.setHours(0, 0, 0, 0);
                } else {
                    from.setDate(now.getDate() - 7);
                }
                query += "&created_at=gte." + encodeURIComponent(from.toISOString());
            }

            const response = await fetch(
                SCOREBOARD_ENDPOINT + query,
                {
                    headers: {
                        "apikey": SUPABASE_KEY,
                        "Authorization": "Bearer " + SUPABASE_KEY
                    }
                }
            );

            if (!response.ok) throw new Error(await response.text());

            const scores = await response.json();
            const bestByUser = new Map();
            scores.forEach(s => {
                const username = String(s.username || "").trim();
                if (!username) return;
                const key = username.toLowerCase();
                const existing = bestByUser.get(key);
                const currentScore = Number(s.score || 0);
                if (!existing || currentScore > Number(existing.score || 0)) {
                    bestByUser.set(key, {...s, username});
                }
            });
            const leaderboardScores = Array.from(bestByUser.values())
                .sort((a, b) => Number(b.score || 0) - Number(a.score || 0))
                .slice(0, 10);

            if (leaderboardScores.length === 0) {
                box.innerHTML = "<li>Noch keine Scores.</li>";
                return;
            }

            box.innerHTML = leaderboardScores.map(s => {
                const levelText = s.level ? " · Level " + s.level : "";
                return "<li><strong>" + escapeHtml(s.username) + "</strong> - " + s.score + levelText + "</li>";
            }).join("");
        } catch (error) {
            console.error(error);
            box.innerHTML = "<li>Scoreboard noch nicht verbunden.</li>";
        }
    }

    function loop() {
        frame++;
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        drawBackground();
        drawGround();

        if (state === "playing") {
            chicken.vy += gravity;
            if (chicken.jumping && jumpHeld && jumpHoldFrames < 18 && chicken.vy < 0) {
                chicken.vy -= 0.42;
                jumpHoldFrames++;
            }
            chicken.y += chicken.vy;

            if (chicken.y >= groundY - chicken.h - 6) {
                chicken.y = groundY - chicken.h - 6;
                chicken.vy = 0;
                chicken.jumping = false;
                jumpHoldFrames = 0;
            }

            if (frame % getSpawnInterval() === 0) spawnFence();

            fences.forEach(fence => {
                fence.x -= speed;
                if (!fence.passed && fence.x + fence.w < chicken.x) {
                    fence.passed = true;
                    score++;
                    playScoreSound();
                    speed = Math.min(MAX_SPEED, speed + 0.12 + Math.min(score, 20) * 0.003);
                    level = 1 + Math.floor(score / 5);
                    scorePops.push({x: chicken.x + chicken.w + 12, y: chicken.y + 8, life: 34});
                    for (let i = 0; i < 16; i++) {
                        particles.push({
                            x: chicken.x + chicken.w,
                            y: chicken.y + 14 + Math.random() * 22,
                            vx: -1 + Math.random() * 3,
                            vy: -2.2 + Math.random() * 1.8,
                            r: 2 + Math.random() * 3.5,
                            color: Math.random() > 0.45 ? "255, 230, 109" : "124, 255, 178",
                            life: 18 + Math.random() * 16,
                            maxLife: 34
                        });
                    }
                }
                if (collision(chicken, fence)) endGame();
                drawFence(fence);
            });
            fences = fences.filter(f => f.x > -80);
        } else {
            fences.forEach(drawFence);
        }

        drawParticles();
        drawChicken();
        drawUI();
        requestAnimationFrame(loop);
    }

    renderScores();
    updateSoundButton();
    showMenu("Chicken Jump", "Spring über Zäune, sammle Gehirnzellen und halte so lange wie möglich durch.", "Spiel starten");
    loop();
    </script>
    </body>
    </html>
    """.replace("__SUPABASE_URL__", SUPABASE_URL)
       .replace("__SUPABASE_KEY__", SUPABASE_ANON_KEY)
       .replace("__CHICKEN_THEME_SRC__", chicken_theme_data_uri), height=860, scrolling=True)

    st.markdown("## Weitere Abenteuer")
    st.markdown("""
    <div class="dnd-hero">
        <div>
            <div class="section-kicker">Tabletop Modus</div>
            <h2>Dungeons and Dragons</h2>
            <p>Öffne eine eigene Vollbild-Ansicht mit Lobbys, Charakteren, Party-Übersicht und DnD-Würfeln.</p>
        </div>
        <div class="dnd-rule-grid">
            <div class="dnd-panel"><div class="dnd-pill">Lobbys</div><p>Offen oder mit Passwort.</p></div>
            <div class="dnd-panel"><div class="dnd-pill">Würfel</div><p>d4 bis d100 inklusive Vorteil und Nachteil.</p></div>
            <div class="dnd-panel"><div class="dnd-pill">Chronik</div><p>Würfe bleiben in der Runde sichtbar.</p></div>
        </div>
    </div>
    """, unsafe_allow_html=True)
    if st.button("Dungeons and Dragons öffnen", key="open_dnd_minigame", use_container_width=True):
        st.session_state["minigame_view"] = "dnd"
        st.rerun()

    st.markdown("## Glücksräder")
    wheel_entries = get_punishment_wheel_entries()
    task_wheel_entries = get_task_wheel_entries()
    wheel_password = st.text_input("Admin Passwort für Glücksräder", type="password", key="wheel_admin_password")
    wheel_unlocked = wheel_password == "einsmarello"
    if wheel_password and not wheel_unlocked:
        st.error("Falsches Admin-Passwort für die Glücksräder.")

    punishment_labels = [f"{entry.get('reward_name')} ({entry.get('username')})" for entry in wheel_entries]
    task_labels = [f"{entry.get('reward_name')} ({entry.get('username')})" for entry in task_wheel_entries]
    punishment_payload = json.dumps(punishment_labels or ["Keine Bestrafungen in der Queue"], ensure_ascii=False)
    task_payload = json.dumps(task_labels or ["Keine Aufgaben in der Queue"], ensure_ascii=False)
    punishment_disabled_attr = "" if wheel_unlocked and punishment_labels else "disabled"
    task_disabled_attr = "" if wheel_unlocked and task_labels else "disabled"
    button_text = "Rad drehen" if wheel_unlocked else "Nur Admin"
    helper_text = (
        "Admin-Modus aktiv. Offene Käufe können gedreht und danach abgehakt werden."
        if wheel_unlocked
        else "Diese Räder zeigen gekaufte Bestrafungen und Aufgaben. Drehen kann nur der Admin."
    )

    components.html(f"""
    <div class="wheel-board">
        <section class="wheel-card punishment-card">
            <div class="wheel-stage">
                <div class="wheel-glow"></div>
                <div class="wheel-pointer"></div>
                <div id="punishmentWheel" class="prize-wheel"></div>
                <div class="wheel-center"><strong>!</strong></div>
            </div>
            <div class="wheel-copy">
                <div class="section-kicker">Bestrafungs Ideen</div>
                <h2 id="punishmentResult">Bestrafungsrad</h2>
                <p>{helper_text}</p>
                <button id="spinPunishment" {punishment_disabled_attr}>{button_text}</button>
                <ol id="punishmentItems"></ol>
            </div>
        </section>
        <section class="wheel-card task-card">
            <div class="wheel-stage">
                <div class="wheel-glow"></div>
                <div class="wheel-pointer"></div>
                <div id="taskWheel" class="prize-wheel"></div>
                <div class="wheel-center"><strong>OK</strong></div>
            </div>
            <div class="wheel-copy">
                <div class="section-kicker">Aufgaben</div>
                <h2 id="taskResult">Aufgabenrad</h2>
                <p>{helper_text}</p>
                <button id="spinTask" {task_disabled_attr}>{button_text}</button>
                <ol id="taskItems"></ol>
            </div>
        </section>
    </div>
    <style>
    body {{ margin:0; background:transparent; }}
    .wheel-board {{ display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:18px; color:white; font-family:Inter,Segoe UI,Arial,sans-serif; }}
    .wheel-card {{ position:relative; overflow:hidden; display:grid; grid-template-columns:minmax(220px,.82fr) minmax(0,1fr); gap:18px; align-items:center; min-height:410px; padding:22px; border:1px solid rgba(255,255,255,.16); border-radius:22px; background:radial-gradient(circle at 18% 18%,rgba(255,255,255,.16),transparent 30%),linear-gradient(145deg,rgba(18,9,28,.96),rgba(42,21,58,.92)); box-shadow:0 26px 80px rgba(0,0,0,.34), inset 0 1px 0 rgba(255,255,255,.10); }}
    .task-card {{ background:radial-gradient(circle at 18% 18%,rgba(124,255,178,.16),transparent 30%),linear-gradient(145deg,rgba(8,24,27,.96),rgba(22,50,48,.92)); }}
    .wheel-stage {{ position:relative; width:min(330px,100%); aspect-ratio:1; margin:auto; display:grid; place-items:center; }}
    .wheel-glow {{ position:absolute; inset:8%; border-radius:50%; background:radial-gradient(circle,rgba(255,255,255,.24),transparent 58%); filter:blur(16px); }}
    .prize-wheel {{ position:relative; width:100%; height:100%; border-radius:50%; border:12px solid rgba(255,255,255,.18); box-shadow:0 24px 70px rgba(0,0,0,.42), inset 0 0 38px rgba(0,0,0,.30); transition:transform 4s cubic-bezier(.12,.78,.16,1); }}
    .prize-wheel::after {{ content:""; position:absolute; inset:9%; border-radius:50%; border:1px solid rgba(255,255,255,.22); background:radial-gradient(circle at 35% 25%,rgba(255,255,255,.18),transparent 42%); }}
    .wheel-pointer {{ position:absolute; left:50%; top:-8px; width:0; height:0; transform:translateX(-50%); border-left:20px solid transparent; border-right:20px solid transparent; border-top:42px solid #fff6d8; z-index:4; filter:drop-shadow(0 8px 14px rgba(0,0,0,.35)); }}
    .wheel-center {{ position:absolute; inset:36%; z-index:5; display:grid; place-items:center; border-radius:50%; background:linear-gradient(145deg,#fff8dc,#ffd166); border:6px solid rgba(22,8,31,.72); box-shadow:0 12px 30px rgba(0,0,0,.36), inset 0 2px 8px rgba(255,255,255,.55); color:#16091f; font-size:28px; }}
    .section-kicker {{ color:#ffdf6e; font-size:12px; font-weight:950; letter-spacing:.08em; text-transform:uppercase; }}
    .wheel-copy h2 {{ margin:8px 0 10px; font-size:clamp(28px,3vw,42px); line-height:1.02; }}
    .wheel-copy p {{ min-height:58px; color:#f0dcff; font-weight:760; line-height:1.45; }}
    .task-card .wheel-copy p {{ color:#c9fff0; }}
    .wheel-copy button {{ width:100%; max-width:220px; padding:14px 18px; border-radius:14px; border:0; font-weight:950; color:#120817; background:linear-gradient(135deg,#ffe66d,#ff54a0); cursor:pointer; box-shadow:0 12px 30px rgba(255,84,160,.22); }}
    .task-card .wheel-copy button {{ background:linear-gradient(135deg,#7cffb2,#00d4ff); box-shadow:0 12px 30px rgba(0,212,255,.20); }}
    .wheel-copy button:disabled {{ cursor:not-allowed; opacity:.48; filter:grayscale(.35); box-shadow:none; }}
    .wheel-copy ol {{ margin:18px 0 0; padding-left:22px; max-height:116px; overflow:auto; }}
    .wheel-copy li {{ margin:7px 0; color:#f8e9ff; font-weight:800; }}
    .task-card .wheel-copy li {{ color:#dcfff6; }}
    @media (max-width:1050px) {{ .wheel-board {{ grid-template-columns:1fr; }} }}
    @media (max-width:680px) {{ .wheel-card {{ grid-template-columns:1fr; }} .wheel-stage {{ width:min(300px,100%); }} }}
    </style>
    <script>
    const configs = [
        {{ wheelId:"punishmentWheel", resultId:"punishmentResult", listId:"punishmentItems", buttonId:"spinPunishment", items:{punishment_payload}, colors:["#ff4d8d","#7b2cbf","#ffd166","#c77dff","#ff8fab","#5a189a"] }},
        {{ wheelId:"taskWheel", resultId:"taskResult", listId:"taskItems", buttonId:"spinTask", items:{task_payload}, colors:["#7cffb2","#00d4ff","#ffe66d","#2ec4b6","#b8f7ff","#39ff88"] }}
    ];
    function escapeHtml(value) {{ const div = document.createElement("div"); div.textContent = value; return div.innerHTML; }}
    function gradientFor(colors, count) {{
        const segments = Math.max(count, 6);
        const step = 360 / segments;
        const stops = [];
        for (let i = 0; i < segments; i++) stops.push(`${{colors[i % colors.length]}} ${{i * step}}deg ${{(i + 1) * step}}deg`);
        return `conic-gradient(${{stops.join(",")}})`;
    }}
    configs.forEach((config) => {{
        const wheel = document.getElementById(config.wheelId);
        const result = document.getElementById(config.resultId);
        const list = document.getElementById(config.listId);
        const button = document.getElementById(config.buttonId);
        let rotation = 0;
        wheel.style.background = gradientFor(config.colors, config.items.length);
        list.innerHTML = config.items.map((item, index) => `<li>${{index + 1}}. ${{escapeHtml(item)}}</li>`).join("");
        if (!button.disabled) {{
            button.addEventListener("click", () => {{
                button.disabled = true;
                result.textContent = "Dreht...";
                const selected = Math.floor(Math.random() * config.items.length);
                const slice = 360 / config.items.length;
                rotation += 1800 + (360 - selected * slice) + Math.random() * Math.min(slice, 45);
                wheel.style.transform = `rotate(${{rotation}}deg)`;
                setTimeout(() => {{
                    result.textContent = config.items[selected];
                    button.disabled = false;
                }}, 4100);
            }});
        }}
    }});
    </script>
    """, height=820)

    if wheel_unlocked and wheel_entries:
        selected_done = st.selectbox(
            "Gezogene/erledigte Bestrafung abhaken",
            wheel_entries,
            format_func=lambda entry: f"{entry.get('reward_name')} von {entry.get('username')}",
        )
        if st.button("Als erledigt markieren", key="mark_punishment_done"):
            if mark_punishment_done(selected_done["id"]):
                st.success("Bestrafung erledigt und aus dem Rad entfernt.")
                st.rerun()
            else:
                st.error("Konnte den Eintrag nicht aktualisieren. Prüfe die Purchases-Migration.")

    if wheel_unlocked and task_wheel_entries:
        selected_task_done = st.selectbox(
            "Gezogene/erledigte Aufgabe abhaken",
            task_wheel_entries,
            format_func=lambda entry: f"{entry.get('reward_name')} von {entry.get('username')}",
        )
        if st.button("Aufgabe als erledigt markieren", key="mark_task_done"):
            if mark_wheel_entry_done(selected_task_done["id"]):
                st.success("Aufgabe erledigt und aus dem Rad entfernt.")
                st.rerun()
            else:
                st.error("Konnte den Eintrag nicht aktualisieren. Prüfe die Purchases-Migration.")

elif menu == "🎮 Minispiele":

    st.subheader("🐔 Chicken Jump")

    st.markdown("""
    <div class="card">
        <h3>🎮 Anleitung</h3>
        <p>
        Das Huhn läuft automatisch nach rechts.<br>
        Linksklick oder SPACE = springen.<br>
        Weiche den Zäunen aus. Das Spiel wird immer schneller.
        </p>
    </div>
    """, unsafe_allow_html=True)

    components.html("""
    <html>
    <body style="margin:0; background:#0f0816; color:white; font-family:Arial; overflow:hidden;">

    <canvas id="game" width="900" height="420"></canvas>

    <div id="scoreboard" style="
        width:900px;
        background:rgba(255,255,255,0.05);
        border:1px solid rgba(199,125,255,0.35);
        border-radius:16px;
        padding:14px;
        box-sizing:border-box;
        margin-top:10px;
    ">
        <b>🏆 Scoreboard</b>
        <div id="scores" style="margin-top:8px;color:#ddd;"></div>
    </div>

    <script>
    const canvas = document.getElementById("game");
    const ctx = canvas.getContext("2d");

    let chicken = {
        x: 120,
        y: 310,
        w: 42,
        h: 42,
        vy: 0,
        jumping: false
    };

    let gravity = 0.75;
    let fences = [];
    let speed = 5;
    let score = 0;
    let gameOver = false;
    let frame = 0;

    function jump() {
        if (gameOver) {
            saveScore();
            resetGame();
            return;
        }

        if (!chicken.jumping) {
            chicken.vy = -15;
            chicken.jumping = true;
        }
    }

    document.addEventListener("click", jump);
    document.addEventListener("keydown", function(e) {
        if (e.code === "Space") {
            jump();
        }
    });

    function spawnFence() {
        fences.push({
            x: 900,
            y: 320,
            w: 35,
            h: 55,
            passed: false
        });
    }

    function drawChicken() {
        ctx.fillStyle = "#ffd43b";
        ctx.fillRect(chicken.x, chicken.y, chicken.w, chicken.h);

        ctx.fillStyle = "#ff922b";
        ctx.beginPath();
        ctx.moveTo(chicken.x + chicken.w, chicken.y + 18);
        ctx.lineTo(chicken.x + chicken.w + 18, chicken.y + 25);
        ctx.lineTo(chicken.x + chicken.w, chicken.y + 32);
        ctx.fill();

        ctx.fillStyle = "black";
        ctx.beginPath();
        ctx.arc(chicken.x + 30, chicken.y + 12, 4, 0, Math.PI * 2);
        ctx.fill();

        ctx.fillStyle = "#ff6b6b";
        ctx.fillRect(chicken.x + 8, chicken.y - 10, 18, 10);
    }

    function drawFence(fence) {
        ctx.fillStyle = "#c084fc";

        ctx.fillRect(fence.x, fence.y, fence.w, fence.h);
        ctx.fillRect(fence.x - 10, fence.y + 12, fence.w + 20, 8);
        ctx.fillRect(fence.x - 10, fence.y + 32, fence.w + 20, 8);
    }

    function collision(a, b) {
        return (
            a.x < b.x + b.w &&
            a.x + a.w > b.x &&
            a.y < b.y + b.h &&
            a.y + a.h > b.y
        );
    }

    function drawGround() {
        ctx.fillStyle = "#22112f";
        ctx.fillRect(0, 360, 900, 60);

        ctx.fillStyle = "#7b2cbf";
        for (let i = 0; i < 900; i += 40) {
            ctx.fillRect(i - (frame * speed % 40), 360, 20, 4);
        }
    }

    function drawUI() {
        ctx.fillStyle = "white";
        ctx.font = "28px Arial";
        ctx.fillText("Score: " + score, 25, 45);

        ctx.font = "18px Arial";
        ctx.fillStyle = "#c77dff";
        ctx.fillText("Speed: " + speed.toFixed(1), 25, 75);
    }

    function drawGameOver() {
        ctx.fillStyle = "rgba(0,0,0,0.72)";
        ctx.fillRect(0, 0, 900, 420);

        ctx.fillStyle = "#c77dff";
        ctx.font = "58px Arial";
        ctx.fillText("Game Over", 290, 170);

        ctx.fillStyle = "white";
        ctx.font = "32px Arial";
        ctx.fillText("Score: " + score, 380, 225);

        ctx.font = "22px Arial";
        ctx.fillText("Klicke, um Score einzutragen und neu zu starten", 245, 275);
    }

    function saveScore() {
        let name = prompt("Dein Twitch-Name für das Scoreboard:");

        if (!name) return;

        let scores = JSON.parse(localStorage.getItem("chicken_scores") || "[]");

        scores.push({
            name: name,
            score: score
        });

        scores.sort((a, b) => b.score - a.score);
        scores = scores.slice(0, 10);

        localStorage.setItem("chicken_scores", JSON.stringify(scores));
        renderScores();
    }

    function renderScores() {
        let scores = JSON.parse(localStorage.getItem("chicken_scores") || "[]");
        let box = document.getElementById("scores");

        if (scores.length === 0) {
            box.innerHTML = "Noch keine Scores.";
            return;
        }

        box.innerHTML = scores.map((s, i) => {
            return (i + 1) + ". " + s.name + " — " + s.score;
        }).join("<br>");
    }

    function resetGame() {
        chicken.y = 310;
        chicken.vy = 0;
        chicken.jumping = false;
        fences = [];
        speed = 5;
        score = 0;
        frame = 0;
        gameOver = false;
    }

    function loop() {
        frame++;

        ctx.clearRect(0, 0, 900, 420);

        ctx.fillStyle = "#0f0816";
        ctx.fillRect(0, 0, 900, 420);

        drawGround();

        if (!gameOver) {
            chicken.vy += gravity;
            chicken.y += chicken.vy;

            if (chicken.y >= 310) {
                chicken.y = 310;
                chicken.vy = 0;
                chicken.jumping = false;
            }

            if (frame % Math.max(55, Math.floor(115 - speed * 6)) === 0) {
                spawnFence();
            }

            fences.forEach(fence => {
                fence.x -= speed;

                if (!fence.passed && fence.x + fence.w < chicken.x) {
                    fence.passed = true;
                    score++;
                    speed += 0.25;
                }

                if (collision(chicken, fence)) {
                    gameOver = true;
                }

                drawFence(fence);
            });

            fences = fences.filter(f => f.x > -80);
        } else {
            fences.forEach(drawFence);
        }

        drawChicken();
        drawUI();

        if (gameOver) {
            drawGameOver();
        }

        requestAnimationFrame(loop);
    }

    renderScores();
    loop();
    </script>

    </body>
    </html>
    """, height=560)

# =========================
# ADMIN
# =========================

elif menu == "🔐 Admin":

    password = st.text_input(
        "Admin Passwort",
        type="password"
    )

    if password == "einsmarello":

        members = get_members()
        usernames = [str(member.get("username")) for member in members if member.get("username")]
        events = get_events()
        shop_items = get_shop_items()
        news_posts = get_news_posts()
        patch_notes = get_patch_notes()
        creative_items = get_creative_gallery(100)
        support_messages = get_support_messages()
        open_support_count = len([message for message in support_messages if message.get("status") == "open"])
        wish_posts = get_wish_posts()
        wish_reactions = get_wish_reactions()
        pending_trade_count = len(api_get_optional("chicken_trades?status=eq.pending&select=id"))
        active_categories = len({str(item.get("category") or get_default_shop_category()) for item in shop_items})
        wheel_queue_count = len(get_punishment_wheel_entries())
        task_wheel_queue_count = len(get_task_wheel_entries())

        st.markdown("""
        <div class="admin-hero">
            <div>
                <div class="section-kicker">Admin Center</div>
                <h2>Gehirnzone Kontrolle</h2>
                <div class="admin-muted">Viewer, Punkte, Shop und Events an einem Ort.</div>
            </div>
        </div>
        """, unsafe_allow_html=True)

        st.markdown(f"""
        <div class="admin-stat-grid">
            <div class="admin-stat"><strong>{len(members)}</strong><span>Viewer</span></div>
            <div class="admin-stat"><strong>{len(shop_items)}</strong><span>Shop-Items</span></div>
            <div class="admin-stat"><strong>{len(events)}</strong><span>Events</span></div>
        </div>
        """, unsafe_allow_html=True)

        st.markdown(f"""
        <div class="admin-control-grid">
            <div class="admin-control-card">
                <div class="section-kicker">Community</div>
                <h3>{pending_trade_count}</h3>
                <div class="admin-muted">Offene Chicken-Trades</div>
            </div>
            <div class="admin-control-card">
                <div class="section-kicker">Content</div>
                <h3>{len(news_posts)}</h3>
                <div class="admin-muted">Aktive News-Beiträge</div>
            </div>
            <div class="admin-control-card">
                <div class="section-kicker">Updates</div>
                <h3>{len(patch_notes)}</h3>
                <div class="admin-muted">Patch Notes</div>
            </div>
            <div class="admin-control-card">
                <div class="section-kicker">Shop</div>
                <h3>{active_categories}</h3>
                <div class="admin-muted">Kategorien mit Items</div>
            </div>
            <div class="admin-control-card">
                <div class="section-kicker">Bestrafungsrad</div>
                <h3>{wheel_queue_count}</h3>
                <div class="admin-muted">Offene Ideen in der Queue</div>
            </div>
            <div class="admin-control-card">
                <div class="section-kicker">Aufgabenrad</div>
                <h3>{task_wheel_queue_count}</h3>
                <div class="admin-muted">Offene Aufgaben in der Queue</div>
            </div>
            <div class="admin-control-card">
                <div class="section-kicker">Kreativwand</div>
                <h3>{len(creative_items)}</h3>
                <div class="admin-muted">Bilder in der Hall of Fame</div>
            </div>
            <div class="admin-control-card">
                <div class="section-kicker">Support</div>
                <h3>{open_support_count}</h3>
                <div class="admin-muted">Offene Meldungen</div>
            </div>
        </div>
        """, unsafe_allow_html=True)

        overview_tab, registration_tab, viewer_tab, news_tab, patch_tab, shop_tab, event_tab, creative_tab, support_tab, danger_tab = st.tabs([
            "Dashboard",
            "Registrierungen",
            "Viewer",
            "News",
            "Patch Notes",
            "Shop",
            "Events",
            "Kreativwand",
            "Support",
            "Moderation",
        ])

        with overview_tab:
            top_members = sorted(members, key=lambda member: int(member.get("braincells") or 0), reverse=True)[:5]
            left_col, right_col = st.columns([1.2, 0.8])

            with left_col:
                if top_members:
                    top_members_html = ""
                    for index, member in enumerate(top_members, start=1):
                        top_members_html += (
                            '<div class="admin-list-item">'
                            f'<b>#{index} {html.escape(str(member.get("username") or "Unbekannt"))}</b><br>'
                            f'<span class="admin-muted">🧠 {int(member.get("braincells") or 0)} · 🥚 {int(member.get("chickens") or 0)}</span>'
                            '</div>'
                        )
                    st.markdown(f'<div class="admin-panel"><h3>Top Viewer</h3>{top_members_html}</div>', unsafe_allow_html=True)
                else:
                    st.info("Noch keine Viewer vorhanden.")

            with right_col:
                st.markdown(f"""
                <div class="admin-panel">
                    <h3>Live-Status</h3>
                    <div class="admin-stat-grid" style="grid-template-columns:1fr;">
                        <div class="admin-stat"><strong>{pending_trade_count}</strong><span>Offene Trades</span></div>
                        <div class="admin-stat"><strong>{total_chickens}</strong><span>Gesamte Chickens</span></div>
                        <div class="admin-stat"><strong>{total_braincells}</strong><span>Gesamte Gehirnzellen</span></div>
                    </div>
                </div>
                """, unsafe_allow_html=True)

        with registration_tab:
            st.markdown("### Registrierungsanfragen")
            pending_requests = get_registration_requests("pending")
            approved_requests = get_registration_requests("approved")

            if "last_registration_codes" not in st.session_state:
                st.session_state["last_registration_codes"] = {}

            if pending_requests:
                st.markdown("#### Offen")
                for request_row in pending_requests:
                    request_id = str(request_row.get("id"))
                    username = str(request_row.get("username") or "Unbekannt")
                    created_at = str(request_row.get("created_at") or "")
                    st.markdown(
                        f'<div class="admin-list-item"><b>{html.escape(username)}</b><br>'
                        f'<span class="admin-muted">Angefragt: {html.escape(created_at)}</span></div>',
                        unsafe_allow_html=True
                    )
                    approve_col, deny_col = st.columns(2)
                    with approve_col:
                        if st.button("Genehmigen", key=f"approve_registration_{request_id}"):
                            code = approve_registration_request(request_id)
                            if code:
                                st.session_state["last_registration_codes"][request_id] = code
                                st.success(f"Einmalcode für {username}: {code}")
                                st.rerun()
                            else:
                                st.error("Anfrage konnte nicht genehmigt werden.")
                    with deny_col:
                        if st.button("Ablehnen", key=f"deny_registration_{request_id}"):
                            if deny_registration_request(request_id):
                                st.success("Anfrage abgelehnt.")
                                st.rerun()
                            else:
                                st.error("Anfrage konnte nicht abgelehnt werden.")
            else:
                st.info("Keine offenen Registrierungsanfragen.")

            if approved_requests:
                st.markdown("#### Genehmigt, noch nicht eingelöst")
                for request_row in approved_requests:
                    request_id = str(request_row.get("id"))
                    username = str(request_row.get("username") or "Unbekannt")
                    last_code = st.session_state["last_registration_codes"].get(request_id)
                    code_text = f"Code: {last_code}" if last_code else "Code wurde aus Sicherheitsgründen nur beim Genehmigen angezeigt."
                    st.markdown(
                        f'<div class="admin-list-item"><b>{html.escape(username)}</b><br>'
                        f'<span class="admin-muted">{html.escape(code_text)}</span></div>',
                        unsafe_allow_html=True
                    )
                    if st.button("Neuen Code erzeugen", key=f"regenerate_registration_{request_id}"):
                        code = approve_registration_request(request_id)
                        if code:
                            st.session_state["last_registration_codes"][request_id] = code
                            st.success(f"Neuer Einmalcode für {username}: {code}")
                            st.rerun()
                        else:
                            st.error("Code konnte nicht erzeugt werden.")

        with viewer_tab:
            st.markdown("### Viewer verwalten")

            selected_user = None
            if usernames:
                selected_user = st.selectbox(
                    "Viewer auswählen",
                    usernames,
                    index=0,
                    placeholder="Viewer auswählen...",
                )
            else:
                st.info("Noch keine Viewer vorhanden.")

            if selected_user:
                selected_data = get_user(selected_user)
                current_brain = int(selected_data.get("braincells") or 0) if selected_data else 0
                current_chickens = int(selected_data.get("chickens") or 0) if selected_data else 0
                rank_name, _, _ = get_progress(current_brain)

                st.markdown(f"""
                <div class="admin-panel">
                    <div class="section-kicker">Ausgewählter Viewer</div>
                    <h3>{html.escape(selected_user)}</h3>
                    <div class="admin-muted">{html.escape(rank_name)} · 🧠 {current_brain} · 🥚 {current_chickens}</div>
                </div>
                """, unsafe_allow_html=True)

                with st.form("admin_points_form"):
                    col_a, col_b = st.columns(2)
                    with col_a:
                        add_brain = st.number_input("Gehirnzellen hinzufügen", min_value=0, step=10)
                        add_chickens = st.number_input("Chickens hinzufügen", min_value=0, step=10)
                    with col_b:
                        remove_brain = st.number_input("Gehirnzellen abziehen", min_value=0, step=10)
                        remove_chickens = st.number_input("Chickens abziehen", min_value=0, step=10)

                    if st.form_submit_button("Punkte speichern"):
                        add_points(selected_user, chickens=add_chickens, braincells=add_brain)
                        remove_points(selected_user, chickens=remove_chickens, braincells=remove_brain)
                        get_members.clear()
                        get_leaderboard.clear()
                        st.success("Viewer aktualisiert.")
                        st.rerun()

                with st.expander("Passwort zurücksetzen"):
                    new_password = st.text_input("Neues Passwort", type="password")
                    if st.button("Passwort speichern"):
                        if new_password:
                            set_user_password(selected_user, new_password)
                            st.success("Passwort aktualisiert.")
                        else:
                            st.error("Bitte ein Passwort eingeben.")

        with news_tab:
            st.markdown("### News verwalten")

            with st.form("create_news_form"):
                news_title = st.text_input("Headline")
                news_body = st.text_area("Nachrichtentext", height=180)
                news_image = st.text_input("Bild-URL", placeholder="https://...")
                create_news_submit = st.form_submit_button("News veröffentlichen")

            if create_news_submit:
                if create_news_post(news_title, news_body, news_image):
                    st.success("News veröffentlicht.")
                    st.rerun()
                else:
                    st.error("News konnte nicht erstellt werden. Prüfe die News-Tabelle und die Eingaben.")

            if news_posts:
                st.markdown("#### Aktive News")
                for post in news_posts:
                    col1, col2 = st.columns([4, 1])
                    with col1:
                        st.markdown(
                            f'<div class="news-card"><h3>{html.escape(str(post.get("title") or ""))}</h3>'
                            f'<p>{html.escape(str(post.get("body") or ""))}</p></div>',
                            unsafe_allow_html=True
                        )
                    with col2:
                        if st.button("Entfernen", key=f"delete_news_{post['id']}"):
                            if delete_news_post(post["id"]):
                                st.success("News entfernt.")
                                st.rerun()
                            else:
                                st.error("News konnte nicht entfernt werden.")

        with patch_tab:
            st.markdown("### Patch Notes verwalten")
            st.caption("Jede Zeile im Feld Änderungen wird als eigener Listenpunkt angezeigt.")

            with st.form("create_patch_note_form"):
                patch_version = st.text_input("Version", placeholder="Patch 1.1")
                patch_title = st.text_input("Titel", placeholder="Neues Update")
                patch_date = st.date_input("Datum", value=datetime.now(ZoneInfo("Europe/Berlin")).date())
                patch_changes = st.text_area(
                    "Änderungen",
                    height=180,
                    placeholder="Eine Änderung pro Zeile",
                )
                create_patch = st.form_submit_button("Patch Note veröffentlichen")

            if create_patch:
                if create_patch_note(patch_version, patch_title, patch_changes, patch_date):
                    st.success("Patch Note veröffentlicht.")
                    st.rerun()
                else:
                    st.error("Patch Note konnte nicht erstellt werden. Führe in Supabase zuerst add_patch_notes_table.sql aus.")

            if patch_notes:
                st.markdown("#### Aktive Patch Notes")
                for note in patch_notes:
                    note_id = note.get("id")
                    changes_preview = "".join(
                        f"<li>{html.escape(str(change))}</li>"
                        for change in note.get("changes", [])[:4]
                    )
                    col1, col2 = st.columns([4, 1])
                    with col1:
                        st.markdown(
                            '<div class="patch-note-card">'
                            '<div class="patch-note-head">'
                            '<div>'
                            f'<div class="patch-version">{html.escape(str(note.get("version") or ""))}</div>'
                            f'<h3>{html.escape(str(note.get("title") or ""))}</h3>'
                            '</div>'
                            f'<div class="patch-date">{html.escape(str(note.get("date") or ""))}</div>'
                            '</div>'
                            f'<ul class="patch-change-list">{changes_preview}</ul>'
                            '</div>',
                            unsafe_allow_html=True,
                        )
                    with col2:
                        if note_id:
                            if st.button("Entfernen", key=f"delete_patch_note_{note_id}"):
                                if delete_patch_note(note_id):
                                    st.success("Patch Note entfernt.")
                                    st.rerun()
                                else:
                                    st.error("Patch Note konnte nicht entfernt werden.")
                        else:
                            st.info("Fallback aus dem Code.")

        with shop_tab:
            st.markdown("### Shop verwalten")
            category_summary = ""
            for category in SHOP_CATEGORIES:
                count = len([item for item in shop_items if item.get("category") == category])
                category_summary += (
                    '<div class="shop-status-pill">'
                    f'<strong>{count}</strong><span>{html.escape(category)}</span>'
                    '</div>'
                )
            st.markdown(f'<div class="shop-status-row">{category_summary}</div>', unsafe_allow_html=True)

            with st.form("create_shop_item_form"):
                item_name = st.text_input("Name des Shop-Items")
                item_description = st.text_area("Beschreibung des Shop-Items")
                item_category = st.selectbox("Kategorie", SHOP_CATEGORIES)
                item_price = st.number_input("Preis in Chickens", min_value=1, step=1)
                create_item = st.form_submit_button("Shop-Item erstellen")

            if create_item:
                if create_shop_item(item_name, item_description, item_price, item_category):
                    st.success("Shop-Item erstellt")
                    st.rerun()
                else:
                    st.error("Shop-Item konnte nicht erstellt werden. Prüfe die Shop-Datenbank.")

            if shop_items:
                st.markdown("#### Aktive Shop-Items")
                for item in shop_items:
                    with st.expander(f"{item['name']} · 🥚 {item['price']}"):
                        if item.get("id"):
                            with st.form(f"edit_shop_item_{item['id']}"):
                                edited_name = st.text_input("Name", value=item["name"])
                                edited_desc = st.text_area("Beschreibung", value=item["desc"])
                                edited_category = st.selectbox(
                                    "Kategorie",
                                    SHOP_CATEGORIES,
                                    index=SHOP_CATEGORIES.index(item.get("category")) if item.get("category") in SHOP_CATEGORIES else 0,
                                )
                                edited_price = st.number_input("Preis", min_value=1, step=1, value=int(item["price"]))
                                save_col, delete_col = st.columns(2)
                                with save_col:
                                    save_item = st.form_submit_button("Änderungen speichern")
                                with delete_col:
                                    remove_item = st.form_submit_button("Deaktivieren")

                            if save_item:
                                if update_shop_item(item["id"], edited_name, edited_desc, edited_price, edited_category):
                                    st.success("Shop-Item aktualisiert.")
                                    st.rerun()
                                else:
                                    st.error("Shop-Item konnte nicht aktualisiert werden.")

                            if remove_item:
                                if delete_shop_item(item["id"]):
                                    st.success("Shop-Item deaktiviert.")
                                    st.rerun()
                                else:
                                    st.error("Shop-Item konnte nicht deaktiviert werden.")
                        else:
                            st.info("Dieses Standard-Item kommt aus dem Code. Erstelle eigene Shop-Items in Supabase, um es zu verwalten.")
            else:
                st.info("Noch keine Shop-Items vorhanden.")

        with event_tab:
            st.markdown("### Events verwalten")

            with st.form("create_event_form"):
                event_title = st.text_input("Event Titel")
                event_description = st.text_area("Beschreibung")
                date_col, time_col = st.columns(2)
                with date_col:
                    selected_date = st.date_input("Datum")
                with time_col:
                    selected_time = st.time_input("Uhrzeit")
                create_event_submit = st.form_submit_button("Event erstellen")

            if create_event_submit:
                event_datetime = datetime.combine(selected_date, selected_time).strftime("%d.%m.%Y %H:%M")
                if create_event(event_title, event_description, event_datetime):
                    get_events.clear()
                    st.success("Event erstellt.")
                    st.rerun()
                else:
                    st.error("Event konnte nicht erstellt werden.")

            if events:
                st.markdown("#### Aktive Events")
                for event in events:
                    signup_count = len(get_event_signups(event["id"]))
                    col1, col2 = st.columns([4, 1])

                    with col1:
                        st.markdown(f"""
                        <div class="event-card">
                            <h3>{html.escape(str(event["title"]))}</h3>
                            <p>{html.escape(str(event["description"]))}</p>
                            <b>{html.escape(str(event.get("event_date") or ""))} · {signup_count} Anmeldung(en)</b>
                        </div>
                        """, unsafe_allow_html=True)

                    with col2:
                        if st.button("Löschen", key=f"delete_{event['id']}"):
                            delete_event(event["id"])
                            get_events.clear()
                            st.success("Event gelöscht.")
                            st.rerun()
            else:
                st.info("Noch keine Events vorhanden.")

        with creative_tab:
            st.markdown("### Kreativwand moderieren")
            if not creative_items:
                st.info("Noch keine Bilder in der Hall of Fame.")
            else:
                for item in creative_items:
                    art_id = str(item.get("id"))
                    title = str(item.get("title") or "").strip()
                    username = str(item.get("username") or "Unbekannt")
                    created_at = format_gallery_timestamp(item.get("created_at"))
                    image_data = str(item.get("image_data") or "")
                    title_html = f'<b>{html.escape(title)}</b><br>' if title else ""

                    preview_col, action_col = st.columns([3, 1])
                    with preview_col:
                        st.markdown(
                            '<div class="admin-list-item">'
                            f'{title_html}'
                            f'<span class="admin-muted">von {html.escape(username)} · {html.escape(created_at)}</span>'
                            '</div>',
                            unsafe_allow_html=True
                        )
                        if image_data:
                            st.image(image_data, width=240)
                    with action_col:
                        if st.button("Bild löschen", key=f"delete_creative_{art_id}"):
                            if delete_creative_art(art_id):
                                st.success("Bild gelöscht.")
                                st.rerun()
                            else:
                                st.error("Bild konnte nicht gelöscht werden.")

        with support_tab:
            st.markdown("### Support-Meldungen")
            if not support_messages:
                st.info("Noch keine Support-Meldungen vorhanden.")
            else:
                for message in support_messages:
                    message_id = str(message.get("id") or "")
                    title = str(message.get("title") or "Meldung")
                    body = str(message.get("message") or "")
                    username = str(message.get("username") or "Gast")
                    category = str(message.get("category") or "Problem")
                    status = str(message.get("status") or "open")
                    created_at = format_gallery_timestamp(message.get("created_at"))

                    st.markdown(
                        '<div class="admin-list-item">'
                        f'<b>{html.escape(title)}</b><br>'
                        f'<span class="admin-muted">{html.escape(category)} · von {html.escape(username)} · {html.escape(created_at)} · {html.escape(status)}</span>'
                        f'<p>{html.escape(body)}</p>'
                        '</div>',
                        unsafe_allow_html=True,
                    )
                    done_col, open_col = st.columns(2)
                    with done_col:
                        if status != "done" and st.button("Als erledigt markieren", key=f"support_done_{message_id}"):
                            if set_support_message_status(message_id, "done"):
                                st.success("Meldung erledigt.")
                                st.rerun()
                            else:
                                st.error("Status konnte nicht gespeichert werden.")
                    with open_col:
                        if status == "done" and st.button("Wieder öffnen", key=f"support_open_{message_id}"):
                            if set_support_message_status(message_id, "open"):
                                st.success("Meldung wieder geöffnet.")
                                st.rerun()
                            else:
                                st.error("Status konnte nicht gespeichert werden.")

            st.markdown("### Wünsche moderieren")
            if not wish_posts:
                st.info("Noch keine Wünsche vorhanden.")
            else:
                wish_summary = summarize_wish_reactions(wish_reactions)
                for wish in wish_posts:
                    wish_id = str(wish.get("id") or "")
                    title = str(wish.get("title") or "Wunsch")
                    description = str(wish.get("description") or "")
                    username = str(wish.get("username") or "Gast")
                    created_at = format_gallery_timestamp(wish.get("created_at"))
                    counts = wish_summary.get(wish_id, {"up": 0, "down": 0})

                    wish_col, action_col = st.columns([4, 1])
                    with wish_col:
                        st.markdown(
                            '<div class="admin-list-item">'
                            f'<b>{html.escape(title)}</b><br>'
                            f'<span class="admin-muted">von {html.escape(username)} · {html.escape(created_at)} · 👍 {int(counts.get("up") or 0)} · 👎 {int(counts.get("down") or 0)}</span>'
                            f'<p>{html.escape(description)}</p>'
                            '</div>',
                            unsafe_allow_html=True,
                        )
                    with action_col:
                        if st.button("Wunsch entfernen", key=f"delete_wish_{wish_id}"):
                            if delete_wish_post(wish_id):
                                st.success("Wunsch entfernt.")
                                st.rerun()
                            else:
                                st.error("Wunsch konnte nicht entfernt werden.")

        with danger_tab:
            st.markdown("### Moderation")
            st.warning("Löschen entfernt den User und zugehörige Event-/Purchase-Daten.")

            delete_username = None
            if usernames:
                delete_username = st.selectbox(
                    "User zum Löschen",
                    usernames,
                    index=0,
                    placeholder="Viewer auswählen...",
                    key="delete_user_select",
                )
            else:
                st.info("Es gibt aktuell keinen User zum Löschen.")
            confirm_delete = st.text_input("Zum Bestätigen den Usernamen erneut eingeben")

            if st.button("User löschen", type="primary"):
                if delete_username and confirm_delete == delete_username:
                    delete_user(delete_username)
                    get_members.clear()
                    get_leaderboard.clear()
                    st.success("User gelöscht.")
                    st.rerun()
                else:
                    st.error("Bestätigung stimmt nicht mit dem Usernamen überein.")

    elif password:
        st.error("Falsches Passwort")

