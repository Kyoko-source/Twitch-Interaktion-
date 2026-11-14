import React, { useCallback, useEffect, useRef, useState } from "react";
import { Mail, X } from "lucide-react";
import { api } from "../api";
import { MemberAvatar } from "./CommunityLayout";
import "./chat-notifier.css";

const POLL_MS = 8000;
let activeChat = "";

// ChatPage reports which private conversation is open, so no popup appears for it.
export function setActiveChat(username) { activeChat = username || ""; }

export function openChatWith(username, setPage) {
  try { localStorage.setItem("aviary_chat_target", username); } catch { /* optional handoff */ }
  window.dispatchEvent(new CustomEvent("aviary-open-chat", { detail: { username } }));
  setPage("chat");
}

export function refreshChatUnread() { window.dispatchEvent(new Event("aviary-chat-read")); }

function ping() {
  try {
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return;
    const ctx = ping.ctx || (ping.ctx = new Ctx());
    if (ctx.state === "suspended") ctx.resume().catch(() => {});
    const now = ctx.currentTime;
    [[880, 0], [1320, 0.11]].forEach(([freq, at]) => {
      const osc = ctx.createOscillator(), gain = ctx.createGain();
      osc.type = "sine"; osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.0001, now + at);
      gain.gain.exponentialRampToValueAtTime(0.12, now + at + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + at + 0.32);
      osc.connect(gain).connect(ctx.destination);
      osc.start(now + at); osc.stop(now + at + 0.35);
    });
  } catch { /* sound is a bonus */ }
}

export function useChatUnread(user) {
  const [summary, setSummary] = useState({ total: 0, conversations: [] });
  const [toasts, setToasts] = useState([]);
  const announced = useRef(new Set());
  const username = user?.username;

  const load = useCallback(async () => {
    if (!username) return;
    let next;
    try { next = await api("/api/chat/unread"); } catch { return; }
    const conversations = Array.isArray(next?.conversations) ? next.conversations : [];
    next = { total: Number(next?.total) || 0, conversations };
    setSummary(next);
    const fresh = next.conversations.filter((item) => item.last_id && !announced.current.has(item.last_id) && item.username !== activeChat);
    next.conversations.forEach((item) => announced.current.add(item.last_id));
    if (!fresh.length) return;
    ping();
    setToasts((current) => [...fresh.map((item) => ({ ...item, key: item.last_id })), ...current.filter((t) => !fresh.some((f) => f.username === t.username))].slice(0, 3));
    if (document.hidden && "Notification" in window && Notification.permission === "granted") {
      fresh.forEach((item) => {
        try {
          const note = new Notification(`Neue Nachricht von ${item.username}`, { body: item.last_body, tag: `aviary-chat-${item.username}`, icon: "/assets/aviary-mascot-bust.webp" });
          note.onclick = () => { window.focus(); window.dispatchEvent(new CustomEvent("aviary-chat-notification-click", { detail: { username: item.username } })); note.close(); };
        } catch { /* some browsers only allow notifications from a service worker */ }
      });
    }
  }, [username]);

  useEffect(() => {
    announced.current = new Set();
    setToasts([]);
    setSummary({ total: 0, conversations: [] });
    if (!username) return undefined;
    load();
    const interval = window.setInterval(load, POLL_MS);
    const onFocus = () => load();
    window.addEventListener("focus", onFocus);
    window.addEventListener("aviary-chat-read", onFocus);
    return () => {
      window.clearInterval(interval);
      window.removeEventListener("focus", onFocus);
      window.removeEventListener("aviary-chat-read", onFocus);
    };
  }, [username, load]);

  // Toasts disappear on their own after a while.
  useEffect(() => {
    if (!toasts.length) return undefined;
    const timer = window.setTimeout(() => setToasts((current) => current.slice(0, -1)), 12000);
    return () => window.clearTimeout(timer);
  }, [toasts]);

  const dismiss = useCallback((key) => setToasts((current) => current.filter((t) => t.key !== key)), []);
  return { summary, toasts, dismiss };
}

export function ChatToasts({ toasts, dismiss, setPage }) {
  useEffect(() => {
    function fromNotification(event) { openChatWith(event.detail.username, setPage); }
    window.addEventListener("aviary-chat-notification-click", fromNotification);
    return () => window.removeEventListener("aviary-chat-notification-click", fromNotification);
  }, [setPage]);
  if (!toasts.length) return null;
  return <div className="chatToasts" role="status" aria-live="polite">
    {toasts.map((toast) => <article className="chatToast" key={toast.key}>
      <MemberAvatar user={{ username: toast.username }} />
      <div>
        <header><Mail size={14} /> Neue Nachricht von <b>{toast.username}</b>{toast.count > 1 && <em>{toast.count}</em>}</header>
        <p>{toast.last_body}</p>
        <button type="button" onClick={() => { dismiss(toast.key); openChatWith(toast.username, setPage); }}>Antworten</button>
      </div>
      <button type="button" className="chatToastClose" aria-label="Schließen" onClick={() => dismiss(toast.key)}><X size={16} /></button>
    </article>)}
  </div>;
}
