import React, { useState } from "react";
import { api } from "../api";
import { useApi } from "./shared";

export function SupportPage({ user }) {
  const [form, setForm] = useState({ username: user?.username || "", category: "Problem", title: "", message: "" });
  const [wish, setWish] = useState({ title: "", description: "" });
  const [message, setMessage] = useState("");
  const { data: wishes } = useApi("/api/support/wishes", []);
  async function sendSupport(event) {
    event.preventDefault();
    try {
      const result = await api("/api/support", { method: "POST", body: JSON.stringify(form) });
      setMessage(result.message);
    } catch (err) {
      setMessage(err.message);
    }
  }
  async function sendWish(event) {
    event.preventDefault();
    try {
      const result = await api("/api/support/wishes", { method: "POST", body: JSON.stringify(wish) });
      setMessage(result.message);
    } catch (err) {
      setMessage(err.message);
    }
  }
  return (
    <section className="twoCol">
      <form className="panel form" onSubmit={sendSupport}>
        <h2>Problem melden</h2>
        <label>Name<input value={form.username} onChange={(event) => setForm({ ...form, username: event.target.value })} /></label>
        <label>Kategorie<input value={form.category} onChange={(event) => setForm({ ...form, category: event.target.value })} /></label>
        <label>Titel<input value={form.title} onChange={(event) => setForm({ ...form, title: event.target.value })} /></label>
        <label>Beschreibung<textarea value={form.message} onChange={(event) => setForm({ ...form, message: event.target.value })} /></label>
        <button type="submit">Senden</button>
        {message && <div className="notice">{message}</div>}
      </form>
      <div className="panel">
        <h2>Wuensche</h2>
        {user && (
          <form className="form" onSubmit={sendWish}>
            <label>Titel<input value={wish.title} onChange={(event) => setWish({ ...wish, title: event.target.value })} /></label>
            <label>Beschreibung<textarea value={wish.description} onChange={(event) => setWish({ ...wish, description: event.target.value })} /></label>
            <button type="submit">Wunsch veroeffentlichen</button>
          </form>
        )}
        <div className="list">{wishes.map((item) => <article className="miniCard" key={item.id}><strong>{item.title}</strong><span>{item.description}</span></article>)}</div>
      </div>
    </section>
  );
}
