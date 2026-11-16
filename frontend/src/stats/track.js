// Privacy-friendly page tracking for the admin Statistik: a random visitor id in localStorage
// (no cookie, no IP stored), the visible page, the external referrer once per visit, and a
// ping every minute while the tab is visible to measure time on the site.
import { useEffect } from "react";
import { api } from "../api";

const KEY = "aviary_vid";
let visitor = "";
let referrerSent = false;

function visitorId() {
  if (visitor) return visitor;
  try { visitor = localStorage.getItem(KEY) || ""; } catch { /* private mode */ }
  if (!visitor) {
    visitor = (crypto.randomUUID ? crypto.randomUUID() : `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 12)}`).replace(/[^A-Za-z0-9-]/g, "");
    try { localStorage.setItem(KEY, visitor); } catch { /* id lives for this visit only */ }
  }
  return visitor;
}

function send(kind, path) {
  const body = { visitor: visitorId(), path: String(path || "home").slice(0, 80), kind, width: window.innerWidth || 0, ref: "" };
  if (kind === "view" && !referrerSent) { body.ref = (document.referrer || "").slice(0, 300); referrerSent = true; }
  api("/api/track", { method: "POST", body: JSON.stringify(body), keepalive: true }).catch(() => {});
}

export function usePageTracking(path) {
  useEffect(() => { send("view", path); }, [path]);
  useEffect(() => {
    const timer = window.setInterval(() => { if (document.visibilityState === "visible") send("ping", path); }, 60000);
    return () => window.clearInterval(timer);
  }, [path]);
}
