import streamlit as st
import pandas as pd
import requests
from datetime import datetime

st.set_page_config(
    page_title="Gehirnzone",
    page_icon="🧠",
    layout="wide"
)

# =========================
# SUPABASE
# =========================

SUPABASE_URL = "https://pmgwiyypxiefsowrsbhd.supabase.co"
SUPABASE_KEY = "sb_publishable_GQbbRfKETHdjbCJGxCCyIA_nldlMHpJ"

HEADERS = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json"
}

# =========================
# SUPABASE HELPERS
# =========================

def api_get(path):
    url = f"{SUPABASE_URL}/rest/v1/{path}"
    r = requests.get(url, headers=HEADERS)
    if r.status_code >= 400:
        st.error(r.text)
        return []
    return r.json()

def api_post(table, payload):
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    r = requests.post(
        url,
        headers={**HEADERS, "Prefer": "return=representation"},
        json=payload
    )
    if r.status_code >= 400:
        st.error(r.text)
        return None
    return r.json()

def api_patch(path, payload):
    url = f"{SUPABASE_URL}/rest/v1/{path}"
    r = requests.patch(url, headers=HEADERS, json=payload)
    if r.status_code >= 400:
        st.error(r.text)
        return False
    return True

def api_delete(path):
    url = f"{SUPABASE_URL}/rest/v1/{path}"
    r = requests.delete(url, headers=HEADERS)
    if r.status_code >= 400:
        st.error(r.text)
        return False
    return True

# =========================
# USER
# =========================

def get_users():
    return api_get("users?select=*&order=braincells.desc")

def get_user(username):
    username = username.lower().strip()
    data = api_get(f"users?username=eq.{username}")
    return data[0] if data else None

def create_user(username):
    username = username.lower().strip()
    return api_post("users", {
        "username": username,
        "chickens": 0,
        "braincells": 0,
        "created_at": datetime.now().isoformat()
    })

def get_or_create_user(username):
    username = username.lower().strip()
    if username == "":
        username = "gast"

    user = get_user(username)

    if user is None:
        created = create_user(username)
        user = created[0] if created else None

    return user

def update_user(username, chickens, braincells):
    username = username.lower().strip()
    return api_patch(
        f"users?username=eq.{username}",
        {
            "chickens": chickens,
            "braincells": braincells
        }
    )

def add_points(username, chickens=0, braincells=0):
    user = get_or_create_user(username)

    if user is None:
        return

    new_chickens = int(user["chickens"]) + chickens
    new_braincells = int(user["braincells"]) + braincells

    update_user(username, new_chickens, new_braincells)

def get_leaderboard():
    users = get_users()

    if not users:
        return pd.DataFrame(columns=["Viewer", "Chickens", "Gehirnzellen"])

    df = pd.DataFrame(users)

    df = df.rename(columns={
        "username": "Viewer",
        "chickens": "Chickens",
        "braincells": "Gehirnzellen"
    })

    return df[["Viewer", "Chickens", "Gehirnzellen"]]

# =========================
# EVENTS
# =========================

def get_events():
    return api_get("events?select=*&order=id.desc")

def create_event(title, description, event_date):
    return api_post("events", {
        "title": title,
        "description": description,
        "event_date": event_date,
        "created_at": datetime.now().isoformat()
    })

def get_event_signups(event_id):
    return api_get(
        f"event_signups?event_id=eq.{event_id}&select=*&order=id.asc"
    )

def is_signed_up(event_id, username):
    username = username.lower().strip()
    data = api_get(
        f"event_signups?event_id=eq.{event_id}&username=eq.{username}"
    )
    return len(data) > 0

def signup_event(event_id, username):
    username = username.lower().strip()

    if username == "":
        return False

    if is_signed_up(event_id, username):
        return False

    api_post("event_signups", {
        "event_id": event_id,
        "username": username,
        "created_at": datetime.now().isoformat()
    })

    get_or_create_user(username)
    return True

def leave_event(event_id, username):
    username = username.lower().strip()

    return api_delete(
        f"event_signups?event_id=eq.{event_id}&username=eq.{username}"
    )

# =========================
# SHOP / REWARDS
# =========================

rewards = [
    {
        "name": "⭐ 1 Woche VIP",
        "price": 10000,
        "desc": "Erhalte für 1 Woche VIP auf dem Twitch-Kanal"
    },
    {
        "name": "🎮 Steam Random Key",
        "price": 50000,
        "desc": "Bekomme einen zufälligen Steam Key"
    },
    {
        "name": "💬 Discord Frage",
        "price": 5000,
        "desc": "Komm in den Discord und stell mir eine Frage"
    },
    {
        "name": "🖼️ Zuschauerbild neben Facecam",
        "price": 2500,
        "desc": "Der Streamer nutzt für 1 Tag dein gemaltes Bild neben der Facecam"
    },
]

# =========================
# DESIGN
# =========================

st.markdown("""
<style>
.stApp {
    background: radial-gradient(circle at top, #251033 0%, #0d0b12 45%, #07070a 100%);
    color: white;
}

.block-container {
    max-width: 1250px;
    padding-top: 2rem;
}

h1 {
    text-align: center;
    font-size: 64px !important;
    color: #c77dff;
    text-shadow: 0 0 30px rgba(199,125,255,0.55);
}

.topbar {
    background: rgba(20,20,30,0.75);
    border-radius: 20px;
    padding: 18px;
    margin-bottom: 25px;
    border: 1px solid rgba(255,255,255,0.08);
}

.card,
.metric-card,
.reward-card,
.event-card {
    background: rgba(255,255,255,0.045);
    border: 1px solid rgba(255,255,255,0.09);
    border-radius: 20px;
    padding: 24px;
    transition: all 0.25s ease;
}

.card:hover,
.metric-card:hover,
.reward-card:hover,
.event-card:hover {
    transform: translateY(-5px);
    box-shadow: 0 0 30px rgba(199,125,255,0.35);
    border-color: #c77dff;
}

.metric-card {
    text-align: center;
}

.metric-number {
    font-size: 36px;
    font-weight: 900;
}

.metric-label {
    color: #aaa;
}

.stButton > button {
    background: linear-gradient(135deg, #9d4edd, #c77dff);
    border: none;
    border-radius: 14px;
    color: black;
    font-weight: 900;
    padding: 0.6rem 1rem;
}

.stButton > button:hover {
    transform: translateY(-2px);
    box-shadow: 0 0 25px rgba(199,125,255,0.6);
}

.stRadio > div {
    justify-content: center;
    background: rgba(255,255,255,0.04);
    border: 1px solid rgba(157,78,221,0.25);
    border-radius: 18px;
    padding: 10px;
}

.small {
    color: #aaa;
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

st.markdown(f"""
<div class="topbar">
    <div style="display:flex; justify-content:space-between; align-items:center; gap:20px; flex-wrap:wrap;">
        <h2 style="margin:0;">🧠 Gehirnzone</h2>
        <div style="color:#aaa;">
            🥚 {total_chickens} &nbsp;&nbsp; | &nbsp;&nbsp; 🧠 {total_braincells}
        </div>
    </div>
</div>
""", unsafe_allow_html=True)

menu = st.radio(
    "",
    [
        "🏠 Home",
        "🛒 Shop",
        "🏆 Rangliste",
        "⚡ Events",
        "🔐 Admin"
    ],
    horizontal=True,
    label_visibility="collapsed"
)

st.markdown("<h1>Gehirnzone</h1>", unsafe_allow_html=True)

# =========================
# HOME
# =========================

if menu == "🏠 Home":
    st.subheader("🏠 Hauptmenü")

    c1, c2, c3 = st.columns(3)

    with c1:
        st.markdown(f"""
        <div class="metric-card">
            <div class="metric-number">{total_users}</div>
            <div class="metric-label">Viewer</div>
        </div>
        """, unsafe_allow_html=True)

    with c2:
        st.markdown(f"""
        <div class="metric-card">
            <div class="metric-number">{total_chickens}</div>
            <div class="metric-label">Chickens</div>
        </div>
        """, unsafe_allow_html=True)

    with c3:
        st.markdown(f"""
        <div class="metric-card">
            <div class="metric-number">{total_braincells}</div>
            <div class="metric-label">Gehirnzellen</div>
        </div>
        """, unsafe_allow_html=True)

    st.write("")

    left, right = st.columns(2)

    with left:
        st.markdown(f"""
        <div class="card">
            <h3>⏰ Aktuelle Uhrzeit</h3>
            <h2>{datetime.now().strftime("%H:%M:%S")}</h2>
            <p class="small">Lokale Uhrzeit deiner App.</p>
        </div>
        """, unsafe_allow_html=True)

    with right:
        st.markdown("""
        <div class="card">
            <h3>💜 Twitch Profil</h3>
            <p>Besuche den Twitch-Kanal von einsmarello.</p>
            <a href="https://www.twitch.tv/einsmarello" target="_blank" style="color:#c77dff;">
                twitch.tv/einsmarello
            </a>
        </div>
        """, unsafe_allow_html=True)

# =========================
# SHOP
# =========================

elif menu == "🛒 Shop":
    st.subheader("💰 Dein Konto")

    username = st.text_input("Dein Twitch-Name", value="einsmarello")
    user = get_or_create_user(username)

    if user:
        c1, c2 = st.columns(2)

        with c1:
            st.markdown(f"""
            <div class="metric-card">
                <h3>🥚 Chickens</h3>
                <div class="metric-number">{user["chickens"]}</div>
            </div>
            """, unsafe_allow_html=True)

        with c2:
            st.markdown(f"""
            <div class="metric-card">
                <h3>🧠 Gehirnzellen</h3>
                <div class="metric-number">{user["braincells"]}</div>
            </div>
            """, unsafe_allow_html=True)

    st.write("")
    st.subheader("🛒 Shop")

    for reward in rewards:
        col1, col2 = st.columns([4, 1])

        with col1:
            st.markdown(f"""
            <div class="reward-card">
                <h3>{reward["name"]}</h3>
                <p>{reward["desc"]}</p>
                <b>Preis: {reward["price"]} Gehirnzellen</b>
            </div>
            """, unsafe_allow_html=True)

        with col2:
            st.write("")
            st.button("Kaufen", key=f"buy_{reward['name']}")

# =========================
# RANGLISTE
# =========================

elif menu == "🏆 Rangliste":
    st.subheader("🏆 Rangliste")

    if leaderboard.empty:
        st.info("Noch keine Daten vorhanden.")
    else:
        st.dataframe(
            leaderboard,
            use_container_width=True,
            hide_index=True
        )

# =========================
# EVENTS
# =========================

elif menu == "⚡ Events":
    st.subheader("⚡ Events")

    viewer_name = st.text_input(
        "Dein Twitch-Name für Event-Anmeldung",
        value="einsmarello"
    )

    events = get_events()

    if not events:
        st.info("Aktuell gibt es keine Events.")
    else:
        for event in events:
            event_id = event["id"]
            title = event.get("title", "Ohne Titel")
            description = event.get("description", "")
            event_date = event.get("event_date", "")

            signups = get_event_signups(event_id)
            signed_up = is_signed_up(event_id, viewer_name)

            st.markdown(f"""
            <div class="event-card">
                <h2>⚡ {title}</h2>
                <p>{description}</p>
                <p><b>Datum:</b> {event_date}</p>
                <p><b>Teilnehmer:</b> {len(signups)}</p>
            </div>
            """, unsafe_allow_html=True)

            col1, col2 = st.columns([1, 4])

            with col1:
                if not signed_up:
                    if st.button("Anmelden", key=f"join_{event_id}"):
                        signup_event(event_id, viewer_name)
                        st.success("Du bist angemeldet!")
                        st.rerun()
                else:
                    if st.button("Abmelden", key=f"leave_{event_id}"):
                        leave_event(event_id, viewer_name)
                        st.warning("Du bist abgemeldet.")
                        st.rerun()

            with col2:
                if signups:
                    names = ", ".join([s["username"] for s in signups])
                    st.caption(f"Angemeldet: {names}")
                else:
                    st.caption("Noch niemand angemeldet.")

            st.write("---")

# =========================
# ADMIN
# =========================

elif menu == "🔐 Admin":
    st.subheader("🔐 Admin")

    password = st.text_input("Admin Passwort", type="password")

    if password == "einsmarello":

        st.markdown("### Punkte vergeben")

        admin_user = st.text_input("Viewer Name")

        braincells = st.number_input(
            "Gehirnzellen",
            min_value=0,
            step=10
        )

        chickens = st.number_input(
            "Chickens",
            min_value=0,
            step=1
        )

        if st.button("Punkte speichern"):
            add_points(
                admin_user,
                chickens=chickens,
                braincells=braincells
            )
            st.success("Punkte gespeichert!")
            st.rerun()

        st.write("---")

        st.markdown("### Neues Event erstellen")

        event_title = st.text_input("Event-Titel")
        event_description = st.text_area("Event-Beschreibung")
        event_date = st.text_input("Event-Datum / Uhrzeit", placeholder="z. B. Samstag 20:00 Uhr")

        if st.button("Event erstellen"):
            if event_title.strip():
                create_event(
                    event_title,
                    event_description,
                    event_date
                )
                st.success("Event wurde erstellt!")
                st.rerun()
            else:
                st.error("Bitte Event-Titel eingeben.")

    elif password:
        st.error("Falsches Passwort.")
