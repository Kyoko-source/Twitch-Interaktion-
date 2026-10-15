(() => {
  "use strict";
  const preview = new URLSearchParams(location.search).get("preview") === "1";
  const box = document.getElementById("shop-alert");
  const countdown = document.getElementById("reward-countdown");
  let events = [], currentId = null, started = 0, deadline = 0, animation = null;
  let serverBase = Date.now() / 1000, performanceBase = performance.now();
  const seen = new Set();
  try { JSON.parse(sessionStorage.getItem("aviary-shop-alerts") || "[]").forEach((id) => seen.add(id)); } catch { /* Storage is optional in OBS. */ }
  function resize() { document.documentElement.style.setProperty("--overlay-scale", Math.min(innerWidth / 1536, innerHeight / 1024)); }
  addEventListener("resize", resize);
  resize();
  const now = () => serverBase + (performance.now() - performanceBase) / 1000;
  function remember(id) {
    seen.add(id);
    try { sessionStorage.setItem("aviary-shop-alerts", JSON.stringify([...seen].slice(-200))); } catch { /* No replay within the current page regardless. */ }
  }
  function show(event) {
    currentId = event.id;
    started = event.starts;
    deadline = event.ends;
    document.getElementById("buyer-name").textContent = String(event.username || "Community").slice(0, 64);
    const title = String(event.item_name || "Bestrafung").slice(0, 100);
    document.getElementById("reward-name").textContent = title;
    document.getElementById("reward-price").textContent = `${Number(event.price || 0).toLocaleString("de-DE")} Chickens`;
    box.classList.toggle("has-long-title", title.length > 26);
    box.classList.remove("is-entering");
    box.hidden = false;
    void box.offsetWidth;
    box.classList.add("is-entering");
    if (!preview) remember(event.id);
    if (animation) cancelAnimationFrame(animation);
    tick();
  }
  function tick() {
    const time = now();
    if (time >= deadline) {
      box.hidden = true;
      currentId = null;
      animation = null;
      return;
    }
    countdown.style.transform = `scaleX(${Math.max(0, Math.min(1, (deadline - time) / Math.max(.1, deadline - started)))})`;
    animation = requestAnimationFrame(tick);
  }
  function selectEvent() {
    if (currentId !== null) return;
    const time = now();
    const event = events.find((event) => Number.isFinite(event.starts) && Number.isFinite(event.ends) && event.starts <= time && event.ends > time && !seen.has(event.id));
    if (event) show(event);
  }
  async function poll() {
    try {
      const response = await fetch("/api/purchase-alerts", { cache: "no-store", signal: AbortSignal.timeout(5000) });
      if (!response.ok) throw new Error("Unavailable");
      const state = await response.json();
      if (!Number.isFinite(state.server_time) || !Array.isArray(state.events)) return;
      serverBase = state.server_time;
      performanceBase = performance.now();
      events = state.events;
      selectEvent();
    } catch { /* An already-visible alert still expires during a network failure. */ }
    finally { setTimeout(poll, 1000); }
  }
  if (preview) {
    addEventListener("message", (event) => {
      if (event.origin !== location.origin || event.source !== parent || event.data?.type !== "aviary-shop-preview") return;
      serverBase = Date.now() / 1000;
      performanceBase = performance.now();
      const time = now();
      const duration = Math.max(5, Math.min(20, Number(event.data.duration) || 10));
      show({ id: "preview", username: event.data.username || "magical_kyoko_", item_name: event.data.item_name || "3 Squats", price: event.data.price ?? 450, starts: time, ends: time + duration });
    });
  } else {
    poll();
    setInterval(selectEvent, 100);
  }
})();
