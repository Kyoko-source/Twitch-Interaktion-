// Santa's Cookie Crisis – simulation (no DOM, no drawing).
//
// Everything is counted in whole cookies: one cookie = 25 g of dough, the storage starts with
// 25 t = 1,000,000 cookies. Dough moves through buffers (ball → sheet → tray → oven entry →
// belt → exit → falling) and is never created or lost:
//   dough + ball + sheet + tray + queue + belt + exit + falling + baked === 1,000,000
// A Schokotaler is credited in exactly the moment a cookie lands in the chute.

export const GRAMS_PER_COOKIE = 25;
export const GOAL = 1_000_000;
export const OVEN_SLOTS = 14;        // belt length inside the oven, in cookie slots
export const FALL_TIME = 0.42;       // seconds from belt end to the bottom of the chute
export const CLICK_RATE = 2.5;       // clicks per second assumed for "manual capacity" hints
const STEP = 1 / 60;

const lv = (levels, id) => levels[id] || 0;

// ------------------------------------------------------------------------------------ upgrades
// stage: which station it improves (for the bottleneck hint); kind: "tool" (manual), "machine"
// (automation, counts as an active machine) or "magic".
export const PHASES = [
  { n: 1, name: "Kleine Weihnachtsbäckerei", unlock: 0 },
  { n: 2, name: "Mechanische Werkstatt", unlock: 1_200 },
  { n: 3, name: "Automatische Weihnachtsbäckerei", unlock: 12_000 },
  { n: 4, name: "Industrielle Keksproduktion", unlock: 90_000 },
  { n: 5, name: "Magische Weihnachts-Megafabrik", unlock: 330_000 },
];

export const UPGRADES = [
  // Phase 1 – tools for the elf's hands
  { id: "nudelholz", phase: 1, stage: "roll", kind: "tool", name: "Größeres Nudelholz", text: "Weniger Rollbewegungen pro Teigplatte.", base: 14, growth: 4, max: 2 },
  { id: "teigrolle", phase: 1, stage: "portion", kind: "tool", name: "Breitere Teigrolle", text: "Größere Teigplatten – mehr Kekse pro Portion.", base: 22, growth: 3, max: 3 },
  { id: "form", phase: 1, stage: "cut", kind: "tool", name: "Mehrfach-Ausstechform", text: "Sticht mehrere Sterne auf einmal aus.", base: 12, growth: 3.4, max: 3 },
  { id: "blech", phase: 1, stage: "load", kind: "tool", name: "Größeres Backblech", text: "Mehr Kekse pro Fahrt zum Ofen.", base: 10, growth: 3, max: 3 },
  { id: "bandtempo", phase: 1, stage: "oven", kind: "tool", name: "Schnelleres Förderband", text: "Das Ofenband läuft zügiger.", base: 18, growth: 2.1, max: 5 },
  { id: "eingang", phase: 1, stage: "oven", kind: "tool", name: "Größerer Ofeneingang", text: "Mehr Kekse nebeneinander auf dem Band.", base: 90, growth: 3.5, max: 2 },
  { id: "schacht", phase: 1, stage: "chute", kind: "tool", name: "Breiterer Sammelschacht", text: "Der Schacht schluckt mehr Kekse pro Sekunde.", base: 25, growth: 2.4, max: 4 },
  // Phase 2 – mechanics
  { id: "portionierer", phase: 2, stage: "portion", kind: "machine", name: "Automatischer Teigportionierer", text: "Ein Trichter portioniert Teig ganz von selbst.", base: 160, growth: 2.1, max: 5 },
  { id: "walze", phase: 2, stage: "roll", kind: "machine", name: "Mechanische Teigwalze", text: "Eine Kurbeldrehung walzt zwei Teigplatten auf einmal.", base: 220, growth: 1, max: 1 },
  { id: "stanzpresse", phase: 2, stage: "cut", kind: "machine", name: "Mehrfach-Stanzpresse", text: "Ein Hebelzug stanzt eine ganze Platte aus.", base: 280, growth: 3.2, max: 2 },
  { id: "motor", phase: 2, stage: "oven", kind: "machine", name: "Elektrischer Förderbandmotor", text: "Ein Motor treibt das Ofenband deutlich schneller an.", base: 320, growth: 2.4, max: 3 },
  { id: "blechschieber", phase: 2, stage: "load", kind: "machine", name: "Automatischer Blechschieber", text: "Schiebt volle Bleche selbst auf das Ofenband.", base: 260, growth: 1, max: 1 },
  { id: "transport", phase: 2, stage: "load", kind: "machine", name: "Mechanischer Kekstransport", text: "Ein Zubringerband bringt Kekse laufend zum Ofen.", base: 420, growth: 2.2, max: 4 },
  // Phase 3 – automation
  { id: "zufuhr", phase: 3, stage: "portion", kind: "machine", name: "Automatische Teigzufuhr", text: "Ein Rohr versorgt den Portionierer pausenlos mit Teig.", base: 2_600, growth: 2.8, max: 3 },
  { id: "steuerung", phase: 3, stage: "roll", kind: "machine", name: "Zentrale Maschinensteuerung", text: "Walze und Presse laufen jetzt automatisch.", base: 3_200, growth: 2.5, max: 4 },
  { id: "ausstechwalze", phase: 3, stage: "cut", kind: "machine", name: "Rotierende Ausstechwalze", text: "Eine Walze mit Sternformen sticht im Durchlauf aus.", base: 5_500, growth: 2.8, max: 3 },
  { id: "platzierung", phase: 3, stage: "load", kind: "machine", name: "Automatische Keksplatzierung", text: "Greifarme setzen die Kekse exakt aufs Band.", base: 4_600, growth: 2.8, max: 3 },
  { id: "syncband", phase: 3, stage: "oven", kind: "machine", name: "Synchronisierte Förderbänder", text: "Alle Bänder laufen im Takt – schneller und ruckfrei.", base: 4_000, growth: 2.5, max: 3 },
  { id: "durchlauf", phase: 3, stage: "oven", kind: "machine", name: "Breiterer Durchlaufofen", text: "Der Ofen wird breiter: zwei Kekse mehr pro Reihe.", base: 8_000, growth: 3, max: 2 },
  { id: "mehrspur", phase: 3, stage: "oven", kind: "machine", name: "Mehrspurige Ofenförderbänder", text: "Eine weitere Spur läuft durch den Ofen.", base: 9_500, growth: 2.9, max: 3 },
  { id: "sammelstation", phase: 3, stage: "chute", kind: "machine", name: "Automatische Sammelstation", text: "Rüttler und Rinnen verteilen die Kekse im Schacht.", base: 5_000, growth: 2.8, max: 3 },
  // Phase 4 – industry
  { id: "extruder", phase: 4, stage: "portion", kind: "machine", name: "Hochgeschwindigkeits-Teigextruder", text: "Presst Teig als endloses Band – portionieren und walzen in einem.", base: 30_000, growth: 2.2, max: 3 },
  { id: "industrie", phase: 4, stage: "cut", kind: "machine", name: "Industrielle Ausstechmaschinen", text: "Breite Stanzbrücken im Dauerbetrieb.", base: 32_000, growth: 2.2, max: 3 },
  { id: "verteiler", phase: 4, stage: "load", kind: "machine", name: "Automatische Verteilersysteme", text: "Weichen verteilen die Kekse auf alle Spuren.", base: 30_000, growth: 2.2, max: 3 },
  { id: "hochleistung", phase: 4, stage: "roll", kind: "machine", name: "Hochleistungsmotoren", text: "Kräftigere Motoren für Walzen und Bänder.", base: 26_000, growth: 2.2, max: 3 },
  { id: "etagen", phase: 4, stage: "oven", kind: "machine", name: "Mehrstöckige Förderbandöfen", text: "Ein weiteres Ofenstockwerk mit eigenen Bändern.", base: 55_000, growth: 2.0, max: 2 },
  { id: "magnet", phase: 4, stage: "oven", kind: "machine", name: "Magnetische Transportsysteme", text: "Magnetbänder gleiten ohne Reibung.", base: 40_000, growth: 2.2, max: 2 },
  { id: "sensoren", phase: 4, stage: "chute", kind: "machine", name: "Präzisionssensoren", text: "Sensoren takten Schacht und Maschinen fein ab.", base: 28_000, growth: 2.2, max: 3 },
  { id: "vollauto", phase: 4, stage: "all", kind: "machine", name: "Vollautomatische Produktionsstraßen", text: "Alle Stationen greifen nahtlos ineinander: alles ×1,3.", base: 100_000, growth: 1, max: 1 },
  // Phase 5 – Christmas magic
  { id: "beschleuniger", phase: 5, stage: "portion", kind: "magic", name: "Magischer Teigbeschleuniger", text: "Funkelnder Teig fließt doppelt so schnell.", base: 55_000, growth: 2.0, max: 2 },
  { id: "ultra", phase: 5, stage: "cut", kind: "magic", name: "Ultrahochgeschwindigkeits-Ausstechsysteme", text: "Die Formen bewegen sich schneller als das Auge.", base: 55_000, growth: 2.0, max: 2 },
  { id: "portale", phase: 5, stage: "load", kind: "magic", name: "Magische Keksportale", text: "Kekse verschwinden hier und erscheinen direkt auf dem Band.", base: 60_000, growth: 2.0, max: 2 },
  { id: "turboofen", phase: 5, stage: "oven", kind: "magic", name: "Riesiger Weihnachts-Turboofen", text: "Ein gewaltiger Ofen mit deutlich breiteren Bändern.", base: 70_000, growth: 2.0, max: 2 },
  { id: "schwebend", phase: 5, stage: "oven", kind: "magic", name: "Schwebende Förderbänder", text: "Zusätzliche Bänder schweben durch die Halle.", base: 65_000, growth: 2.0, max: 2 },
  { id: "rentier", phase: 5, stage: "all", kind: "magic", name: "Rentierenergie-Generator", text: "Ein Laufrad voller Rentierkraft: alles ×1,2.", base: 80_000, growth: 1.7, max: 2 },
  { id: "goldstrasse", phase: 5, stage: "all", kind: "magic", name: "Goldene Weihnachts-Produktionsstraße", text: "Eine goldene Straße: alles ×1,3.", base: 140_000, growth: 1, max: 1 },
  { id: "megafabrik", phase: 5, stage: "all", kind: "magic", name: "Nordpol-Megafabrik", text: "Die ganze Halle wird zur Megafabrik: alles ×1,4.", base: 200_000, growth: 1, max: 1 },
];
export const UPGRADE_BY_ID = Object.fromEntries(UPGRADES.map((u) => [u.id, u]));

export function upgradeCost(u, level) {
  return Math.round(u.base * Math.pow(u.growth, level));
}

// ------------------------------------------------------------------------------------ derived stats
export function derive(levels) {
  const L = (id) => lv(levels, id);
  const global = (L("vollauto") ? 1.3 : 1) * Math.pow(1.2, L("rentier")) * (L("goldstrasse") ? 1.3 : 1) * (L("megafabrik") ? 1.4 : 1);
  const sheetSize = [8, 12, 16, 24][L("teigrolle")];
  const strokes = [3, 2, 1][L("nudelholz")];
  const cutter = [1, 2, 3, 4][L("form")];
  const pressSize = [0, 24, 48][L("stanzpresse")];
  const walze = L("walze") > 0;
  const trayBase = [6, 10, 16, 24][L("blech")];

  let autoPortion = L("portionierer") ? 1.4 * Math.pow(1.55, L("portionierer") - 1) : 0;
  autoPortion *= Math.pow(2.4, L("zufuhr")) * Math.pow(1.8, L("extruder")) * Math.pow(1.7, L("beschleuniger"));
  let autoRoll = L("steuerung") ? 18 * Math.pow(1.9, L("steuerung") - 1) : 0;
  autoRoll *= Math.pow(1.8, L("extruder")) * Math.pow(1.35, L("hochleistung")) * Math.pow(1.7, L("beschleuniger"));
  let autoCut = L("steuerung") ? 18 * Math.pow(1.9, L("steuerung") - 1) : 0;
  autoCut *= Math.pow(1.8, L("ausstechwalze")) * Math.pow(1.8, L("industrie")) * Math.pow(1.7, L("ultra"));
  let autoLoad = L("transport") ? 1.8 * Math.pow(1.6, L("transport") - 1) : 0;
  autoLoad *= Math.pow(2.5, L("platzierung")) * Math.pow(1.8, L("verteiler")) * Math.pow(1.7, L("portale"));

  const speed = 0.8 * Math.pow(1.2, L("bandtempo")) * Math.pow(1.4, L("motor")) * Math.pow(1.3, L("syncband")) * Math.pow(1.15, L("hochleistung")) * Math.pow(1.2, L("magnet")) * Math.pow(1.15, L("schwebend"));
  const perRow = ([1, 2, 3][L("eingang")] + 2 * L("durchlauf")) * Math.pow(1.4, L("turboofen"));
  const lanes = 1 + L("mehrspur") + 2 * L("schwebend");
  const floors = 1 + L("etagen");
  const ovenRate = speed * perRow * lanes * floors * global;
  const chuteRate = 3 * Math.pow(1.6, L("schacht")) * Math.pow(3, L("sammelstation")) * Math.pow(2, L("sensoren")) * Math.pow(1.7, L("portale")) * global;

  autoPortion *= global; autoRoll *= global; autoCut *= global; autoLoad *= global;
  const trayCap = Math.max(trayBase, Math.ceil(autoCut * 1.5));
  const queueCap = Math.max(24, Math.ceil(ovenRate * 3));
  const ballCap = Math.max(sheetSize * 3, Math.ceil(autoPortion * 2));
  const sheetCap = Math.max(sheetSize * 4, Math.ceil(Math.max(autoRoll, autoPortion) * 2));
  // Visual belt speed: the oven never takes less than 1.2 s, extra throughput comes as density.
  return {
    sheetSize, strokes, cutter, pressSize, walze, trayCap, queueCap, ballCap, sheetCap,
    autoPortion, autoRoll, autoCut, autoLoad, pusher: L("blechschieber") > 0,
    speed: Math.min(speed * Math.min(global, 1.5), OVEN_SLOTS / 1.2), perRow, lanes, floors, ovenRate, chuteRate, global,
  };
}

// Production model. Machines run at their rate; the elf's two hands (~2.5 clicks/s) fill the
// gaps at every station where machines are still too slow. A station needs `clicks` hand
// actions per cookie. The whole line makes T cookies/s when the hands can cover
//   sum over stations of max(0, T - machine rate) * clicks  <=  CLICK_RATE
// and T is never above the oven and the chute.
export function stations(d) {
  return [
    { id: "portion", name: "Portionieren", auto: d.autoPortion, clicks: 1 / d.sheetSize },
    { id: "roll", name: "Ausrollen", auto: d.autoRoll, clicks: d.walze ? 1 / (d.sheetSize * 2) : d.strokes / d.sheetSize },
    { id: "cut", name: "Ausstechen", auto: d.autoCut, clicks: 1 / (d.pressSize || d.cutter) },
    { id: "load", name: "Zum Ofen", auto: d.autoLoad + (d.pusher ? d.trayCap / 1.1 : 0), clicks: 1 / d.trayCap },
  ];
}

const handsNeeded = (list, T) => list.reduce((a, st) => a + Math.max(0, T - st.auto) * st.clicks, 0);

export function throughput(d) {
  const list = stations(d);
  const cap = Math.min(d.ovenRate, d.chuteRate);
  if (handsNeeded(list, cap) <= CLICK_RATE) return cap;
  let lo = 0, hi = cap;
  for (let i = 0; i < 50; i++) {
    const mid = (lo + hi) / 2;
    if (handsNeeded(list, mid) <= CLICK_RATE) lo = mid; else hi = mid;
  }
  return lo;
}

// Every station with its machine rate and how much hand work it needs at the current pace.
export function capacities(d) {
  const T = throughput(d);
  const list = stations(d).map((st) => ({ ...st, rate: st.auto, hand: Math.max(0, T - st.auto) * st.clicks }));
  return [...list, { id: "oven", name: "Ofen", rate: d.ovenRate, auto: d.ovenRate, hand: 0 }, { id: "chute", name: "Schacht", rate: d.chuteRate, auto: d.chuteRate, hand: 0 }];
}

// What limits production: the oven, the chute, or the hands at the station that needs most work.
export function bottleneck(d) {
  const T = throughput(d);
  const caps = capacities(d);
  if (T >= Math.min(d.ovenRate, d.chuteRate) - 1e-6) return d.ovenRate <= d.chuteRate ? caps[4] : caps[5];
  return caps.slice(0, 4).sort((a, b) => b.hand - a.hand)[0];
}

// ------------------------------------------------------------------------------------ state
export function createState() {
  return {
    v: 1, t: 0,
    dough: GOAL, ball: 0, rollProgress: 0, sheet: 0, tray: 0, queue: 0,
    belt: [],      // [[position in slots, count]] oldest first
    exit: 0,       // baked cookies waiting at the end of the belt
    falling: [],   // [[landing time, count]] oldest first
    talers: 0, earned: 0, baked: 0, spent: 0,
    levels: {},
    acc: { portion: 0, roll: 0, cut: 0, load: 0, oven: 1, chute: 1 }, // an idle belt and chute take the next cookie at once
    pushT: 0,
    clicks: 0,
    finished: null,
    events: [],    // transient, for sounds/visuals (not saved)
  };
}

export function totalDough(s) {
  const onBelt = s.belt.reduce((a, b) => a + b[1], 0);
  const inAir = s.falling.reduce((a, b) => a + b[1], 0);
  return s.dough + s.ball + s.sheet + s.tray + s.queue + onBelt + s.exit + inAir + s.baked;
}

const emit = (s, type, n = 1) => { s.events.push({ type, n }); };

// ------------------------------------------------------------------------------------ manual actions
export function actPortion(s, d = derive(s.levels)) {
  if (s.dough <= 0) return 0;
  const space = d.ballCap - s.ball;
  const n = Math.min(d.sheetSize, s.dough, space);
  if (n <= 0) { emit(s, "blocked", 0); return 0; }
  s.dough -= n; s.ball += n; s.clicks += 1;
  emit(s, "portion", n);
  return n;
}

export function actRoll(s, d = derive(s.levels)) {
  if (s.ball <= 0) return 0;
  const space = d.sheetCap - s.sheet;
  if (space <= 0) { emit(s, "blocked", 0); return 0; }
  s.clicks += 1;
  if (d.walze) {
    const n = Math.min(s.ball, d.sheetSize * 2, space);
    s.ball -= n; s.sheet += n; s.rollProgress = 0;
    emit(s, "crank", n);
    return n;
  }
  s.rollProgress = Math.min(1, s.rollProgress + 1 / d.strokes);
  emit(s, "roll", 0);
  if (s.rollProgress >= 1 - 1e-9) {
    const n = Math.min(s.ball, d.sheetSize, space);
    s.ball -= n; s.sheet += n; s.rollProgress = 0;
    emit(s, "rolled", n);
    return n;
  }
  return 0;
}

export function actCut(s, d = derive(s.levels)) {
  if (s.sheet <= 0) return 0;
  const n = Math.min(s.sheet, d.pressSize || d.cutter, d.trayCap - s.tray);
  if (n <= 0) { emit(s, "blocked", 0); return 0; }
  s.sheet -= n; s.tray += n; s.clicks += 1;
  emit(s, d.pressSize ? "press" : "cut", n);
  return n;
}

export function actLoad(s, d = derive(s.levels)) {
  if (s.tray <= 0) return 0;
  const n = Math.min(s.tray, d.queueCap - s.queue);
  if (n <= 0) { emit(s, "blocked", 0); return 0; }
  s.tray -= n; s.queue += n; s.clicks += 1;
  emit(s, "load", n);
  return n;
}

export function buy(s, id) {
  const u = UPGRADE_BY_ID[id];
  if (!u || !isUnlocked(s, u)) return false;
  const level = lv(s.levels, id);
  if (level >= u.max) return false;
  const cost = upgradeCost(u, level);
  if (s.talers < cost) return false;
  s.talers -= cost; s.spent += cost;
  s.levels = { ...s.levels, [id]: level + 1 };
  emit(s, u.phase >= 3 || u.kind !== "tool" ? "machine" : "buy", u.phase);
  return true;
}

export function phaseOf(s) {
  let p = 1;
  for (const ph of PHASES) if (s.earned >= ph.unlock) p = ph.n;
  return p;
}

export function isUnlocked(s, u) {
  return phaseOf(s) >= u.phase;
}

export function activeMachines(levels) {
  return UPGRADES.filter((u) => u.kind !== "tool" && lv(levels, u.id) > 0).length;
}

// The upgrade that helps most right now: the biggest boost of the whole line per taler.
// If nothing raises it directly (e.g. two limits at once), the cheapest one at the bottleneck.
export function recommended(s, d = derive(s.levels)) {
  const now = Math.max(throughput(d), 1e-9);
  const neck = bottleneck(d);
  const open = UPGRADES.filter((u) => isUnlocked(s, u) && lv(s.levels, u.id) < u.max);
  const cost = (u) => upgradeCost(u, lv(s.levels, u.id));
  let best = null, bestValue = 0;
  for (const u of open) {
    const ratio = throughput(derive({ ...s.levels, [u.id]: lv(s.levels, u.id) + 1 })) / now;
    if (!(ratio > 1.0001)) continue;
    const value = Math.log(ratio) / cost(u);
    if (value > bestValue) { best = u; bestValue = value; }
  }
  const byCost = (list) => list.sort((a, b) => cost(a) - cost(b))[0];
  return best || byCost(open.filter((u) => u.stage === neck.id || u.stage === "all")) || byCost(open) || null;
}

// ------------------------------------------------------------------------------------ simulation
function flow(s, key, rate, avail, space, dt) {
  if (rate <= 0) { s.acc[key] = 0; return 0; }
  s.acc[key] += rate * dt;
  const n = Math.max(0, Math.min(Math.floor(s.acc[key]), avail, space));
  s.acc[key] -= n;
  // A blocked machine does not store up work.
  if (s.acc[key] > Math.max(1, rate * dt * 2)) s.acc[key] = Math.max(1, rate * dt * 2);
  return n;
}

function tick(s, d, dt) {
  s.t += dt;
  // automatic stations, upstream first
  let n = flow(s, "portion", d.autoPortion, s.dough, d.ballCap - s.ball, dt);
  if (n) { s.dough -= n; s.ball += n; }
  n = flow(s, "roll", d.autoRoll, s.ball, d.sheetCap - s.sheet, dt);
  if (n) { s.ball -= n; s.sheet += n; s.rollProgress = 0; }
  n = flow(s, "cut", d.autoCut, s.sheet, d.trayCap - s.tray, dt);
  if (n) { s.sheet -= n; s.tray += n; }
  n = flow(s, "load", d.autoLoad, s.tray, d.queueCap - s.queue, dt);
  if (n) { s.tray -= n; s.queue += n; }
  s.pushT = Math.max(0, s.pushT - dt);
  if (d.pusher && s.pushT <= 0 && s.tray > 0 && (s.tray >= d.trayCap || (s.sheet === 0 && s.ball === 0 && !d.autoCut))) {
    const m = Math.min(s.tray, d.queueCap - s.queue);
    if (m > 0) { s.tray -= m; s.queue += m; s.pushT = 1.1; emit(s, "push", m); }
  }
  // oven entry: limited by belt speed × width × lanes × floors
  n = flow(s, "oven", d.ovenRate, s.queue, Infinity, dt);
  if (n) {
    s.queue -= n;
    const last = s.belt[s.belt.length - 1];
    if (last && last[0] === 0) last[1] += n; else s.belt.push([0, n]);
  }
  // belt movement and exit
  const move = d.speed * dt;
  for (const b of s.belt) b[0] += move;
  while (s.belt.length && s.belt[0][0] >= OVEN_SLOTS) { s.exit += s.belt[0][1]; s.belt.shift(); }
  // chute: cookies fall, the taler comes on landing
  n = flow(s, "chute", d.chuteRate, s.exit, Infinity, dt);
  if (n) {
    s.exit -= n;
    const last = s.falling[s.falling.length - 1];
    const land = s.t + FALL_TIME;
    if (last && Math.abs(last[0] - land) < 1e-9) last[1] += n; else s.falling.push([land, n]);
  }
  while (s.falling.length && s.falling[0][0] <= s.t + 1e-9) {
    const [, m] = s.falling.shift();
    s.talers += m; s.earned += m; s.baked += m;
    emit(s, "land", m);
  }
  if (s.baked >= GOAL && s.finished == null) { s.finished = s.t; emit(s, "finale", 1); }
}

// Advance the simulation by dt seconds in fixed steps (a hidden tab catches up for at most 2 min).
export function step(s, dt) {
  let left = Math.min(dt, 120);
  const d = derive(s.levels);
  while (left > 1e-9) {
    const h = Math.min(STEP, left);
    tick(s, d, h);
    left -= h;
  }
  return d;
}

// ------------------------------------------------------------------------------------ save / load
export function serialize(s) {
  const { events, ...rest } = s;
  return JSON.stringify({ ...rest, savedAt: Date.now() });
}

export function deserialize(text) {
  const raw = typeof text === "string" ? JSON.parse(text) : text;
  if (!raw || raw.v !== 1) throw new Error("Unbekannter Spielstand");
  const s = { ...createState(), ...raw, events: [] };
  s.levels = { ...(raw.levels || {}) };
  s.acc = { ...createState().acc, ...(raw.acc || {}) };
  s.belt = (raw.belt || []).map((b) => [Number(b[0]), Math.max(0, Math.floor(b[1]))]);
  s.falling = (raw.falling || []).map((b) => [Number(b[0]), Math.max(0, Math.floor(b[1]))]);
  for (const k of ["dough", "ball", "sheet", "tray", "queue", "exit", "talers", "earned", "baked", "spent"]) s[k] = Math.max(0, Math.floor(Number(s[k]) || 0));
  if (totalDough(s) !== GOAL) throw new Error("Spielstand ist beschädigt (Teigbilanz stimmt nicht).");
  return s;
}
