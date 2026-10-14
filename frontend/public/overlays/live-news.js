(() => {
  const preview = new URLSearchParams(location.search).get("preview") === "1";
  const ticker = document.getElementById("ticker");
  const track = document.getElementById("news-track");
  const firstCopy = track.firstElementChild;
  const labels = { breaking: "BREAKING NEWS", normal: "NEWS", community: "COMMUNITY NEWS" };
  const label = document.getElementById("news-label");
  let signature = "";
  let hideTimer;
  let sound;

  function fitSource() {
    ticker.style.setProperty("--overlay-scale", String(innerWidth / 1920));
  }
  fitSource();
  new ResizeObserver(fitSource).observe(document.body);

  function normalizedMessage(message) {
    return `+++ ${message.slice(0, 1000).replace(/\s+/g, " ").trim()} +++`;
  }

  // The admin's 1920px preview provides the exact cycle length before publishing.
  window.liveNewsCycleSeconds = (state) => {
    const context = document.createElement("canvas").getContext("2d");
    const labelStyle = getComputedStyle(label);
    context.font = labelStyle.font;
    const spacing = ["marginLeft", "marginRight", "paddingLeft", "paddingRight"]
      .reduce((total, property) => total + parseFloat(labelStyle[property]), 0);
    const windowWidth = Math.max(1, 1920 - context.measureText(labels[state.kind]).width - spacing);
    context.font = getComputedStyle(firstCopy).font;
    const textWidth = context.measureText(normalizedMessage(state.message)).width;
    return Math.max(1, (windowWidth + textWidth) / state.speed);
  };

  function stopSound() {
    if (sound) { sound.pause(); sound = null; }
  }

  function finish() {
    clearTimeout(hideTimer);
    ticker.hidden = true;
    track.style.animation = "none";
    stopSound();
  }

  function playSound(state, elapsed) {
    stopSound();
    ticker.dataset.soundState = "disabled";
    if (preview || state.sound_enabled === false || state.volume === 0) return;
    if (elapsed > 5) { ticker.dataset.soundState = "stale"; return; }
    const soundKey = state.updated_at ? `${state.revision}:${state.updated_at}` : null;
    try {
      if (soundKey && sessionStorage.getItem("live-news-last-sound") === soundKey) {
        ticker.dataset.soundState = "already-played";
        return;
      }
    } catch { /* OBS may restrict browser storage. */ }
    const audio = new Audio(`/overlays/sounds/${state.kind}.wav`);
    sound = audio;
    audio.volume = Math.max(0, Math.min(1, (state.volume ?? 70) / 100));
    ticker.dataset.soundState = "loading";
    audio.play().then(() => {
      if (sound === audio) {
        ticker.dataset.soundState = "playing";
        try { if (soundKey) sessionStorage.setItem("live-news-last-sound", soundKey); } catch { /* Optional deduplication. */ }
      }
    }).catch(() => {
      if (sound === audio) ticker.dataset.soundState = "blocked";
    });
    audio.addEventListener("ended", () => {
      if (sound === audio) ticker.dataset.soundState = "ended";
    }, { once: true });
  }

  function render(state) {
    if (!state || typeof state.message !== "string" || !Object.hasOwn(labels, state.kind)) return;
    const next = JSON.stringify(state);
    if (next === signature) return;
    signature = next;
    finish();
    if (state.enabled !== true || !state.message.trim()) return;
    const started = preview ? Date.now() : Date.parse(state.updated_at) || Date.now();
    const elapsed = Math.max(0, (Date.now() - started) / 1000);
    const mode = state.playback_mode === "duration" ? "duration" : "loops";
    const cycle = preview ? window.liveNewsCycleSeconds(state) : Number(state.cycle_seconds) || 30;
    const loops = Math.min(20, Math.max(1, Number(state.repeat_count) || 3));
    const run = mode === "duration" ? Math.min(3600, Math.max(5, Number(state.duration_seconds) || 30)) : cycle * loops;
    const remaining = !preview && state.ends_at ? (Date.parse(state.ends_at) - Date.now()) / 1000 : run - elapsed;
    if (!(remaining > 0)) return;
    ticker.hidden = false;
    ticker.dataset.kind = state.kind;
    label.textContent = labels[state.kind];
    firstCopy.textContent = normalizedMessage(state.message);
    track.style.setProperty("--start", `${document.querySelector(".news-window").clientWidth}px`);
    track.style.setProperty("--distance", getComputedStyle(firstCopy).width);
    track.style.setProperty("--duration", `${cycle}s`);
    void track.offsetWidth;
    track.style.animation = "";
    track.style.animationIterationCount = mode === "loops" ? String(loops) : "infinite";
    track.style.animationDelay = `-${elapsed}s`;
    hideTimer = setTimeout(finish, remaining * 1000);
    playSound(state, elapsed);
  }

  track.addEventListener("animationend", finish);
  if (preview) {
    window.addEventListener("message", (event) => {
      if (event.origin !== location.origin || event.source !== parent || event.data?.type !== "live-news-preview") return;
      render(event.data.state);
    });
  } else {
    async function poll() {
      try {
        const response = await fetch("/api/live-news", { cache: "no-store", signal: AbortSignal.timeout(5000) });
        if (response.ok) render(await response.json());
      } catch {
        // The local deadline still hides the ticker even if the connection fails.
      } finally {
        setTimeout(poll, 1000);
      }
    }
    poll();
  }
})();
