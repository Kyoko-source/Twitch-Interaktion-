import React, { useState } from "react";
import { api } from "../api";
import { EmptyLogin, useApi } from "./shared";

export function EventsPage({ user, setPage }) {
  const { data, loading, error } = useApi("/api/events", []);
  const [message, setMessage] = useState("");
  if (!user) return <EmptyLogin setPage={setPage} />;
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
      <div className="list">
        {data.map((event) => (
          <article className="rowCard eventTicket" key={event.id}>
            <div><h3>{event.title}</h3><p>{event.description}</p><span>{event.event_date}</span></div>
            <button onClick={() => signup(event.id)} type="button">Anmelden</button>
          </article>
        ))}
      </div>
    </section>
  );
}
