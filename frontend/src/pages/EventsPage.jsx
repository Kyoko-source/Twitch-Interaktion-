import React, { useState } from "react";
import { api } from "../api";
import { useApi } from "./shared";

export function EventsPage({ user, setPage }) {
  const { data, loading, error } = useApi("/api/events", []);
  const [message, setMessage] = useState("");
  async function signup(eventId) {
    try {
      const result = await api("/api/events/signup", { method: "POST", body: JSON.stringify({ event_id: eventId }) });
      setMessage(result.message);
    } catch (err) {
      setMessage(err.message);
    }
  }
  return (
    <section className="stack">
      <h1>Events</h1>
      {message && <div className="notice">{message}</div>}
      {loading && <div className="notice">Lade Events...</div>}
      {error && <div className="notice error">{error}</div>}
      {!loading && !error && !data.length && <div className="notice">Gerade sind keine Events geplant. Schau bald wieder vorbei.</div>}
      <div className="list">
        {data.map((event) => (
          <article className="rowCard eventTicket" key={event.id}>
            <div><h3>{event.title}</h3><p>{event.description}</p><span>{event.event_date}</span></div>
            {user
              ? <button onClick={() => signup(event.id)} type="button">Teilnehmen</button>
              : <button className="ghost" onClick={() => setPage("login")} type="button">Zum Teilnehmen einloggen</button>}
          </article>
        ))}
      </div>
    </section>
  );
}
