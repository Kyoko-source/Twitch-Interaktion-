import React, { useEffect, useRef, useState } from "react";
import { Ban, LogOut, Shield, ShieldOff, Unlock } from "lucide-react";
import { requestId } from "./useGameRewards";

const ROLES = { member: "Mitglied", vip: "VIP", moderator: "Moderator", admin: "Admin" };
export function AdminMembers({ users, adminCall, onUpdated }) {
  const [query, setQuery] = useState(""), [draft, setDraft] = useState({});
  const [action, setAction] = useState(null), [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false), [message, setMessage] = useState("");
  const lock = useRef(false), dialog = useRef(null), actionId = useRef(null);
  useEffect(() => { setDraft({}); }, [users]);
  useEffect(() => { if (action) { dialog.current?.showModal(); setReason(""); actionId.current = requestId(); } }, [action]);

  async function role(user, nextRole) {
    if (lock.current) return;
    lock.current = true; setBusy(true); setMessage("");
    try {
      await adminCall("/api/admin/role", { method: "POST", body: JSON.stringify({ username: user.username, role: nextRole }) });
      setMessage(`${user.username}: ${nextRole === "member" ? "Sonderrolle entfernt. Jetzt normales Mitglied." : `Rolle ${ROLES[nextRole]} gespeichert.`}`);
      onUpdated();
    } catch (error) { setMessage(error.message); }
    finally { lock.current = false; setBusy(false); }
  }
  async function moderate() {
    if (lock.current || !action) return;
    lock.current = true; setBusy(true); setMessage("");
    try {
      const result = await adminCall(`/api/admin/members/${encodeURIComponent(action.user.username)}/action`, {
        method: "POST", body: JSON.stringify({ action: action.type, reason, request_id: actionId.current }),
      });
      setMessage(`${action.user.username}: ${result.message}`); setAction(null); onUpdated();
    } catch (error) { setMessage(error.message); }
    finally { lock.current = false; setBusy(false); }
  }
  const filtered = users.filter((user) => user.username.toLowerCase().includes(query.toLowerCase()));
  return <section className="adminMembers panel">
    <div className="adminMemberHeading"><div><h2>Mitglieder verwalten</h2><p>Rollen vergeben oder entfernen, Sitzungen beenden und Konten sperren.</p></div><label>Suchen<input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Twitch-Name" /></label></div>
    {message && <p className="notice" role="status">{message}</p>}
    <div className="adminMemberList">{filtered.map((user) => <article className="adminMemberRow" key={user.username}>
      <div className="adminMemberIdentity"><strong>{user.username}</strong><span className={user.banned ? "memberBanned" : ""}>{user.banned ? "Gesperrt" : ROLES[user.role] || "Mitglied"}</span>{user.ban_reason && <small>{user.ban_reason}</small>}</div>
      <div className="adminMemberRole"><select aria-label={`Rolle für ${user.username}`} value={draft[user.username] ?? user.role ?? "member"} disabled={busy} onChange={(event) => setDraft((current) => ({ ...current, [user.username]: event.target.value }))}>{Object.entries(ROLES).map(([id, label]) => <option key={id} value={id}>{label}</option>)}</select>
        <button type="button" className="ghost" disabled={busy || (draft[user.username] ?? user.role ?? "member") === (user.role || "member")} onClick={() => role(user, draft[user.username])}><Shield size={15} /> Rolle speichern</button></div>
      <div className="adminMemberActions">{user.role && user.role !== "member" && <button type="button" className="ghost" disabled={busy} onClick={() => role(user, "member")}><ShieldOff size={15} /> Rolle entfernen</button>}
        {!user.banned && <button type="button" className="ghost" disabled={busy} onClick={() => setAction({ type: "kick", user })}><LogOut size={15} /> Kicken</button>}
        <button type="button" className={user.banned ? "ghost" : "memberBanButton"} disabled={busy} onClick={() => setAction({ type: user.banned ? "unban" : "ban", user })}>{user.banned ? <Unlock size={15} /> : <Ban size={15} />}{user.banned ? "Entbannen" : "Bannen"}</button>
      </div>
    </article>)}</div>
    {!filtered.length && <p>Keine passenden Mitglieder.</p>}
    {action && <dialog ref={dialog} className="adminMemberDialog" aria-labelledby="member-action-title" onCancel={(event) => { if (busy) event.preventDefault(); else setAction(null); }}>
      <h3 id="member-action-title">{action.user.username} {action.type === "kick" ? "kicken" : action.type === "ban" ? "bannen" : "entbannen"}?</h3>
      <p>{action.type === "kick" ? "Alle laufenden Sitzungen und Spielrunden werden beendet. Das Mitglied kann sich anschließend neu anmelden." : action.type === "ban" ? "Das Mitglied wird auf allen Geräten abgemeldet und kann sich nicht mehr anmelden. Du kannst die Sperre hier wieder aufheben." : "Das Mitglied darf sich wieder anmelden. Alte Sitzungen bleiben ungültig."}</p>
      {action.type === "ban" && <label>Grund (optional)<textarea maxLength={300} value={reason} onChange={(event) => setReason(event.target.value)} disabled={busy} /></label>}
      <div><button type="button" className="ghost" disabled={busy} onClick={() => setAction(null)}>Abbrechen</button><button type="button" disabled={busy} onClick={moderate}>{busy ? "Wird gespeichert …" : "Aktion bestätigen"}</button></div>
    </dialog>}
  </section>;
}

export function AdminPoints({ users, adminCall, onUpdated }) {
  const [username, setUsername] = useState(""), [amount, setAmount] = useState(0), [busy, setBusy] = useState(false), [message, setMessage] = useState("");
  const booking = useRef(null), lock = useRef(false);
  async function submit(event) {
    event.preventDefault(); if (lock.current) return;
    lock.current = true; setBusy(true);
    const signature = JSON.stringify([username, Number(amount)]);
    if (booking.current?.signature !== signature) booking.current = { signature, id: requestId() };
    try {
      const result = await adminCall("/api/admin/points", { method: "POST", body: JSON.stringify({ username, chickens_delta: Number(amount), request_id: booking.current.id }) });
      setMessage(`${result.message} ${username}: ${result.wallet.chickens} Chickens verfügbar.`);
      booking.current = null; setAmount(0); onUpdated();
    } catch (error) { setMessage(error.message); }
    finally { lock.current = false; setBusy(false); }
  }
  return <form className="panel form" onSubmit={submit}><h2>Chickens buchen</h2><p>Admin-Buchungen ändern das Guthaben. Für die Rangliste zählen ausschließlich erspielte Chickens.</p>
    <label>Mitglied<select required value={username} disabled={busy} onChange={(event) => { setUsername(event.target.value); booking.current = null; }}><option value="">Mitglied auswählen</option>{users.map((user) => <option key={user.username} value={user.username}>{user.username}</option>)}</select></label>
    <label>Chickens Delta<input type="number" required value={amount} disabled={busy} onChange={(event) => { setAmount(event.target.value); booking.current = null; }} /></label>
    <button type="submit" disabled={busy || !username || Number(amount) === 0}>{busy ? "Wird gebucht …" : "Chickens buchen"}</button>
    {message && <p role="status">{message}</p>}
  </form>;
}
