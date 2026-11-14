import React, { useEffect, useState } from "react";
import { Check, Plus, Shield, Trash2, X } from "lucide-react";
import { ShopAlertsAdmin } from "../economy/ShopAlertsAdmin";
import { AdminMembers, AdminPoints } from "../economy/AdminMembers";
import { api } from "../api";
import { LiveNewsAdmin } from "../live-news/LiveNewsAdmin";
import { Stat } from "./shared";

export function AdminPage() {
  const [password, setPassword] = useState("");
  const [overview, setOverview] = useState(null);
  const [message, setMessage] = useState("");
  const [approvedCode, setApprovedCode] = useState(null);
  const [copied, setCopied] = useState(false);
  const [tab, setTab] = useState("registrations");
  const [reloadKey, setReloadKey] = useState(0);
  const [news, setNews] = useState({ title: "", body: "", image_url: "" });
  const [shop, setShop] = useState({ name: "", description: "", price: 0, category: "Rewards" });
  const [eventForm, setEventForm] = useState({ title: "", description: "", event_date: "" });

  async function adminCall(path, options = {}) {
    return api(path, { ...options, headers: { "X-Admin-Password": password, ...(options.headers || {}) } });
  }

  async function load() {
    try {
      setMessage("");
      const [adminOverview, shopItems, events, newsPosts] = await Promise.all([
        adminCall("/api/admin/overview"),
        api("/api/shop").catch(() => []),
        api("/api/events").catch(() => []),
        api("/api/news").catch(() => []),
      ]);
      setOverview({ ...adminOverview, shop_items: shopItems, events, news_posts: newsPosts });
    } catch (err) {
      setMessage(err.message);
    }
  }

  useEffect(() => {
    if (overview) load();
  }, [reloadKey]);

  async function mutate(path, options, success) {
    try {
      const result = await adminCall(path, options);
      setMessage(success || result.message || "Gespeichert.");
      setReloadKey((value) => value + 1);
    } catch (err) {
      setMessage(err.message);
    }
  }

  async function approveRegistration(id, username) {
    try {
      const result = await adminCall(`/api/admin/registration/${id}/approve`, { method: "POST", body: "{}" });
      setMessage(`Code für ${username}: ${result.code}`);
      setCopied(false);
      setApprovedCode({ username, code: result.code });
      setReloadKey((value) => value + 1);
    } catch (err) {
      setMessage(err.message);
    }
  }

  async function rejectRegistration(id, username) {
    if (!window.confirm(`Registrierung von ${username} ablehnen?`)) return;
    try {
      await adminCall(`/api/admin/registration/${id}/reject`, { method: "POST", body: "{}" });
      setMessage(`Anfrage von ${username} abgelehnt.`);
      setReloadKey((value) => value + 1);
    } catch (err) {
      setMessage(err.message);
    }
  }

  const tabs = [
    ["registrations", "Registrierungen"],
    ["points", "Chickens"],
    ["roles", "Mitglieder & Rollen"],
    ["news", "News"],
    ["live-news", "Live News"],
    ["shop-alerts", "Shop-Alerts"],
    ["shop", "Shop"],
    ["events", "Events"],
    ["support", "Support"],
  ];

  return (
    <section className="stack">
      <div className="adminHero">
        <div>
          <p className="kicker">Admin Center</p>
          <h1>Kontrollraum</h1>
          <p>Registrierungen, Chickens, News, Shop, Events und Meldungen verwalten.</p>
        </div>
        <Shield size={72} />
      </div>
      <div className="panel form">
        <label>Admin Passwort<input type="password" value={password} onChange={(event) => setPassword(event.target.value)} /></label>
        <button onClick={load} type="button">Dashboard laden</button>
        {message && <div className="notice">{message}</div>}
      </div>
      {approvedCode && (
        <div className="approvalCodeModal" role="dialog" aria-modal="true" aria-label={`Einmalcode für ${approvedCode.username}`}>
          <div className="approvalCodeCard">
            <h2>Registrierung genehmigt</h2>
            <p>Gib <b>{approvedCode.username}</b> diesen Einmalcode. Er wird nur jetzt angezeigt und nirgends gespeichert.</p>
            <code data-testid="approval-code">{approvedCode.code}</code>
            <div className="registrationActions">
              <button type="button" onClick={() => navigator.clipboard?.writeText(approvedCode.code).then(() => setCopied(true)).catch(() => {})}>{copied ? <><Check size={16} /> Kopiert</> : "Code kopieren"}</button>
              <button type="button" className="ghost" onClick={() => setApprovedCode(null)}>Fertig</button>
            </div>
          </div>
        </div>
      )}
      {overview && (
        <>
          <div className="adminStats">
            <Stat label="Viewer" value={overview.users.length} />
            <Stat label="Anfragen" value={overview.registration_requests.length} />
            <Stat label="Meldungen" value={overview.support_messages.length} />
            <Stat label="Shop Items" value={overview.shop_items.length} />
          </div>
          <div className="segmented adminTabs">
            {tabs.map(([id, label]) => <button className={tab === id ? "active" : ""} onClick={() => setTab(id)} type="button" key={id}>{label}</button>)}
          </div>
          {tab === "registrations" && <div className="grid">{overview.registration_requests.map((item) => <article className="card" key={item.id}><h3>{item.username}</h3><p>{item.status}</p><div className="registrationActions"><button onClick={() => approveRegistration(item.id, item.username)} type="button"><Check size={16} /> Genehmigen</button><button className="ghost danger" onClick={() => rejectRegistration(item.id, item.username)} type="button"><X size={16} /> Ablehnen</button></div></article>)}</div>}
          {tab === "points" && <AdminPoints users={overview.users} adminCall={adminCall} onUpdated={() => setReloadKey((value) => value + 1)} />}
          {tab === "roles" && <AdminMembers users={overview.users} adminCall={adminCall} onUpdated={() => setReloadKey((value) => value + 1)} />}
          {tab === "news" && (
            <AdminListForm title="News erstellen" form={news} setForm={setNews} fields={["title", "body", "image_url"]} onSubmit={() => mutate("/api/admin/news", { method: "POST", body: JSON.stringify(news) })}>
              {overview.news_posts.map((item) => <AdminRow key={item.id} title={item.title} text={item.body} onDelete={() => mutate(`/api/admin/news/${item.id}`, { method: "DELETE" })} />)}
            </AdminListForm>
          )}
          {tab === "live-news" && <LiveNewsAdmin password={password} />}
          {tab === "shop-alerts" && <ShopAlertsAdmin password={password} />}
          {tab === "shop" && (
            <AdminListForm title="Shop Item erstellen" form={shop} setForm={setShop} fields={["name", "description", "price", "category"]} onSubmit={() => mutate("/api/admin/shop", { method: "POST", body: JSON.stringify({ ...shop, price: Number(shop.price) }) })}>
              {overview.shop_items.map((item) => <AdminRow key={item.id} title={`${item.name} · ${item.price} Chickens`} text={item.description || item.desc} onDelete={() => mutate(`/api/admin/shop/${item.id}`, { method: "DELETE" })} />)}
            </AdminListForm>
          )}
          {tab === "events" && (
            <AdminListForm title="Event erstellen" form={eventForm} setForm={setEventForm} fields={["title", "description", "event_date"]} onSubmit={() => mutate("/api/admin/events", { method: "POST", body: JSON.stringify(eventForm) })}>
              {overview.events.map((item) => <AdminRow key={item.id} title={`${item.title} · ${item.event_date || "TBA"}`} text={item.description} onDelete={() => mutate(`/api/admin/events/${item.id}`, { method: "DELETE" })} />)}
            </AdminListForm>
          )}
          {tab === "support" && <div className="list">{overview.support_messages.map((item) => <AdminRow key={item.id} title={`${item.title} · ${item.category}`} text={`${item.username}: ${item.message}`} onDelete={() => mutate(`/api/admin/support/${item.id}`, { method: "PATCH", body: "{}" }, "Meldung geschlossen.")} />)}</div>}
        </>
      )}
    </section>
  );
}

export function AdminListForm({ title, form, setForm, fields, onSubmit, children }) {
  return (
    <section className="twoCol">
      <form className="panel form" onSubmit={(event) => { event.preventDefault(); onSubmit(); }}>
        <h2>{title}</h2>
        {fields.map((field) => (
          <label key={field}>{field.replace("_", " ")}
            {field === "body" || field === "description" ? <textarea value={form[field] || ""} onChange={(event) => setForm({ ...form, [field]: event.target.value })} /> : <input type={field === "price" ? "number" : "text"} value={form[field] || ""} onChange={(event) => setForm({ ...form, [field]: event.target.value })} />}
          </label>
        ))}
        <button type="submit"><Plus size={16} /> Erstellen</button>
      </form>
      <div className="list">{children}</div>
    </section>
  );
}

export function AdminRow({ title, text, onDelete }) {
  return (
    <article className="rowCard">
      <div><h3>{title}</h3><p>{text}</p></div>
      <button className="ghost dangerButton" onClick={onDelete} type="button"><Trash2 size={16} /></button>
    </article>
  );
}
