(() => {
  const preview = new URLSearchParams(location.search).get("preview") === "1";
  const ticker = document.getElementById("ticker");
  const track = document.getElementById("news-track");
  const firstCopy = track.firstElementChild;
  const labels = { breaking: "BREAKING NEWS", normal: "NEWS", community: "COMMUNITY NEWS" };
  let current = null;
  let signature = "";

  function measure() {
    if (ticker.hidden || !current) return;
    const width = document.querySelector(".news-window").clientWidth;
    const distance = firstCopy.getBoundingClientRect().width;
    const count = Math.max(2, Math.ceil(width / distance) + 1);
    while (track.children.length < count) {
      const copy = firstCopy.cloneNode(true);
      copy.setAttribute("aria-hidden", "true");
      track.append(copy);
    }
    while (track.children.length > count) track.lastElementChild.remove();
    track.style.setProperty("--distance", `${distance}px`);
    track.style.setProperty("--duration", `${distance / current.speed}s`);
  }

  function render(state) {
    if (!state || typeof state.message !== "string" || !Object.hasOwn(labels, state.kind)) return;
    current = {
      message: state.message.slice(0, 1000).replace(/\s+/g, " ").trim(),
      kind: state.kind,
      speed: Math.min(220, Math.max(40, Number(state.speed) || 90)),
      enabled: state.enabled === true,
    };
    const next = JSON.stringify(current);
    if (next === signature) return;
    signature = next;
    ticker.hidden = !current.enabled || !current.message;
    ticker.dataset.kind = current.kind;
    document.getElementById("news-label").textContent = labels[current.kind];
    for (const copy of track.children) copy.textContent = `+++ ${current.message} +++`;
    // A publication starts a new loop. Identical polling responses never interrupt it.
    track.style.animation = "none";
    measure();
    void track.offsetWidth;
    track.style.animation = "";
  }

  new ResizeObserver(measure).observe(document.body);
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
        // Preserve the last publication during temporary network failures.
      } finally {
        setTimeout(poll, 1000);
      }
    }
    poll();
  }
})();
