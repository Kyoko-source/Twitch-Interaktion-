import re
import secrets
import json
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any
from urllib.parse import quote

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from .auth import create_access_token, current_user, hash_password, require_admin, verify_password
from .config import get_settings
from .supabase import supabase


USERNAME_RE = re.compile(r"^[A-Za-z0-9_-]{2,32}$")
USER_ROLES = {"admin", "moderator", "vip", "member"}
SYSTEMATICS_FILE = Path("/data/systematics.json")
USER_ROLES_FILE = Path("/data/user_roles.json")
CHAT_MESSAGES_FILE = Path("/data/chat_messages.json")
CHAT_STYLES_FILE = Path("/data/chat_styles.json")
CHAT_STYLE_PURCHASES_FILE = Path("/data/chat_style_purchases.json")
PURCHASE_CATEGORY_FALLBACK = "In Stream Rewards"
PURCHASE_CATEGORIES = {
    "In Stream Rewards",
    "Bestrafungs Ideen",
    "Idee Bestrafungsrad",
    "Aufgaben",
    "Aufgaben Ideen",
    "Idee Aufgabenrad",
    "Out of Stream Rewards",
}
CHAT_STYLE_SHOP_ITEMS = [
    {"id": "chat-style-sparkle", "name": "Chat Animation: Sternenfunkeln", "description": "Goldene Glitzersterne laufen weich ueber deine Chatbalken.", "price": 650, "category": "Chat Animation", "style": "sparkle"},
    {"id": "chat-style-cotton", "name": "Chat Animation: Zuckerwatte", "description": "Suess, rosa und weich pulsierend mit kleinen Herzchen.", "price": 900, "category": "Chat Animation", "style": "cotton"},
    {"id": "chat-style-neon", "name": "Chat Animation: Neon Pulse", "description": "Cooler Cyber-Look mit wandernder Neon-Kante.", "price": 1200, "category": "Chat Animation", "style": "neon"},
    {"id": "chat-style-royal", "name": "Chat Animation: Royal Glow", "description": "Lila VIP-Schimmer mit edlem Glanz fuer deine Nachrichten.", "price": 1500, "category": "Chat Animation", "style": "royal"},
]

app = FastAPI(title="Aviary API")
settings = get_settings()
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class LoginRequest(BaseModel):
    username: str
    password: str


class RegistrationRequest(BaseModel):
    username: str
    password: str


class RegistrationComplete(BaseModel):
    username: str
    password: str
    code: str


class ProfileUpdate(BaseModel):
    bio: str = Field(default="", max_length=300)
    favorite_game: str = Field(default="", max_length=80)
    avatar_url: str = Field(default="", max_length=500)


class SupportCreate(BaseModel):
    username: str = Field(default="Gast", max_length=64)
    category: str = Field(default="Problem", max_length=64)
    title: str = Field(max_length=140)
    message: str = Field(max_length=2500)


class WishCreate(BaseModel):
    title: str = Field(max_length=140)
    description: str = Field(max_length=1800)


class EventSignup(BaseModel):
    event_id: str


class PurchaseRequest(BaseModel):
    item_id: str


class ChatStyleUpdate(BaseModel):
    style: str = Field(max_length=40)


class PointsUpdate(BaseModel):
    username: str
    chickens_delta: int = 0
    braincells_delta: int = 0


class RoleUpdate(BaseModel):
    username: str
    role: str


class ScoreCreate(BaseModel):
    game: str
    score: int
    level: int = 1
    round: int = 1
    seconds_survived: int = 0
    kills: int = 0
    build: str = ""


class GalleryCreate(BaseModel):
    title: str = Field(default="Ohne Titel", max_length=120)
    image_data: str = Field(max_length=1600000)


class GalleryReaction(BaseModel):
    art_id: str
    emoji: str = Field(max_length=8)


class ChatCreate(BaseModel):
    body: str = Field(max_length=1200)
    recipient_username: str | None = Field(default=None, max_length=32)


class NewsCreate(BaseModel):
    title: str = Field(max_length=140)
    body: str = Field(max_length=2500)
    image_url: str = Field(default="", max_length=500)


class ShopItemCreate(BaseModel):
    name: str = Field(max_length=100)
    description: str = Field(default="", max_length=1200)
    price: int = 0
    category: str = Field(default="Rewards", max_length=80)


class EventCreate(BaseModel):
    title: str = Field(max_length=140)
    description: str = Field(default="", max_length=1800)
    event_date: str = Field(default="", max_length=80)


class IdPayload(BaseModel):
    id: str


class SystematicsNode(BaseModel):
    id: str
    title: str = Field(max_length=120)
    subtitle: str = Field(default="", max_length=220)
    color: str = Field(default="#b46cff", max_length=32)
    image_url: str = Field(default="", max_length=500)
    x: float = 0
    y: float = 0


class SystematicsLink(BaseModel):
    source: str
    target: str


class SystematicsDocument(BaseModel):
    title: str = Field(default="Systematik", max_length=120)
    description: str = Field(default="Baue deine eigene Systematik mit Boxen, Farben, Bildern und Verbindungen.", max_length=500)
    nodes: list[SystematicsNode]
    links: list[SystematicsLink]


def clean_username(username: str) -> str:
    value = username.strip()
    if not USERNAME_RE.match(value):
        raise HTTPException(status_code=400, detail="Ungueltiger Twitch-Name")
    return value


def rows(path: str) -> list[dict[str, Any]]:
    return supabase().get(path)


def default_systematics() -> dict[str, Any]:
    return {
        "title": "Tier-Systematik",
        "description": "Ein frei bearbeitbarer Baukasten fuer Klassen, Gruppen, Arten oder eigene Kategorien.",
        "nodes": [
            {"id": "root", "title": "Lebewesen", "subtitle": "Startpunkt", "color": "#ffcf8a", "image_url": "", "x": 420, "y": 48},
            {"id": "animals", "title": "Tiere", "subtitle": "Animalia", "color": "#b46cff", "image_url": "", "x": 250, "y": 210},
            {"id": "birds", "title": "Voegel", "subtitle": "Aves", "color": "#7af4dc", "image_url": "", "x": 585, "y": 210},
            {"id": "chicken", "title": "Huehnervoegel", "subtitle": "Galliformes", "color": "#ff6fb7", "image_url": "", "x": 585, "y": 380},
        ],
        "links": [
            {"source": "root", "target": "animals"},
            {"source": "root", "target": "birds"},
            {"source": "birds", "target": "chicken"},
        ],
    }


def load_systematics() -> dict[str, Any]:
    try:
        if SYSTEMATICS_FILE.exists():
            return json.loads(SYSTEMATICS_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        pass
    return default_systematics()


def score_table(game: str) -> str | None:
    return {
        "chicken-jump": "chicken_scores",
        "chicken-snake": "chicken_snake_scores",
        "chicken-racer": "chicken_racer_scores",
        "braincell-survivor": "braincell_survivor_scores",
    }.get(game)


def single_user(username: str) -> dict[str, Any] | None:
    result = rows(f"users?username=eq.{quote(username)}&limit=1")
    return result[0] if result else None


def public_user(user: dict[str, Any]) -> dict[str, Any]:
    hidden = {"password_hash", "approval_code_hash"}
    public = {key: value for key, value in user.items() if key not in hidden}
    public["role"] = user_role(str(public.get("username") or ""), public.get("role"))
    return public


def chat_style_ids() -> set[str]:
    return {"default", *(str(item["style"]) for item in CHAT_STYLE_SHOP_ITEMS)}


def load_chat_styles() -> dict[str, str]:
    try:
        if not CHAT_STYLES_FILE.exists():
            return {}
        data = json.loads(CHAT_STYLES_FILE.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            return {}
        valid = chat_style_ids()
        return {str(username): str(style) for username, style in data.items() if str(style) in valid}
    except (OSError, json.JSONDecodeError):
        return {}


def save_chat_styles(styles: dict[str, str]) -> None:
    CHAT_STYLES_FILE.parent.mkdir(parents=True, exist_ok=True)
    CHAT_STYLES_FILE.write_text(json.dumps(styles, ensure_ascii=False, indent=2), encoding="utf-8")


def chat_style_for(username: str) -> str:
    return load_chat_styles().get(username, "default")


def purchased_item_names(username: str) -> set[str]:
    try:
        purchases = rows(f"purchases?username=eq.{quote(username)}&select=reward_name")
    except HTTPException:
        purchases = []
    return {str(purchase.get("reward_name") or "") for purchase in purchases}


def load_chat_style_purchases() -> dict[str, list[str]]:
    try:
        if not CHAT_STYLE_PURCHASES_FILE.exists():
            return {}
        data = json.loads(CHAT_STYLE_PURCHASES_FILE.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            return {}
        return {str(username): [str(style) for style in styles if str(style) in chat_style_ids()] for username, styles in data.items() if isinstance(styles, list)}
    except (OSError, json.JSONDecodeError):
        return {}


def save_chat_style_purchases(purchases: dict[str, list[str]]) -> None:
    CHAT_STYLE_PURCHASES_FILE.parent.mkdir(parents=True, exist_ok=True)
    CHAT_STYLE_PURCHASES_FILE.write_text(json.dumps(purchases, ensure_ascii=False, indent=2), encoding="utf-8")


def remember_chat_style_purchase(username: str, style: str) -> None:
    purchases = load_chat_style_purchases()
    owned = set(purchases.get(username, []))
    owned.add(style)
    purchases[username] = sorted(owned)
    save_chat_style_purchases(purchases)


def owned_chat_styles(username: str) -> set[str]:
    names = purchased_item_names(username)
    owned = {"default", *load_chat_style_purchases().get(username, [])}
    for item in CHAT_STYLE_SHOP_ITEMS:
        if item["name"] in names:
            owned.add(str(item["style"]))
    return owned


def enrich_chat_messages(messages: list[dict[str, Any]]) -> list[dict[str, Any]]:
    usernames = {str(message.get("sender_username") or "") for message in messages}
    usernames.update(str(message.get("recipient_username") or "") for message in messages if message.get("recipient_username"))
    valid_usernames = sorted(name for name in usernames if name)
    users_by_name = {
        str(user.get("username") or ""): public_user(user)
        for user in rows("users?select=*&username=in.(" + ",".join(quote(name) for name in valid_usernames) + ")")
    } if valid_usernames else {}
    enriched = []
    styles = load_chat_styles()
    for message in messages:
        sender = str(message.get("sender_username") or "")
        recipient = str(message.get("recipient_username") or "")
        enriched.append({
            **message,
            "sender": users_by_name.get(sender, {"username": sender, "role": "member"}),
            "recipient": users_by_name.get(recipient, {"username": recipient, "role": "member"}) if recipient else None,
            "chat_style": styles.get(sender, "default"),
        })
    return enriched


def normalize_role(role: Any) -> str:
    value = str(role or "member").strip().lower()
    return value if value in USER_ROLES else "member"


def load_user_roles() -> dict[str, str]:
    try:
        if not USER_ROLES_FILE.exists():
            return {}
        data = json.loads(USER_ROLES_FILE.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            return {}
        return {str(username): normalize_role(role) for username, role in data.items()}
    except (OSError, json.JSONDecodeError):
        return {}


def save_user_roles(roles: dict[str, str]) -> None:
    USER_ROLES_FILE.parent.mkdir(parents=True, exist_ok=True)
    USER_ROLES_FILE.write_text(json.dumps(roles, ensure_ascii=False, indent=2), encoding="utf-8")


def user_role(username: str, fallback: Any = None) -> str:
    stored = load_user_roles().get(username)
    return stored or normalize_role(fallback)


def load_chat_messages() -> list[dict[str, Any]]:
    try:
        if not CHAT_MESSAGES_FILE.exists():
            return []
        data = json.loads(CHAT_MESSAGES_FILE.read_text(encoding="utf-8"))
        return data if isinstance(data, list) else []
    except (OSError, json.JSONDecodeError):
        return []


def save_chat_messages(messages: list[dict[str, Any]]) -> None:
    CHAT_MESSAGES_FILE.parent.mkdir(parents=True, exist_ok=True)
    CHAT_MESSAGES_FILE.write_text(json.dumps(messages[-600:], ensure_ascii=False, indent=2), encoding="utf-8")


def store_chat_message(channel: str, sender: str, body: str, recipient: str | None = None) -> dict[str, Any]:
    messages = load_chat_messages()
    message = {
        "id": secrets.token_hex(12),
        "channel": channel,
        "sender_username": sender,
        "recipient_username": recipient,
        "body": body,
        "created_at": datetime.now().isoformat(),
    }
    messages.append(message)
    save_chat_messages(messages)
    return message


def global_chat_rows() -> list[dict[str, Any]]:
    return [message for message in load_chat_messages() if message.get("channel") == "global"][-120:]


def private_chat_rows(me: str, other: str) -> list[dict[str, Any]]:
    messages = []
    for message in load_chat_messages():
        if message.get("channel") != "private":
            continue
        sender = str(message.get("sender_username") or "")
        recipient = str(message.get("recipient_username") or "")
        if {sender, recipient} == {me, other}:
            messages.append(message)
    return messages[-120:]


def rank_name(points: int) -> str:
    if points >= 10000:
        return "Aviary Legende"
    if points >= 5000:
        return "Goldener Pepple"
    if points >= 2000:
        return "Schwarm Elite"
    if points >= 750:
        return "Stammgast"
    if points >= 250:
        return "Nestling"
    return "Frisch geschluepft"


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/api/auth/login")
def login(payload: LoginRequest) -> dict[str, Any]:
    username = clean_username(payload.username)
    user = single_user(username)
    if not user or not verify_password(payload.password, user.get("password_hash")):
        raise HTTPException(status_code=401, detail="Login fehlgeschlagen")
    return {"token": create_access_token(username), "user": public_user(user)}


@app.get("/api/auth/me")
def me(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    return {"user": public_user(user)}


@app.post("/api/auth/registration-requests")
def request_registration(payload: RegistrationRequest) -> dict[str, str]:
    username = clean_username(payload.username)
    if single_user(username):
        raise HTTPException(status_code=409, detail="User existiert bereits")
    existing = rows(f"registration_requests?username=eq.{quote(username)}&status=in.(pending,approved)&limit=1")
    if existing:
        return {"message": "Deine Registrierung wartet bereits auf Freigabe."}
    supabase().post(
        "registration_requests",
        {"username": username, "password_hash": hash_password(payload.password), "status": "pending"},
        returning=False,
    )
    return {"message": "Registrierung wurde an den Adminbereich gesendet."}


@app.post("/api/auth/complete-registration")
def complete_registration(payload: RegistrationComplete) -> dict[str, Any]:
    username = clean_username(payload.username)
    requests_for_user = rows(
        "registration_requests?select=*&"
        f"username=eq.{quote(username)}&"
        "status=eq.approved&used_at=is.null&order=approved_at.desc"
    )
    approved_request = None
    for request_row in requests_for_user:
        password_ok = verify_password(payload.password, request_row.get("password_hash"))
        code_ok = verify_password(payload.code.strip(), request_row.get("approval_code_hash"))
        if password_ok and code_ok:
            approved_request = request_row
            break
    if not approved_request:
        raise HTTPException(status_code=400, detail="Name, Passwort oder Einmalcode stimmt nicht")

    existing = single_user(username)
    if existing and existing.get("password_hash"):
        raise HTTPException(status_code=409, detail="User ist bereits registriert")

    if existing:
        user_rows = supabase().patch(f"users?username=eq.{quote(username)}", {"password_hash": hash_password(payload.password)})
        user = user_rows[0] if user_rows else existing
    else:
        created = supabase().post(
            "users",
            {"username": username, "password_hash": hash_password(payload.password), "chickens": 0, "braincells": 0},
        )
        user = created[0] if created else single_user(username)
    if not user:
        raise HTTPException(status_code=500, detail="User konnte nicht erstellt werden")

    supabase().patch(
        f"registration_requests?id=eq.{quote(str(approved_request.get('id')))}",
        {"status": "used", "used_at": datetime.now().isoformat()},
    )
    return {"token": create_access_token(username), "user": public_user(user)}


@app.get("/api/dashboard")
def dashboard() -> dict[str, Any]:
    users = rows("users?select=*&order=braincells.desc")
    cutoff = (datetime.now() - timedelta(seconds=45)).isoformat()
    try:
        presence_rows = rows(f"user_presence?select=username,last_seen&last_seen=gte.{quote(cutoff)}&order=last_seen.desc&limit=8")
    except HTTPException:
        presence_rows = []
    users_by_name = {str(user.get("username") or ""): public_user(user) for user in users}
    active_members = [
        {**users_by_name.get(str(row.get("username") or ""), {"username": row.get("username")}), "last_seen": row.get("last_seen"), "status": "Online"}
        for row in presence_rows
        if row.get("username")
    ]
    news = rows("news_posts?select=*&active=eq.true&order=published_at.desc,created_at.desc&limit=5")
    events = rows("events?select=*&order=id.desc&limit=5")
    gallery = rows("creative_gallery?select=*&order=created_at.desc&limit=6")
    leaderboard = [public_user(user) for user in users]
    return {
        "stats": {
            "users": len(users),
            "chickens": sum(int(user.get("chickens") or 0) for user in users),
            "braincells": sum(int(user.get("braincells") or 0) for user in users),
        },
        "leaderboard": leaderboard[:10],
        "active_members": active_members,
        "news": news,
        "events": events,
        "gallery": gallery,
    }


@app.post("/api/presence")
def touch_presence(user: dict[str, Any] = Depends(current_user)) -> dict[str, str]:
    username = str(user["username"])
    supabase().upsert(
        "user_presence?on_conflict=username",
        {"username": username, "last_seen": datetime.now().isoformat()},
        returning=False,
    )
    return {"status": "online"}


@app.delete("/api/presence")
def clear_presence(user: dict[str, Any] = Depends(current_user)) -> dict[str, str]:
    supabase().delete(f"user_presence?username=eq.{quote(str(user['username']))}")
    return {"status": "offline"}


@app.get("/api/users")
def users() -> list[dict[str, Any]]:
    return [public_user(user) for user in rows("users?select=*&order=braincells.desc")]


@app.get("/api/chat/online")
def chat_online(user: dict[str, Any] = Depends(current_user)) -> list[dict[str, Any]]:
    cutoff = (datetime.now() - timedelta(seconds=55)).isoformat()
    try:
        presence_rows = rows(f"user_presence?select=username,last_seen&last_seen=gte.{quote(cutoff)}&order=last_seen.desc&limit=50")
    except HTTPException:
        presence_rows = []
    usernames = [str(row.get("username") or "") for row in presence_rows if row.get("username")]
    users_by_name = {
        str(member.get("username") or ""): public_user(member)
        for member in rows("users?select=*&username=in.(" + ",".join(quote(name) for name in usernames) + ")")
    } if usernames else {}
    return [
        {**users_by_name.get(username, {"username": username, "role": "member"}), "last_seen": row.get("last_seen"), "status": "Online"}
        for row in presence_rows
        for username in [str(row.get("username") or "")]
        if username
    ]


@app.get("/api/chat/global")
def chat_global(user: dict[str, Any] = Depends(current_user)) -> list[dict[str, Any]]:
    return enrich_chat_messages(global_chat_rows())


@app.post("/api/chat/global")
def create_global_message(payload: ChatCreate, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    body = payload.body.strip()
    if not body:
        raise HTTPException(status_code=400, detail="Nachricht ist leer")
    created = store_chat_message("global", str(user["username"]), body)
    return {"message": enrich_chat_messages([created])[0]}


@app.get("/api/chat/private/{username}")
def chat_private(username: str, user: dict[str, Any] = Depends(current_user)) -> list[dict[str, Any]]:
    other = clean_username(username)
    me = str(user["username"])
    if other == me:
        raise HTTPException(status_code=400, detail="Du kannst dir nicht selbst schreiben")
    if not single_user(other):
        raise HTTPException(status_code=404, detail="Mitglied nicht gefunden")
    return enrich_chat_messages(private_chat_rows(me, other))


@app.post("/api/chat/private/{username}")
def create_private_message(username: str, payload: ChatCreate, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    recipient = clean_username(username)
    sender = str(user["username"])
    if recipient == sender:
        raise HTTPException(status_code=400, detail="Du kannst dir nicht selbst schreiben")
    if not single_user(recipient):
        raise HTTPException(status_code=404, detail="Mitglied nicht gefunden")
    body = payload.body.strip()
    if not body:
        raise HTTPException(status_code=400, detail="Nachricht ist leer")
    created = store_chat_message("private", sender, body, recipient)
    return {"message": enrich_chat_messages([created])[0]}


@app.get("/api/chat/styles")
def chat_styles(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    username = str(user["username"])
    owned = owned_chat_styles(username)
    return {
        "selected": chat_style_for(username),
        "styles": [
            {"id": "default", "name": "Standard", "description": "Ruhiger Standard-Chatbalken.", "owned": True},
            *[
                {
                    "id": item["style"],
                    "name": item["name"].replace("Chat Animation: ", ""),
                    "description": item["description"],
                    "price": item["price"],
                    "shop_id": item["id"],
                    "owned": item["style"] in owned,
                }
                for item in CHAT_STYLE_SHOP_ITEMS
            ],
        ],
    }


@app.post("/api/chat/styles")
def update_chat_style(payload: ChatStyleUpdate, user: dict[str, Any] = Depends(current_user)) -> dict[str, str]:
    style = payload.style.strip()
    username = str(user["username"])
    if style not in chat_style_ids():
        raise HTTPException(status_code=400, detail="Diese Chat-Animation gibt es nicht")
    if style not in owned_chat_styles(username):
        raise HTTPException(status_code=403, detail="Diese Chat-Animation musst du erst im Shop kaufen")
    styles = load_chat_styles()
    styles[username] = style
    save_chat_styles(styles)
    return {"message": "Chat-Animation aktiviert.", "style": style}


@app.get("/api/leaderboard")
def leaderboard() -> list[dict[str, Any]]:
    return [
        {**public_user(user), "rank_name": rank_name(int(user.get("braincells") or 0))}
        for user in rows("users?select=*&order=braincells.desc")
    ]


@app.get("/api/profile/{username}")
def profile(username: str) -> dict[str, Any]:
    user = single_user(clean_username(username))
    if not user:
        raise HTTPException(status_code=404, detail="Profil nicht gefunden")
    return public_user(user)


@app.patch("/api/profile")
def update_profile(payload: ProfileUpdate, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    username = quote(str(user["username"]))
    updated = supabase().patch(
        f"users?username=eq.{username}",
        {
            "bio": payload.bio.strip(),
            "favorite_game": payload.favorite_game.strip(),
            "avatar_url": payload.avatar_url.strip(),
        },
    )
    return {"user": public_user(updated[0] if updated else user)}


@app.post("/api/daily-reward")
def daily_reward(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    today = date.today().isoformat()
    username = str(user["username"])
    existing = rows(f"daily_rewards?username=eq.{quote(username)}&reward_date=eq.{today}&limit=1")
    if existing:
        return {"claimed": False, "message": "Daily Reward wurde heute schon abgeholt."}
    streak = len(rows(f"daily_rewards?username=eq.{quote(username)}&order=reward_date.desc&limit=7"))
    chickens = 250 + min(streak, 7) * 50
    braincells = 25
    supabase().post("daily_rewards", {"username": username, "reward_date": today, "chickens": chickens, "braincells": braincells}, returning=False)
    supabase().patch(
        f"users?username=eq.{quote(username)}",
        {
            "chickens": int(user.get("chickens") or 0) + chickens,
            "braincells": int(user.get("braincells") or 0) + braincells,
        },
    )
    return {"claimed": True, "message": f"+{chickens} Chickens und +{braincells} Pepples"}


@app.get("/api/news")
def news() -> list[dict[str, Any]]:
    return rows("news_posts?select=*&active=eq.true&order=published_at.desc,created_at.desc&limit=20")


@app.get("/api/patch-notes")
def patch_notes() -> list[dict[str, Any]]:
    return rows("patch_notes?select=*&active=eq.true&order=published_date.desc,created_at.desc&limit=50")


@app.get("/api/shop")
def shop() -> list[dict[str, Any]]:
    items = rows("shop_items?select=*&active=eq.true&order=category.asc,price.asc")
    existing_names = {str(item.get("name") or "") for item in items}
    builtins = [item for item in CHAT_STYLE_SHOP_ITEMS if item["name"] not in existing_names]
    return [*items, *builtins]


@app.post("/api/shop/purchase")
def purchase(payload: PurchaseRequest, user: dict[str, Any] = Depends(current_user)) -> dict[str, str]:
    builtin_item = next((item for item in CHAT_STYLE_SHOP_ITEMS if item["id"] == payload.item_id), None)
    items = [builtin_item] if builtin_item else rows(f"shop_items?id=eq.{quote(payload.item_id)}&active=eq.true&limit=1")
    if not items:
        raise HTTPException(status_code=404, detail="Item nicht gefunden")
    item = items[0]
    price = int(item.get("price") or 0)
    current_chickens = int(user.get("chickens") or 0)
    if builtin_item and item.get("name") in purchased_item_names(str(user["username"])):
        return {"message": "Chat-Animation besitzt du bereits."}
    if current_chickens < price:
        raise HTTPException(status_code=400, detail="Nicht genug Chickens")
    purchase_category = str(item.get("category") or "").strip()
    if purchase_category not in PURCHASE_CATEGORIES:
        purchase_category = PURCHASE_CATEGORY_FALLBACK
    supabase().post(
        "purchases",
        {"username": user["username"], "reward_name": item.get("name"), "reward_category": purchase_category, "price": price, "status": "open"},
        returning=False,
    )
    if builtin_item:
        remember_chat_style_purchase(str(user["username"]), str(item["style"]))
    supabase().patch(f"users?username=eq.{quote(str(user['username']))}", {"chickens": current_chickens - price})
    return {"message": "Item gekauft."}


@app.get("/api/events")
def events() -> list[dict[str, Any]]:
    return rows("events?select=*&order=id.desc")


@app.post("/api/events/signup")
def signup(payload: EventSignup, user: dict[str, Any] = Depends(current_user)) -> dict[str, str]:
    event_id = quote(payload.event_id)
    username = str(user["username"])
    existing = rows(f"event_signups?event_id=eq.{event_id}&username=eq.{quote(username)}&limit=1")
    if existing:
        return {"message": "Du bist bereits angemeldet."}
    supabase().post("event_signups", {"event_id": payload.event_id, "username": username}, returning=False)
    return {"message": "Angemeldet."}


@app.get("/api/gallery")
def gallery() -> list[dict[str, Any]]:
    items = rows("creative_gallery?select=*&order=created_at.desc&limit=60")
    reactions = rows("creative_gallery_reactions?select=art_id,username,emoji,created_at&order=created_at.desc&limit=1000")
    by_art: dict[str, dict[str, int]] = {}
    user_reactions: dict[str, dict[str, str]] = {}
    for reaction in reactions:
        art_id = str(reaction.get("art_id") or "")
        emoji = str(reaction.get("emoji") or "")
        username = str(reaction.get("username") or "")
        if not art_id or not emoji:
            continue
        by_art.setdefault(art_id, {})
        by_art[art_id][emoji] = by_art[art_id].get(emoji, 0) + 1
        if username:
            user_reactions.setdefault(art_id, {})[username] = emoji
    return [
        {
            **item,
            "reactions": by_art.get(str(item.get("id") or ""), {}),
            "user_reactions": user_reactions.get(str(item.get("id") or ""), {}),
        }
        for item in items
    ]


@app.post("/api/gallery")
def save_gallery_art(payload: GalleryCreate, user: dict[str, Any] = Depends(current_user)) -> dict[str, str]:
    image_data = payload.image_data.strip()
    if not image_data.startswith("data:image/png;base64,"):
        raise HTTPException(status_code=400, detail="Bitte ein gemaltes PNG-Bild speichern")
    title = payload.title.strip() or "Ohne Titel"
    username = str(user["username"])
    payload_data = {
        "username": username,
        "title": title,
        "image_data": image_data,
        "created_at": datetime.now().isoformat(),
    }
    existing = rows(f"creative_gallery?username=eq.{quote(username)}&order=created_at.desc&limit=1")
    if existing:
        supabase().patch(f"creative_gallery?id=eq.{quote(str(existing[0].get('id')))}", payload_data)
    else:
        supabase().post("creative_gallery", payload_data, returning=False)
    return {"message": "Dein Bild ist jetzt in der Hall of Fame."}


@app.post("/api/gallery/reactions")
def react_gallery_art(payload: GalleryReaction, user: dict[str, Any] = Depends(current_user)) -> dict[str, str]:
    emoji = payload.emoji.strip()
    if emoji not in {"😍", "😂", "🔥", "💜", "👏"}:
        raise HTTPException(status_code=400, detail="Diese Reaktion gibt es nicht")
    art_id = quote(payload.art_id.strip())
    if not rows(f"creative_gallery?id=eq.{art_id}&limit=1"):
        raise HTTPException(status_code=404, detail="Bild nicht gefunden")
    username = str(user["username"])
    existing = rows(f"creative_gallery_reactions?art_id=eq.{art_id}&username=eq.{quote(username)}&limit=1")
    if existing:
        supabase().patch(f"creative_gallery_reactions?id=eq.{quote(str(existing[0].get('id')))}", {"emoji": emoji, "created_at": datetime.now().isoformat()})
    else:
        supabase().post("creative_gallery_reactions", {"art_id": payload.art_id, "username": username, "emoji": emoji}, returning=False)
    return {"message": "Reaktion gespeichert."}


@app.get("/api/systematics")
def systematics() -> dict[str, Any]:
    return load_systematics()


@app.put("/api/admin/systematics", dependencies=[Depends(require_admin)])
def save_systematics(payload: SystematicsDocument) -> dict[str, str]:
    data = payload.model_dump()
    SYSTEMATICS_FILE.parent.mkdir(parents=True, exist_ok=True)
    SYSTEMATICS_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return {"message": "Systematik gespeichert."}


@app.get("/api/support/wishes")
def wishes() -> list[dict[str, Any]]:
    return rows("wish_posts?select=*&active=eq.true&order=created_at.desc")


@app.post("/api/support")
def create_support(payload: SupportCreate) -> dict[str, str]:
    supabase().post(
        "support_messages",
        {
            "username": payload.username.strip() or "Gast",
            "category": payload.category.strip() or "Problem",
            "title": payload.title.strip(),
            "message": payload.message.strip(),
            "status": "open",
        },
        returning=False,
    )
    return {"message": "Meldung wurde gesendet."}


@app.post("/api/support/wishes")
def create_wish(payload: WishCreate, user: dict[str, Any] = Depends(current_user)) -> dict[str, str]:
    supabase().post(
        "wish_posts",
        {"username": user["username"], "title": payload.title.strip(), "description": payload.description.strip(), "active": True},
        returning=False,
    )
    return {"message": "Wunsch wurde veroeffentlicht."}


@app.get("/api/scores/{game}")
def scores(game: str) -> list[dict[str, Any]]:
    table = score_table(game)
    if not table:
        raise HTTPException(status_code=404, detail="Spiel nicht gefunden")
    return rows(f"{table}?select=*&order=score.desc,created_at.asc&limit=100")


@app.post("/api/scores")
def save_score(payload: ScoreCreate, user: dict[str, Any] = Depends(current_user)) -> dict[str, str]:
    table = score_table(payload.game)
    if not table:
        raise HTTPException(status_code=404, detail="Spiel nicht gefunden")
    data: dict[str, Any] = {
        "username": user["username"],
        "score": max(0, int(payload.score)),
        "level": max(1, int(payload.level)),
    }
    if payload.game == "chicken-racer":
        data["round"] = max(1, int(payload.round))
    if payload.game == "braincell-survivor":
        data.update(
            {
                "seconds_survived": max(0, int(payload.seconds_survived)),
                "kills": max(0, int(payload.kills)),
                "build": payload.build[:500],
            }
        )
    supabase().post(table, data, returning=False)
    return {"message": "Score gespeichert."}


@app.get("/api/admin/overview", dependencies=[Depends(require_admin)])
def admin_overview() -> dict[str, Any]:
    users_data = rows("users?select=*&order=braincells.desc")
    return {
        "users": [public_user(user) for user in users_data],
        "registration_requests": rows("registration_requests?select=*&status=eq.pending&order=created_at.asc"),
        "support_messages": rows("support_messages?select=*&order=created_at.desc&limit=100"),
        "wishes": rows("wish_posts?select=*&active=eq.true&order=created_at.desc&limit=100"),
    }


@app.post("/api/admin/points", dependencies=[Depends(require_admin)])
def admin_points(payload: PointsUpdate) -> dict[str, str]:
    username = clean_username(payload.username)
    user = single_user(username)
    if not user:
        raise HTTPException(status_code=404, detail="User nicht gefunden")
    supabase().patch(
        f"users?username=eq.{quote(username)}",
        {
            "chickens": max(0, int(user.get("chickens") or 0) + payload.chickens_delta),
            "braincells": max(0, int(user.get("braincells") or 0) + payload.braincells_delta),
        },
    )
    return {"message": "Punkte aktualisiert."}


@app.post("/api/admin/role", dependencies=[Depends(require_admin)])
def admin_role(payload: RoleUpdate) -> dict[str, str]:
    username = clean_username(payload.username)
    role = normalize_role(payload.role)
    user = single_user(username)
    if not user:
        raise HTTPException(status_code=404, detail="User nicht gefunden")
    roles = load_user_roles()
    roles[username] = role
    save_user_roles(roles)
    try:
        supabase().patch(f"users?username=eq.{quote(username)}", {"role": role})
    except HTTPException:
        pass
    return {"message": "Rolle aktualisiert."}


@app.post("/api/admin/registration/{request_id}/approve", dependencies=[Depends(require_admin)])
def approve_registration(request_id: str) -> dict[str, str]:
    code = "".join(secrets.choice("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") for _ in range(8))
    supabase().patch(
        f"registration_requests?id=eq.{quote(request_id)}",
        {
            "status": "approved",
            "approval_code_hash": hash_password(code),
            "approved_at": datetime.now().isoformat(),
        },
    )
    return {"code": code}


@app.post("/api/admin/news", dependencies=[Depends(require_admin)])
def admin_create_news(payload: NewsCreate) -> dict[str, str]:
    supabase().post(
        "news_posts",
        {
            "title": payload.title.strip(),
            "body": payload.body.strip(),
            "image_url": payload.image_url.strip(),
            "active": True,
            "published_at": datetime.now().isoformat(),
        },
        returning=False,
    )
    return {"message": "News erstellt."}


@app.delete("/api/admin/news/{post_id}", dependencies=[Depends(require_admin)])
def admin_delete_news(post_id: str) -> dict[str, str]:
    supabase().delete(f"news_posts?id=eq.{quote(post_id)}")
    return {"message": "News geloescht."}


@app.post("/api/admin/shop", dependencies=[Depends(require_admin)])
def admin_create_shop_item(payload: ShopItemCreate) -> dict[str, str]:
    supabase().post(
        "shop_items",
        {
            "name": payload.name.strip(),
            "description": payload.description.strip(),
            "price": max(0, int(payload.price)),
            "category": payload.category.strip() or "Rewards",
            "active": True,
        },
        returning=False,
    )
    return {"message": "Shop-Item erstellt."}


@app.delete("/api/admin/shop/{item_id}", dependencies=[Depends(require_admin)])
def admin_delete_shop_item(item_id: str) -> dict[str, str]:
    supabase().patch(f"shop_items?id=eq.{quote(item_id)}", {"active": False})
    return {"message": "Shop-Item deaktiviert."}


@app.post("/api/admin/events", dependencies=[Depends(require_admin)])
def admin_create_event(payload: EventCreate) -> dict[str, str]:
    supabase().post(
        "events",
        {
            "title": payload.title.strip(),
            "description": payload.description.strip(),
            "event_date": payload.event_date.strip(),
        },
        returning=False,
    )
    return {"message": "Event erstellt."}


@app.delete("/api/admin/events/{event_id}", dependencies=[Depends(require_admin)])
def admin_delete_event(event_id: str) -> dict[str, str]:
    supabase().delete(f"event_signups?event_id=eq.{quote(event_id)}")
    supabase().delete(f"events?id=eq.{quote(event_id)}")
    return {"message": "Event geloescht."}


@app.delete("/api/admin/wishes/{wish_id}", dependencies=[Depends(require_admin)])
def admin_delete_wish(wish_id: str) -> dict[str, str]:
    supabase().patch(f"wish_posts?id=eq.{quote(wish_id)}", {"active": False})
    return {"message": "Wunsch entfernt."}


@app.patch("/api/admin/support/{message_id}", dependencies=[Depends(require_admin)])
def admin_close_support(message_id: str) -> dict[str, str]:
    supabase().patch(f"support_messages?id=eq.{quote(message_id)}", {"status": "closed"})
    return {"message": "Meldung geschlossen."}
