import streamlit as st
import pandas as pd
import requests
from datetime import datetime
import streamlit.components.v1 as components

# =========================
# APP
# =========================

st.set_page_config(
    page_title="Gehirnzone",
    page_icon="🧠",
    layout="wide"
)

# =========================
# SUPABASE
# =========================

SUPABASE_URL = "https://pmgwiyypxiefsowrsbhd.supabase.co"
SUPABASE_KEY = "DEIN_PUBLISHABLE_KEY"

HEADERS = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json"
}

# =========================
# API
# =========================

def api_get(path):

    response = requests.get(
        f"{SUPABASE_URL}/rest/v1/{path}",
        headers=HEADERS
    )

    if response.status_code >= 400:
        st.error(response.text)
        return []

    return response.json()

def api_post(table, payload):

    response = requests.post(
        f"{SUPABASE_URL}/rest/v1/{table}",
        headers={
            **HEADERS,
            "Prefer": "return=representation"
        },
        json=payload
    )

    if response.status_code >= 400:
        st.error(response.text)
        return None

    return response.json()

def api_patch(path, payload):

    response = requests.patch(
        f"{SUPABASE_URL}/rest/v1/{path}",
        headers=HEADERS,
        json=payload
    )

    if response.status_code >= 400:
        st.error(response.text)
        return False

    return True

def api_delete(path):

    response = requests.delete(
        f"{SUPABASE_URL}/rest/v1/{path}",
        headers=HEADERS
    )

    if response.status_code >= 400:
        st.error(response.text)
        return False

    return True

# =========================
# USER
# =========================

def get_user(username):

    username = username.lower().strip()

    data = api_get(
        f"users?username=eq.{username}"
    )

    return data[0] if data else None

def create_user(username):

    username = username.lower().strip()

    created = api_post(
        "users",
        {
            "username": username,
            "chickens": 0,
            "braincells": 0,
            "created_at": datetime.now().isoformat()
        }
    )

    return created[0] if created else None

def get_or_create_user(username):

    username = username.lower().strip()

    if username == "":
        username = "gast"

    user = get_user(username)

    if user is None:
        user = create_user(username)

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

def delete_user(username):

    username = username.lower().strip()

    api_delete(
        f"event_signups?username=eq.{username}"
    )

    api_delete(
        f"purchases?username=eq.{username}"
    )

    return api_delete(
        f"users?username=eq.{username}"
    )

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

    new_chickens = max(
        0,
        int(user["chickens"]) - chickens
    )

    new_braincells = max(
        0,
        int(user["braincells"]) - braincells
    )

    update_user(
        username,
        new_chickens,
        new_braincells
    )

def get_leaderboard():

    users = api_get(
        "users?select=*&order=braincells.desc"
    )

    if not users:
        return pd.DataFrame(
            columns=[
                "Viewer",
                "Chickens",
                "Gehirnzellen"
            ]
        )

    df = pd.DataFrame(users)

    df = df.rename(columns={
        "username": "Viewer",
        "chickens": "Chickens",
        "braincells": "Gehirnzellen"
    })

    return df[[
        "Viewer",
        "Chickens",
        "Gehirnzellen"
    ]]

# =========================
# RANKS
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

    return (
        rank_name,
        progress,
        f"{missing} Gehirnzellen bis zum nächsten Rang"
    )

# =========================
# EVENTS
# =========================

def get_events():

    return api_get(
        "events?select=*&order=id.desc"
    )

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

    api_delete(
        f"event_signups?event_id=eq.{event_id}"
    )

    return api_delete(
        f"events?id=eq.{event_id}"
    )

def get_event_signups(event_id):

    return api_get(
        f"event_signups?event_id=eq.{event_id}&select=*"
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

    username = username.lower().strip()

    return api_delete(
        f"event_signups?event_id=eq.{event_id}&username=eq.{username}"
    )

# =========================
# SHOP
# =========================

rewards = [
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

def buy_reward(username, reward):

    user = get_or_create_user(username)

    if user is None:
        return False

    current = int(user["braincells"])

    if current < reward["price"]:
        return False

    update_user(
        username,
        int(user["chickens"]),
        current - reward["price"]
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

    return True

# =========================
# DESIGN
# =========================

st.markdown("""
<style>

.stApp {
    background:
    radial-gradient(circle at 20% 20%, rgba(157,78,221,0.25), transparent 25%),
    radial-gradient(circle at 80% 30%, rgba(0,245,255,0.18), transparent 30%),
    radial-gradient(circle at 50% 80%, rgba(199,125,255,0.18), transparent 35%),
    linear-gradient(180deg, #09090f 0%, #0f0816 100%);
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
    max-width: 1250px;
    padding-top: 2rem;
}

h1 {
    text-align: center;
    font-size: 64px !important;
    color: #c77dff;
    text-shadow: 0 0 35px rgba(199,125,255,0.7);
}

.topbar {
    background: rgba(20,20,30,0.75);
    border-radius: 20px;
    padding: 18px;
    margin-bottom: 25px;
    border: 1px solid rgba(255,255,255,0.08);
    backdrop-filter: blur(10px);
}

.card,
.metric-card,
.reward-card,
.event-card,
.profile-card {
    background: rgba(255,255,255,0.045);
    border: 1px solid rgba(255,255,255,0.09);
    border-radius: 20px;
    padding: 24px;
    transition: all 0.25s ease;
    backdrop-filter: blur(8px);
}

.card:hover,
.metric-card:hover,
.reward-card:hover,
.event-card:hover,
.profile-card:hover {
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

st.markdown(f"""
<div class="topbar">
<div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap;">
<h2>🧠 Gehirnzone</h2>
<div>
🥚 {total_chickens} &nbsp;&nbsp; 🧠 {total_braincells}
</div>
</div>
</div>
""", unsafe_allow_html=True)

menu = st.radio(
    "",
    [
        "🏠 Home",
        "👤 Profil",
        "🛒 Shop",
        "🏆 Rangliste",
        "⚡ Events",
        "🎮 Minispiele",
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

# =========================
# PROFIL
# =========================

elif menu == "👤 Profil":

    profile_name = st.text_input(
        "Twitch-Name",
        value="einsmarello"
    )

    user = get_or_create_user(profile_name)

    if user:

        braincells = int(user["braincells"])
        chickens = int(user["chickens"])

        rank_name, progress, progress_text = get_progress(braincells)

        st.markdown(f"""
        <div class="profile-card">
            <h2>{user["username"]}</h2>
            <h3>{rank_name}</h3>

            <p>
            🧠 {braincells} Gehirnzellen<br>
            🥚 {chickens} Chickens
            </p>

            <div class="progress-bg">
                <div class="progress-fill" style="width:{progress}%"></div>
            </div>

            <p>{progress}% · {progress_text}</p>
        </div>
        """, unsafe_allow_html=True)

# =========================
# SHOP
# =========================

elif menu == "🛒 Shop":

    username = st.text_input(
        "Dein Twitch-Name",
        value="einsmarello"
    )

    user = get_or_create_user(username)

    if user:

        st.markdown(f"""
        <div class="card">
            <h2>🧠 {user["braincells"]}</h2>
            <p>Gehirnzellen</p>
        </div>
        """, unsafe_allow_html=True)

    st.write("")

    for reward in rewards:

        col1, col2 = st.columns([4,1])

        with col1:
            st.markdown(f"""
            <div class="reward-card">
                <h3>{reward["name"]}</h3>
                <p>{reward["desc"]}</p>
                <b>{reward["price"]} Gehirnzellen</b>
            </div>
            """, unsafe_allow_html=True)

        with col2:
            st.write("")

            if st.button(
                "Kaufen",
                key=reward["name"]
            ):

                success = buy_reward(
                    username,
                    reward
                )

                if success:
                    st.success("Gekauft!")
                    st.rerun()
                else:
                    st.error("Nicht genug Gehirnzellen")

# =========================
# LEADERBOARD
# =========================

elif menu == "🏆 Rangliste":

    if leaderboard.empty:

        st.info("Keine Daten vorhanden.")

    else:

        ranked = leaderboard.copy()

        ranked["Rang"] = ranked[
            "Gehirnzellen"
        ].apply(
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

    viewer_name = st.text_input(
        "Dein Twitch-Name",
        value="einsmarello"
    )

    events = get_events()

    if not events:

        st.info("Keine Events vorhanden.")

    else:

        for event in events:

            event_id = event["id"]

            signups = get_event_signups(event_id)

            signed_up = is_signed_up(
                event_id,
                viewer_name
            )

            st.markdown(f"""
            <div class="event-card">
                <h2>{event["title"]}</h2>
                <p>{event["description"]}</p>
                <p><b>{event["event_date"]}</b></p>
                <p>Teilnehmer: {len(signups)}</p>
            </div>
            """, unsafe_allow_html=True)

            col1, col2 = st.columns([1,4])

            with col1:

                if not signed_up:

                    if st.button(
                        "Anmelden",
                        key=f"join_{event_id}"
                    ):

                        signup_event(
                            event_id,
                            viewer_name
                        )

                        st.success("Angemeldet")
                        st.rerun()

                else:

                    if st.button(
                        "Abmelden",
                        key=f"leave_{event_id}"
                    ):

                        leave_event(
                            event_id,
                            viewer_name
                        )

                        st.warning("Abgemeldet")
                        st.rerun()

            with col2:

                if signups:
                    names = ", ".join(
                        [
                            s["username"]
                            for s in signups
                        ]
                    )

                    st.caption(
                        f"Angemeldet: {names}"
                    )

            st.write("---")

# =========================
# FLAPPY CHICKEN
# =========================

elif menu == "🎮 Minispiele":

    st.subheader("🐔 Flappy Chicken")

    components.html("""
    <html>
    <body style="margin:0; overflow:hidden; background:#0f0816;">
    <canvas id="game" width="800" height="500"></canvas>

    <script>
    const canvas = document.getElementById("game");
    const ctx = canvas.getContext("2d");

    let birdY = 250;
    let velocity = 0;
    let gravity = 0.5;
    let score = 0;

    const pipes = [];

    function jump() {
        velocity = -8;
    }

    document.addEventListener("keydown", jump);
    document.addEventListener("click", jump);

    function spawnPipe() {
        const top = Math.random() * 250 + 50;

        pipes.push({
            x: 800,
            top: top
        });
    }

    setInterval(spawnPipe, 1800);

    function gameLoop() {

        ctx.fillStyle = "#0f0816";
        ctx.fillRect(0,0,800,500);

        velocity += gravity;
        birdY += velocity;

        ctx.fillStyle = "yellow";
        ctx.beginPath();
        ctx.arc(120, birdY, 20, 0, Math.PI*2);
        ctx.fill();

        ctx.fillStyle = "#9d4edd";

        pipes.forEach(pipe => {

            pipe.x -= 3;

            ctx.fillRect(pipe.x, 0, 70, pipe.top);

            ctx.fillRect(
                pipe.x,
                pipe.top + 140,
                70,
                500
            );

            if (
                120 + 20 > pipe.x &&
                120 - 20 < pipe.x + 70 &&
                (
                    birdY - 20 < pipe.top ||
                    birdY + 20 > pipe.top + 140
                )
            ) {

                alert("Game Over! Score: " + score);
                location.reload();
            }

            if (pipe.x === 117) {
                score++;
            }
        });

        if (birdY > 500 || birdY < 0) {
            alert("Game Over! Score: " + score);
            location.reload();
        }

        ctx.fillStyle = "white";
        ctx.font = "30px Arial";
        ctx.fillText("Score: " + score, 20, 40);

        requestAnimationFrame(gameLoop);
    }

    gameLoop();

    </script>
    </body>
    </html>
    """, height=520)

# =========================
# ADMIN
# =========================

elif menu == "🔐 Admin":

    password = st.text_input(
        "Admin Passwort",
        type="password"
    )

    if password == "einsmarello":

        st.subheader("Punkte verwalten")

        admin_user = st.text_input(
            "Viewer Name"
        )

        add_brain = st.number_input(
            "Gehirnzellen hinzufügen",
            min_value=0,
            step=10
        )

        remove_brain = st.number_input(
            "Gehirnzellen abziehen",
            min_value=0,
            step=10
        )

        if st.button("Punkte speichern"):

            add_points(
                admin_user,
                braincells=add_brain
            )

            remove_points(
                admin_user,
                braincells=remove_brain
            )

            st.success("Gespeichert")
            st.rerun()

        st.write("---")

        st.subheader("Event erstellen")

        event_title = st.text_input(
            "Event Titel"
        )

        event_description = st.text_area(
            "Beschreibung"
        )

        event_date = st.text_input(
            "Datum"
        )

        if st.button("Event erstellen"):

            create_event(
                event_title,
                event_description,
                event_date
            )

            st.success("Event erstellt")
            st.rerun()

        st.write("---")

        st.subheader("Events löschen")

        events = get_events()

        for event in events:

            col1, col2 = st.columns([4,1])

            with col1:
                st.markdown(f"""
                <div class="event-card">
                    <h3>{event["title"]}</h3>
                    <p>{event["description"]}</p>
                </div>
                """, unsafe_allow_html=True)

            with col2:

                if st.button(
                    "Löschen",
                    key=f"delete_{event['id']}"
                ):

                    delete_event(event["id"])

                    st.success("Event gelöscht")
                    st.rerun()

        st.write("---")

        st.subheader("User löschen")

        delete_username = st.text_input(
            "User zum Löschen"
        )

        if st.button("User löschen"):

            delete_user(delete_username)

            st.success("User gelöscht")
            st.rerun()

    elif password:

        st.error("Falsches Passwort")
