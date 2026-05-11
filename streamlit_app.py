import streamlit as st
import pandas as pd

st.set_page_config(
    page_title="Gehirnzone",
    page_icon="🧠",
    layout="wide"
)

# ---------- STYLE ----------
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

.nav {
    display: flex;
    justify-content: center;
    gap: 14px;
    margin-bottom: 25px;
}

.nav-item {
    padding: 12px 22px;
    border-radius: 14px;
    background: rgba(157, 78, 221, 0.12);
    border: 1px solid rgba(157, 78, 221, 0.35);
    color: #c77dff;
    font-weight: 700;
}

.card {
    background: rgba(255,255,255,0.045);
    border: 1px solid rgba(255,255,255,0.09);
    border-radius: 22px;
    padding: 24px;
    box-shadow: 0 0 25px rgba(157,78,221,0.12);
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
    background: linear-gradient(135deg, rgba(255,193,7,0.18), rgba(255,193,7,0.04));
    border: 1px solid rgba(255,193,7,0.35);
    border-radius: 22px;
    padding: 28px;
}

.purple-card {
    background: linear-gradient(135deg, rgba(157,78,221,0.25), rgba(157,78,221,0.05));
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

.small {
    color: #9d92aa;
    font-size: 14px;
}

.stButton > button {
    background: linear-gradient(135deg, #9d4edd, #c77dff);
    color: black;
    border: none;
    border-radius: 14px;
    padding: 0.7rem 1.1rem;
    font-weight: 800;
}

.stTextInput input, .stNumberInput input, .stSelectbox div {
    background-color: rgba(255,255,255,0.07) !important;
    color: white !important;
}
</style>
""", unsafe_allow_html=True)

# ---------- DATA ----------
if "users" not in st.session_state:
    st.session_state.users = {
        "einsmarello": {"chickens": 999, "braincells": 5000},
        "viewer_anna": {"chickens": 120, "braincells": 450},
        "viewer_max": {"chickens": 80, "braincells": 300},
    }

if "rewards" not in st.session_state:
    st.session_state.rewards = [
        {"name": "Sound Alert", "price": 100, "desc": "Spiele einen Sound im Stream ab"},
        {"name": "Hydrate", "price": 150, "desc": "Einsmarello muss trinken"},
        {"name": "VIP für 1 Stream", "price": 1000, "desc": "VIP Status für einen Stream"},
        {"name": "Meme einreichen", "price": 250, "desc": "Dein Meme kommt in die Meme-Zone"},
    ]

# ---------- HEADER ----------
st.markdown("""
<div class="nav">
    <div class="nav-item">🏠 Home</div>
    <div class="nav-item">🛒 Shop</div>
    <div class="nav-item">🏆 Rangliste</div>
    <div class="nav-item">⚡ Events</div>
    <div class="nav-item">😂 Memes</div>
</div>
""", unsafe_allow_html=True)

st.markdown("<h1>Gehirnzone</h1>", unsafe_allow_html=True)
st.markdown(
    "<div class='subtitle'>Deine chaotische digitale Heimat. Sammle Chickens, verdiene Gehirnzellen und werde Teil der Community 🧠🐔</div>",
    unsafe_allow_html=True
)

# ---------- METRICS ----------
total_users = len(st.session_state.users)
total_chickens = sum(u["chickens"] for u in st.session_state.users.values())
total_braincells = sum(u["braincells"] for u in st.session_state.users.values())

c1, c2, c3, c4 = st.columns(4)
with c1:
    st.markdown(f"<div class='metric-card'>👥<div class='metric-number'>{total_users}</div><div class='metric-label'>Community</div></div>", unsafe_allow_html=True)
with c2:
    st.markdown(f"<div class='metric-card'>🧠<div class='metric-number'>{total_braincells}</div><div class='metric-label'>Gehirnzellen im Umlauf</div></div>", unsafe_allow_html=True)
with c3:
    st.markdown(f"<div class='metric-card'>🥚<div class='metric-number'>{total_chickens}</div><div class='metric-label'>Chickens gesammelt</div></div>", unsafe_allow_html=True)
with c4:
    st.markdown("<div class='metric-card'>📡<div class='metric-number'>0</div><div class='metric-label'>Streams verbunden</div></div>", unsafe_allow_html=True)

st.write("")
st.write("")

# ---------- USER ACCOUNT ----------
st.markdown("## 💰 Dein Konto")

username = st.text_input("Dein Twitch-Name", value="viewer_anna").strip().lower()

if username and username not in st.session_state.users:
    st.session_state.users[username] = {"chickens": 0, "braincells": 0}

user = st.session_state.users.get(username, {"chickens": 0, "braincells": 0})

a, b = st.columns(2)
with a:
    st.markdown(f"""
    <div class="gold-card">
        <h3>🥚 CHICKENS</h3>
        <h2>{user["chickens"]}</h2>
        <p class="small">Sammelwährung durch Zuschauen, Chatten und Events.</p>
    </div>
    """, unsafe_allow_html=True)

with b:
    st.markdown(f"""
    <div class="purple-card">
        <h3>🧠 GEHIRNZELLEN</h3>
        <h2>{user["braincells"]}</h2>
        <p class="small">Community-Währung für den Shop.</p>
    </div>
    """, unsafe_allow_html=True)

# ---------- SHOP ----------
st.write("")
st.markdown("## 🛒 Shop")

for reward in st.session_state.rewards:
    col1, col2 = st.columns([3, 1])
    with col1:
        st.markdown(f"""
        <div class="reward">
            <h3>{reward["name"]}</h3>
            <p class="small">{reward["desc"]}</p>
            <b>Preis: {reward["price"]} Gehirnzellen</b>
        </div>
        """, unsafe_allow_html=True)
    with col2:
        if st.button(f"Kaufen", key=reward["name"]):
            if user["braincells"] >= reward["price"]:
                st.session_state.users[username]["braincells"] -= reward["price"]
                st.success(f"{reward['name']} eingelöst!")
            else:
                st.error("Nicht genug Gehirnzellen.")

# ---------- LEADERBOARD ----------
st.write("")
st.markdown("## 🏆 Rangliste")

df = pd.DataFrame([
    {
        "Viewer": name,
        "Chickens": data["chickens"],
        "Gehirnzellen": data["braincells"]
    }
    for name, data in st.session_state.users.items()
]).sort_values("Gehirnzellen", ascending=False)

st.dataframe(df, use_container_width=True, hide_index=True)

# ---------- ADMIN ----------
st.write("")
st.markdown("## 🔐 Admin-Bereich für einsmarello")

with st.expander("Admin öffnen"):
    admin_user = st.text_input("Viewer auswählen oder neu erstellen")
    amount = st.number_input("Anzahl Gehirnzellen", min_value=0, step=10)

    if st.button("Gehirnzellen hinzufügen"):
        admin_user = admin_user.strip().lower()
        if admin_user:
            if admin_user not in st.session_state.users:
                st.session_state.users[admin_user] = {"chickens": 0, "braincells": 0}
            st.session_state.users[admin_user]["braincells"] += amount
            st.success(f"{amount} Gehirnzellen an {admin_user} gegeben.")

    chicken_amount = st.number_input("Anzahl Chickens", min_value=0, step=10)

    if st.button("Chickens hinzufügen"):
        admin_user = admin_user.strip().lower()
        if admin_user:
            if admin_user not in st.session_state.users:
                st.session_state.users[admin_user] = {"chickens": 0, "braincells": 0}
            st.session_state.users[admin_user]["chickens"] += chicken_amount
            st.success(f"{chicken_amount} Chickens an {admin_user} gegeben.")
