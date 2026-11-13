import React, { useEffect, useMemo, useState } from "react";
import { Mail, MessageCircle, Send, Users } from "lucide-react";
import { api } from "../api";
import { Avatar, EmptyLogin, PanelTitle, RoleBadge } from "./shared";

export function formatChatTime(value) {
  if (!value) return "";
  try {
    return new Intl.DateTimeFormat("de-DE", { hour: "2-digit", minute: "2-digit" }).format(new Date(value));
  } catch {
    return "";
  }
}

export function chatStyleClass(style) {
  return `chatStyle-${["sparkle", "cotton", "neon", "royal"].includes(style) ? style : "default"}`;
}

export function ChatPage({ user, setPage }) {
  const initialTarget = useMemo(() => {
    try {
      return localStorage.getItem("aviary_chat_target") || "";
    } catch {
      return "";
    }
  }, []);
  const [mode, setMode] = useState(initialTarget ? "private" : "global");
  const [selectedUser, setSelectedUser] = useState(initialTarget);
  const [users, setUsers] = useState([]);
  const [onlineUsers, setOnlineUsers] = useState([]);
  const [messages, setMessages] = useState([]);
  const [body, setBody] = useState("");
  const [notice, setNotice] = useState("");
  const [loading, setLoading] = useState(true);
  const [styleState, setStyleState] = useState({ selected: "default", styles: [] });

  useEffect(() => {
    try {
      localStorage.removeItem("aviary_chat_target");
    } catch {
      // Optional handoff only.
    }
  }, []);

  useEffect(() => {
    if (!user) return undefined;
    let alive = true;
    async function loadPeople() {
      try {
        const [nextUsers, nextOnline, nextStyles] = await Promise.all([
          api("/api/users"),
          api("/api/chat/online"),
          api("/api/chat/styles"),
        ]);
        if (!alive) return;
        setUsers(nextUsers);
        setOnlineUsers(nextOnline);
        setStyleState(nextStyles);
      } catch (err) {
        if (alive) setNotice(err.message);
      }
    }
    loadPeople();
    const interval = window.setInterval(loadPeople, 10000);
    return () => {
      alive = false;
      window.clearInterval(interval);
    };
  }, [user?.username]);

  useEffect(() => {
    if (!user) return undefined;
    let alive = true;
    async function loadMessages() {
      const path = mode === "global" ? "/api/chat/global" : selectedUser ? `/api/chat/private/${encodeURIComponent(selectedUser)}` : "";
      if (!path) {
        setMessages([]);
        setLoading(false);
        return;
      }
      try {
        const next = await api(path);
        if (!alive) return;
        setMessages(next);
        setNotice("");
      } catch (err) {
        if (alive) setNotice(err.message.includes("chat_messages") ? "Chat-Tabelle fehlt noch. Bitte add_chat_tables.sql in Supabase ausfuehren." : err.message);
      } finally {
        if (alive) setLoading(false);
      }
    }
    setLoading(true);
    loadMessages();
    const interval = window.setInterval(loadMessages, 3500);
    return () => {
      alive = false;
      window.clearInterval(interval);
    };
  }, [mode, selectedUser, user?.username]);

  if (!user) return <EmptyLogin setPage={setPage} />;

  const onlineNames = new Set(onlineUsers.map((member) => member.username));
  const selectableUsers = users.filter((member) => member.username && member.username !== user.username);
  const currentTarget = selectableUsers.find((member) => member.username === selectedUser);

  async function chooseStyle(style) {
    const next = styleState.styles.find((entry) => entry.id === style);
    if (!next?.owned) {
      setPage("shop");
      return;
    }
    try {
      const result = await api("/api/chat/styles", { method: "POST", body: JSON.stringify({ style }) });
      setStyleState((current) => ({ ...current, selected: result.style }));
      setNotice(result.message);
    } catch (err) {
      setNotice(err.message);
    }
  }

  async function sendMessage(event) {
    event.preventDefault();
    const text = body.trim();
    if (!text) return;
    if (mode === "private" && !selectedUser) {
      setNotice("Waehle zuerst ein Mitglied fuer den privaten Chat.");
      return;
    }
    const path = mode === "global" ? "/api/chat/global" : `/api/chat/private/${encodeURIComponent(selectedUser)}`;
    try {
      const result = await api(path, { method: "POST", body: JSON.stringify({ body: text }) });
      setMessages((current) => [...current, result.message].filter(Boolean));
      setBody("");
      setNotice("");
    } catch (err) {
      setNotice(err.message.includes("chat_messages") ? "Chat-Tabelle fehlt noch. Bitte add_chat_tables.sql in Supabase ausfuehren." : err.message);
    }
  }

  return (
    <section className="stack chatPage">
      <div className="chatHero">
        <div>
          <p className="kicker">Live Schwarmfunk</p>
          <h1>Chat</h1>
          <p>Global mit allen Online-Mitgliedern schreiben oder direkt private Nachrichten senden.</p>
        </div>
        <div className="chatModeTabs" role="tablist" aria-label="Chatmodus">
          <button className={mode === "global" ? "active" : ""} onClick={() => setMode("global")} type="button"><MessageCircle size={17} /> Global</button>
          <button className={mode === "private" ? "active" : ""} onClick={() => setMode("private")} type="button"><Mail size={17} /> Privat</button>
        </div>
      </div>
      <div className="chatLayout">
        <aside className="chatSidebar panel">
          <PanelTitle icon={Users} title="Online" action={`${onlineUsers.length}`} />
          <div className="chatPeopleList">
            {onlineUsers.length ? onlineUsers.map((member) => (
              <button key={member.username} onClick={() => { setSelectedUser(member.username); setMode("private"); }} type="button">
                <Avatar user={member} />
                <span><b>{member.username}</b><small>Online</small></span>
                <i />
              </button>
            )) : <div className="notice">Gerade niemand online.</div>}
          </div>
          <PanelTitle icon={Mail} title="Privat schreiben" action={`${selectableUsers.length}`} />
          <div className="chatPeopleList compact">
            {selectableUsers.map((member) => (
              <button className={selectedUser === member.username && mode === "private" ? "active" : ""} key={member.username} onClick={() => { setSelectedUser(member.username); setMode("private"); }} type="button">
                <Avatar user={member} />
                <span><b>{member.username}</b><small>{onlineNames.has(member.username) ? "Online" : "Offline"}</small></span>
                {onlineNames.has(member.username) && <i />}
              </button>
            ))}
          </div>
        </aside>
        <div className="chatWindow panel">
          <div className="chatWindowHead">
            <div>
              <span>{mode === "global" ? "Globalchat" : "Privater Chat"}</span>
              <strong>{mode === "global" ? "Alle online im Aviary" : currentTarget?.username || "Mitglied waehlen"}</strong>
            </div>
            {mode === "private" && currentTarget && <RoleBadge user={currentTarget} />}
          </div>
          {notice && <div className="notice error">{notice}</div>}
          <div className="chatStylePicker" aria-label="Chatbalken Animationen">
            {styleState.styles.map((style) => (
              <button
                className={`${styleState.selected === style.id ? "active" : ""} ${chatStyleClass(style.id)}`}
                key={style.id}
                onClick={() => chooseStyle(style.id)}
                type="button"
                title={style.owned ? style.description : "Im Shop kaufen"}
              >
                <span>{style.name}</span>
                {!style.owned && <small>{style.price} Chickens</small>}
              </button>
            ))}
          </div>
          <div className="chatMessages" aria-live="polite">
            {loading && <div className="notice">Lade Chat...</div>}
            {!loading && !messages.length && <div className="notice">Noch keine Nachrichten. Schreib die erste.</div>}
            {messages.map((message) => {
              const mine = message.sender_username === user.username;
              return (
                <article className={`chatBubble ${mine ? "mine" : ""} ${chatStyleClass(message.chat_style)}`} key={message.id || `${message.sender_username}-${message.created_at}`}>
                  {!mine && <Avatar user={message.sender} />}
                  <div>
                    <header>
                      <b>{message.sender?.username || message.sender_username}</b>
                      <RoleBadge user={message.sender} />
                      <time>{formatChatTime(message.created_at)}</time>
                    </header>
                    <p>{message.body}</p>
                  </div>
                </article>
              );
            })}
          </div>
          <form className="chatComposer" onSubmit={sendMessage}>
            <input
              value={body}
              onChange={(event) => setBody(event.target.value)}
              placeholder={mode === "global" ? "Nachricht an alle Online-Mitglieder..." : selectedUser ? `Nachricht an ${selectedUser}...` : "Erst Mitglied links waehlen..."}
              maxLength={1200}
              disabled={mode === "private" && !selectedUser}
            />
            <button type="submit" disabled={!body.trim() || (mode === "private" && !selectedUser)}><Send size={17} /> Senden</button>
          </form>
        </div>
      </div>
    </section>
  );
}
