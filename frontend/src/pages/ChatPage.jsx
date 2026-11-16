import React, { useEffect, useMemo, useRef, useState } from "react";
import { ArrowDown, ArrowLeft, Bell, Check, Hash, Lock, MessageCircle, Palette, Search, Send, UserRound } from "lucide-react";
import { refreshChatUnread, setActiveChat } from "../ui/ChatNotifier";
import { api } from "../api";
import { EmptyLogin, LevelChip, ProfileLink, RoleBadge, profileHref, userRole } from "./shared";
import { chatStyleClass } from "../ui/chatStyles.js";
import "./chat.css";

function ChatAvatar({ user, online = false }) {
  const name = String(user?.username || "?");
  return (
    <span className="cAvatar">
      {user?.avatar_url ? <img src={user.avatar_url} alt="" /> : name.slice(0, 2)}
      {online && <i aria-label="online" />}
    </span>
  );
}

function dayLabel(value) {
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return "";
  const today = new Date(); today.setHours(0, 0, 0, 0);
  const that = new Date(d); that.setHours(0, 0, 0, 0);
  const diff = Math.round((today - that) / 86400000);
  if (diff === 0) return "Heute";
  if (diff === 1) return "Gestern";
  return d.toLocaleDateString("de-DE", { weekday: "long", day: "numeric", month: "long" });
}

// Messages from the same person within 5 minutes form one group; a new day gets a divider.
export function groupMessages(messages) {
  const out = [];
  let last = null, lastDay = "";
  for (const message of messages) {
    const day = dayLabel(message.created_at);
    if (day && day !== lastDay) { out.push({ key: `day-${day}-${out.length}`, day }); lastDay = day; last = null; }
    const at = new Date(message.created_at).getTime() || 0;
    if (last && last.sender === message.sender_username && at - last.at < 5 * 60 * 1000) {
      last.items.push(message); last.at = at;
    } else {
      last = { key: `g-${message.id || at}-${out.length}`, sender: message.sender_username, user: message.sender || { username: message.sender_username }, items: [message], at };
      out.push(last);
    }
  }
  return out;
}

// @name and links to profiles (…/#u/name) become profile links; other links stay clickable.
function renderBody(text, knownNames) {
  const parts = String(text || "").split(/(@[\w.-]{2,32}|https?:\/\/[^\s]+)/g);
  return parts.map((part, i) => {
    if (part.startsWith("@") && knownNames.has(part.slice(1))) return <a key={i} className="cMention" href={profileHref(part.slice(1))}>{part}</a>;
    if (/^https?:\/\//.test(part)) {
      const profile = part.match(/#u\/([^\s/?#]+)/);
      if (profile && part.includes(window.location.host)) {
        const name = decodeURIComponent(profile[1]);
        return <a key={i} className="cMention" href={profileHref(name)}>@{name}</a>;
      }
      return <a key={i} href={part} target="_blank" rel="noopener noreferrer nofollow">{part}</a>;
    }
    return part;
  });
}

export function formatChatTime(value) {
  if (!value) return "";
  try {
    return new Intl.DateTimeFormat("de-DE", { hour: "2-digit", minute: "2-digit" }).format(new Date(value));
  } catch {
    return "";
  }
}

export { chatStyleClass };

export function ChatPage({ user, setPage, unread = { total: 0, conversations: [] } }) {
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
  const [styleOpen, setStyleOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [atBottom, setAtBottom] = useState(true);
  const scroller = useRef(null);
  const composer = useRef(null);
  const stick = useRef(true);
  const unreadRef = useRef(new Set());
  unreadRef.current = new Set(unread.conversations.map((item) => item.username));
  const [notifyPermission, setNotifyPermission] = useState(() => ("Notification" in window ? Notification.permission : "unsupported"));

  // Popups and the unread counter skip the conversation that is open right now.
  useEffect(() => {
    setActiveChat(mode === "private" ? selectedUser : "");
    return () => setActiveChat("");
  }, [mode, selectedUser]);

  useEffect(() => {
    function openFromToast(event) { setSelectedUser(event.detail.username); setMode("private"); }
    window.addEventListener("aviary-open-chat", openFromToast);
    return () => window.removeEventListener("aviary-open-chat", openFromToast);
  }, []);

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
        if (mode === "private" && unreadRef.current.has(selectedUser)) refreshChatUnread();
        setMessages(next);
        setNotice("");
      } catch (err) {
        if (alive) setNotice(err.message.includes("chat_messages") ? "Chat-Tabelle fehlt noch. Bitte add_chat_tables.sql in Supabase ausführen." : err.message);
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

  function scrollToEnd(smooth = false) {
    const el = scroller.current;
    if (!el) return;
    el.scrollTo({ top: el.scrollHeight, behavior: smooth ? "smooth" : "auto" });
    stick.current = true;
    setAtBottom(true);
  }

  function onScroll() {
    const el = scroller.current;
    if (!el) return;
    const near = el.scrollHeight - el.scrollTop - el.clientHeight < 80;
    stick.current = near;
    setAtBottom(near);
  }

  // Stay at the newest message unless the reader scrolled up.
  useEffect(() => { if (stick.current) scrollToEnd(); }, [messages.length]);
  useEffect(() => { stick.current = true; scrollToEnd(); }, [mode, selectedUser]);

  // The composer grows with the text (up to 6 lines).
  useEffect(() => {
    const el = composer.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = `${Math.min(el.scrollHeight, 150)}px`;
  }, [body]);

  if (!user) return <EmptyLogin setPage={setPage} />;

  const unreadBy = new Map(unread.conversations.map((item) => [item.username, item.count]));

  const onlineNames = new Set(onlineUsers.map((member) => member.username));
  const selectableUsers = users
    .filter((member) => member.username && member.username !== user.username)
    .sort((a, b) => (unreadBy.get(b.username) || 0) - (unreadBy.get(a.username) || 0));
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
      setNotice("Wähle zuerst ein Mitglied für den privaten Chat.");
      return;
    }
    const path = mode === "global" ? "/api/chat/global" : `/api/chat/private/${encodeURIComponent(selectedUser)}`;
    try {
      const result = await api(path, { method: "POST", body: JSON.stringify({ body: text }) });
      setMessages((current) => [...current, result.message].filter(Boolean));
      setBody("");
      setNotice("");
    } catch (err) {
      setNotice(err.message.includes("chat_messages") ? "Chat-Tabelle fehlt noch. Bitte add_chat_tables.sql in Supabase ausführen." : err.message);
    }
  }

  const filteredUsers = query ? selectableUsers.filter((member) => member.username.toLowerCase().includes(query.toLowerCase())) : selectableUsers;
  const knownNames = new Set(users.map((member) => member.username));
  const groups = groupMessages(messages);
  const showList = mode === "private" && !selectedUser;
  const currentStyle = styleState.styles.find((entry) => entry.id === styleState.selected);

  function openConversation(name) {
    setSelectedUser(name);
    setMode("private");
  }

  return (
    <section className={`cChat${showList ? " cShowList" : ""}`} data-testid="chat-page">
      <aside className="cSide" aria-label="Unterhaltungen">
        <div className="cSideHead">
          <h1>Chat</h1>
          {notifyPermission === "default" && <button type="button" className="cBellBtn" title="Desktop-Benachrichtigungen aktivieren" aria-label="Desktop-Benachrichtigungen aktivieren" onClick={() => Notification.requestPermission().then(setNotifyPermission).catch(() => {})}><Bell size={16} /></button>}
        </div>
        <button type="button" className={`cConv cGlobal${mode === "global" ? " active" : ""}`} onClick={() => setMode("global")}>
          <span className="cConvIcon"><Hash size={18} /></span>
          <span className="cConvText"><b>Globalchat</b><small>{onlineUsers.length} online</small></span>
        </button>
        {onlineUsers.length > 0 && (
          <div className="cOnlineStrip" aria-label="Gerade online">
            {onlineUsers.slice(0, 12).map((member) => (
              <button key={member.username} type="button" title={member.username} onClick={() => member.username !== user.username && openConversation(member.username)}>
                <ChatAvatar user={member} online />
              </button>
            ))}
          </div>
        )}
        <label className="cSearch"><Search size={15} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Mitglied suchen" aria-label="Mitglied suchen" /></label>
        <div className="cConvList">
          {filteredUsers.map((member) => {
            const count = unreadBy.get(member.username) || 0;
            return (
              <button key={member.username} type="button" className={`cConv${selectedUser === member.username && mode === "private" ? " active" : ""}${count ? " unread" : ""}`} onClick={() => openConversation(member.username)}>
                <ChatAvatar user={member} online={onlineNames.has(member.username)} />
                <span className="cConvText"><b>{member.username}</b><small>{count ? "Neue Nachricht" : member.level_title || (onlineNames.has(member.username) ? "Online" : "Offline")}</small></span>
                {count > 0 ? <em className="cUnread">{count}</em> : member.level ? <span className="cLv">{member.level}</span> : null}
              </button>
            );
          })}
          {!filteredUsers.length && <p className="cEmptySmall">Niemand gefunden.</p>}
        </div>
      </aside>

      <div className="cMain">
        <header className="cHead">
          <button type="button" className="cBack" onClick={() => (mode === "private" ? setSelectedUser("") : setMode("private"))} aria-label="Zur Übersicht"><ArrowLeft size={18} /></button>
          {mode === "global" ? (
            <>
              <span className="cConvIcon"><Hash size={18} /></span>
              <div className="cHeadText"><strong>Globalchat</strong><small>{onlineUsers.length ? `${onlineUsers.length} online · alle im Aviary` : "Alle im Aviary"}</small></div>
            </>
          ) : currentTarget ? (
            <>
              <ChatAvatar user={currentTarget} online={onlineNames.has(currentTarget.username)} />
              <div className="cHeadText"><strong><ProfileLink user={currentTarget} /> <LevelChip user={currentTarget} /></strong><small>{onlineNames.has(currentTarget.username) ? "Online" : "Offline"}{currentTarget.level_title ? ` · ${currentTarget.level_title}` : ""}</small></div>
              <a className="cHeadBtn" href={profileHref(currentTarget.username)} title="Profil ansehen"><UserRound size={17} /><span>Profil</span></a>
            </>
          ) : (
            <div className="cHeadText"><strong>Privat</strong><small>Wähle links ein Mitglied</small></div>
          )}
          <div className="cStyleWrap">
            <button type="button" className={`cHeadBtn${styleOpen ? " on" : ""}`} onClick={() => setStyleOpen(!styleOpen)} aria-expanded={styleOpen} title="Chat-Stil wählen"><Palette size={17} /><span>{currentStyle?.name || "Stil"}</span></button>
            {styleOpen && (
              <div className="cStyleMenu" role="menu">
                <small>Dein Chat-Stil</small>
                {styleState.styles.map((style) => (
                  <button key={style.id} role="menuitemradio" aria-checked={styleState.selected === style.id} type="button" className={`cStyleItem${styleState.selected === style.id ? " on" : ""}`} onClick={() => { chooseStyle(style.id); setStyleOpen(false); }}>
                    <span className={`chatBubble ${chatStyleClass(style.id)}`}><span>{style.name}</span></span>
                    {style.owned ? styleState.selected === style.id && <Check size={15} /> : <small><Lock size={12} /> {style.price}</small>}
                  </button>
                ))}
              </div>
            )}
          </div>
        </header>
        {notice && <div className="cNotice" role="alert">{notice}</div>}

        <div className="cMessages" ref={scroller} onScroll={onScroll} aria-live="polite">
          {loading && !messages.length && <div className="cEmpty">Lade Chat …</div>}
          {!loading && !messages.length && mode === "private" && !selectedUser && <div className="cEmpty"><MessageCircle size={34} /><p>Wähle ein Mitglied und schreib los.</p></div>}
          {!loading && !messages.length && (mode === "global" || selectedUser) && <div className="cEmpty"><MessageCircle size={34} /><p>Noch keine Nachrichten. Schreib die erste! 👋</p></div>}
          {groups.map((group) => group.day ? (
            <div className="cDay" key={group.key}><span>{group.day}</span></div>
          ) : (
            <div className={`cGroup${group.sender === user.username ? " mine" : ""}`} key={group.key}>
              {group.sender !== user.username && <a className="cGroupAvatar" href={profileHref(group.sender)} title={`Profil von ${group.sender}`}><ChatAvatar user={group.user} /></a>}
              <div className="cGroupBody">
                {group.sender !== user.username && (
                  <div className="cMeta">
                    <ProfileLink username={group.sender} className="cName" />
                    <LevelChip user={group.user} />
                    {userRole(group.user) !== "member" && <RoleBadge user={group.user} />}
                    <time>{formatChatTime(group.items[0].created_at)}</time>
                  </div>
                )}
                {group.items.map((message, index) => (
                  <div className={`chatBubble cBubble ${chatStyleClass(message.chat_style)}`} key={message.id || `${message.sender_username}-${message.created_at}`}>
                    <div>
                      <p>{renderBody(message.body, knownNames)}</p>
                      {(group.sender === user.username || index > 0) && <time>{formatChatTime(message.created_at)}</time>}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
        {!atBottom && <button type="button" className="cJump" onClick={() => scrollToEnd(true)}><ArrowDown size={15} /> Neueste</button>}

        <form className="cComposer" onSubmit={sendMessage}>
          <textarea
            ref={composer}
            rows={1}
            value={body}
            onChange={(event) => setBody(event.target.value)}
            onKeyDown={(event) => { if (event.key === "Enter" && !event.shiftKey) { event.preventDefault(); event.currentTarget.form.requestSubmit(); } }}
            placeholder={mode === "global" ? "Nachricht an alle …" : selectedUser ? `Nachricht an ${selectedUser} …` : "Erst ein Mitglied wählen …"}
            maxLength={1200}
            disabled={mode === "private" && !selectedUser}
            aria-label="Nachricht"
          />
          {body.length > 1000 && <small className="cCount">{1200 - body.length}</small>}
          <button type="submit" className="cSend" disabled={!body.trim() || (mode === "private" && !selectedUser)} aria-label="Senden"><Send size={18} /></button>
        </form>
      </div>
    </section>
  );
}
