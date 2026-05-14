import streamlit as st
import pandas as pd
import requests
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
import streamlit.components.v1 as components
import hashlib
import re
import urllib.parse
import uuid
import html
import textwrap
from typing import Optional

st.set_page_config(
    page_title="Gehirnzone",
    page_icon="🧠",
    layout="wide"
)

PASSWORD_SALT = "gehirnzone_guest_auth_salt"

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
    SUPABASE_KEY = st.secrets["supabase"]["key"]
except KeyError:
    st.error("Supabase-Secrets sind nicht konfiguriert. Bitte setze SUPABASE_URL und SUPABASE_KEY in den App-Einstellungen.")
    st.stop()

HEADERS = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
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
        "desc": "VIP für 1 Woche"
    },
    {
        "name": "🎮 Steam Random Key",
        "price": 50000,
        "desc": "Zufälliger Steam Key"
    },
    {
        "name": "💬 Discord Frage",
        "price": 5000,
        "desc": "Frage im Discord stellen"
    },
    {
        "name": "🖼️ Zuschauerbild neben Facecam",
        "price": 2500,
        "desc": "Bild neben der Facecam"
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
            "desc": item.get("description") or ""
        }
        for item in items
    ]


def create_shop_item(name, description, price):
    if not name.strip() or int(price) <= 0:
        return None

    created = api_post(
        "shop_items",
        {
            "name": name.strip()[:100],
            "description": description.strip()[:300],
            "price": int(price),
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


def update_shop_item(item_id, name, description, price):
    if not item_id or not str(name).strip() or int(price) <= 0:
        return False

    success = api_patch(
        f"shop_items?id=eq.{item_id}",
        {
            "name": str(name).strip()[:100],
            "description": str(description).strip()[:300],
            "price": int(price),
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
    return True

# =========================
# DESIGN
# =========================

st.markdown("""
<style>

.stApp {
    background:
    radial-gradient(circle at 12% 16%, rgba(0,212,255,0.20), transparent 28%),
    radial-gradient(circle at 86% 8%, rgba(255,198,41,0.13), transparent 24%),
    radial-gradient(circle at 72% 78%, rgba(255,84,160,0.16), transparent 32%),
    linear-gradient(145deg, #07080d 0%, #121018 48%, #081619 100%);
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
    text-shadow: 0 0 34px rgba(0,212,255,0.22);
}

h1::after {
    content: "Community Control, Rewards und Rankings";
    display: block;
    margin-top: 14px;
    color: #a9f3ff;
    font-size: 16px;
    font-weight: 800;
    letter-spacing: 0;
    text-shadow: none;
}

.topbar {
    background: linear-gradient(135deg, rgba(0,212,255,0.12), rgba(255,84,160,0.08));
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
    box-shadow: 0 22px 65px rgba(0,212,255,0.18);
    border-color: rgba(0,212,255,0.45);
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
    color: #b8dbe1;
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

.section-kicker {
    color: #ffc629;
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
        linear-gradient(150deg, rgba(0,212,255,0.10), rgba(255,84,160,0.07)),
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
    border: 2px solid rgba(0,212,255,0.55);
    box-shadow: 0 0 30px rgba(0,212,255,0.22);
    background: linear-gradient(135deg, #00d4ff, #ffc629, #ff54a0);
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
    background: linear-gradient(90deg, #00d4ff, #ffc629, #ff54a0);
}

.member-rank-pill {
    float: right;
    padding: 6px 10px;
    border-radius: 999px;
    color: #061015;
    background: #ffc629;
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
    background: linear-gradient(90deg, #00d4ff, #ff54a0);
}

.member-card .profile-avatar {
    margin-bottom: 12px;
}

.member-favorite {
    margin-top: 12px;
    color: #00d4ff;
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
        linear-gradient(135deg, rgba(0,212,255,0.24), rgba(255,198,41,0.11), rgba(255,84,160,0.16)),
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
    background: radial-gradient(circle, rgba(255,198,41,0.22), transparent 62%);
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
    background: linear-gradient(135deg, #00d4ff, #ffc629);
    font-size: 13px;
    font-weight: 950;
}

.profile-big-name {
    font-size: clamp(38px, 6vw, 72px);
    line-height: 0.95;
    font-weight: 950;
    margin-bottom: 12px;
    text-shadow: 0 0 30px rgba(0,212,255,0.18);
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
    background: rgba(0,212,255,0.09);
    border: 1px solid rgba(0,212,255,0.18);
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
    background: linear-gradient(90deg, #00d4ff, #ffc629, #ff54a0);
    box-shadow: 0 0 24px rgba(0,212,255,0.35);
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
        linear-gradient(135deg, rgba(0,212,255,0.16), rgba(199,125,255,0.12)),
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
        linear-gradient(135deg, rgba(0,212,255,0.18), rgba(255,198,41,0.10), rgba(255,84,160,0.14)),
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
    background: radial-gradient(circle, rgba(255,198,41,0.20), transparent 65%);
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
    color: #b8dbe1;
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
    background: rgba(255,198,41,0.16);
    color: #fff2bc;
    border: 1px solid rgba(255,198,41,0.28);
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
        linear-gradient(135deg, rgba(0,212,255,0.14), rgba(255,198,41,0.10)),
        rgba(255,255,255,0.07);
    border-color: rgba(0,212,255,0.32);
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
    color: #a9f3ff;
    font-weight: 800;
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
    .profile-hero {
        grid-template-columns: 1fr;
    }

    .profile-stat-grid,
    .admin-stat-grid {
        grid-template-columns: 1fr;
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
    background: linear-gradient(135deg, #00d4ff, #ffc629);
    border: 1px solid rgba(255,255,255,0.18);
    border-radius: 12px;
    color: #061015;
    font-weight: 900;
    padding: 0.6rem 1rem;
    box-shadow: 0 12px 30px rgba(0,0,0,0.18);
}

.stButton > button:hover {
    transform: translateY(-2px);
    box-shadow: 0 18px 42px rgba(0,212,255,0.22);
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
    background: linear-gradient(135deg, #9d4edd, #00d4ff);
    border-color: transparent;
    box-shadow: 0 0 22px rgba(0,212,255,0.24);
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

        login_tab, register_tab = st.tabs(["Anmelden", "Registrieren"])

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

        with register_tab:
            register_name = st.text_input("Twitch-Name", key="register_name")
            register_password = st.text_input("Passwort", type="password", key="register_password")
            register_confirm = st.text_input("Passwort bestätigen", type="password", key="register_confirm")

            if st.button("Registrieren", key="register_submit"):
                if not validate_username(register_name):
                    st.error("Ungültiger Twitch-Name. Nur Buchstaben, Zahlen, - und _ sind erlaubt.")
                elif register_password == "":
                    st.error("Bitte gib ein Passwort ein.")
                elif register_password != register_confirm:
                    st.error("Die Passwörter stimmen nicht überein.")
                else:
                    existing_user = get_user(register_name)
                    if existing_user and existing_user.get("password_hash"):
                        st.error("Dieser Name ist bereits registriert.")
                    elif existing_user:
                        if set_user_password(register_name, register_password):
                            st.session_state["logged_in_username"] = register_name
                            st.success("Registrierung erfolgreich. Du bist jetzt angemeldet.")
                            st.rerun()
                        else:
                            st.error("Registrierung fehlgeschlagen. Prüfe die Datenbank-Konfiguration.")
                    else:
                        new_user = create_user(register_name, register_password)
                        if new_user:
                            st.session_state["logged_in_username"] = new_user["username"]
                            st.success("Registrierung erfolgreich. Du bist jetzt angemeldet.")
                            st.rerun()
                        else:
                            st.error("Registrierung fehlgeschlagen. Prüfe die Datenbank-Konfiguration.")

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

        rank_name, progress, progress_text = get_progress(braincells)
        level = get_profile_level(braincells)
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
        next_level_points = level * 100
        points_to_level = max(0, next_level_points - braincells)

        st.markdown(f"""
        <div class="profile-shell">
            <div class="profile-showcase">
                <div class="profile-showcase-inner">
                    {avatar_markup}
                    <div>
                        <div class="profile-rank-badge">Level {level} · {html.escape(rank_name)}</div>
                        <div class="profile-big-name">{html.escape(user["username"])}</div>
                        <div class="profile-bio-large">{html.escape(bio)}</div>
                        <div class="profile-chip-row">
                            <div class="profile-chip">Lieblingsspiel: {html.escape(favorite_game)}</div>
                            <div class="profile-chip">Rang #{rank_position}</div>
                            <div class="profile-chip">{completion}% Profil</div>
                            <div class="profile-chip">{unlocked_count}/{len(achievements)} Achievements</div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="profile-side-panel">
                <div class="section-kicker">Fortschritt</div>
                <h3>Nächstes Level</h3>
                <div class="profile-progress-track">
                    <div class="profile-progress-fill" style="width:{progress}%;"></div>
                </div>
                <div class="admin-muted">{progress}% · {html.escape(progress_text)}</div>
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

    st.write("")
    st.markdown("## Chicken-Handel")

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

    outgoing_trades = get_outgoing_trades(logged_in_username)
    if outgoing_trades:
        with st.expander("Deine offenen Handelsanfragen"):
            for trade in outgoing_trades:
                amount = int(trade.get("amount") or 0)
                recipient = trade.get("recipient")
                if trade.get("trade_type") == "gift":
                    st.write(f"Du möchtest {recipient} {amount} Chicken(s) schenken.")
                else:
                    st.write(f"Du fragst {amount} Chicken(s) von {recipient} an.")

    st.write("---")
    st.markdown("## Shop")

    for reward in get_shop_items():

        col1, col2 = st.columns([4, 1])

        with col1:
            st.markdown(f"""
                <div class="reward-card">
                    <h3>{reward["name"]}</h3>
                    <p>{reward["desc"]}</p>
                    <b>🥚 {reward["price"]} Chickens</b>
                </div>
                """, unsafe_allow_html=True)

        with col2:
            st.write("")

            if st.button("Kaufen", key=reward["name"]):
                success = buy_reward(effective_username, reward)

                if success:
                    st.success("Gekauft!")
                    st.rerun()
                else:
                    st.error("Nicht genug Chickens")

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

        ranked = leaderboard.copy()

        if search:
            ranked = ranked[ranked["Viewer"].str.contains(search, case=False, na=False)]

        ranked["Rang"] = ranked["Gehirnzellen"].apply(
            lambda x: get_rank(int(x))[0]
        )

        st.dataframe(
            ranked,
            use_container_width=True,
            hide_index=True
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

            st.markdown(f"""
            <div class="event-card">
                <h2>{event["title"]}</h2>
                <p>{event["description"]}</p>
                <p><b>{event["event_date"]}</b></p>
                <p>Teilnehmer: {len(signups)}</p>
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

    components.html("""
    <html>
    <head>
    <style>
        * { box-sizing: border-box; }
        body {
            margin: 0;
            min-height: 820px;
            background:
                radial-gradient(circle at 18% 14%, rgba(0, 245, 255, 0.18), transparent 26%),
                radial-gradient(circle at 82% 18%, rgba(199, 125, 255, 0.20), transparent 28%),
                linear-gradient(180deg, #070912 0%, #14091f 100%);
            color: white;
            font-family: Inter, Segoe UI, Arial, sans-serif;
            overflow: auto;
        }
        .shell { width: min(100%, 1040px); margin: 0 auto; padding: 16px; }
        .game-panel {
            position: relative;
            overflow: hidden;
            border: 1px solid rgba(255,255,255,0.12);
            border-radius: 18px;
            background: rgba(5, 8, 16, 0.72);
            box-shadow: 0 24px 70px rgba(0,0,0,0.42);
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
            background: linear-gradient(180deg, rgba(7,9,18,0.34), rgba(7,9,18,0.82));
        }
        .menu-card {
            width: min(520px, 92%);
            border: 1px solid rgba(255,255,255,0.16);
            border-radius: 18px;
            padding: 24px;
            text-align: center;
            background: rgba(12, 14, 24, 0.86);
            box-shadow: 0 0 40px rgba(157,78,221,0.24);
            backdrop-filter: blur(10px);
        }
        .menu-card h1 { margin: 0 0 8px; font-size: 44px; line-height: 1; }
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
        button.secondary {
            color: #fff;
            background: rgba(255,255,255,0.10);
            border: 1px solid rgba(255,255,255,0.16);
            box-shadow: none;
        }
        .hud { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-top: 12px; }
        .hud-card {
            min-height: 74px;
            padding: 13px 14px;
            border: 1px solid rgba(255,255,255,0.11);
            border-radius: 12px;
            background: rgba(255,255,255,0.055);
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
            border-radius: 14px;
            padding: 14px;
            background: rgba(255,255,255,0.045);
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
        @media (max-width: 720px) {
            body { min-height: 900px; }
            .hud { grid-template-columns: 1fr; }
            .scores li { align-items: flex-start; flex-direction: column; }
            .menu-card h1 { font-size: 34px; }
        }
    </style>
    </head>
    <body>
    <div class="shell">
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
                </div>
            </div>
        </div>

        <div class="hud">
            <div class="hud-card"><span>Score</span><strong id="scoreValue">0</strong></div>
            <div class="hud-card"><span>Tempo</span><strong id="speedValue">1.0x</strong></div>
            <div class="hud-card"><span>Level</span><strong id="levelValue">1</strong></div>
        </div>

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
    const scoreValue = document.getElementById("scoreValue");
    const speedValue = document.getElementById("speedValue");
    const levelValue = document.getElementById("levelValue");
    const SUPABASE_URL = "__SUPABASE_URL__";
    const SUPABASE_KEY = "__SUPABASE_KEY__";
    const SCOREBOARD_ENDPOINT = SUPABASE_URL + "/rest/v1/chicken_scores";

    let chicken = { x: 120, y: 338, w: 54, h: 46, vy: 0, jumping: false };
    const groundY = 390;
    let gravity = 0.82;
    let fences = [];
    let clouds = [];
    let particles = [];
    let speed = 5.4;
    let score = 0;
    let level = 1;
    let state = "menu";
    let frame = 0;
    let savedCurrentScore = false;
    let currentScoreFilter = "all";

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
            chicken.vy = -16.5;
            chicken.jumping = true;
            particles.push({x: chicken.x + 10, y: groundY - 12, life: 18});
        }
    }

    startBtn.addEventListener("click", startGame);
    scoreBtn.addEventListener("click", saveScore);
    canvas.addEventListener("click", jump);
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
            jump();
        } else if (e.code === "Enter" && state !== "playing") {
            startGame();
        }
    });

    function spawnFence() {
        const height = 46 + Math.random() * 26;
        fences.push({
            x: canvas.width + 40,
            y: groundY - height,
            w: 30 + Math.random() * 14,
            h: height,
            passed: false
        });
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
        sky.addColorStop(0, "#08172c");
        sky.addColorStop(0.55, "#161032");
        sky.addColorStop(1, "#260d2f");
        ctx.fillStyle = sky;
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        ctx.fillStyle = "rgba(255,255,255,0.35)";
        for (let i = 0; i < 42; i++) {
            const x = (i * 137 + frame * 0.18) % canvas.width;
            const y = 18 + (i * 53) % 190;
            ctx.fillRect(x, y, 2, 2);
        }

        if (frame % 180 === 0) spawnCloud();
        clouds.forEach(c => {
            c.x -= c.speed;
            ctx.fillStyle = "rgba(255,255,255,0.12)";
            roundedRect(c.x, c.y, c.w, 22, 999);
            roundedRect(c.x + c.w * 0.18, c.y - 12, c.w * 0.45, 28, 999);
        });
        clouds = clouds.filter(c => c.x + c.w > -120);
    }

    function drawGround() {
        const ground = ctx.createLinearGradient(0, groundY, 0, canvas.height);
        ground.addColorStop(0, "#2f1846");
        ground.addColorStop(1, "#120817");
        ctx.fillStyle = ground;
        ctx.fillRect(0, groundY, canvas.width, canvas.height - groundY);

        ctx.fillStyle = "#00d4ff";
        for (let i = 0; i < canvas.width + 60; i += 44) {
            roundedRect(i - (frame * speed % 44), groundY + 12, 22, 4, 4);
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
        ctx.fillStyle = "#ffd43b";
        roundedRect(0, 5, chicken.w, chicken.h, 14);
        ctx.fillStyle = "#ffe66d";
        roundedRect(16, -8, 32, 30, 14);
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
        ctx.fillStyle = "#ff6b6b";
        roundedRect(18, -18, 20, 12, 5);
        ctx.strokeStyle = "#ff922b";
        ctx.lineWidth = 4;
        ctx.beginPath();
        ctx.moveTo(17, 47);
        ctx.lineTo(13, 58);
        ctx.moveTo(38, 47);
        ctx.lineTo(42, 58);
        ctx.stroke();
        ctx.restore();
    }

    function drawFence(fence) {
        const grad = ctx.createLinearGradient(fence.x, fence.y, fence.x, fence.y + fence.h);
        grad.addColorStop(0, "#d8b4fe");
        grad.addColorStop(1, "#7c3aed");
        ctx.fillStyle = grad;
        roundedRect(fence.x, fence.y, fence.w, fence.h, 6);
        roundedRect(fence.x - 12, fence.y + fence.h * 0.25, fence.w + 24, 8, 4);
        roundedRect(fence.x - 12, fence.y + fence.h * 0.62, fence.w + 24, 8, 4);
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
            p.x -= speed * 0.25;
            p.y += 0.4;
            ctx.fillStyle = "rgba(255, 230, 109," + Math.max(p.life / 18, 0) + ")";
            ctx.beginPath();
            ctx.arc(p.x, p.y, 3, 0, Math.PI * 2);
            ctx.fill();
        });
        particles = particles.filter(p => p.life > 0);
    }

    function drawUI() {
        scoreValue.textContent = score;
        speedValue.textContent = (speed / 5.4).toFixed(1) + "x";
        levelValue.textContent = level;
    }

    function startGame() {
        chicken.y = groundY - chicken.h - 6;
        chicken.vy = 0;
        chicken.jumping = false;
        fences = [];
        particles = [];
        speed = 5.4;
        score = 0;
        level = 1;
        frame = 0;
        savedCurrentScore = false;
        state = "playing";
        hideMenu();
    }

    function endGame() {
        state = "gameover";
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
            let query = "?select=username,score,level,created_at&order=score.desc,created_at.asc&limit=10";
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
            if (scores.length === 0) {
                box.innerHTML = "<li>Noch keine Scores.</li>";
                return;
            }

            box.innerHTML = scores.map(s => {
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
            chicken.y += chicken.vy;

            if (chicken.y >= groundY - chicken.h - 6) {
                chicken.y = groundY - chicken.h - 6;
                chicken.vy = 0;
                chicken.jumping = false;
            }

            if (frame % Math.max(46, Math.floor(112 - speed * 7)) === 0) spawnFence();

            fences.forEach(fence => {
                fence.x -= speed;
                if (!fence.passed && fence.x + fence.w < chicken.x) {
                    fence.passed = true;
                    score++;
                    speed += 0.23;
                    level = 1 + Math.floor(score / 5);
                    particles.push({x: chicken.x + chicken.w, y: chicken.y + 10, life: 22});
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
    showMenu("Chicken Jump", "Spring ueber Zaeune, sammle Gehirnzellen und halte so lange wie moeglich durch.", "Spiel starten");
    loop();
    </script>
    </body>
    </html>
    """.replace("__SUPABASE_URL__", SUPABASE_URL).replace("__SUPABASE_KEY__", SUPABASE_KEY), height=860, scrolling=True)

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
        pending_trade_count = len(api_get_optional("chicken_trades?status=eq.pending&select=id"))

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

        overview_tab, viewer_tab, shop_tab, event_tab, danger_tab = st.tabs([
            "Dashboard",
            "Viewer",
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

        with shop_tab:
            st.markdown("### Shop verwalten")

            with st.form("create_shop_item_form"):
                item_name = st.text_input("Name des Shop-Items")
                item_description = st.text_area("Beschreibung des Shop-Items")
                item_price = st.number_input("Preis in Chickens", min_value=1, step=1)
                create_item = st.form_submit_button("Shop-Item erstellen")

            if create_item:
                if create_shop_item(item_name, item_description, item_price):
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
                                edited_price = st.number_input("Preis", min_value=1, step=1, value=int(item["price"]))
                                save_col, delete_col = st.columns(2)
                                with save_col:
                                    save_item = st.form_submit_button("Änderungen speichern")
                                with delete_col:
                                    remove_item = st.form_submit_button("Deaktivieren")

                            if save_item:
                                if update_shop_item(item["id"], edited_name, edited_desc, edited_price):
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
