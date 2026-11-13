import React, { useMemo, useState } from "react";
import { BookOpen, ChevronDown, Crown, Dices, Flame, HeartPulse, Map as MapIcon, Moon, Search, Shield, Skull, Sparkles, Swords, Users, Wand2 } from "lucide-react";
import { CLASSES, MONSTERS, signed } from "./rules";
import { MonsterArt } from "./MonsterArt";

// Rules primer for newcomers. Each topic is an accordion card; `text`
// holds the searchable plain text, `body` what is rendered.

export const CONDITION_INFO = {
  Blind: "Sieht nichts. Angriffe gegen dich haben Vorteil, deine eigenen Nachteil.",
  Bezaubert: "Du greifst den Bezauberer nicht an, er hat Vorteil bei sozialen Proben gegen dich.",
  Taub: "Hört nichts, scheitert automatisch an Proben, die Gehör brauchen.",
  Erschöpft: "Stapelt sich in Stufen. Jede Stufe zieht 2 von W20-Proben ab und senkt das Tempo um 1,5 m. Stufe 6 ist der Tod.",
  Verängstigt: "Nachteil auf Proben und Angriffe, solange du die Quelle der Angst siehst. Du kannst dich ihr nicht nähern.",
  Gepackt: "Tempo 0. Endet, wenn der Packende kampfunfähig wird oder du dich losreißt.",
  Kampfunfähig: "Keine Aktionen, Bonusaktionen oder Reaktionen.",
  Unsichtbar: "Kann nicht gesehen werden. Deine Angriffe haben Vorteil, Angriffe gegen dich Nachteil.",
  Gelähmt: "Kampfunfähig, kann sich nicht bewegen. Treffer aus 1,5 m sind automatisch kritisch.",
  Versteinert: "Zu Stein geworden, kampfunfähig, Resistenz gegen jeden Schaden.",
  Vergiftet: "Nachteil bei Angriffswürfen und Attributsproben.",
  Liegend: "Nur Kriechen. Nahkampfangriffe gegen dich haben Vorteil, Fernkampf Nachteil. Aufstehen kostet halbes Tempo.",
  Festgesetzt: "Tempo 0. Angriffe gegen dich haben Vorteil, deine Nachteil, Nachteil auf GES-Rettungswürfe.",
  Betäubt: "Kampfunfähig, scheitert an STÄ- und GES-Rettungswürfen. Angriffe gegen dich haben Vorteil.",
  Bewusstlos: "Kampfunfähig, liegend, lässt alles fallen. Treffer aus 1,5 m sind kritisch.",
  Konzentration: "Du hältst einen Konzentrationszauber aufrecht. Bei Schaden: KON-Rettungswurf SG 10 (oder halber Schaden, wenn höher).",
};

const P = ({ children }) => <p>{children}</p>;
const Tip = ({ children }) => <div className="guideTip"><Sparkles size={15} /><span>{children}</span></div>;
const Table = ({ head, rows }) => <table className="guideTable"><thead><tr>{head.map((h) => <th key={h}>{h}</th>)}</tr></thead><tbody>{rows.map((r) => <tr key={r[0]}>{r.map((c, i) => <td key={i}>{c}</td>)}</tr>)}</tbody></table>;

const TOPICS = [
  { id: "what", icon: BookOpen, title: "Was ist Dungeons & Dragons?", items: [
    { q: "Das Spiel in einem Satz", text: "Gemeinsam erzählte Abenteuer mit Würfeln",
      body: <><P>Dungeons & Dragons ist ein <b>Pen-and-Paper-Rollenspiel</b>: Ihr erzählt gemeinsam eine Geschichte. Jeder Spieler steuert einen Helden, der Dungeon Master (DM) beschreibt die Welt und spielt alle anderen Figuren. Würfel entscheiden, ob riskante Aktionen gelingen.</P>
        <P>Es gibt kein Spielbrett, das alles vorgibt, und keine Gewinner. Ihr gewinnt zusammen, wenn die Geschichte gut wird, egal ob der Drache fällt oder eure Helden glorreich scheitern.</P></> },
    { q: "Was braucht man?", text: "Würfel Charakterbogen Freunde Fantasie",
      body: <><P>Klassisch: Würfel, Charakterbögen, Stifte und ein paar Snacks. Hier am Tisch habt ihr alles im Browser: Würfel von W4 bis W100, Charakterbögen, eine Battlemap und den Chat.</P>
        <P>Eine Runde braucht <b>einen DM</b> und am besten <b>3 bis 5 Spieler</b>. Hier sind bis zu acht Helden möglich, Zuschauer beliebig viele.</P></> },
    { q: "Kampagne, One-Shot, Sitzung?", text: "Kampagne One-Shot Sitzung",
      body: <><P><b>Sitzung:</b> ein Spielabend, meist 2 bis 4 Stunden. <b>One-Shot:</b> ein Abenteuer, das in einer Sitzung endet, ideal zum Reinschnuppern. <b>Kampagne:</b> eine lange Geschichte über viele Sitzungen, in der eure Helden Stufe um Stufe stärker werden.</P>
        <Tip>Für die erste Runde ist ein One-Shot mit Stufe-1-Helden perfekt. Unter „Übungsrunde“ in der Lobby kannst du alles gefahrlos ausprobieren.</Tip></> },
  ] },
  { id: "flow", icon: MapIcon, title: "Wie wird gespielt?", items: [
    { q: "Der Grundablauf", text: "DM beschreibt Spieler handeln Würfel entscheiden",
      body: <><ol className="guideSteps">
        <li><b>Der DM beschreibt</b> die Lage: „Ihr steht vor einer moosbedeckten Tür, dahinter hört ihr Knurren.“</li>
        <li><b>Die Spieler sagen, was ihre Helden tun:</b> „Ich lausche an der Tür.“ oder „Ich trete sie ein!“</li>
        <li><b>Der DM entscheidet,</b> ob gewürfelt wird. Ist eine Aktion sicher, gelingt sie einfach. Ist sie riskant, wird eine Probe fällig.</li>
        <li><b>Das Ergebnis wird erzählt</b>, und die Geschichte geht weiter.</li></ol>
        <P>Dieser Kreislauf wiederholt sich die ganze Sitzung. Ihr könnt alles versuchen, auch Dinge, an die der DM nie gedacht hat.</P></> },
    { q: "Die drei Säulen des Spiels", text: "Erkundung Interaktion Kampf",
      body: <><P><b>Erkundung:</b> Ruinen durchsuchen, Fallen finden, Rätsel lösen, Wildnis durchqueren.</P>
        <P><b>Interaktion:</b> Mit Figuren des DM reden, verhandeln, lügen, Verbündete gewinnen. Im Chat könnt ihr mit dem Schalter „Spieler“ auf „Charakter“ wechseln und in der Rolle eures Helden sprechen.</P>
        <P><b>Kampf:</b> Rundenbasiert auf der Battlemap mit Initiative, Angriffen und Zaubern.</P></> },
    { q: "Was darf mein Held?", text: "Freiheit Regeln Spaß",
      body: <><P>Alles, was in der Welt plausibel ist. Die Regeln helfen dem DM nur zu entscheiden, wie wahrscheinlich etwas klappt. Gute Faustregel: Sag, <i>was</i> du erreichen willst und <i>wie</i>. „Ich lenke die Wache ab, indem ich eine Münze klirren lasse.“ ist besser als „Ich mache eine Täuschen-Probe“.</P></> },
  ] },
  { id: "dice", icon: Dices, title: "Würfel & Proben", items: [
    { q: "Die Würfel und ihre Schreibweise", text: "W4 W6 W8 W10 W12 W20 W100 2d6+3",
      body: <><P>Es gibt sieben Würfel: <b>W4, W6, W8, W10, W12, W20</b> und den <b>W100</b> (Prozentwürfel). „2W6+3“ heißt: zwei sechsseitige Würfel werfen, Augen addieren, 3 dazurechnen. Die Formel im Würfel-Reiter nutzt die englische Schreibweise <code>2d6+3</code>.</P>
        <P>Der wichtigste Würfel ist der <b>W20</b>. Fast jede Probe, jeder Angriff und jeder Rettungswurf ist ein W20-Wurf.</P></> },
    { q: "So funktioniert eine Probe", text: "W20 Modifikator Schwierigkeitsgrad SG",
      body: <><P><b>W20 + Modifikator ≥ Schwierigkeitsgrad (SG)</b>, dann gelingt es. Der DM legt den SG fest:</P>
        <Table head={["Aufgabe", "SG"]} rows={[["Sehr leicht", "5"], ["Leicht", "10"], ["Mittel", "15"], ["Schwer", "20"], ["Sehr schwer", "25"], ["Fast unmöglich", "30"]]} />
        <P>Klick im Charakterbogen einfach auf eine Fertigkeit oder ein Attribut, und der richtige Wurf mit Bonus wird gewürfelt.</P></> },
    { q: "Attribute und Modifikatoren", text: "Stärke Geschicklichkeit Konstitution Intelligenz Weisheit Charisma Modifikator",
      body: <><P>Jeder Held hat sechs Attribute zwischen 1 und 20 (selten bis 30). Daraus ergibt sich der <b>Modifikator</b>: (Wert − 10) ÷ 2, abgerundet.</P>
        <Table head={["Wert", "Modifikator"]} rows={[["8–9", "−1"], ["10–11", "+0"], ["12–13", "+1"], ["14–15", "+2"], ["16–17", "+3"], ["18–19", "+4"], ["20", "+5"]]} />
        <P><b>STÄ</b> Kraft und Athletik · <b>GES</b> Reflexe, Heimlichkeit, Fernkampf · <b>KON</b> Ausdauer und TP · <b>INT</b> Wissen und Logik · <b>WEI</b> Wahrnehmung und Intuition · <b>CHA</b> Ausstrahlung und Überzeugungskraft.</P></> },
    { q: "Übungsbonus, Fertigkeiten und Rettungswürfe", text: "Übungsbonus geübt Fertigkeit Rettungswurf",
      body: <><P>Bist du in etwas <b>geübt</b> (leuchtender Punkt im Bogen), addierst du deinen <b>Übungsbonus</b>: +2 auf Stufe 1–4, +3 ab Stufe 5, bis +6 auf Stufe 17–20.</P>
        <P><b>Rettungswürfe</b> (RW) sind Reaktionen auf Gefahr: dem Feuerball ausweichen (GES-RW), dem Gift widerstehen (KON-RW), Gedankenkontrolle abschütteln (WEI-RW). Jede Klasse ist in zwei Rettungswürfen geübt.</P>
        <P><b>Passive Wahrnehmung</b> = 10 + Wahrnehmungsbonus. Der DM nutzt sie, um heimlich zu prüfen, ob ihr etwas bemerkt.</P></> },
    { q: "Vorteil, Nachteil, Natürliche 20", text: "Vorteil Nachteil kritisch Patzer",
      body: <><P><b>Vorteil:</b> zwei W20 werfen, den höheren nehmen. <b>Nachteil:</b> den niedrigeren. Beides hebt sich auf. Stell den Modus im Würfel-Reiter ein, dann gilt er für deine nächsten W20-Würfe.</P>
        <P>Eine <b>natürliche 20</b> beim Angriff ist ein <b>kritischer Treffer</b>: Alle Schadenswürfel werden doppelt geworfen. Eine <b>natürliche 1</b> verfehlt immer. Am Tisch gibt es dafür eine extra Animation.</P></> },
  ] },
  { id: "combat", icon: Swords, title: "Der Kampf", items: [
    { q: "Initiative und Runden", text: "Initiative Runde Reihenfolge Zug",
      body: <><P>Startet der DM einen Kampf, würfeln alle <b>Initiative</b> (W20 + GES-Modifikator). Daraus entsteht die Reihenfolge im Kampf-Reiter. Eine <b>Runde</b> sind etwa 6 Sekunden Spielzeit, in der jeder genau einen <b>Zug</b> hat. Wer gerade dran ist, leuchtet golden auf der Karte.</P></> },
    { q: "Was kann ich in meinem Zug tun?", text: "Bewegung Aktion Bonusaktion Reaktion",
      body: <><P>Du hast in deinem Zug:</P>
        <ul className="guideList"><li><b>Bewegung</b> bis zu deinem Tempo (meist 9 m = 6 Felder à 1,5 m). Du kannst sie aufteilen.</li>
          <li><b>Eine Aktion:</b> Angriff, Zauber wirken, Spurt (doppelte Bewegung), Rückzug (keine Gelegenheitsangriffe), Ausweichen (Angriffe gegen dich mit Nachteil), Helfen, Verstecken, Gegenstand benutzen oder eine Aktion vorbereiten.</li>
          <li><b>Eine Bonusaktion</b>, wenn eine Fähigkeit oder ein Zauber es erlaubt.</li>
          <li><b>Eine Reaktion</b> pro Runde, auch außerhalb deines Zuges, etwa ein Gelegenheitsangriff, wenn ein Feind an dir vorbeiläuft.</li></ul></> },
    { q: "Angreifen und Schaden", text: "Angriffswurf Rüstungsklasse RK Schaden",
      body: <><P><b>Angriffswurf:</b> W20 + Attributsmodifikator + Übungsbonus. Erreicht oder übertrifft das die <b>Rüstungsklasse (RK)</b> des Ziels, triffst du. Dann würfelst du den Schaden der Waffe, z. B. Langschwert 1W8 + STÄ.</P>
        <P>Nahkampfwaffen nutzen meist STÄ, Fernkampf- und Finesse-Waffen GES.</P>
        <Tip>Der DM sieht bei jeder Kreatur aus dem Bestiarium fertige Angriffsknöpfe: ein Klick würfelt Treffer und Schaden.</Tip></> },
    { q: "Trefferpunkte, Bewusstlosigkeit und Tod", text: "TP Trefferpunkte bewusstlos Todesrettungswurf temporäre",
      body: <><P><b>Trefferpunkte (TP)</b> sind Ausdauer und Glück. Bei 0 TP fällt ein Held <b>bewusstlos</b> um. Monster sind dann meist besiegt.</P>
        <P>Bewusstlose Helden machen zu Beginn ihres Zuges einen <b>Todesrettungswurf</b>: W20, ab 10 ein Erfolg. Drei Erfolge stabilisieren, drei Fehlschläge bedeuten den Tod. Eine natürliche 20 weckt den Helden mit 1 TP. Jede Heilung holt ihn sofort zurück.</P>
        <P><b>Temporäre TP</b> sind ein Puffer, der zuerst verbraucht wird. Am Tisch zieht „Schaden“ sie automatisch zuerst ab.</P></> },
    { q: "Deckung und Gelände", text: "Deckung halbe Dreiviertel schwieriges Gelände",
      body: <><P><b>Halbe Deckung</b> (Mauer bis zur Hüfte): +2 RK. <b>Dreiviertel-Deckung</b> (Schießscharte): +5 RK. <b>Volle Deckung:</b> nicht direkt angreifbar. <b>Schwieriges Gelände</b> kostet doppelte Bewegung.</P></> },
  ] },
  { id: "magic", icon: Wand2, title: "Zauber nutzen", items: [
    { q: "Wer kann zaubern?", text: "Zauberwirker Zauberattribut Magier Kleriker",
      body: <><P>Volle Zauberwirker sind <b>Barde, Kleriker, Druide, Zauberer, Hexenmeister und Magier</b>. <b>Paladin und Waldläufer</b> zaubern als Halbwirker ab Stufe 1 bis 2. Kämpfer, Mönch, Barbar und Schurke zaubern nur mit bestimmten Unterklassen.</P>
        <Table head={["Klasse", "Zauberattribut"]} rows={[["Magier", "INT"], ["Kleriker, Druide, Waldläufer", "WEI"], ["Barde, Zauberer, Hexenmeister, Paladin", "CHA"]]} /></> },
    { q: "Zaubertricks und Zauberplätze", text: "Zaubertrick Zauberplatz Grad Rast",
      body: <><P><b>Zaubertricks</b> (Grad 0) wirkst du beliebig oft, z. B. <i>Feuerpfeil</i> oder <i>Heilige Flamme</i>.</P>
        <P>Alle anderen Zauber haben einen <b>Grad von 1 bis 9</b> und verbrauchen einen <b>Zauberplatz</b> mindestens dieses Grades. Wie viele Plätze du hast, hängt von Klasse und Stufe ab. Eine lange Rast füllt sie wieder auf, beim Hexenmeister schon die kurze.</P>
        <P>Ein Zauber in einem höheren Platz wird oft stärker: <i>Magisches Geschoss</i> im Grad-2-Platz schießt ein Geschoss mehr.</P>
        <Tip>Notiere deine Zauber und freien Plätze im Feld „Zauber“ deines Bogens, z. B. „Grad 1: ●●○“.</Tip></> },
    { q: "Zauberangriff und Zauber-SG", text: "Zauberangriff Rettungswurf SG 8 + Übung",
      body: <><P>Manche Zauber treffen per <b>Zauberangriff</b>: W20 + Übungsbonus + Zauberattribut-Modifikator gegen die RK.</P>
        <P>Andere zwingen das Ziel zu einem <b>Rettungswurf</b> gegen deinen <b>Zauber-SG = 8 + Übungsbonus + Zauberattribut-Modifikator</b>. Ein Magier mit INT 16 auf Stufe 1 hat also SG 8 + 2 + 3 = 13.</P></> },
    { q: "Konzentration, Komponenten, Rituale", text: "Konzentration Komponenten verbal gestisch material Ritual",
      body: <><P><b>Konzentration:</b> Manche Zauber halten an, solange du dich konzentrierst. Du kannst nur einen davon gleichzeitig aufrechterhalten. Erleidest du Schaden, machst du einen KON-Rettungswurf (SG 10 oder halber Schaden, wenn höher). Markiere dich mit dem Zustand „Konzentration“, dann vergisst es niemand.</P>
        <P><b>Komponenten:</b> V (verbal, sprechen), G (gestisch, Hände frei), M (Material, Fokus oder Zutat).</P>
        <P><b>Ritual:</b> Zauber mit diesem Merkmal kannst du in 10 Extraminuten ohne Zauberplatz wirken.</P></> },
    { q: "Beispiel: Ein Feuerball am Tisch", text: "Feuerball Beispiel 8d6",
      body: <><ol className="guideSteps"><li>Die Magierin sagt: „Ich werfe einen Feuerball zwischen die Goblins!“ und streicht einen Grad-3-Platz.</li>
        <li>Der DM lässt jeden Goblin einen GES-Rettungswurf gegen ihren Zauber-SG machen, verdeckt im Würfel-Reiter.</li>
        <li>Sie würfelt <code>8d6</code> Feuerschaden. Wer den Rettungswurf schafft, nimmt die Hälfte.</li>
        <li>Der DM trägt den Schaden bei jeder Kreatur ein, und die Lebensbalken sinken.</li></ol></> },
  ] },
  { id: "dm", icon: Crown, title: "Was macht der Dungeon Master?", items: [
    { q: "Die drei Rollen des DM", text: "Erzähler Schiedsrichter Spielleiter Monster",
      body: <><P><b>Erzähler:</b> beschreibt Orte, Stimmungen und Geräusche. <b>Schiedsrichter:</b> entscheidet, wann gewürfelt wird und wie Regeln greifen. <b>Gegenspieler und Weltbewohner:</b> spielt alle Monster und Nichtspielercharaktere (NSC), vom Wirt bis zum Drachen.</P>
        <P>Der DM ist nicht der Gegner der Spieler. Sein Ziel ist eine spannende Geschichte, in der die Helden glänzen können.</P></> },
    { q: "Deine Werkzeuge an diesem Tisch", text: "Szene Kreaturen verdeckt TP verbergen Hinterhalt",
      body: <><ul className="guideList"><li><b>Tisch-Reiter:</b> Szenen ansagen (alle sehen eine Einblendung), Kartengröße, Thema und eigenes Kartenbild, Tisch schließen, Spieler entfernen.</li>
        <li><b>Kreaturen-Reiter:</b> Monster aus dem Bestiarium mit einem Klick beschwören, eigene Wesen mit Porträt oder Bildlink bauen, TP vor Spielern verbergen oder Kreaturen versteckt platzieren.</li>
        <li><b>Würfel-Reiter:</b> „Verdeckt würfeln“, und nur du siehst das Ergebnis.</li>
        <li><b>Kampf-Reiter:</b> Kampf starten würfelt Initiative für alle, „Nächster“ gibt den Zug weiter, Werte lassen sich nachträglich ändern.</li></ul></> },
    { q: "Tipps für neue Dungeon Master", text: "Tipps Ja und Spotlight Regel 0 Session Zero",
      body: <><ul className="guideList"><li><b>Regel 0:</b> Spaß geht vor Regeln. Schlag nicht jede Kleinigkeit nach, entscheide und bleib im Fluss.</li>
        <li><b>„Ja, und …“</b> statt „Nein“: Belohne kreative Ideen. Scheitern darf die Geschichte interessanter machen.</li>
        <li><b>Rampenlicht verteilen:</b> Frag ruhigere Spieler direkt: „Was macht deine Heldin?“</li>
        <li><b>Session Zero:</b> Sprecht vorher über Ton, Themen und Grenzen. „Linien und Schleier“ oder eine X-Karte helfen, dass sich alle wohlfühlen.</li>
        <li><b>Klein anfangen:</b> Ein Dorf, ein Problem, ein Dungeon mit drei bis fünf Räumen reicht für den ersten Abend.</li></ul></> },
    { q: "Wie schwer sollte ein Kampf sein?", text: "Herausforderungsgrad HG Balance",
      body: <><P>Der <b>Herausforderungsgrad (HG)</b> eines Monsters zeigt grob, für welche Stufe es eine Herausforderung ist. Für vier Helden der Stufe 1 sind zum Beispiel vier Goblins (HG 1/4) ein ordentlicher Kampf, ein Oger (HG 2) schon gefährlich.</P>
        <Tip>Schau während des Kampfes auf die Lebensbalken. Läuft es zu glatt, lass Verstärkung auftauchen. Wird es zu hart, kann ein Monster fliehen.</Tip></> },
  ] },
  { id: "hero", icon: Shield, title: "Einen Helden erschaffen", items: [
    { q: "In fünf Schritten zum Helden", text: "Klasse Herkunft Volk Attribute Ausrüstung",
      body: <><ol className="guideSteps"><li><b>Klasse wählen:</b> Was kann dein Held? Kämpfen, zaubern, schleichen? Der Bogen trägt Rettungswürfe, Rüstung und Startausrüstung automatisch ein.</li>
        <li><b>Volk und Hintergrund:</b> Woher kommt er? Elf, Zwerg, Mensch …, ehemaliger Soldat oder Gelehrter?</li>
        <li><b>Attribute verteilen:</b> „Standardwerte“ setzt 15, 14, 13, 12, 10, 8 passend zur Klasse.</li>
        <li><b>Fertigkeiten wählen:</b> Klick die leuchtenden Klassenfertigkeiten an.</li>
        <li><b>Details:</b> Name, Persönlichkeit, Aussehen, ein Ziel und eine Schwäche. Das macht ihn lebendig.</li></ol></> },
    { q: "Stufenaufstieg", text: "Stufe Erfahrung Trefferwürfel",
      body: <><P>Nach Abenteuern steigen Helden im Rang auf, meist entscheidet der DM, wann. Pro Stufe gibt es mehr TP (Trefferwürfel + KON), neue Fähigkeiten und alle vier Stufen einen höheren Übungsbonus. Setz einfach die Stufe im Bogen hoch, die TP werden vorgeschlagen.</P></> },
  ] },
  { id: "classes", icon: Users, title: "Die zwölf Klassen", items: CLASSES.map((c) => ({ q: c.name, text: `${c.blurb} ${c.armor}`,
    body: <div className="guideClass" style={{ "--cls": c.color }}><P>{c.blurb}</P>
      <div className="guideFacts"><span><b>Trefferwürfel</b> W{c.die}</span><span><b>Rüstung</b> {c.armor}</span><span><b>Wichtig</b> {c.primary.slice(0, 2).map((a) => a.toUpperCase()).join(", ")}</span><span><b>Fertigkeiten</b> {c.pick} wählen</span></div>
      <P><b>Start:</b> {c.kit}</P></div> })) },
  { id: "conditions", icon: HeartPulse, title: "Zustände erklärt", items: Object.entries(CONDITION_INFO).map(([name, info]) => ({ q: name, text: info, body: <P>{info}</P> })) },
  { id: "rest", icon: Moon, title: "Rasten & Heilung", items: [
    { q: "Kurze und lange Rast", text: "kurze Rast lange Rast Trefferwürfel",
      body: <><P><b>Kurze Rast</b> (mindestens 1 Stunde): Du darfst Trefferwürfel ausgeben und heilst je Würfel Augen + KON-Mod. Manche Fähigkeiten laden sich auf.</P>
        <P><b>Lange Rast</b> (8 Stunden, höchstens 2 davon Wache): alle TP zurück, die Hälfte der Trefferwürfel, alle Zauberplätze. Nur eine pro 24 Stunden.</P></> },
    { q: "Heiltränke und Heilzauber", text: "Heiltrank Heilen Wunden heilen",
      body: <P><b>Heiltrank:</b> 2W4+2 TP. <b>Wunden heilen</b> (Grad 1): 2W8 + Zaubermod. <b>Heilendes Wort</b> (Grad 1, Bonusaktion, Fernwirkung): 2W4 + Zaubermod. Trag die Heilung mit dem grünen „Heilen“-Knopf ein.</P> },
  ] },
  { id: "bestiary", icon: Skull, title: "Bestiarium", items: MONSTERS.map((m) => ({ q: m.name, text: `${m.type} ${m.lore}`,
    body: <div className="guideMonster"><MonsterArt art={m.art} color={m.color} name={m.name} />
      <div><P>{m.lore}</P><div className="guideFacts"><span><b>HG</b> {m.cr}</span><span><b>TP</b> {m.max_hp}</span><span><b>RK</b> {m.ac}</span><span><b>Typ</b> {m.type}</span></div>
        <ul className="guideList">{m.attacks.map((a) => <li key={a.name}><b>{a.name}</b> {a.save ? `${a.save}` : `${signed(a.hit)} zum Treffen`}{a.dmg ? `, ${a.dmg}` : ""}{a.note ? ` (${a.note})` : ""}</li>)}</ul></div></div> })) },
  { id: "glossary", icon: Flame, title: "Glossar", items: [
    { q: "Abkürzungen von A bis Z", text: "RK TP SG HG NSC W20 RW",
      body: <Table head={["Kürzel", "Bedeutung"]} rows={[["DM", "Dungeon Master, Spielleitung"], ["HG", "Herausforderungsgrad eines Monsters"], ["NSC", "Nichtspielercharakter, gespielt vom DM"], ["RK", "Rüstungsklasse, so schwer bist du zu treffen"], ["RW", "Rettungswurf"], ["SG", "Schwierigkeitsgrad einer Probe"], ["TP", "Trefferpunkte"], ["W20", "Zwanzigseitiger Würfel (englisch d20)"], ["Mod", "Attributsmodifikator"], ["Init", "Initiative, die Reihenfolge im Kampf"]]} /> },
  ] },
];

export function Guide({ compact = false }) {
  const [query, setQuery] = useState("");
  const [open, setOpen] = useState(() => new Set(["what:0"]));
  const [topic, setTopic] = useState("what");
  const q = query.trim().toLowerCase();
  const visible = useMemo(() => TOPICS.map((t) => ({ ...t, items: t.items.map((it, i) => ({ ...it, key: `${t.id}:${i}` }))
    .filter((it) => !q || `${t.title} ${it.q} ${it.text}`.toLowerCase().includes(q)) })).filter((t) => t.items.length), [q]);
  const toggle = (key) => setOpen((s) => { const n = new Set(s); if (n.has(key)) n.delete(key); else n.add(key); return n; });
  const shown = q ? visible : visible.filter((t) => t.id === topic);

  return <div className={`dndGuide ${compact ? "isCompact" : ""}`}>
    <div className="guideHead">
      <label className="guideSearch"><Search size={16} /><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Suchen: Vorteil, Zauberplatz, Initiative …" aria-label="Wissen durchsuchen" /></label>
      <label className="guideSelect">Thema
        <select value={topic} onChange={(e) => { setTopic(e.target.value); setQuery(""); }} disabled={Boolean(q)}>
          {TOPICS.map((t) => <option key={t.id} value={t.id}>{t.title}</option>)}
        </select></label>
    </div>
    {!compact && <nav className="guideTopics">{TOPICS.map((t) => { const Icon = t.icon; return <button type="button" key={t.id} className={topic === t.id && !q ? "active" : ""} onClick={() => { setTopic(t.id); setQuery(""); }}><Icon size={16} />{t.title}</button>; })}</nav>}
    <div className="guideBody" key={q ? "search" : topic}>
      {shown.map((t) => { const Icon = t.icon; return <section key={t.id} className="guideTopic">
        <h3><Icon size={20} />{t.title}</h3>
        {t.items.map((it) => { const isOpen = q ? true : open.has(it.key); return <article key={it.key} className={`guideItem ${isOpen ? "isOpen" : ""}`}>
          <button type="button" className="guideQ" aria-expanded={isOpen} onClick={() => toggle(it.key)}><span>{it.q}</span><ChevronDown size={18} /></button>
          <div className="guideA"><div>{it.body}</div></div>
        </article>; })}
      </section>; })}
      {!shown.length && <div className="notice">Nichts gefunden. Probier ein anderes Stichwort.</div>}
    </div>
    <p className="guideCredit">Regeln nach dem System Reference Document 5.2 von Wizards of the Coast, lizenziert unter CC-BY-4.0.</p>
  </div>;
}
