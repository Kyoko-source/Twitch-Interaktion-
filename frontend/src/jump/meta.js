// Chicken Jump progression: stages within a run, golden-feather bank, upgrades and missions that
// carry over between runs. Pure logic (no Phaser) so it can be tested with node --test.
export const META_KEY = "chicken-jump-meta-v1";

// A run walks through these stages; after the last one the cycle repeats as a faster "Meisterlauf".
export const STAGES = [
  { name: "Morgenwiese", sub: "Zäune, Vögel und Heu", length: 400, mix: { fence: 6, bird: 3, hay: 2 } },
  { name: "Bisonweide", sub: "Achtung: Bullen stürmen heran!", length: 500, mix: { fence: 3, bird: 2, bull: 4, hay: 2, mud: 2 } },
  { name: "Heuernte", sub: "Traktoren und Heuballen", length: 600, mix: { fence: 2, bird: 2, hay: 4, tractor: 3, mud: 2, bull: 2 } },
  { name: "Waldrand", sub: "Füchse und tiefe Äste", length: 700, mix: { fence: 2, bird: 3, fox: 4, branch: 4, bull: 2, hay: 1 } },
  { name: "Gewitternacht", sub: "Alles auf einmal, im Regen", length: 800, mix: { fence: 2, bird: 2, bull: 3, stampede: 2, tractor: 2, fox: 2, branch: 2, mud: 2, hay: 2 }, storm: true },
];

export function stageAt(distance) {
  const cycle = STAGES.reduce((n, s) => n + s.length, 0);
  const lap = Math.floor(distance / cycle);
  let d = distance - lap * cycle, index = 0;
  while (index < STAGES.length - 1 && d >= STAGES[index].length) { d -= STAGES[index].length; index += 1; }
  return { index, lap, number: lap * STAGES.length + index + 1, progress: d / STAGES[index].length, ...STAGES[index] };
}

export function pickWeighted(mix, rnd = Math.random) {
  const entries = Object.entries(mix);
  let roll = rnd() * entries.reduce((n, [, w]) => n + w, 0);
  for (const [kind, w] of entries) { roll -= w; if (roll < 0) return kind; }
  return entries[entries.length - 1][0];
}

export const UPGRADES = [
  { id: "shield", label: "Startschild", text: "Jeder Lauf beginnt mit einem Schild.", costs: [150] },
  { id: "magnet", label: "Stärkerer Magnet", text: "Magnet hält 2 Sekunden länger.", costs: [80, 160, 320] },
  { id: "star", label: "Längere Doppelpunkte", text: "Doppelpunkte halten 2 Sekunden länger.", costs: [80, 160, 320] },
  { id: "luck", label: "Glücksklee", text: "Power-ups erscheinen häufiger.", costs: [100, 200, 400] },
  { id: "revive", label: "Zweite Chance", text: "Einmal pro Lauf nach einem Treffer weiterlaufen.", costs: [600] },
];

export const MISSIONS = [
  { id: "bulls3", text: "Springe in einem Lauf über 3 Bullen", stat: "bulls", goal: 3, reward: 80 },
  { id: "bulls8", text: "Springe in einem Lauf über 8 Bullen", stat: "bulls", goal: 8, reward: 200 },
  { id: "dist1000", text: "Laufe 1.000 m weit", stat: "distance", goal: 1000, reward: 100 },
  { id: "dist2500", text: "Laufe 2.500 m weit", stat: "distance", goal: 2500, reward: 250 },
  { id: "feathers60", text: "Sammle 60 Federn in einem Lauf", stat: "feathers", goal: 60, reward: 80 },
  { id: "feathers150", text: "Sammle 150 Federn in einem Lauf", stat: "feathers", goal: 150, reward: 200 },
  { id: "near5", text: "Schaffe 5 knappe Sprünge in einem Lauf", stat: "near", goal: 5, reward: 90 },
  { id: "duck6", text: "Ducke dich unter 6 Vögeln oder Ästen durch", stat: "ducks", goal: 6, reward: 90 },
  { id: "stage3", text: "Erreiche Abschnitt 3 (Heuernte)", stat: "stage", goal: 3, reward: 120 },
  { id: "stage5", text: "Erreiche Abschnitt 5 (Gewitternacht)", stat: "stage", goal: 5, reward: 300 },
  { id: "combo6", text: "Schaffe eine Federkette x6", stat: "combo", goal: 6, reward: 100 },
  { id: "smash2", text: "Zerschmettere 2 Hindernisse mit dem Schild", stat: "smash", goal: 2, reward: 120 },
  { id: "tractor2", text: "Überspringe 2 Traktoren in einem Lauf", stat: "tractors", goal: 2, reward: 110 },
  { id: "fox4", text: "Überspringe 4 Füchse in einem Lauf", stat: "foxes", goal: 4, reward: 110 },
];

export const RANKS = [
  { at: 0, name: "Küken" }, { at: 200, name: "Junghenne" }, { at: 600, name: "Hofhenne" }, { at: 1500, name: "Flinkes Huhn" },
  { at: 3000, name: "Weidesprinterin" }, { at: 6000, name: "Bisonbezwingerin" }, { at: 12000, name: "Legende vom Hof" },
];

export function rankFor(lifetime) {
  let index = 0;
  for (let i = 0; i < RANKS.length; i += 1) if (lifetime >= RANKS[i].at) index = i;
  const next = RANKS[index + 1];
  return { ...RANKS[index], index, next: next?.at ?? null, progress: next ? (lifetime - RANKS[index].at) / (next.at - RANKS[index].at) : 1 };
}

export function freshMeta() { return { bank: 0, lifetime: 0, upgrades: {}, missions: [], done: [], runs: 0 }; }

export function loadMeta(storage = globalThis.localStorage) {
  let meta = freshMeta();
  try { meta = { ...meta, ...JSON.parse(storage?.getItem(META_KEY) || "{}") }; } catch { /* storage is optional */ }
  return fillMissions(meta);
}

export function saveMeta(meta, storage = globalThis.localStorage) {
  try { storage?.setItem(META_KEY, JSON.stringify(meta)); } catch { /* storage is optional */ }
}

// Keep three active missions; finished ones are replaced by the next unfinished ones.
export function fillMissions(meta) {
  const active = meta.missions.filter((id) => MISSIONS.some((m) => m.id === id) && !meta.done.includes(id));
  for (const m of MISSIONS) {
    if (active.length >= 3) break;
    if (!active.includes(m.id) && !meta.done.includes(m.id)) active.push(m.id);
  }
  // Everything done once: start the pool again so there is always something to chase.
  if (active.length < 3 && meta.done.length >= MISSIONS.length) return fillMissions({ ...meta, done: [], missions: active });
  return { ...meta, missions: active };
}

export function level(meta, id) { return meta.upgrades[id] || 0; }

export function upgradeCost(meta, id) {
  const spec = UPGRADES.find((u) => u.id === id);
  return spec?.costs[level(meta, id)] ?? null;
}

export function buyUpgrade(meta, id) {
  const cost = upgradeCost(meta, id);
  if (cost === null || meta.bank < cost) return null;
  return { ...meta, bank: meta.bank - cost, upgrades: { ...meta.upgrades, [id]: level(meta, id) + 1 } };
}

// Missions completed by these run stats (does not change meta).
export function completedBy(meta, stats) {
  return meta.missions.map((id) => MISSIONS.find((m) => m.id === id)).filter((m) => m && (stats[m.stat] || 0) >= m.goal);
}

// Bank the run: collected feathers plus mission rewards; returns the new meta and what happened.
export function settleRun(meta, stats) {
  const missions = completedBy(meta, stats);
  const reward = missions.reduce((n, m) => n + m.reward, 0);
  const earned = (stats.feathers || 0) + reward;
  const before = rankFor(meta.lifetime);
  let next = { ...meta, bank: meta.bank + earned, lifetime: meta.lifetime + earned, runs: meta.runs + 1, done: [...meta.done, ...missions.map((m) => m.id)] };
  next = fillMissions(next);
  const after = rankFor(next.lifetime);
  return { meta: next, earned, missions, rankUp: after.index > before.index ? after : null };
}
