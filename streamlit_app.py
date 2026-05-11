import streamlit as st
import pandas as pd
import sqlite3
from datetime import datetime

st.set_page_config(
    page_title="Gehirnzone",
    page_icon="🧠",
    layout="wide"
)

DB_NAME = "gehirnzone.db"

# ---------- DATENBANK ----------
def get_db():
    return sqlite3.connect(DB_NAME, check_same_thread=False)

def init_db():
    conn = get_db()
    c = conn.cursor()

    c.execute("""
        CREATE TABLE IF NOT EXISTS users (
            username TEXT PRIMARY KEY,
            chickens INTEGER DEFAULT 0,
            braincells INTEGER DEFAULT 0,
            created_at TEXT
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS purchases (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT,
            reward_name TEXT,
            price INTEGER,
            created_at TEXT
        )
    """)

    conn.commit()
    conn.close()

def get_or_create_user(username):
    username = username.strip().lower()

    if username == "":
        username = "gast"

    conn = get_db()
    c = conn.cursor()

    c.execute(
        "SELECT username, chickens, braincells FROM users WHERE username = ?",
        (username,)
    )

    user = c.fetchone()

    if user is None:
        c.execute(
            """
            INSERT INTO users
            (username, chickens, braincells, created_at)
            VALUES (?, ?, ?, ?)
            """,
            (username, 0, 0, datetime.now().isoformat())
        )

        conn.commit()
        user = (username, 0, 0)

    conn.close()

    return {
        "username": user[0],
        "chickens": user[1],
        "braincells": user[2],
    }

def add_points(username, chickens=0, braincells=0):
    username = username.strip().lower()

    get_or_create_user(username)

    conn = get_db()
    c = conn.cursor()

    c.execute("""
        UPDATE users
        SET chickens = chickens + ?,
            braincells = braincells + ?
        WHERE username = ?
    """, (chickens, braincells, username))

    conn.commit()
    conn.close()

def spend_braincells(username, reward_name, price):
    username = username.strip().lower()

    user = get_or_create_user(username)

    if user["braincells"] < price:
        return False

    conn = get_db()
    c = conn.cursor()

    c.execute("""
        UPDATE users
        SET braincells = braincells - ?
        WHERE username = ?
    """, (price, username))

    c.execute("""
        INSERT INTO purchases
        (username, reward_name, price, created_at)
        VALUES (?, ?, ?, ?)
    """, (
        username,
        reward_name,
        price,
        datetime.now().isoformat()
    ))

    conn.commit()
    conn.close()

    return True

def get_leaderboard():
    conn = get_db()

    df = pd.read_sql_query("""
        SELECT
            username AS Viewer,
            chickens AS Chickens,
            braincells AS Gehirnzellen
        FROM users
        ORDER BY braincells DESC
    """, conn)

    conn.close()

    return df

def get_purchases():
    conn = get_db()

    df = pd.read_sql_query("""
        SELECT
            username AS Viewer,
            reward_name AS Reward,
            price AS Preis,
            created_at AS Datum
        FROM purchases
        ORDER BY id DESC
    """, conn)

    conn.close()

    return df

init_db()

# ---------- OBS OVERLAY ----------
params = st.query_params
overlay_mode = params.get("overlay", "0") == "1"

if overlay_mode:

    top = get_leaderboard()

    st.markdown("""
    <style>
    .stApp {
        background: transparent !important;
    }

    [data-testid="stHeader"],
    [data-testid="stToolbar"],
    footer {
        display: none !important;
    }

    .block-container {
        padding: 2rem;
        max-width: 100%;
    }

    .top-box {
        text-align: center;
        background: rgba(20, 0, 35, 0.88);
        border: 4px solid #c77dff;
        border-radius: 35px;
        padding: 35px;
        box-shadow: 0 0 60px #9d4edd;
        color: white;
        margin-top: 80px;
    }

    .top-title {
        font-size: 48px;
        font-weight: 900;
        color: #ffcc00;
        text-shadow: 0 0 25px #ffcc00;
    }

    .top-user {
        font-size: 58px;
        font-weight: 900;
        color: #c77dff;
        margin-top: 10px;
    }

    .top-points {
        font-size: 34px;
        margin-top: 15px;
    }
    </style>
    """, unsafe_allow_html=True)

    if not top.empty:

        username = top.iloc[0]["Viewer"]
        braincells = int(top.iloc[0]["Gehirnzellen"])
        chickens = int(top.iloc[0]["Chickens"])

        st.markdown(f"""
        <div class="top-box">
            <div class="top-title">
                🏆 TOP GEHIRNZELLE
            </div>

            <div class="top-user">
                {username}
            </div>

            <div class="top-points">
                🧠 {braincells} Gehirnzellen<br>
                🥚 {chickens} Chickens
            </div>
        </div>
        """, unsafe_allow_html=True)

    st.stop()

# ---------- DESIGN ----------
st.markdown("""
<style>

.stApp {
    background: radial-gradient(circle at top, #251033 0%, #0d0b12 45%, #07070a 100%);
    color: white;
}

[data-testid="stHeader"] {
    background: transparent;
}

.block-container {
    padding-top: 2rem;
    max-width: 1200px;
}

h1 {
    text-align: center;
    font-size: 72px !important;
    color: #b05cff;
    text-shadow: 0 0 30px #9d4edd;
    margin-bottom: 0;
}

.subtitle {
    text-align: center;
    color: #aaa0b8;
    font-size: 20px;
    margin-bottom: 40px;
}

.metric-card {
    text-align: center;
    background: rgba(255,255,255,0.045);
    border: 1px solid rgba(255,255,255,0.08);
    border-radius: 18px;
    padding: 24px;
}

.metric-number {
    font-size: 32px;
    font-weight: 900;
    color: white;
}

.metric-label {
    color: #9d92aa;
    font-size: 14px;
}

.gold-card {
    background: linear-gradient(
        135deg,
        rgba(255,193,7,0.18),
        rgba(255,193,7,0.04)
    );

    border: 1px solid rgba(255,193,7,0.35);
    border-radius: 22px;
    padding: 28px;
}

.purple-card {
    background: linear-gradient(
        135deg,
        rgba(157,78,221,0.25),
        rgba(157,78,221,0.05)
    );

    border: 1px solid rgba(157,78,221,0.45);
    border-radius: 22px;
    padding: 28px;
    box-shadow: 0 0 25px rgba(157,78,221,0.25);
}

.reward {
    background: rgba(255,255,255,0.055);
    border: 1px solid rgba(255,255,255,0.11);
    border-radius: 18px;
    padding: 20px;
    margin-bottom: 14px;
}

.stButton > button {
    background: linear-gradient(135deg, #9d4edd, #c77dff);
    color: black;
    border: none;
    border-radius: 14px;
    padding: 0.7rem 1.1rem;
    font-weight: 800;
}

</style>
""", unsafe_allow_html=True)

# ---------- REWARDS ----------
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

# ---------- HEADER ----------
st.markdown("<h1>Gehirnzone</h1>", unsafe_allow_html=True)

st.markdown("""
<div class='subtitle'>
Deine chaotische digitale Heimat 🧠🐔
</div>
""", unsafe_allow_html=True)

# ---------- METRICS ----------
leaderboard = get_leaderboard()

total_users = len(leaderboard)

total_chickens = (
    int(leaderboard["Chickens"].sum())
    if not leaderboard.empty else 0
)

total_braincells = (
    int(leaderboard["Gehirnzellen"].sum())
    if not leaderboard.empty else 0
)

c1, c2, c3 = st.columns(3)

with c1:
    st.markdown(f"""
    <div class='metric-card'>
        👥
        <div class='metric-number'>{total_users}</div>
        <div class='metric-label'>Community</div>
    </div>
    """, unsafe_allow_html=True)

with c2:
    st.markdown(f"""
    <div class='metric-card'>
        🧠
        <div class='metric-number'>{total_braincells}</div>
        <div class='metric-label'>Gehirnzellen</div>
    </div>
    """, unsafe_allow_html=True)

with c3:
    st.markdown(f"""
    <div class='metric-card'>
        🥚
        <div class='metric-number'>{total_chickens}</div>
        <div class='metric-label'>Chickens</div>
    </div>
    """, unsafe_allow_html=True)

# ---------- KONTO ----------
st.write("")
st.markdown("## 💰 Dein Konto")

username = st.text_input(
    "Dein Twitch-Name",
    value="einsmarello"
)

user = get_or_create_user(username)

a, b = st.columns(2)

with a:
    st.markdown(f"""
    <div class="gold-card">
        <h3>🥚 CHICKENS</h3>
        <h2>{user["chickens"]}</h2>
    </div>
    """, unsafe_allow_html=True)

with b:
    st.markdown(f"""
    <div class="purple-card">
        <h3>🧠 GEHIRNZELLEN</h3>
        <h2>{user["braincells"]}</h2>
    </div>
    """, unsafe_allow_html=True)

# ---------- SHOP ----------
st.write("")
st.markdown("## 🛒 Shop")

for reward in rewards:

    col1, col2 = st.columns([3, 1])

    with col1:
        st.markdown(f"""
        <div class="reward">
            <h3>{reward["name"]}</h3>
            <p>{reward["desc"]}</p>
            <b>{reward["price"]} Gehirnzellen</b>
        </div>
        """, unsafe_allow_html=True)

    with col2:

        if st.button("Kaufen", key=reward["name"]):

            success = spend_braincells(
                username,
                reward["name"],
                reward["price"]
            )

            if success:
                st.success("Reward eingelöst!")
                st.rerun()

            else:
                st.error("Nicht genug Gehirnzellen!")

# ---------- RANGLISTE ----------
st.write("")
st.markdown("## 🏆 Rangliste")

st.dataframe(
    get_leaderboard(),
    use_container_width=True,
    hide_index=True
)

# ---------- ADMIN ----------
st.write("")
st.markdown("## 🔐 Admin")

with st.expander("Admin öffnen"):

    admin_password = st.text_input(
        "Passwort",
        type="password"
    )

    if admin_password == "einsmarello":

        admin_user = st.text_input("Viewer")

        brain_amount = st.number_input(
            "Gehirnzellen",
            min_value=0,
            step=10
        )

        chicken_amount = st.number_input(
            "Chickens",
            min_value=0,
            step=10
        )

        if st.button("Punkte speichern"):

            add_points(
                admin_user,
                chickens=chicken_amount,
                braincells=brain_amount
            )

            st.success("Punkte gespeichert!")
            st.rerun()

        st.markdown("### Letzte Käufe")

        st.dataframe(
            get_purchases(),
            use_container_width=True,
            hide_index=True
        )

    elif admin_password:
        st.error("Falsches Passwort.")
