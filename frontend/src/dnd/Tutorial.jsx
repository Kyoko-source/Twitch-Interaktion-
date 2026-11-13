import React, { useEffect, useLayoutEffect, useState } from "react";
import { ChevronLeft, ChevronRight, GraduationCap, X } from "lucide-react";

// Every explained control carries data-tip="<key>". The help mode shows
// TIPS[key] on click instead of running the control; the guided tour
// walks through a role-specific list of keys with a spotlight.

export const TIPS = {
  welcome: { t: "Willkommen am Spieltisch!", d: "Diese Tour zeigt dir in einer Minute jeden wichtigen Bereich. Mit „Weiter“ gehst du Schritt für Schritt, mit Esc oder × brichst du jederzeit ab." },
  code: { t: "Tischcode", d: "Ein Klick kopiert den sechsstelligen Code. Schick ihn deinen Freunden: Sie geben ihn in der Lobby unter „Mit Code beitreten“ ein. Der Link in der Adresszeile funktioniert auch." },
  party: { t: "Wer sitzt am Tisch?", d: "Alle Mitglieder mit Rolle. Die Krone markiert den Dungeon Master, gedimmte Namen sind Zuschauer." },
  lobby: { t: "Zur Lobby", d: "Zurück zur Tischübersicht. Du bleibst Mitglied und kannst jederzeit über „Deine Tische“ zurückkehren." },
  leave: { t: "Tisch verlassen", d: "Du verlässt die Runde endgültig, dein Charakter wird entfernt." },
  tour: { t: "Tutorial", d: "Startet diese geführte Tour noch einmal." },
  help: { t: "Erklärmodus", d: "Solange er an ist, löst ein Klick auf einen Knopf nichts aus, sondern erklärt ihn. Nochmal klicken schaltet ihn aus." },
  map: { t: "Die Battlemap", d: "Jedes Feld sind 1,5 m. Spieler ziehen ihren eigenen Helden, der DM zieht alles. Ein Klick auf eine Figur zeigt ihre Karte mit Lebensbalken." },
  token: { t: "Spielfigur", d: "Ring und Balken zeigen die Lebenspunkte: grün, gelb, rot, grau = besiegt. Ein goldener Kreis heißt: Diese Figur ist am Zug. Die Zahl oben rechts sind aktive Zustände." },
  "sel-card": { t: "Ausgewählte Figur", d: "Details zur angeklickten Figur. Bei Monstern siehst du Porträt und Beschreibung, der DM zusätzlich fertige Angriffsknöpfe." },
  "sel-hp": { t: "Schaden & Heilung", d: "Zahl eintippen, dann „Schaden“ oder „Heilen“. Temporäre TP werden zuerst abgezogen. Der Balken animiert sich für alle am Tisch." },
  "sel-conds": { t: "Zustände", d: "Vergiftet, liegend, Konzentration … Ein Klick schaltet einen Zustand an oder aus. Was er bewirkt, steht im Wissen-Reiter unter „Zustände erklärt“." },
  "sel-attacks": { t: "Angriffe des Monsters", d: "Linker Knopf würfelt den Angriff (W20 + Bonus gegen die RK des Ziels), rechter Knopf den Schaden. Rettungswurf-Angriffe zeigen den SG, den die Helden schaffen müssen." },
  "sel-dm": { t: "DM-Steuerung", d: "Kreatur verstecken (Hinterhalt), ihre TP vor Spielern verbergen, das Porträt wechseln oder sie vom Feld nehmen." },
  "tab-sheet": { t: "Charakter-Reiter", d: "Dein Charakterbogen. Fast jeder Wert ist anklickbar und würfelt sofort die passende Probe mit allen Boni." },
  "tab-dice": { t: "Würfel-Reiter", d: "Der Würfelbecher für alles, was der Bogen nicht abdeckt: Schaden, Prozentwürfe, freie Formeln." },
  "tab-combat": { t: "Kampf-Reiter", d: "Die Initiative-Reihenfolge. Wer oben leuchtet, ist dran." },
  "tab-creatures": { t: "Kreaturen-Reiter (DM)", d: "Das Bestiarium. Hier beschwörst du Monster auf die Karte und baust eigene Wesen." },
  "tab-table": { t: "Tisch-Reiter (DM)", d: "Szenen ansagen, Karte einstellen, Tisch schließen und Mitglieder verwalten." },
  "tab-guide": { t: "Wissen-Reiter", d: "Das Regel-Lexikon zum Aufklappen: Was ist DnD, wie funktionieren Proben, Kampf und Zauber, was macht der DM, alle Klassen, Zustände und Monster." },
  "hero-switch": { t: "Heldenauswahl", d: "Wechselt zwischen den Charakterbögen am Tisch. Fremde Bögen kannst du ansehen, aber nur deinen eigenen ändern." },
  "sheet-edit": { t: "Bogen bearbeiten", d: "Öffnet den Baukasten: Klasse, Volk, Stufe, Werte, Fertigkeiten und Notizen. „Speichern“ überträgt alles an den Tisch." },
  "sheet-class": { t: "Klasse wählen", d: "Die Klasse bestimmt Trefferwürfel, Rüstung, Rettungswürfe und Startausrüstung. Alles wird beim Wechsel automatisch vorgeschlagen." },
  "sheet-array": { t: "Standardwerte", d: "Verteilt 15, 14, 13, 12, 10 und 8 so, dass die wichtigsten Attribute deiner Klasse die besten Werte bekommen." },
  "sheet-hp": { t: "Trefferpunkte", d: "Aktuelle und maximale TP, dahinter temporäre TP. Bei 0 TP fällt dein Held bewusstlos um und muss Todesrettungswürfe machen." },
  "sheet-ac": { t: "Rüstungsklasse (RK)", d: "So schwer bist du zu treffen. Ein Angriff muss diesen Wert erreichen." },
  "sheet-init": { t: "Initiative", d: "Klick würfelt W20 + GES-Modifikator, z. B. wenn der DM einen Überraschungskampf ausruft." },
  "sheet-speed": { t: "Tempo", d: "So weit kommst du pro Zug, in Fuß (30 Fuß = 9 m = 6 Felder)." },
  "sheet-prof": { t: "Übungsbonus", d: "Kommt auf alles, worin du geübt bist. Steigt mit der Stufe von +2 bis +6." },
  "sheet-passive": { t: "Passive Wahrnehmung", d: "10 + Wahrnehmungsbonus. Der DM prüft damit heimlich, ob du Fallen oder Lauernde bemerkst." },
  "sheet-abilities": { t: "Attribute", d: "Die großen Zahlen sind Modifikatoren, darunter der Wert. Klick = Attributsprobe. Der „RW“-Knopf würfelt den Rettungswurf, leuchtend bei Übung." },
  "sheet-skills": { t: "Fertigkeiten", d: "Klick würfelt die Probe mit Bonus. Ein gefüllter Punkt bedeutet geübt. Beim Bearbeiten leuchten die Fertigkeiten, die deine Klasse wählen darf." },
  "sheet-notes": { t: "Ausrüstung, Talente, Zauber", d: "Freitext für alles Weitere. Tipp: Zauberplätze als ●●○ notieren und beim Wirken anpassen." },
  "sheet-create": { t: "Held an den Tisch", d: "Speichert deinen neuen Helden. Er erscheint sofort als Figur auf der Karte." },
  "dice-rack": { t: "Würfelbecher", d: "Klick legt einen Würfel in den Becher (mehrfach = mehrere), Doppelklick würfelt ihn sofort einzeln." },
  "dice-formula": { t: "Formel", d: "Wird aus dem Becher gebaut, du kannst aber auch frei tippen: 1d20+5, 4d6kh3 (die besten 3 behalten), 2d8-1." },
  "dice-bonus": { t: "Bonus", d: "Wird auf die Formel addiert, z. B. dein Angriffsbonus." },
  "dice-label": { t: "Wofür?", d: "Beschriftung im Protokoll, damit alle wissen, was gewürfelt wurde." },
  "dice-mode": { t: "Vorteil & Nachteil", d: "Vorteil wirft den ersten W20 doppelt und nimmt den höheren, Nachteil den niedrigeren. Gilt auch für Klicks im Bogen." },
  "dice-hidden": { t: "Verdeckt / privat", d: "Der DM würfelt verdeckt (nur er sieht es). Spieler würfeln privat (nur sie selbst und der DM)." },
  "dice-clear": { t: "Leeren", d: "Leert den Würfelbecher und setzt den Bonus zurück." },
  "dice-roll": { t: "Würfeln!", d: "Wirft die Formel. Alle am Tisch sehen den Wurf groß animiert, eine natürliche 20 oder 1 bekommt eine Extra-Show." },
  "combat-start": { t: "Kampf starten", d: "Würfelt Initiative für alle Helden und sichtbaren Kreaturen und sortiert die Reihenfolge. Danach Runde 1." },
  "combat-next": { t: "Nächster Zug", d: "Gibt den Zug an die nächste Figur weiter. Nach der letzten beginnt eine neue Runde." },
  "combat-end": { t: "Kampf beenden", d: "Löscht die Initiative-Reihenfolge." },
  "combat-list": { t: "Initiative-Reihenfolge", d: "Höchster Wert zuerst. Klick wählt die Figur auf der Karte aus. Der DM kann Werte im Zahlenfeld nachträglich ändern." },
  "cr-bestiary": { t: "Bestiarium", d: "Ein Klick beschwört das Monster mit echten Werten auf die Karte, mit Porträt, Lebensbalken und Angriffen. „Anzahl“ unten gilt auch hier." },
  "cr-custom": { t: "Eigene Kreatur", d: "Baue dein eigenes Wesen: Name, TP, RK, Initiative, Größe, Farbe und Porträt." },
  "cr-art": { t: "Porträt", d: "Wähle eines der gezeichneten Porträts als Aussehen für deine Kreatur." },
  "cr-image": { t: "Eigenes Bild", d: "Optional ein Bildlink (https), der statt des Porträts angezeigt wird." },
  "cr-hidehp": { t: "TP verbergen", d: "Spieler sehen dann nur, wie angeschlagen das Monster wirkt, nicht die genauen Zahlen." },
  "cr-ambush": { t: "Hinterhalt", d: "Die Kreatur ist nur für dich sichtbar, bis du sie mit „Aufdecken“ zeigst." },
  "cr-summon": { t: "Beschwören", d: "Setzt die Kreatur (oder mehrere, nummeriert) auf freie Felder der Karte." },
  "cr-list": { t: "Auf dem Feld", d: "Alle Kreaturen mit exakten TP. Schnell Schaden oder Heilung eintragen, Klick wählt sie auf der Karte aus." },
  "tp-scene": { t: "Szene ansagen", d: "Titel und Erzähltext werden allen als filmische Einblendung gezeigt und im Protokoll festgehalten." },
  "tp-map": { t: "Karte", d: "Größe in Feldern, ein Stimmungsthema oder ein eigenes Kartenbild per https-Link." },
  "tp-lock": { t: "Tisch schließen", d: "Ein geschlossener Tisch nimmt keine neuen Mitglieder mehr auf. Wer schon drin ist, bleibt." },
  "tp-members": { t: "Mitglieder", d: "Alle Mitglieder. Mit dem Symbol rechts entfernst du jemanden vom Tisch." },
  "tp-dissolve": { t: "Tisch auflösen", d: "Löscht den Tisch mit allen Charakteren und Kreaturen endgültig." },
  log: { t: "Protokoll & Chat", d: "Jeder Wurf, jede Szene und jede Nachricht. Würfe zeigen jeden einzelnen Würfel, gestrichene Würfel bei Vorteil oder Nachteil sind durchgestrichen." },
  "log-ic": { t: "Spieler oder Charakter", d: "Schaltet um, ob du als du selbst schreibst oder in der Rolle deines Helden. Rollenspiel-Text erscheint als Zitat." },
  "log-input": { t: "Nachricht", d: "Schreib an den Tisch. Enter sendet." },
  guide: { t: "Wissen", d: "Such oben nach einem Begriff oder wähle ein Thema und klapp die Fragen auf." },
  done: { t: "Bereit für das Abenteuer!", d: "Das war's. Den Erklärmodus (?) oben kannst du jederzeit anschalten. Dann erklärt sich jeder Knopf per Klick. Viel Spaß und gute Würfe!" },
};

const DM_TOUR = ["welcome", "code", "party", "map", ["tab-creatures", "creatures"], ["cr-bestiary", "creatures"], ["cr-custom", "creatures"], ["cr-list", "creatures"], "token",
  ["combat-start", "combat"], ["dice-rack", "dice"], ["dice-mode", "dice"], ["dice-hidden", "dice"], ["tp-scene", "table"], ["tp-map", "table"], "log", "log-ic", ["tab-guide", "guide"], "help", "done"];
const PLAYER_TOUR = ["welcome", "code", "party", ["tab-sheet", "sheet"], ["sheet-abilities", "sheet"], ["sheet-skills", "sheet"], ["sheet-hp", "sheet"], "map", "token",
  ["dice-rack", "dice"], ["dice-mode", "dice"], ["dice-roll", "dice"], ["combat-list", "combat"], "log", "log-ic", ["tab-guide", "guide"], "help", "done"];

export function tourFor(role) { return (role === "dm" ? DM_TOUR : PLAYER_TOUR).map((s) => (Array.isArray(s) ? { tip: s[0], tab: s[1] } : { tip: s })); }

const findTarget = (tip) => [...document.querySelectorAll(`[data-tip="${tip}"]`)].find((el) => el.getClientRects().length);

function useTargetRect(tip, tick) {
  const [rect, setRect] = useState(null);
  useLayoutEffect(() => {
    let frame; let last = "";
    const measure = () => {
      const el = tip && findTarget(tip);
      const r = el?.getBoundingClientRect();
      const sig = r ? `${r.left|0},${r.top|0},${r.width|0},${r.height|0}` : "";
      if (sig !== last) { last = sig; setRect(r ? { left: r.left, top: r.top, width: r.width, height: r.height } : null); }
      frame = requestAnimationFrame(measure);
    };
    measure();
    return () => cancelAnimationFrame(frame);
  }, [tip, tick]);
  return rect;
}

function bubbleStyle(rect) {
  const w = Math.min(340, window.innerWidth - 24);
  if (!rect) return { width: w, left: (window.innerWidth - w) / 2, top: Math.max(80, window.innerHeight * .3) };
  const below = rect.top + rect.height + 14;
  const roomBelow = window.innerHeight - below;
  const left = Math.max(12, Math.min(window.innerWidth - w - 12, rect.left + rect.width / 2 - w / 2));
  if (roomBelow > 190) return { width: w, left, top: below };
  if (rect.top > 210) return { width: w, left, bottom: window.innerHeight - rect.top + 14 };
  return { width: w, left, top: Math.max(12, Math.min(window.innerHeight - 220, rect.top + 20)) };
}

export function Tour({ steps, setTab, onClose }) {
  const [index, setIndex] = useState(0);
  const step = steps[index];
  useEffect(() => { if (step.tab) setTab(step.tab); }, [step, setTab]);
  useEffect(() => {
    const t = setTimeout(() => findTarget(step.tip)?.scrollIntoView({ block: "nearest", behavior: "smooth" }), 60);
    return () => clearTimeout(t);
  }, [step]);
  useEffect(() => {
    const key = (e) => { if (e.key === "Escape") onClose(); if (e.key === "ArrowRight") setIndex((i) => Math.min(steps.length - 1, i + 1)); if (e.key === "ArrowLeft") setIndex((i) => Math.max(0, i - 1)); };
    window.addEventListener("keydown", key);
    return () => window.removeEventListener("keydown", key);
  }, [steps.length, onClose]);
  const rect = useTargetRect(step.tip, index);
  const tip = TIPS[step.tip] || { t: step.tip, d: "" };
  const last = index === steps.length - 1;
  const pad = 6;
  return <div className="tourLayer" role="dialog" aria-modal="true" aria-label="Tutorial">
    <div className={`tourSpot ${rect ? "" : "isCenter"}`} style={rect ? { left: rect.left - pad, top: rect.top - pad, width: rect.width + pad * 2, height: rect.height + pad * 2 } : undefined} />
    <div className="tourBubble" style={bubbleStyle(rect)} key={index}>
      <header><GraduationCap size={18} /><small>Schritt {index + 1} von {steps.length}</small><button type="button" className="quietIcon" onClick={onClose} aria-label="Tutorial beenden"><X size={16} /></button></header>
      <h4>{tip.t}</h4>
      <p>{tip.d}</p>
      <div className="tourProgress"><span style={{ width: `${((index + 1) / steps.length) * 100}%` }} /></div>
      <footer>
        <button type="button" className="ghost" disabled={index === 0} onClick={() => setIndex(index - 1)}><ChevronLeft size={16} />Zurück</button>
        <button type="button" onClick={() => (last ? onClose() : setIndex(index + 1))}>{last ? "Los geht's!" : <>Weiter<ChevronRight size={16} /></>}</button>
      </footer>
    </div>
  </div>;
}

// Help mode: capture clicks on [data-tip] elements and explain them.
export function useHelpMode(active) {
  const [bubble, setBubble] = useState(null);
  useEffect(() => {
    if (!active) { setBubble(null); return undefined; }
    const block = (e) => {
      if (e.target.closest(".helpBubble, [data-help-pass]")) return;
      const el = e.target.closest("[data-tip]");
      if (!el || !el.closest(".dndShell")) return;
      // Tabs keep working so every panel can be explored in help mode.
      if (!el.hasAttribute("data-help-also")) { e.preventDefault(); e.stopPropagation(); }
      if (e.type === "click") {
        const r = el.getBoundingClientRect();
        setBubble({ tip: el.dataset.tip, rect: { left: r.left, top: r.top, width: r.width, height: r.height } });
      }
    };
    const close = (e) => { if (e.key === "Escape") setBubble(null); };
    const events = ["pointerdown", "mousedown", "click", "dblclick"];
    events.forEach((t) => document.addEventListener(t, block, true));
    window.addEventListener("keydown", close);
    const drop = () => setBubble(null);
    window.addEventListener("scroll", drop, true);
    return () => { events.forEach((t) => document.removeEventListener(t, block, true)); window.removeEventListener("keydown", close); window.removeEventListener("scroll", drop, true); };
  }, [active]);
  return [bubble, () => setBubble(null)];
}

export function HelpBubble({ bubble, onClose }) {
  if (!bubble) return null;
  const tip = TIPS[bubble.tip] || { t: "Ohne Erklärung", d: "" };
  const { rect } = bubble;
  return <>
    <div className="helpRing" style={{ left: rect.left - 4, top: rect.top - 4, width: rect.width + 8, height: rect.height + 8 }} />
    <div className="helpBubble tourBubble" style={bubbleStyle(rect)} role="tooltip">
      <header><span className="helpQ">?</span><h4>{tip.t}</h4><button type="button" className="quietIcon" onClick={onClose} aria-label="Erklärung schließen"><X size={16} /></button></header>
      <p>{tip.d}</p>
    </div>
  </>;
}
