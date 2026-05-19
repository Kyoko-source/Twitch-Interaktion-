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
from pathlib import Path
from typing import Optional

st.set_page_config(
    page_title="Gehirnzone",
    page_icon="🧠",
    layout="wide"
)

PASSWORD_SALT = "gehirnzone_guest_auth_salt"
REGISTRATION_CODE_SALT = "gehirnzone_registration_code_salt"

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
    SUPABASE_ANON_KEY = st.secrets["supabase"].get("anon_key", st.secrets["supabase"]["key"])
    SUPABASE_SERVICE_KEY = st.secrets["supabase"].get("service_key", st.secrets["supabase"]["key"])
except KeyError:
    st.error("Supabase-Secrets sind nicht konfiguriert. Bitte setze url, anon_key und service_key in den App-Einstellungen.")
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
        return False, "Fuer diesen Namen wartet bereits eine Anfrage auf Genehmigung."

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
        return False, "Anfrage konnte nicht erstellt werden. Fuehre zuerst add_registration_requests_table.sql in Supabase aus."

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
        return None, "Registrierung fehlgeschlagen. Pruefe Name, Passwort und Einmalcode."

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


def build_achievements(user, rank_position=None, best_score=None, daily_state=None):
    braincells = int(user.get("braincells") or 0)
    chickens = int(user.get("chickens") or 0)
    bio = str(user.get("bio") or "").strip()
    favorite_game = str(user.get("favorite_game") or "").strip()
    avatar_url = str(user.get("avatar_url") or "").strip()
    score = int(best_score.get("score") or 0) if best_score else 0
    streak = int(daily_state.get("streak") or 0) if daily_state else 0

    achievements = [
        ("Profil-Profi", "Bio, Lieblingsspiel und Avatar gesetzt", bool(bio and favorite_game and avatar_url)),
        ("Chicken Sammler", "Mindestens 1.000 Chickens besitzen", chickens >= 1000),
        ("Gehirntraining", "Mindestens 500 Gehirnzellen gesammelt", braincells >= 500),
        ("Top 3 Energie", "In der Rangliste unter den Top 3", isinstance(rank_position, int) and rank_position <= 3),
        ("Jump Talent", "Chicken Jump Score von 10+ erreicht", score >= 10),
        ("Daily Streak", "3 Tage Daily Reward in Folge", streak >= 3),
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
    "Out of Stream Rewards",
]

PUNISHMENT_WHEEL_CATEGORIES = [
    "Bestrafungs Ideen",
    "Idee Bestrafungsrad",
]

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


@st.cache_data(ttl=90)
def get_punishment_wheel_entries():
    return api_get_optional(
        "purchases?select=id,username,reward_name,reward_category,status,created_at"
        "&reward_category=in.(Bestrafungs%20Ideen,Idee%20Bestrafungsrad)&status=eq.open&order=created_at.asc"
    )


def mark_punishment_done(purchase_id):
    success = api_patch(
        f"purchases?id=eq.{purchase_id}",
        {"status": "done", "resolved_at": datetime.now(ZoneInfo("Europe/Berlin")).isoformat()}
    )
    get_punishment_wheel_entries.clear()
    return success


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
        return False

    current = int(user["chickens"])

    if current < reward["price"]:
        return False

    update_user(
        username,
        current - reward["price"],
        int(user["braincells"])
    )

    extended_purchase = api_post_optional(
        "purchases",
        {
            "username": username,
            "reward_name": reward["name"],
            "price": reward["price"],
            "reward_category": reward.get("category") or get_default_shop_category(),
            "status": "open",
            "created_at": datetime.now().isoformat()
        }
    )
    if not extended_purchase:
        api_post(
            "purchases",
            {
                "username": username,
                "reward_name": reward["name"],
                "price": reward["price"],
                "created_at": datetime.now().isoformat()
            }
        )

    get_leaderboard.clear()
    get_members.clear()
    get_punishment_wheel_entries.clear()
    return True


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
    padding-top: 1.35rem;
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
    background: linear-gradient(135deg, rgba(199,125,255,0.14), rgba(255,84,160,0.10));
    border-radius: 14px;
    padding: 10px 14px;
    margin-bottom: 14px;
    border: 1px solid rgba(255,255,255,0.12);
    backdrop-filter: blur(14px);
    min-height: 44px;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    position: relative;
    z-index: 1000;
    overflow: visible;
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
}

.member-card::before {
    content: "";
    position: absolute;
    inset: 0 0 auto 0;
    height: 4px;
    background: linear-gradient(90deg, #7b2cbf, #c77dff, #ff54a0);
}

.member-rank-pill {
    float: right;
    padding: 6px 10px;
    border-radius: 999px;
    color: #061015;
    background: linear-gradient(135deg, #c77dff, #ff54a0);
    font-size: 12px;
    font-weight: 950;
}

.member-mini-progress {
    height: 9px;
    margin-top: 16px;
    border-radius: 999px;
    overflow: hidden;
    background: rgba(255,255,255,0.10);
}

.member-mini-progress div {
    height: 100%;
    border-radius: inherit;
    background: linear-gradient(90deg, #c77dff, #ff54a0);
}

.member-card .profile-avatar {
    margin-bottom: 12px;
}

.member-favorite {
    margin-top: 12px;
    color: #ff7ad9;
    font-weight: 800;
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

.home-hero {
    display: grid;
    grid-template-columns: minmax(0, 1.25fr) minmax(300px, 0.75fr);
    gap: 18px;
    align-items: stretch;
    margin: 10px 0 22px;
}

.home-spotlight,
.daily-card,
.activity-card {
    position: relative;
    overflow: hidden;
    border-radius: 18px;
    padding: 28px;
    background:
        linear-gradient(135deg, rgba(123,44,191,0.24), rgba(199,125,255,0.15), rgba(255,84,160,0.18)),
        rgba(255,255,255,0.055);
    border: 1px solid rgba(255,255,255,0.15);
    box-shadow: 0 26px 76px rgba(0,0,0,0.34);
}

.home-spotlight::after {
    content: "";
    position: absolute;
    right: -90px;
    top: -90px;
    width: 260px;
    height: 260px;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(255,84,160,0.22), transparent 65%);
}

.home-spotlight h2 {
    position: relative;
    z-index: 1;
    margin: 8px 0 10px;
    font-size: clamp(34px, 5vw, 68px);
    line-height: 0.95;
}

.home-spotlight p,
.daily-card p,
.activity-card p {
    color: #e5f8ff;
    font-weight: 760;
}

.home-actions {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 12px;
    margin: 18px 0 4px;
}

.home-action-card {
    min-height: 118px;
    border-radius: 14px;
    padding: 18px;
    background: rgba(255,255,255,0.065);
    border: 1px solid rgba(255,255,255,0.12);
}

.home-action-card strong {
    display: block;
    color: #ffffff;
    font-size: 20px;
    margin-bottom: 8px;
}

.home-action-card span {
    color: #e7c9ff;
    font-weight: 760;
}

.daily-card {
    min-height: 100%;
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
    gap: 12px;
    margin: 16px 0 22px;
}

.achievement-card {
    min-height: 128px;
    border-radius: 14px;
    padding: 18px;
    background: rgba(255,255,255,0.055);
    border: 1px solid rgba(255,255,255,0.10);
}

.achievement-card.unlocked {
    background:
        linear-gradient(135deg, rgba(199,125,255,0.16), rgba(255,84,160,0.12)),
        rgba(255,255,255,0.07);
    border-color: rgba(255,84,160,0.34);
}

.achievement-card.locked {
    opacity: 0.58;
    filter: grayscale(0.55);
}

.achievement-card strong {
    display: block;
    margin-bottom: 8px;
    color: #ffffff;
    font-size: 18px;
}

.achievement-card span {
    color: #cfe8ee;
    font-weight: 760;
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
    .achievement-grid,
    .score-strip,
    .newspaper-grid,
    .wheel-shell,
    .market-grid,
    .market-holdings,
    .shop-dashboard,
    .shop-status-row,
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
    max-width: 980px;
    margin: 0 auto 22px auto;
    position: relative;
    z-index: 1;
}

.stRadio > div {
    justify-content: center;
    gap: 8px;
    background: rgba(8,10,18,0.72);
    border: 1px solid rgba(199,125,255,0.28);
    border-radius: 999px;
    padding: 8px;
    box-shadow: 0 18px 45px rgba(0,0,0,0.24);
    backdrop-filter: blur(12px);
}

.stRadio [role="radiogroup"] label {
    min-height: 42px;
    border-radius: 999px;
    padding: 0 12px;
    border: 1px solid rgba(255,255,255,0.08);
    background: rgba(255,255,255,0.035);
    transition: all 0.18s ease;
}

.stRadio [role="radiogroup"] label:hover {
    border-color: rgba(199,125,255,0.55);
    background: rgba(199,125,255,0.12);
}

.stRadio [role="radiogroup"] label:has(input:checked) {
    background: linear-gradient(135deg, #c77dff, #ff54a0);
    border-color: transparent;
    box-shadow: 0 0 22px rgba(255,84,160,0.24);
}

.stRadio [role="radiogroup"] label:has(input:checked) p {
    color: #05050a !important;
    font-weight: 900;
}

.stRadio [role="radiogroup"] label p {
    font-weight: 800;
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
]

if "app_menu" not in st.session_state:
    st.session_state["app_menu"] = "🏠 Home"

if "main_nav" not in st.session_state:
    st.session_state["main_nav"] = "🏠 Home"

st.markdown('<div class="topbar"></div>', unsafe_allow_html=True)
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
            st.rerun()

        if st.button("🔐 Admin", key="account_admin", use_container_width=True):
            st.session_state["app_menu"] = "🔐 Admin"
            st.rerun()

        if st.button("Patch Notes", key="account_patch_notes", use_container_width=True):
            st.session_state["app_menu"] = "Patch Notes"
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

nav_cols = st.columns(len(MAIN_MENU_OPTIONS))
for nav_col, nav_item in zip(nav_cols, MAIN_MENU_OPTIONS):
    with nav_col:
        if st.button(nav_item, key=f"nav_{nav_item}", use_container_width=True):
            st.session_state["app_menu"] = nav_item
            st.session_state["main_nav"] = nav_item
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

st.markdown("<h1>Gehirnzone</h1>", unsafe_allow_html=True)

# =========================
# HOME
# =========================

if menu == "🏠 Home":

    st.markdown('<div class="section-kicker">Live Community Hub</div>', unsafe_allow_html=True)

    viewer_day_html = (
        "<h2>Gehirnzone ist bereit</h2>"
        "<p>Noch kein Viewer des Tages vorhanden. Sammle Gehirnzellen, spiele Chicken Jump und werde sichtbar.</p>"
    )

    if not leaderboard.empty:
        today_seed = datetime.now().strftime("%Y-%m-%d")
        viewer_day = leaderboard.sample(
            1,
            random_state=abs(hash(today_seed)) % (10 ** 8)
        ).iloc[0]
        viewer_day_html = (
            '<div class="section-kicker">Heute im Rampenlicht</div>'
            f'<h2>{html.escape(str(viewer_day["Viewer"]))}</h2>'
            f'<p>🧠 {int(viewer_day["Gehirnzellen"])} Gehirnzellen · 🥚 {int(viewer_day["Chickens"])} Chickens</p>'
        )

    daily_html = (
        '<div class="section-kicker">Daily Reward</div>'
        '<h3>Einloggen und Belohnung sichern</h3>'
        '<p>Melde dich an, um täglich Chickens und Gehirnzellen abzuholen.</p>'
    )
    daily_state = None
    if logged_in_username:
        daily_state = get_daily_reward_state(logged_in_username)
        reward_preview = 250 + min(int(daily_state["streak"]), 7) * 50
        claim_text = "Heute schon abgeholt" if daily_state["claimed_today"] else f"Heute verfügbar: +{reward_preview} Chickens"
        daily_html = (
            '<div class="section-kicker">Daily Reward</div>'
            f'<h3>{claim_text}</h3>'
            f'<div class="daily-streak">🔥 {int(daily_state["streak"])} Tage Streak</div>'
            '<p>Jeden Tag einloggen, Streak halten und Belohnungen stapeln.</p>'
        )

    home_html = (
        '<div class="home-hero">'
        '<div class="home-spotlight">'
        f'{viewer_day_html}'
        '<div class="home-actions">'
        f'<div class="home-action-card"><strong>{total_users}</strong><span>Viewer in der Zone</span></div>'
        f'<div class="home-action-card"><strong>{total_chickens}</strong><span>Chickens im Umlauf</span></div>'
        f'<div class="home-action-card"><strong>{total_braincells}</strong><span>Gehirnzellen gesammelt</span></div>'
        '</div>'
        '</div>'
        f'<div class="daily-card">{daily_html}</div>'
        '</div>'
    )
    st.markdown(home_html, unsafe_allow_html=True)

    if logged_in_username:
        if daily_state and daily_state["claimed_today"]:
            st.info("Daily Reward ist für heute erledigt. Morgen wartet die nächste Belohnung.")
        elif st.button("Daily Reward abholen", key="claim_daily_reward", use_container_width=True):
            success, message = claim_daily_reward(logged_in_username)
            if success:
                st.success(message)
                st.rerun()
            else:
                st.error(message)
    else:
        if st.button("Zum Login für Daily Rewards", key="daily_login_cta", use_container_width=True):
            st.session_state["app_menu"] = "🔑 Login"
            st.rerun()

    scores = get_chicken_scores(3)
    score_cards = []
    for index in range(3):
        if index < len(scores):
            score = scores[index]
            score_cards.append(
                '<div class="score-card">'
                f'<strong>#{index + 1} {html.escape(str(score.get("username") or "Unbekannt"))}</strong>'
                f'<span>{int(score.get("score") or 0)} Punkte · Level {int(score.get("level") or 1)}</span>'
                '</div>'
            )
        else:
            score_cards.append(
                '<div class="score-card">'
                f'<strong>#{index + 1} Noch frei</strong>'
                '<span>Hol dir den Platz in Chicken Jump</span>'
                '</div>'
            )

    st.markdown("## Chicken Jump Highlights")
    st.markdown(f'<div class="score-strip">{"".join(score_cards)}</div>', unsafe_allow_html=True)

    hub_left, hub_right = st.columns(2)
    with hub_left:
        st.markdown(textwrap.dedent(f"""
        <div class="activity-card">
            <div class="section-kicker">Nächster Schritt</div>
            <h3>Profil aufleveln</h3>
            <p>Fülle Bio, Lieblingsspiel und Avatar aus, sammle Achievements und mach deine Viewerkarte stärker.</p>
        </div>
        """), unsafe_allow_html=True)
        if st.button("Profil öffnen", key="home_profile_cta", use_container_width=True):
            st.session_state["app_menu"] = "👤 Profil"
            st.rerun()

    with hub_right:
        st.markdown(textwrap.dedent(f"""
        <div class="activity-card">
            <div class="section-kicker">Arcade</div>
            <h3>Highscore jagen</h3>
            <p>Chicken Jump Scores erscheinen jetzt direkt im Hauptmenü und zählen für Profil-Achievements.</p>
        </div>
        """), unsafe_allow_html=True)
        if st.button("Minispiele öffnen", key="home_games_cta", use_container_width=True):
            st.session_state["app_menu"] = "🎮 Minispiele"
            st.rerun()

# =========================
# LOGIN
# =========================

elif menu == "Patch Notes":

    st.markdown('<div class="section-kicker">Update Verlauf</div>', unsafe_allow_html=True)
    st.markdown("## Patch Notes")
    st.markdown("Hier stehen kurz die wichtigsten Änderungen an der Seite.")

    patch_cards = ""
    for patch in PATCH_NOTES:
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

        login_tab, request_tab, complete_tab = st.tabs(["Anmelden", "Registrierung anfragen", "Code einloesen"])

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
            request_confirm = st.text_input("Passwort bestaetigen", type="password", key="registration_request_confirm")

            if st.button("Anfragen", key="registration_request_submit"):
                if not validate_username(request_name):
                    st.error("Ungueltiger Twitch-Name. Nur Buchstaben, Zahlen, - und _ sind erlaubt.")
                elif request_password == "":
                    st.error("Bitte gib ein Passwort ein.")
                elif request_password != request_confirm:
                    st.error("Die Passwoerter stimmen nicht ueberein.")
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
                    st.error("Ungueltiger Twitch-Name. Nur Buchstaben, Zahlen, - und _ sind erlaubt.")
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

        st.markdown("### Achievements")
        st.markdown(f'<div class="achievement-grid">{achievement_html}</div>', unsafe_allow_html=True)

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
# NEWS
# =========================

elif menu == "📰 News":

    st.markdown('<div class="section-kicker">Gehirnzone Gazette</div>', unsafe_allow_html=True)
    st.markdown("## News")

    posts = get_news_posts()

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

    st.markdown('<div class="section-kicker">Community</div>', unsafe_allow_html=True)
    st.markdown("## Mitglieder")

    members = get_members()

    if not members:
        st.info("Noch keine Mitglieder vorhanden.")
    else:
        search_member = st.text_input("Mitglied suchen", placeholder="Name eingeben...")
        if search_member:
            members = [
                member for member in members
                if search_member.lower() in str(member.get("username", "")).lower()
            ]

        members_html = '<div class="member-grid">'
        for index, member in enumerate(members, start=1):
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
                f'<div class="member-rank-pill">#{index}</div>'
                f'{avatar_markup}'
                f'<div class="profile-name">{html.escape(username)}</div>'
                f'<div class="profile-meta">Level {level} · {rank_name}</div>'
                f'<div class="profile-meta">🧠 {braincells} · 🥚 {chickens}</div>'
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
                            success = buy_reward(effective_username, reward)

                            if success:
                                st.success("Gekauft!")
                                st.rerun()
                            else:
                                st.error("Nicht genug Chickens")

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
# CHICKEN JUMP
# =========================

elif menu.endswith("Minispiele"):

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
            <span>Je laenger du ueberlebst, desto schneller wird das Spiel.</span>
        </div>
        <div class="arcade-card">
            <strong>Globales Scoreboard</strong>
            <span>Gespeicherte Scores sind fuer alle Viewer sichtbar.</span>
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
                    <p id="menuText">Spring ueber Zaeune, sammle Gehirnzellen und halte so lange wie moeglich durch.</p>
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
        let name = prompt("Dein Twitch-Name fuer das Scoreboard:");
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

            if (!response.ok) throw new Error(await response.text());

            savedCurrentScore = true;
            await renderScores();
            showMenu("Score gespeichert", "Dein Score ist jetzt fuer alle sichtbar.", "Nochmal spielen");
        } catch (error) {
            console.error(error);
            showMenu("Speichern fehlgeschlagen", "Die globale Scoreboard-Tabelle fehlt wahrscheinlich noch in Supabase.", "Nochmal spielen");
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
    showMenu("Chicken Jump", "Spring ueber Zaeune, sammle Gehirnzellen und halte so lange wie moeglich durch.", "Spiel starten");
    loop();
    </script>
    </body>
    </html>
    """.replace("__SUPABASE_URL__", SUPABASE_URL)
       .replace("__SUPABASE_KEY__", SUPABASE_ANON_KEY)
       .replace("__CHICKEN_THEME_SRC__", chicken_theme_data_uri), height=860, scrolling=True)

    st.markdown("## Bestrafungsrad")
    wheel_entries = get_punishment_wheel_entries()
    wheel_password = st.text_input("Admin Passwort für Glücksrad", type="password", key="wheel_admin_password")
    wheel_unlocked = wheel_password == "einsmarello"
    if wheel_password and not wheel_unlocked:
        st.error("Falsches Admin-Passwort für das Glücksrad.")

    labels = [f"{entry.get('reward_name')} ({entry.get('username')})" for entry in wheel_entries]
    if not labels:
        labels = ["Eure Bestrafungen"] * 5

    wheel_payload = json.dumps(labels, ensure_ascii=False)
    disabled_attr = "" if wheel_unlocked else "disabled"
    button_text = "Glücksrad drehen" if wheel_unlocked else "Nur Admin kann drehen"
    helper_text = (
        "Admin-Modus aktiv. Offene Käufe aus Bestrafungs Ideen können gedreht werden."
        if wheel_unlocked
        else "Dieses Rad zeigt eure gekauften Bestrafungs-Ideen. Drehen kann nur der Admin."
    )

    components.html(f"""
    <div class="wheel-shell">
        <div class="wheel-stage">
            <div class="wheel-pointer"></div>
            <div id="punishmentWheel" class="punishment-wheel"></div>
            <div class="wheel-center"></div>
        </div>
        <div class="wheel-copy">
            <div class="section-kicker">Bestrafungs Ideen</div>
            <h2 id="wheelResult">Bestrafungsrad</h2>
            <p>{helper_text}</p>
            <button id="spinWheel" {disabled_attr}>{button_text}</button>
            <ol id="wheelItems"></ol>
        </div>
    </div>
    <style>
    body {{ margin:0; background:transparent; }}
    .wheel-shell {{ display:grid; grid-template-columns:minmax(260px,.8fr) minmax(0,1fr); gap:18px; align-items:center; background:linear-gradient(135deg,rgba(123,44,191,.24),rgba(255,84,160,.14)); border:1px solid rgba(255,255,255,.12); border-radius:18px; padding:20px; color:white; font-family:Inter,Segoe UI,Arial,sans-serif; }}
    .wheel-stage {{ position:relative; width:min(380px,100%); aspect-ratio:1; margin:auto; }}
    .punishment-wheel {{ width:100%; height:100%; border-radius:50%; border:10px solid rgba(255,255,255,.14); background:conic-gradient(#7b2cbf 0 72deg,#ff54a0 72deg 144deg,#c77dff 144deg 216deg,#9d4edd 216deg 288deg,#ff7ad9 288deg 360deg); box-shadow:0 24px 70px rgba(0,0,0,.34), inset 0 0 34px rgba(0,0,0,.28); transition:transform 3.2s cubic-bezier(.12,.76,.18,1); }}
    .wheel-pointer {{ position:absolute; left:50%; top:-3px; width:0; height:0; transform:translateX(-50%); border-left:18px solid transparent; border-right:18px solid transparent; border-top:34px solid #fff; z-index:3; }}
    .wheel-center {{ position:absolute; inset:39%; border-radius:50%; background:#120817; border:4px solid rgba(255,255,255,.2); }}
    .section-kicker {{ color:#ff7ad9; font-size:13px; font-weight:900; letter-spacing:.06em; text-transform:uppercase; }}
    .wheel-copy h2 {{ margin:8px 0 10px; font-size:38px; }}
    .wheel-copy p {{ color:#f0c9ff; font-weight:760; line-height:1.5; }}
    #spinWheel {{ padding:14px 18px; border-radius:12px; border:0; font-weight:900; background:linear-gradient(135deg,#c77dff,#ff54a0); color:#120817; cursor:pointer; }}
    #spinWheel:disabled {{ cursor:not-allowed; opacity:.55; filter:grayscale(.35); }}
    #wheelItems {{ padding-left:22px; }}
    #wheelItems li {{ margin:7px 0; color:#f0c9ff; font-weight:800; }}
    @media (max-width:720px) {{ .wheel-shell {{ grid-template-columns:1fr; }} }}
    </style>
    <script>
    const items = {wheel_payload};
    const wheel = document.getElementById("punishmentWheel");
    const result = document.getElementById("wheelResult");
    const list = document.getElementById("wheelItems");
    list.innerHTML = items.map((item, index) => `<li>${{index + 1}}. ${{item}}</li>`).join("");
    let rotation = 0;
    const button = document.getElementById("spinWheel");
    if (!button.disabled) {{
        button.addEventListener("click", () => {{
            const selected = Math.floor(Math.random() * items.length);
            rotation += 1440 + selected * (360 / items.length) + Math.random() * 60;
            wheel.style.transform = `rotate(${{rotation}}deg)`;
            setTimeout(() => {{ result.textContent = items[selected]; }}, 3300);
        }});
    }}
    </script>
    """, height=520)

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
        pending_trade_count = len(api_get_optional("chicken_trades?status=eq.pending&select=id"))
        active_categories = len({str(item.get("category") or get_default_shop_category()) for item in shop_items})
        wheel_queue_count = len(get_punishment_wheel_entries())

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
                <div class="section-kicker">Shop</div>
                <h3>{active_categories}</h3>
                <div class="admin-muted">Kategorien mit Items</div>
            </div>
            <div class="admin-control-card">
                <div class="section-kicker">Bestrafungsrad</div>
                <h3>{wheel_queue_count}</h3>
                <div class="admin-muted">Offene Ideen in der Queue</div>
            </div>
        </div>
        """, unsafe_allow_html=True)

        overview_tab, registration_tab, viewer_tab, news_tab, shop_tab, event_tab, danger_tab = st.tabs([
            "Dashboard",
            "Registrierungen",
            "Viewer",
            "News",
            "Shop",
            "Events",
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
                                st.success(f"Einmalcode fuer {username}: {code}")
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
                    code_text = f"Code: {last_code}" if last_code else "Code wurde aus Sicherheitsgruenden nur beim Genehmigen angezeigt."
                    st.markdown(
                        f'<div class="admin-list-item"><b>{html.escape(username)}</b><br>'
                        f'<span class="admin-muted">{html.escape(code_text)}</span></div>',
                        unsafe_allow_html=True
                    )
                    if st.button("Neuen Code erzeugen", key=f"regenerate_registration_{request_id}"):
                        code = approve_registration_request(request_id)
                        if code:
                            st.session_state["last_registration_codes"][request_id] = code
                            st.success(f"Neuer Einmalcode fuer {username}: {code}")
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
