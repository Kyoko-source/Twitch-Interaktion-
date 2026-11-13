import React, { useEffect, useRef, useState } from "react";
import { Palette } from "lucide-react";
import { api } from "../api";
import { useApi } from "./shared";

export const galleryReactions = ["😍", "😂", "🔥", "💜", "👏"];

export function GalleryPage({ user, setPage }) {
  const canvasRef = useRef(null);
  const drawingRef = useRef(false);
  const lastPointRef = useRef(null);
  const [title, setTitle] = useState("");
  const [color, setColor] = useState("#ff6fb7");
  const [size, setSize] = useState(8);
  const [message, setMessage] = useState("");
  const [refreshKey, setRefreshKey] = useState(0);
  const { data, loading, error } = useApi("/api/gallery", [], refreshKey);

  function canvasPoint(event) {
    const canvas = canvasRef.current;
    const rect = canvas.getBoundingClientRect();
    return {
      x: (event.clientX - rect.left) / rect.width * canvas.width,
      y: (event.clientY - rect.top) / rect.height * canvas.height,
    };
  }

  function clearCanvas() {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    ctx.fillStyle = "#fffaf2";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = "rgba(180, 108, 255, 0.08)";
    for (let x = 0; x < canvas.width; x += 48) ctx.fillRect(x, 0, 1, canvas.height);
    for (let y = 0; y < canvas.height; y += 48) ctx.fillRect(0, y, canvas.width, 1);
  }

  function drawTo(point) {
    const canvas = canvasRef.current;
    const last = lastPointRef.current || point;
    const ctx = canvas.getContext("2d");
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.strokeStyle = color;
    ctx.lineWidth = Number(size);
    ctx.beginPath();
    ctx.moveTo(last.x, last.y);
    ctx.lineTo(point.x, point.y);
    ctx.stroke();
    lastPointRef.current = point;
  }

  useEffect(() => {
    clearCanvas();
  }, []);

  async function publish(event) {
    event.preventDefault();
    if (!user) {
      setPage("login");
      return;
    }
    try {
      const imageData = canvasRef.current.toDataURL("image/png");
      const result = await api("/api/gallery", { method: "POST", body: JSON.stringify({ title, image_data: imageData }) });
      setMessage(result.message);
      setRefreshKey((value) => value + 1);
    } catch (err) {
      setMessage(err.message);
    }
  }

  async function react(item, emoji) {
    if (!user) {
      setPage("login");
      return;
    }
    try {
      await api("/api/gallery/reactions", { method: "POST", body: JSON.stringify({ art_id: item.id, emoji }) });
      setRefreshKey((value) => value + 1);
    } catch (err) {
      setMessage(err.message);
    }
  }

  return (
    <section className="stack galleryPage">
      <div className="sectionHero">
        <div>
          <p className="kicker">Hall of Fame</p>
          <h1>Kreativwand</h1>
          <p>Male direkt im Browser, veroeffentliche dein Bild und gib den Werken der Community Reaktionen.</p>
        </div>
        <Palette size={64} />
      </div>
      <section className="galleryStudio">
        <form className="panel form galleryTools" onSubmit={publish}>
          <h2>Bild malen</h2>
          <label>Titel<input value={title} onChange={(event) => setTitle(event.target.value)} placeholder="Ohne Titel" /></label>
          <div className="paintControls">
            <label>Farbe<input type="color" value={color} onChange={(event) => setColor(event.target.value)} /></label>
            <label>Strich<input type="range" min="2" max="28" value={size} onChange={(event) => setSize(event.target.value)} /></label>
          </div>
          <div className="gameActions">
            <button type="submit">In Hall of Fame veroeffentlichen</button>
            <button className="ghost" onClick={clearCanvas} type="button">Leeren</button>
          </div>
          {!user && <div className="notice">Zum Veroeffentlichen bitte einloggen.</div>}
          {message && <div className="notice">{message}</div>}
        </form>
        <div className="paintSurface">
          <canvas
            ref={canvasRef}
            width="900"
            height="520"
            onPointerDown={(event) => {
              drawingRef.current = true;
              event.currentTarget.setPointerCapture(event.pointerId);
              const point = canvasPoint(event);
              lastPointRef.current = point;
              drawTo(point);
            }}
            onPointerMove={(event) => {
              if (drawingRef.current) drawTo(canvasPoint(event));
            }}
            onPointerUp={() => {
              drawingRef.current = false;
              lastPointRef.current = null;
            }}
            onPointerCancel={() => {
              drawingRef.current = false;
              lastPointRef.current = null;
            }}
          />
        </div>
      </section>
      {loading && <div className="notice">Lade Hall of Fame...</div>}
      {error && <div className="notice error">{error}</div>}
      <div className="galleryGrid">
        {data.length ? data.map((item) => {
          const selected = user ? item.user_reactions?.[user.username] : "";
          return (
            <article className="card imageCard galleryCard" key={item.id}>
              {item.image_data && <img src={item.image_data} alt={item.title || "Hall of Fame Bild"} />}
              <h3>{item.title || "Kunstwerk"}</h3>
              <p>von {item.username}</p>
              {item.created_at && <small>{new Date(item.created_at).toLocaleDateString("de-DE")}</small>}
              <div className="reactionRow">
                {galleryReactions.map((emoji) => (
                  <button className={selected === emoji ? "active" : ""} onClick={() => react(item, emoji)} type="button" key={emoji}>
                    {emoji} {item.reactions?.[emoji] || 0}
                  </button>
                ))}
              </div>
            </article>
          );
        }) : <div className="notice">Noch keine Bilder in der Hall of Fame.</div>}
      </div>
    </section>
  );
}
