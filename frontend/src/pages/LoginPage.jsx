import React, { useState } from "react";
import { api, setToken } from "../api";

export function LoginPage({ onLogin }) {
  const [mode, setMode] = useState("login");
  const [form, setForm] = useState({ username: "", password: "", code: "" });
  const [message, setMessage] = useState("");

  async function submit(event) {
    event.preventDefault();
    setMessage("");
    try {
      if (mode === "login") {
        const result = await api("/api/auth/login", { method: "POST", body: JSON.stringify(form) });
        setToken(result.token);
        onLogin(result.user);
      } else if (mode === "complete") {
        const result = await api("/api/auth/complete-registration", { method: "POST", body: JSON.stringify(form) });
        setToken(result.token);
        onLogin(result.user);
      } else {
        const result = await api("/api/auth/registration-requests", { method: "POST", body: JSON.stringify(form) });
        setMessage(result.message);
      }
    } catch (err) {
      setMessage(err.message);
    }
  }

  return (
    <section className="narrow">
      <div className="panel">
        <p className="kicker">Account</p>
        <h1>{mode === "login" ? "Anmelden" : "Registrierung"}</h1>
        <div className="segmented">
          <button className={mode === "login" ? "active" : ""} onClick={() => setMode("login")} type="button">Login</button>
          <button className={mode === "request" ? "active" : ""} onClick={() => setMode("request")} type="button">Anfrage</button>
          <button className={mode === "complete" ? "active" : ""} onClick={() => setMode("complete")} type="button">Code</button>
        </div>
        <form onSubmit={submit} className="form">
          <label>Twitch-Name<input value={form.username} onChange={(event) => setForm({ ...form, username: event.target.value })} /></label>
          <label>Passwort<input type="password" value={form.password} onChange={(event) => setForm({ ...form, password: event.target.value })} /></label>
          {mode === "complete" && <label>Einmalcode<input value={form.code} onChange={(event) => setForm({ ...form, code: event.target.value })} /></label>}
          <button type="submit">{mode === "login" ? "Anmelden" : mode === "complete" ? "Registrierung abschliessen" : "Anfragen"}</button>
        </form>
        {message && <div className="notice">{message}</div>}
      </div>
    </section>
  );
}
