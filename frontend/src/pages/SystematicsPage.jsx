import React, { useEffect, useRef, useState } from "react";
import { GitBranch, Image as ImageIcon, Link2, Lock, MousePointer2, Plus, RefreshCw, Save, Trash2 } from "lucide-react";
import { api } from "../api";
import { isAdmin as isAdminRole } from "./shared";

export function SystematicsPage({ user }) {
  // Visitors only look at the tree; the builder is for the admin account.
  const isAdmin = isAdminRole(user);
  const boardRef = useRef(null);
  const centred = useRef(false);
  const [doc, setDoc] = useState({ title: "Systematik", description: "", nodes: [], links: [] });
  const [selectedId, setSelectedId] = useState("");
  const [newBox, setNewBox] = useState({ parentId: "", title: "Neue Box", subtitle: "Beschreibung", color: "#b46cff", template: "custom" });
  const [adminPassword, setAdminPassword] = useState("");
  const [editing, setEditing] = useState(false);
  const [connectFrom, setConnectFrom] = useState("");
  const [message, setMessage] = useState("");
  const [reloadKey, setReloadKey] = useState(0);
  const selected = doc.nodes.find((node) => node.id === selectedId) || doc.nodes[0];
  const parentId = selected ? parentForNode(doc, selected.id) : "";
  const nodeOptions = buildNodeOptions(doc);
  const selectedPath = selected ? pathForNode(doc, selected.id) : "";

  useEffect(() => {
    api("/api/systematics")
      .then((result) => {
        setDoc(autoLayoutSystematics({ ...result, links: primaryTreeLinks(result) }));
        setSelectedId(result.nodes?.[0]?.id || "");
        setNewBox((current) => ({ ...current, parentId: result.nodes?.[0]?.id || "" }));
      })
      .catch((err) => setMessage(err.message));
  }, [reloadKey]);

  // The tree is laid out on a wide fixed canvas; on narrow screens start with
  // its root in view instead of the empty left edge.
  useEffect(() => {
    const board = boardRef.current;
    const root = doc.nodes[0];
    if (centred.current || !board || !root) return;
    centred.current = true;
    board.scrollLeft = Math.max(0, Number(root.x || 0) + 82 - board.clientWidth / 2);
  }, [doc.nodes]);

  function updateDoc(patch) {
    setDoc((current) => ({ ...current, ...patch }));
  }

  function updateNode(id, patch) {
    setDoc((current) => ({
      ...current,
      nodes: current.nodes.map((node) => (node.id === id ? { ...node, ...patch } : node)),
    }));
  }

  function selectNode(nodeId) {
    setSelectedId(nodeId);
    setNewBox((current) => ({ ...current, parentId: nodeId }));
  }

  function addNode(overrides = {}) {
    const parent = doc.nodes.find((node) => node.id === (overrides.parentId || newBox.parentId || selected?.id)) || doc.nodes[0];
    const id = `node-${Date.now()}`;
    const node = {
      id,
      title: overrides.title || newBox.title || "Neue Box",
      subtitle: overrides.subtitle || newBox.subtitle || "Beschreibung",
      color: overrides.color || newBox.color || "#b46cff",
      image_url: "",
      x: 0,
      y: 0,
    };
    setDoc((current) => autoLayoutSystematics({
      ...current,
      nodes: [...current.nodes, node],
      links: parent ? [...current.links.filter((link) => link.target !== id), { source: parent.id, target: id }] : current.links,
    }));
    setSelectedId(id);
    setNewBox((current) => ({ ...current, title: "Neue Box", subtitle: "Beschreibung", template: "custom", parentId: parent?.id || "" }));
  }

  function deleteNode() {
    if (!selected || doc.nodes.length <= 1) return;
    setDoc((current) => autoLayoutSystematics({
      ...current,
      nodes: current.nodes.filter((node) => node.id !== selected.id),
      links: current.links.filter((link) => link.source !== selected.id && link.target !== selected.id),
    }));
    setSelectedId(doc.nodes.find((node) => node.id !== selected.id)?.id || "");
  }

  function handleConnect(nodeId) {
    if (!editing) return;
    if (!connectFrom) {
      setConnectFrom(nodeId);
      setMessage("Zielbox anklicken, um automatisch zu verbinden.");
      return;
    }
    if (connectFrom !== nodeId) {
      if (descendantsForNode(doc, nodeId).has(connectFrom)) {
        setMessage("Diese Verbindung würde eine Schleife bauen. Bitte anders einsortieren.");
        setConnectFrom("");
        return;
      }
      setDoc((current) => {
        const exists = current.links.some((link) => link.source === connectFrom && link.target === nodeId);
        return exists ? current : autoLayoutSystematics({ ...current, links: [...current.links, { source: connectFrom, target: nodeId }] });
      });
    }
    setConnectFrom("");
  }

  function removeLink(source, target) {
    setDoc((current) => autoLayoutSystematics({ ...current, links: current.links.filter((link) => link.source !== source || link.target !== target) }));
  }

  function changeParent(nodeId, nextParentId) {
    if (!nodeId || nodeId === nextParentId) return;
    const descendantIds = descendantsForNode(doc, nodeId);
    if (descendantIds.has(nextParentId)) {
      setMessage("Diese Box kann nicht unter ihr eigenes Kind einsortiert werden.");
      return;
    }
    setDoc((current) => autoLayoutSystematics({
      ...current,
      links: [
        ...current.links.filter((link) => link.target !== nodeId),
        ...(nextParentId ? [{ source: nextParentId, target: nodeId }] : []),
      ],
    }));
  }

  function applyTemplate(templateKey) {
    const template = systematicsTemplates.find((item) => item.id === templateKey);
    if (!template) return;
    setNewBox((current) => ({ ...current, template: templateKey, title: template.title, subtitle: template.subtitle, color: template.color }));
  }

  function pointerDown(event, node) {
    event.preventDefault();
    if (connectFrom) {
      handleConnect(node.id);
      return;
    }
    selectNode(node.id);
  }

  function addSibling() {
    addNode({ parentId, title: "Neue Box daneben" });
  }

  function repairStructure() {
    setDoc((current) => autoLayoutSystematics({ ...current, links: primaryTreeLinks(current) }));
    setMessage("Struktur bereinigt: jede Box hat nur noch eine Haupt-Elternbox.");
  }

  async function unlock() {
    try {
      await api("/api/admin/overview", { headers: { "X-Admin-Password": adminPassword } });
      setEditing(true);
      setMessage("Bearbeitungsmodus aktiv.");
    } catch (err) {
      setMessage(err.message);
    }
  }

  async function save() {
    try {
      const arranged = autoLayoutSystematics({ ...doc, links: primaryTreeLinks(doc) });
      const result = await api("/api/admin/systematics", {
        method: "PUT",
        headers: { "X-Admin-Password": adminPassword },
        body: JSON.stringify(arranged),
      });
      setDoc(arranged);
      setMessage(result.message);
      setReloadKey((value) => value + 1);
    } catch (err) {
      setMessage(err.message);
    }
  }

  function imageUpload(event) {
    const file = event.target.files?.[0];
    if (!file || !selected) return;
    const reader = new FileReader();
    reader.onload = () => updateNode(selected.id, { image_url: String(reader.result || "") });
    reader.readAsDataURL(file);
  }

  const nodeById = new Map(doc.nodes.map((node) => [node.id, node]));

  return (
    <section className="systematicsShell">
      <div className="sectionHero systematicsHero">
        <div>
          <p className="kicker">Baukasten</p>
          <h1>{doc.title}</h1>
          <p>{doc.description}</p>
        </div>
        <GitBranch size={68} />
      </div>
      <div className={`systematicsLayout ${isAdmin ? "" : "viewOnly"}`}>
        <div className="systematicsBoardWrap">
          {isAdmin && <div className="systematicsToolbar">
            <div>
              <span className={editing ? "editBadge active" : "editBadge"}>{editing ? "Admin Bearbeitung aktiv" : "Nur Ansicht"}</span>
              {connectFrom && <span className="editBadge active">Zielbox anklicken: verbindet und sortiert automatisch</span>}
            </div>
            <div>
              <button className="ghost" onClick={() => setConnectFrom(selected?.id || "")} disabled={!editing || !selected} type="button"><Link2 size={16} /> Spezial-Verbindung</button>
              <button onClick={() => addNode({ parentId: selected?.id })} disabled={!editing || !selected} type="button"><Plus size={16} /> Kind zu Auswahl</button>
              <button className="ghost" onClick={addSibling} disabled={!editing || !selected} type="button"><Plus size={16} /> Daneben</button>
              <button className="ghost" onClick={() => setDoc((current) => autoLayoutSystematics(current))} disabled={!editing} type="button"><RefreshCw size={16} /> Auto sortieren</button>
              <button className="ghost" onClick={save} disabled={!editing} type="button"><Save size={16} /> Speichern</button>
            </div>
          </div>}
          <div className="systematicsBoard" ref={boardRef}>
            <svg className="systematicsLinks" viewBox="0 0 1080 650" preserveAspectRatio="none">
              {doc.links.map((link) => {
                const source = nodeById.get(link.source);
                const target = nodeById.get(link.target);
                if (!source || !target) return null;
                const x1 = Number(source.x || 0) + 82;
                const y1 = Number(source.y || 0) + 104;
                const x2 = Number(target.x || 0) + 82;
                const y2 = Number(target.y || 0);
                const mid = (y1 + y2) / 2;
                return <path key={`${link.source}-${link.target}`} d={`M ${x1} ${y1} C ${x1} ${mid}, ${x2} ${mid}, ${x2} ${y2}`} />;
              })}
            </svg>
            {doc.nodes.map((node) => (
              <button
                className={`systemNode ${selected?.id === node.id ? "selected" : ""} ${connectFrom === node.id ? "connecting" : ""}`}
                key={node.id}
                onClick={() => selectNode(node.id)}
                onDoubleClick={() => handleConnect(node.id)}
                onPointerDown={(event) => pointerDown(event, node)}
                style={{ left: node.x, top: node.y, "--node-color": node.color }}
                type="button"
              >
                <span className="systemNodeImage">{node.image_url ? <img src={node.image_url} alt="" /> : <GitBranch size={28} />}</span>
                <strong>{node.title}</strong>
                <small>{node.subtitle}</small>
              </button>
            ))}
          </div>
        </div>
        {isAdmin && <aside className="systematicsEditor">
          <div className="panel form">
            <h2><Lock size={18} /> Admin</h2>
            <label>Admin Passwort<input type="password" value={adminPassword} onChange={(event) => setAdminPassword(event.target.value)} /></label>
            <button onClick={unlock} type="button"><MousePointer2 size={16} /> Builder freischalten</button>
            {message && <div className="notice">{message}</div>}
          </div>
          <div className="panel form systematicsQuickAdd">
            <h2><Plus size={18} /> Neue Box</h2>
            <div className="builderHint">
              <strong>1. Ziel wählen</strong>
              <span>Beispiel: für Huhn erst `Vögel` oder `Hühnervögel` auswählen, dann einfügen.</span>
            </div>
            <label>Gehört zu
              <select disabled={!editing} value={newBox.parentId || selected?.id || ""} onChange={(event) => setNewBox({ ...newBox, parentId: event.target.value })}>
                {nodeOptions.map((option) => <option value={option.id} key={option.id}>{option.label}</option>)}
              </select>
            </label>
            <label>Text<input disabled={!editing} value={newBox.title} onChange={(event) => setNewBox({ ...newBox, title: event.target.value, template: "custom" })} /></label>
            <label>Untertext<input disabled={!editing} value={newBox.subtitle} onChange={(event) => setNewBox({ ...newBox, subtitle: event.target.value, template: "custom" })} /></label>
            <label>Farbe<input disabled={!editing} type="color" value={newBox.color} onChange={(event) => setNewBox({ ...newBox, color: event.target.value, template: "custom" })} /></label>
            <div className="newBoxPreview" style={{ "--node-color": newBox.color }}>
              <span>{doc.nodes.find((node) => node.id === newBox.parentId)?.title || "Oberste Ebene"}</span>
              <strong>{newBox.title}</strong>
              <small>{newBox.subtitle}</small>
            </div>
            <button onClick={() => addNode({ parentId: newBox.parentId })} disabled={!editing || !newBox.parentId} type="button"><Plus size={16} /> Unter dieser Box einfügen</button>
          </div>
          {selected && (
            <div className="panel form selectedBoxEditor">
              <h2><MousePointer2 size={18} /> Box bearbeiten</h2>
              {selectedPath && <div className="builderHint"><strong>Aktueller Pfad</strong><span>{selectedPath}</span></div>}
              <div className="editorActions">
                <button onClick={() => addNode({ parentId: selected.id, title: "Neue Unterbox" })} disabled={!editing} type="button">Kind hinzufügen</button>
                <button className="ghost dangerButton" onClick={deleteNode} disabled={!editing || doc.nodes.length <= 1} type="button"><Trash2 size={16} /></button>
              </div>
              <label>Diese Box gehört zu
                <select disabled={!editing || doc.nodes.length <= 1} value={parentId} onChange={(event) => changeParent(selected.id, event.target.value)}>
                  <option value="">Oberste Ebene</option>
                  {nodeOptions.filter((option) => option.id !== selected.id && !descendantsForNode(doc, selected.id).has(option.id)).map((option) => <option value={option.id} key={option.id}>{option.label}</option>)}
                </select>
              </label>
              <label>Text<input disabled={!editing} value={selected.title} onChange={(event) => updateNode(selected.id, { title: event.target.value })} /></label>
              <label>Untertext<input disabled={!editing} value={selected.subtitle} onChange={(event) => updateNode(selected.id, { subtitle: event.target.value })} /></label>
              <label>Farbe<input disabled={!editing} type="color" value={selected.color} onChange={(event) => updateNode(selected.id, { color: event.target.value })} /></label>
              <label>Bild-URL<input disabled={!editing} value={selected.image_url?.startsWith("data:") ? "" : selected.image_url} onChange={(event) => updateNode(selected.id, { image_url: event.target.value })} /></label>
              <label className="fileInput"><ImageIcon size={16} /> Bild hochladen<input disabled={!editing} type="file" accept="image/*" onChange={imageUpload} /></label>
            </div>
          )}
          <details className="panel systematicsAdvanced">
            <summary>Erweitert</summary>
            <div className="form">
              <label>Systematik Titel<input disabled={!editing} value={doc.title} onChange={(event) => updateDoc({ title: event.target.value })} /></label>
              <label>Beschreibung<textarea disabled={!editing} value={doc.description} onChange={(event) => updateDoc({ description: event.target.value })} /></label>
              <label>Vorlage
                <select disabled={!editing} value={newBox.template} onChange={(event) => applyTemplate(event.target.value)}>
                  {systematicsTemplates.map((template) => <option value={template.id} key={template.id}>{template.label}</option>)}
                </select>
              </label>
              <div className="templateChips">
                {systematicsTemplates.slice(2).map((template) => (
                  <button disabled={!editing} onClick={() => applyTemplate(template.id)} type="button" key={template.id} style={{ "--node-color": template.color }}>{template.label}</button>
                ))}
              </div>
            </div>
          </details>
          <div className="panel">
            <h2><Link2 size={18} /> Verbindungen</h2>
            <button className="ghost repairButton" disabled={!editing} onClick={repairStructure} type="button"><RefreshCw size={16} /> Hauptstruktur bereinigen</button>
            <div className="linkList">
              {doc.links.map((link) => <button disabled={!editing} onClick={() => removeLink(link.source, link.target)} type="button" key={`${link.source}-${link.target}`}>{nodeById.get(link.source)?.title}{" -> "}{nodeById.get(link.target)?.title}</button>)}
            </div>
          </div>
        </aside>}
      </div>
    </section>
  );
}

export function TypeIcon() {
  return <span className="typeIcon">T</span>;
}

export const systematicsTemplates = [
  { id: "custom", label: "Eigene Box", title: "Neue Box", subtitle: "Beschreibung", color: "#b46cff" },
  { id: "kingdom", label: "Reich", title: "Tierreich", subtitle: "Animalia", color: "#ffcf8a" },
  { id: "class", label: "Klasse", title: "Vögel", subtitle: "Aves", color: "#7af4dc" },
  { id: "order", label: "Ordnung", title: "Hühnervögel", subtitle: "Galliformes", color: "#ff6fb7" },
  { id: "family", label: "Familie", title: "Fasanenartige", subtitle: "Phasianidae", color: "#c88956" },
  { id: "genus", label: "Gattung", title: "Kammhühner", subtitle: "Gallus", color: "#b46cff" },
  { id: "species", label: "Art", title: "Haushuhn", subtitle: "Gallus gallus domesticus", color: "#ffcf8a" },
  { id: "mammal", label: "Säugetier", title: "Säugetiere", subtitle: "Mammalia", color: "#7af4dc" },
  { id: "reptile", label: "Reptil", title: "Reptilien", subtitle: "Reptilia", color: "#8edb75" },
];

export function parentForNode(doc, nodeId) {
  return doc.links.find((link) => link.target === nodeId)?.source || "";
}

export function pathForNode(doc, nodeId) {
  const byId = new Map(doc.nodes.map((node) => [node.id, node]));
  const parts = [];
  const seen = new Set();
  let currentId = nodeId;
  while (currentId && byId.has(currentId) && !seen.has(currentId)) {
    seen.add(currentId);
    parts.unshift(byId.get(currentId)?.title || "Box");
    currentId = parentForNode(doc, currentId);
  }
  return parts.join(" > ");
}

export function buildNodeOptions(doc) {
  return doc.nodes
    .map((node) => ({ id: node.id, label: pathForNode(doc, node.id) || node.title }))
    .sort((a, b) => a.label.localeCompare(b.label, "de"));
}

export function primaryTreeLinks(doc) {
  const ids = new Set(doc.nodes.map((node) => node.id));
  const accepted = [];
  const targetSeen = new Set();
  for (const link of doc.links) {
    if (!ids.has(link.source) || !ids.has(link.target) || link.source === link.target || targetSeen.has(link.target)) continue;
    const draft = { ...doc, links: [...accepted, link] };
    if (descendantsForNode(draft, link.target).has(link.source)) continue;
    accepted.push(link);
    targetSeen.add(link.target);
  }
  return accepted;
}

export function descendantsForNode(doc, nodeId) {
  const children = new Map(doc.nodes.map((node) => [node.id, []]));
  doc.links.forEach((link) => children.get(link.source)?.push(link.target));
  const result = new Set();
  const queue = [...(children.get(nodeId) || [])];
  while (queue.length) {
    const current = queue.shift();
    if (!current || result.has(current)) continue;
    result.add(current);
    queue.push(...(children.get(current) || []));
  }
  return result;
}

export function autoLayoutSystematics(input) {
  const nodes = Array.isArray(input?.nodes) ? input.nodes : [];
  const rawLinks = Array.isArray(input?.links) ? input.links : [];
  const ids = new Set(nodes.map((node) => node.id));
  const links = rawLinks.filter((link) => ids.has(link.source) && ids.has(link.target) && link.source !== link.target);
  const incoming = new Map(nodes.map((node) => [node.id, 0]));
  const children = new Map(nodes.map((node) => [node.id, []]));
  links.forEach((link) => {
    incoming.set(link.target, (incoming.get(link.target) || 0) + 1);
    children.get(link.source)?.push(link.target);
  });

  const roots = nodes.filter((node) => (incoming.get(node.id) || 0) === 0);
  const levelById = new Map();
  const queue = (roots.length ? roots : nodes.slice(0, 1)).map((node) => ({ id: node.id, level: 0 }));
  while (queue.length) {
    const current = queue.shift();
    if (!current) continue;
    const previous = levelById.get(current.id);
    if (previous !== undefined && previous <= current.level) continue;
    levelById.set(current.id, current.level);
    (children.get(current.id) || []).forEach((childId) => queue.push({ id: childId, level: current.level + 1 }));
  }

  nodes.forEach((node) => {
    if (!levelById.has(node.id)) levelById.set(node.id, Math.max(0, levelById.size ? Math.max(...levelById.values()) + 1 : 0));
  });

  const levels = new Map();
  nodes.forEach((node) => {
    const level = levelById.get(node.id) || 0;
    levels.set(level, [...(levels.get(level) || []), node]);
  });

  const width = 1080;
  const nodeWidth = 164;
  const top = 42;
  const rowGap = 156;
  const arrangedNodes = nodes.map((node) => {
    const level = levelById.get(node.id) || 0;
    const row = levels.get(level) || [];
    const index = row.findIndex((item) => item.id === node.id);
    const gap = Math.max(24, (width - row.length * nodeWidth) / (row.length + 1));
    return {
      ...node,
      x: Math.round(gap + index * (nodeWidth + gap)),
      y: Math.round(top + level * rowGap),
    };
  });

  return {
    title: input?.title || "Systematik",
    description: input?.description || "",
    nodes: arrangedNodes,
    links,
  };
}
