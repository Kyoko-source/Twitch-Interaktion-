// Chicken Defense: pure simulation (no DOM). Units: tiles and seconds.
export const COLS = 22;
export const ROWS = 13;
export const START_KORN = 220;
export const START_EGGS = 20;
export const SECOND_PATH_WAVE = 12;
export const CHAOS_WAVE = 15;
export const APOCALYPSE_WAVE = 25;

// Waypoints in tile coordinates (tile centres). Path B opens later.
export const PATHS = {
  a: [[-1, 2], [4, 2], [4, 9], [9, 9], [9, 4], [14, 4], [14, 10], [19, 10], [19, 6], [20, 6]],
  b: [[6, 13], [6, 11], [12, 11], [12, 7], [17, 7], [17, 6], [20, 6]],
};
export const NEST = { x: 20, y: 6 };

// ------------------------------------------------------------------ towers
// type: bullet (homing projectile), shell (arcing mortar), sniper (instant), chain (tesla),
// pulse (area pulse), beam (continuous), econ (no attack, pays Korn), aura (buffs towers).
// Level 1-3 scale the base; at level 3 one of three branches becomes level 4.
export const TOWERS = {
  gatling: {
    name: "Gatling-Huhn", cost: 60, unlock: 1, type: "bullet", range: 2.3, rate: 4.5, damage: 5, air: true, speed: 15,
    desc: "Rattert alles weg, was in der Nähe ist. Trifft auch Krähen.",
    branches: {
      rapid: { name: "Dauerfeuer", desc: "Doppelte Feuerrate.", apply: (s) => ({ ...s, rate: s.rate * 2.1 }) },
      mutation: { name: "Mutation", desc: "Giftkugeln: Schaden über Zeit, stapelbar.", apply: (s) => ({ ...s, poison: s.damage * 2.2, poisonTime: 3 }) },
      explosive: { name: "Explosiv-Eier", desc: "Jede Kugel explodiert klein.", apply: (s) => ({ ...s, damage: s.damage * 1.5, splash: 0.65 }) },
    },
  },
  frost: {
    name: "Frost-Huhn", cost: 90, unlock: 2, type: "bullet", range: 2.4, rate: 0.9, damage: 5, air: true, speed: 9, splash: 0.9, slow: 0.42, slowTime: 2.2,
    desc: "Eisgeschosse verlangsamen alles im Umkreis.",
    branches: {
      shards: { name: "Eissplitter", desc: "Vierfacher Schaden, Splitter durchbohren.", apply: (s) => ({ ...s, damage: s.damage * 4, rate: s.rate * 1.3 }) },
      blizzard: { name: "Blizzard-Aura", desc: "Dauerhafter Schneesturm um den Turm.", apply: (s) => ({ ...s, type: "pulse", rate: 4, damage: s.damage * 0.5, splash: s.range, slow: 0.55, slowTime: 0.4, pulseFx: "snow" }) },
      deep: { name: "Tiefkühlung", desc: "25 % Chance, Gegner komplett einzufrieren.", apply: (s) => ({ ...s, freeze: 0.25, freezeTime: 1.4 }) },
    },
  },
  mortar: {
    name: "Mörser-Huhn", cost: 125, unlock: 3, type: "shell", range: 3.6, rate: 0.55, damage: 34, splash: 1.15, air: false,
    desc: "Explodierende Eier mit Flächenschaden. Nur Bodenziele.",
    branches: {
      big: { name: "Großer Knall", desc: "Riesige Explosionen.", apply: (s) => ({ ...s, damage: s.damage * 1.6, splash: s.splash * 1.6 }) },
      toxic: { name: "Giftgranaten", desc: "Hinterlässt eine Giftwolke.", apply: (s) => ({ ...s, zone: { kind: "toxic", dps: s.damage * 0.6, time: 4 } }) },
      barrage: { name: "Belagerung", desc: "Drei Granaten pro Salve.", apply: (s) => ({ ...s, volley: 3 }) },
    },
  },
  sniper: {
    name: "Scharfschützen-Huhn", cost: 150, unlock: 4, type: "sniper", range: 6, rate: 0.45, damage: 85, air: true, targeting: "strong",
    desc: "Riesige Reichweite, nimmt sich die Dicksten vor.",
    branches: {
      longshot: { name: "Fernschuss", desc: "Trifft auf der ganzen Karte.", apply: (s) => ({ ...s, range: 30, damage: s.damage * 1.3 }) },
      pierce: { name: "Panzerbrecher", desc: "Ignoriert Rüstung komplett.", apply: (s) => ({ ...s, damage: s.damage * 1.5, pierce: true }) },
      crit: { name: "Kritisches Nest", desc: "35 % Chance auf vierfachen Schaden.", apply: (s) => ({ ...s, crit: 0.35, critMult: 4 }) },
    },
  },
  wizard: {
    name: "Zauber-Huhn", cost: 140, unlock: 5, type: "bullet", range: 2.8, rate: 1.1, damage: 20, air: true, speed: 8, magic: true,
    desc: "Magische Kugeln ignorieren die halbe Rüstung.",
    branches: {
      storm: { name: "Arkaner Sturm", desc: "Kugeln explodieren in arkane Wirbel.", apply: (s) => ({ ...s, splash: 1.3, damage: s.damage * 1.3 }) },
      freezeEggs: { name: "Frosteier", desc: "Jeder Treffer verlangsamt stark.", apply: (s) => ({ ...s, slow: 0.55, slowTime: 2.5, damage: s.damage * 1.2 }) },
      chainMagic: { name: "Kettenzauber", desc: "Der Zauber springt auf 4 weitere Gegner.", apply: (s) => ({ ...s, chain: 5 }) },
    },
  },
  golden: {
    name: "Goldenes Huhn", cost: 160, unlock: 5, type: "econ", range: 2.2, income: 25, air: false,
    desc: "Greift nicht an, legt aber nach jeder Welle Korn.",
    branches: {
      rich: { name: "Reiches Nest", desc: "Dreifaches Korn pro Welle.", apply: (s) => ({ ...s, income: s.income * 3 }) },
      interest: { name: "Zinsen", desc: "+6 % Zinsen auf dein Korn nach jeder Welle (max. 200).", apply: (s) => ({ ...s, interest: 0.06 }) },
      treasure: { name: "Schatz-Aura", desc: "+60 % Beute für Gegner in Reichweite.", apply: (s) => ({ ...s, treasure: 0.6, range: s.range + 1 }) },
    },
  },
  tesla: {
    name: "Tesla-Huhn", cost: 210, unlock: 7, type: "chain", range: 3.0, rate: 0.75, damage: 30, chain: 4, air: true,
    desc: "Kettenblitz springt auf mehrere Gegner.",
    branches: {
      lightning: { name: "Kettenblitz", desc: "Springt auf 5 weitere Gegner.", apply: (s) => ({ ...s, chain: s.chain + 5 }) },
      overcharge: { name: "Überladung", desc: "Mehr als doppelter Schaden.", apply: (s) => ({ ...s, damage: s.damage * 2.3 }) },
      emp: { name: "EMP-Stoß", desc: "Getroffene Gegner sind kurz gelähmt.", apply: (s) => ({ ...s, stun: 0.7 }) },
    },
  },
  rocket: {
    name: "Raketen-Huhn", cost: 240, unlock: 8, type: "bullet", range: 3.4, rate: 0.6, damage: 60, splash: 1.0, air: true, speed: 6, rocket: true,
    desc: "Langsame Raketen mit Wumms.",
    branches: {
      cluster: { name: "Streuraketen", desc: "Jede Rakete zerplatzt in 4 Mini-Bomben.", apply: (s) => ({ ...s, cluster: 4 }) },
      napalm: { name: "Napalm-Eier", desc: "Hinterlässt einen brennenden Teppich.", apply: (s) => ({ ...s, zone: { kind: "fire", dps: s.damage * 0.55, time: 3.5 } }) },
      homing: { name: "Lenkraketen", desc: "Drei Raketen auf drei Ziele gleichzeitig.", apply: (s) => ({ ...s, multi: 3, damage: s.damage * 0.85 }) },
    },
  },
  medic: {
    name: "Sanitäter-Huhn", cost: 200, unlock: 9, type: "aura", range: 2.2, buff: 0.2, air: false,
    desc: "Feuert Türme in der Nähe an: +20 % Schaden und Tempo.",
    branches: {
      heal: { name: "Heilaura", desc: "+1 Ei zurück nach jeder Welle.", apply: (s) => ({ ...s, heal: 1 }) },
      shield: { name: "Schildeier", desc: "Blockt die ersten 3 Diebe jeder Welle.", apply: (s) => ({ ...s, shields: 3 }) },
      revive: { name: "Wiederbelebung", desc: "Einmal pro Spiel: bei 0 Eiern zurück auf 10.", apply: (s) => ({ ...s, revive: 10 }) },
    },
  },
  dark: {
    name: "Dunkle-Materie-Huhn", cost: 380, unlock: 12, type: "pulse", range: 2.6, rate: 0.5, damage: 70, splash: 2.6, air: true, slow: 0.3, slowTime: 1,
    desc: "Gravitationswellen treffen alles im Umkreis.",
    branches: {
      hole: { name: "Schwarzes Loch", desc: "Zieht Gegner ein Stück zurück.", apply: (s) => ({ ...s, pull: 0.9, damage: s.damage * 1.2 }) },
      gravity: { name: "Schwerkraft-Puls", desc: "Größere Wellen, die kurz lähmen.", apply: (s) => ({ ...s, splash: s.splash + 1, range: s.range + 1, stun: 0.6 }) },
      void: { name: "Leerenstrahl", desc: "Dauerstrahl, der immer heißer wird.", apply: (s) => ({ ...s, type: "beam", dps: s.damage * 1.4, range: s.range + 0.8 }) },
    },
  },
};
export const TOWER_ORDER = ["gatling", "frost", "mortar", "sniper", "wizard", "golden", "tesla", "rocket", "medic", "dark"];
export const MAX_LEVEL = 3;

// Enemy roster (art: the concept sheet). size = drawn height in tiles.
export const ENEMIES = {
  runner: { name: "Renn-Huhn", hp: 24, speed: 2.0, bounty: 4, steal: 1, size: 0.8, desc: "Schnell und nervig." },
  fox: { name: "Flieger-Fuchs", hp: 42, speed: 1.15, bounty: 6, steal: 1, size: 0.95, desc: "Der Klassiker unter den Eierdieben." },
  chicks: { name: "Küken-Bande", hp: 13, speed: 2.4, bounty: 2, steal: 1, size: 0.7, pack: 4, desc: "Kommt immer im Rudel." },
  spider: { name: "Eier-Spinne", hp: 30, speed: 1.65, bounty: 4, steal: 1, size: 0.75, desc: "Krabbelt flink über den Weg." },
  pilot: { name: "Flieger-Huhn", hp: 36, speed: 1.5, bounty: 8, steal: 1, size: 0.85, flying: true, desc: "Fliegt direkt zum Nest." },
  slime: { name: "Schleim-Ei", hp: 90, speed: 0.9, bounty: 10, steal: 1, size: 0.9, split: { kind: "slimelet", n: 2 }, desc: "Platzt in zwei kleine Schleime." },
  slimelet: { name: "Mini-Schleim", hp: 30, speed: 1.35, bounty: 3, steal: 1, size: 0.55, sprite: "slime", desc: "" },
  knight: { name: "Ritter-Huhn", hp: 110, speed: 0.8, bounty: 12, steal: 1, size: 0.95, armor: 5, desc: "Schild und Rüstung." },
  raccoon: { name: "Waschbär-Dieb", hp: 60, speed: 1.3, bounty: 11, steal: 1, stealKorn: 40, size: 0.95, desc: "Klaut auch dein Korn!" },
  healer: { name: "Druiden-Huhn", hp: 70, speed: 0.95, bounty: 14, steal: 1, size: 0.95, heal: 0.06, desc: "Heilt Gegner in der Nähe." },
  bomber: { name: "Bomben-Huhn", hp: 70, speed: 1.05, bounty: 12, steal: 2, size: 0.95, bomb: { radius: 1.4, stun: 2.5 }, desc: "Explodiert und lähmt Türme." },
  boar: { name: "Panzer-Eber", hp: 260, speed: 0.7, bounty: 22, steal: 2, size: 1.05, armor: 7, desc: "Ein gepanzerter Brocken." },
  shadow: { name: "Schatten-Rabe", hp: 60, speed: 1.4, bounty: 14, steal: 1, size: 0.9, stealth: 1.6, desc: "Unsichtbar, bis er nah an einem Turm ist." },
  robohawk: { name: "Robo-Falke", hp: 80, speed: 2.0, bounty: 14, steal: 1, size: 0.85, flying: true, armor: 4, desc: "Schnell, fliegt, gepanzert." },
  ice: { name: "Eis-Vogel", hp: 95, speed: 1.25, bounty: 14, steal: 1, size: 0.9, flying: true, immune: ["slow", "freeze"], desc: "Immun gegen Kälte." },
  toxic: { name: "Gift-Ingenieur", hp: 120, speed: 0.85, bounty: 18, steal: 1, size: 1.0, jam: { radius: 1.9, factor: 0.55 }, desc: "Stört Türme: sie feuern langsamer." },
  mech: { name: "Mech-Huhn", hp: 420, speed: 0.6, bounty: 35, steal: 3, size: 1.15, armor: 10, immune: ["stun", "freeze", "pull"], desc: "Stahl auf Beinen." },
  hydra: { name: "Dreikopf-Huhn", hp: 600, speed: 0.7, bounty: 50, steal: 3, size: 1.2, split: { kind: "runner", n: 3, hp: 1.6 }, desc: "Zerfällt in drei Renn-Hühner." },
  golem: { name: "Fels-Golem", hp: 2200, speed: 0.5, bounty: 220, steal: 5, size: 1.7, armor: 8, boss: true, immune: ["stun", "freeze", "pull"], desc: "Boss: unaufhaltsamer Fels." },
  lava: { name: "Lava-Titan", hp: 2600, speed: 0.48, bounty: 380, steal: 6, size: 1.75, armor: 7, boss: true, immune: ["freeze", "pull"], spawnAt: [0.66, 0.33], desc: "Boss: speit Schleim-Eier." },
  dragon: { name: "Drachenkönig", hp: 3200, speed: 0.55, bounty: 700, steal: 10, size: 1.9, armor: 9, boss: true, flying: true, immune: ["stun", "freeze", "pull", "slow"], desc: "Endboss: fliegt, brennt, regiert." },
};
export const BOSS_ORDER = ["golem", "lava", "dragon"];
// Wave in which each enemy first appears.
export const ENEMY_UNLOCK = { fox: 1, runner: 1, chicks: 2, spider: 3, pilot: 4, slime: 5, knight: 6, raccoon: 7, healer: 8, bomber: 9, boar: 11, shadow: 12, robohawk: 13, ice: 14, toxic: 16, mech: 18, hydra: 22 };

export const CHAOS_MODS = {
  turbo: { name: "TURBO", desc: "Alle Gegner +45 % Tempo" },
  panzer: { name: "PANZER", desc: "Alle Gegner +6 Rüstung" },
  schwarm: { name: "SCHWARM", desc: "Doppelt so viele, aber schwächer" },
  regen: { name: "REGENERATION", desc: "Gegner heilen sich" },
  himmel: { name: "LUFTANGRIFF", desc: "Flieger-Schwärme aus allen Richtungen" },
};

const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);

function buildPath(points) {
  const segs = [];
  let total = 0;
  for (let i = 0; i < points.length - 1; i++) {
    const [x1, y1] = points[i], [x2, y2] = points[i + 1];
    const len = Math.hypot(x2 - x1, y2 - y1);
    segs.push({ x1, y1, x2, y2, len, start: total });
    total += len;
  }
  return { points, segs, length: total };
}
export const PATH_DATA = { a: buildPath(PATHS.a), b: buildPath(PATHS.b) };

export function pointOnPath(path, d) {
  const segs = path.segs;
  for (const s of segs) {
    if (d <= s.start + s.len) {
      const t = s.len ? (d - s.start) / s.len : 0;
      return { x: s.x1 + (s.x2 - s.x1) * t, y: s.y1 + (s.y2 - s.y1) * t, dx: Math.sign(s.x2 - s.x1), dy: Math.sign(s.y2 - s.y1) };
    }
  }
  const last = segs.at(-1);
  return { x: last.x2, y: last.y2, dx: Math.sign(last.x2 - last.x1), dy: Math.sign(last.y2 - last.y1) };
}

// Every tile the paths cover cannot hold a tower.
function pathTiles() {
  const set = new Set();
  for (const key of ["a", "b"]) {
    for (const s of PATH_DATA[key].segs) {
      const steps = Math.ceil(s.len * 2);
      for (let i = 0; i <= steps; i++) {
        const x = Math.round(s.x1 + ((s.x2 - s.x1) * i) / steps), y = Math.round(s.y1 + ((s.y2 - s.y1) * i) / steps);
        if (x >= 0 && y >= 0 && x < COLS && y < ROWS) set.add(`${x},${y}`);
      }
    }
  }
  for (const [dx, dy] of [[0, 0], [1, 0], [0, -1], [1, -1], [0, 1], [1, 1]]) set.add(`${NEST.x + dx},${NEST.y + dy}`);
  return set;
}
export const BLOCKED = pathTiles();

/** Stats of a tower at a level (1-3) with an optional branch (applied on top of level 3). */
export function towerStats(kind, level = 1, branch = null) {
  const base = TOWERS[kind];
  const lv = Math.min(level, 3);
  const m = Math.pow(1.6, lv - 1);
  let s = {
    ...base,
    damage: (base.damage || 0) * m,
    range: base.range + (lv - 1) * 0.3,
    rate: (base.rate || 0) * Math.pow(1.12, lv - 1),
    income: (base.income || 0) * lv,
    buff: (base.buff || 0) + (lv - 1) * 0.05,
    chain: base.chain || 0,
  };
  if (branch && base.branches[branch]) s = base.branches[branch].apply(s);
  return s;
}
export const upgradeCost = (kind, level) => Math.round(TOWERS[kind].cost * (level === 1 ? 0.8 : 1.4));
export const branchCost = (kind) => Math.round(TOWERS[kind].cost * 2.4);

/** Hit points multiplier: gentle at first, exponential later, brutal after the apocalypse. */
export function hpScale(wave) {
  let s = Math.pow(1.1, wave - 1);
  if (wave > 12) s *= Math.pow(1.06, wave - 12);
  if (wave > 20) s *= Math.pow(1.06, wave - 20);
  if (wave > APOCALYPSE_WAVE) s *= Math.pow(1.05, wave - APOCALYPSE_WAVE);
  return s;
}

/** The spawn list for a wave: [{ kind, path, delay }]. */
export function makeWave(wave, random = Math.random, mods = []) {
  const list = [];
  const paths = wave >= SECOND_PATH_WAVE ? ["a", "b"] : ["a"];
  const swarm = mods.includes("schwarm") ? 2 : 1;
  const base = Math.round((3 + wave * 1.3 + Math.pow(wave, 1.45) * 0.3) * swarm);
  const gap = Math.max(0.16, 0.95 - wave * 0.028) / (swarm > 1 ? 1.6 : 1);
  const pool = [];
  for (const [kind, from] of Object.entries(ENEMY_UNLOCK)) {
    if (wave < from) continue;
    // fresh enemies are rarer at first, then become regulars
    const weight = wave - from < 2 ? 1 : ["fox", "runner", "chicks"].includes(kind) && wave > 12 ? 1 : 2;
    for (let i = 0; i < weight; i++) pool.push(kind);
  }
  let t = 0;
  for (let i = 0; i < base; i++) {
    let kind = pool[Math.floor(random() * pool.length)];
    if (wave <= 3 && i < 3) kind = "fox";
    const pack = ENEMIES[kind].pack || 1;
    for (let p = 0; p < pack; p++) {
      list.push({ kind, path: paths[(i + p) % paths.length], delay: t });
      t += pack > 1 ? gap * 0.3 : gap;
    }
  }
  if (mods.includes("himmel")) for (let i = 0; i < 6 + wave; i++) list.push({ kind: i % 3 ? "pilot" : "robohawk", path: paths[i % paths.length], delay: random() * t });
  if (wave % 10 === 0) {
    const tier = wave / 10;
    const bosses = tier <= 3 ? [BOSS_ORDER[tier - 1]] : BOSS_ORDER.slice(0, Math.min(3, tier - 2));
    bosses.forEach((kind, i) => list.push({ kind, path: paths[i % paths.length], delay: t + 1.5 + i * 4 }));
  }
  return list.sort((x, y) => x.delay - y.delay);
}

export function pickMods(wave, random = Math.random) {
  if (wave < CHAOS_WAVE) return [];
  const keys = Object.keys(CHAOS_MODS);
  const count = wave >= APOCALYPSE_WAVE ? 2 + Math.floor((wave - APOCALYPSE_WAVE) / 8) : 1;
  const mods = [];
  while (mods.length < Math.min(count, keys.length)) {
    const k = keys[Math.floor(random() * keys.length)];
    if (!mods.includes(k)) mods.push(k);
  }
  return mods;
}

let nextId = 1;

export class DefenseEngine {
  constructor({ random = Math.random, onEvent = () => {} } = {}) {
    this.random = random;
    this.onEvent = onEvent;
    this.reset("ready");
  }

  reset(status = "ready") {
    this.status = status;
    this.time = 0;
    this.wave = 0;
    this.korn = START_KORN;
    this.eggs = START_EGGS;
    this.score = 0;
    this.kills = 0;
    this.towers = [];
    this.enemies = [];
    this.projectiles = [];
    this.zones = [];
    this.queue = [];
    this.waveActive = false;
    this.mods = [];
    this.leaks = 0;
    this.shields = 0;
    this.revived = false;
    this.seen = new Set();
  }

  start() { this.reset("playing"); this.onEvent({ type: "start" }); }
  emit(type, data = {}) { this.onEvent({ type, ...data }); }
  stats(t) { return towerStats(t.kind, t.level, t.branch); }

  towerAt(c, r) { return this.towers.find((t) => t.c === c && t.r === r); }
  unlocked(kind) { return Math.max(1, this.wave) >= TOWERS[kind].unlock; }
  canBuild(kind, c, r) {
    const spec = TOWERS[kind];
    if (!spec || this.status !== "playing") return false;
    if (c < 0 || r < 0 || c >= COLS || r >= ROWS) return false;
    if (BLOCKED.has(`${c},${r}`) || this.towerAt(c, r)) return false;
    if (!this.unlocked(kind)) return false;
    return this.korn >= spec.cost;
  }
  build(kind, c, r) {
    if (!this.canBuild(kind, c, r)) return null;
    const spec = TOWERS[kind];
    this.korn -= spec.cost;
    const tower = { id: nextId++, kind, c, r, x: c, y: r, level: 1, branch: null, spent: spec.cost, cooldown: 0, angle: -Math.PI / 2, target: null, heat: 0, kills: 0, targeting: spec.targeting || "first" };
    this.towers.push(tower);
    this.emit("build", { tower });
    return tower;
  }
  upgrade(id, branch = null) {
    const t = this.towers.find((x) => x.id === id);
    if (!t || this.status !== "playing" || t.branch) return false;
    if (t.level < MAX_LEVEL) {
      const cost = upgradeCost(t.kind, t.level);
      if (this.korn < cost) return false;
      this.korn -= cost; t.spent += cost; t.level++;
      this.emit("upgrade", { tower: t });
      return true;
    }
    if (!branch || !TOWERS[t.kind].branches[branch]) return false;
    const cost = branchCost(t.kind);
    if (this.korn < cost) return false;
    this.korn -= cost; t.spent += cost; t.branch = branch; t.level = 4;
    if (TOWERS[t.kind].branches[branch] && branch === "shield") this.shields = Math.max(this.shields, 3);
    this.emit("upgrade", { tower: t, branch });
    return true;
  }
  sell(id) {
    const i = this.towers.findIndex((x) => x.id === id);
    if (i < 0 || this.status !== "playing") return 0;
    const t = this.towers[i];
    const refund = Math.floor(t.spent * 0.7);
    this.korn += refund;
    this.towers.splice(i, 1);
    this.emit("sell", { tower: t, refund });
    return refund;
  }
  cycleTargeting(id) {
    const t = this.towers.find((x) => x.id === id);
    if (!t) return;
    const order = ["first", "strong", "last"];
    t.targeting = order[(order.indexOf(t.targeting) + 1) % order.length];
  }

  /** Starts the next wave. Calling it early (while enemies still march) pays a bonus. */
  startWave() {
    if (this.status !== "playing" || this.queue.length) return false;
    const early = this.waveActive && this.enemies.length > 0;
    this.wave++;
    this.mods = pickMods(this.wave, this.random);
    this.queue = makeWave(this.wave, this.random, this.mods).map((s) => ({ ...s, at: this.time + s.delay }));
    this.waveActive = true;
    this.shields = this.towers.reduce((n, t) => n + (this.stats(t).shields || 0), 0);
    let bonus = 0;
    if (early) { bonus = 12 + this.wave * 2; this.korn += bonus; }
    this.emit("waveStart", { wave: this.wave, mods: this.mods, boss: this.wave % 10 === 0, early, bonus });
    if (this.wave === SECOND_PATH_WAVE) this.emit("pathOpen", { path: "b" });
    return true;
  }

  spawn(kind, pathKey, distance = 0, scaleWave = this.wave) {
    const spec = ENEMIES[kind];
    let hp = spec.hp * hpScale(scaleWave);
    let speed = spec.speed * (1 + Math.min(0.5, scaleWave * 0.008));
    let armor = (spec.armor || 0) * (1 + scaleWave / 25);
    if (this.mods.includes("turbo")) speed *= 1.45;
    if (this.mods.includes("panzer")) armor += 6;
    if (this.mods.includes("schwarm")) hp *= 0.6;
    const e = {
      id: nextId++, kind, path: pathKey, d: distance, hp, maxHp: hp, speed, armor, slowUntil: 0, slowFactor: 1, stunUntil: 0, dots: [],
      flying: !!spec.flying, x: 0, y: 0, dx: 1, dy: 0, regen: this.mods.includes("regen") ? 0.03 : 0, immune: spec.immune || [], spawned: 0,
      fx: PATH_DATA[pathKey].points[0][0], fy: PATH_DATA[pathKey].points[0][1],
    };
    if (e.flying && pathKey === "a" && this.mods.includes("himmel") && !spec.boss) { e.fx = -1; e.fy = this.random() * ROWS; }
    this.place(e);
    this.enemies.push(e);
    if (spec.boss) this.emit("boss", { enemy: e });
    else if (spec.desc && !this.seen.has(kind)) { this.seen.add(kind); this.emit("newEnemy", { kind }); }
    return e;
  }

  place(e) {
    if (e.flying) {
      const total = Math.hypot(NEST.x - e.fx, NEST.y - e.fy);
      const t = Math.max(0, Math.min(1, e.d / total));
      e.x = e.fx + (NEST.x - e.fx) * t; e.y = e.fy + (NEST.y - e.fy) * t;
      e.dx = Math.sign(NEST.x - e.fx) || 1; e.dy = 0;
      e.done = t >= 1;
    } else {
      const p = pointOnPath(PATH_DATA[e.path], Math.max(0, e.d));
      e.x = p.x; e.y = p.y; e.dx = p.dx; e.dy = p.dy;
      e.done = e.d >= PATH_DATA[e.path].length;
    }
  }

  damage(e, amount, source, opts = {}) {
    if (e.hp <= 0) return 0;
    const armor = opts.pierce ? 0 : opts.magic ? e.armor / 2 : e.armor;
    const real = Math.max(amount * 0.25, amount - armor);
    e.hp -= real;
    e.hitAt = this.time;
    const spec = ENEMIES[e.kind];
    if (spec.spawnAt && e.hp > 0) {
      while (e.spawned < spec.spawnAt.length && e.hp / e.maxHp < spec.spawnAt[e.spawned]) {
        e.spawned++;
        for (let i = 0; i < 3; i++) this.spawn("slime", e.path, Math.max(0, e.d + 0.4 - i * 0.4));
        this.emit("bossSpawn", { enemy: e });
      }
    }
    if (opts.crit) e.critAt = this.time;
    if (e.hp <= 0) this.kill(e, source);
    return real;
  }

  kill(e, source) {
    const spec = ENEMIES[e.kind];
    let bounty = spec.bounty * (1 + this.wave * 0.03);
    // Golden treasure auras pay extra for kills in their range.
    for (const t of this.towers) { const s = this.stats(t); if (s.treasure && dist(t, e) <= s.range) bounty *= 1 + s.treasure; }
    bounty = Math.round(bounty);
    this.korn += bounty;
    this.score += bounty * 10;
    this.kills++;
    if (source) source.kills++;
    this.emit("kill", { enemy: e, bounty });
    if (spec.split) {
      for (let i = 0; i < spec.split.n; i++) {
        const child = this.spawn(spec.split.kind, e.path, Math.max(0, e.d - i * 0.35));
        if (spec.split.hp) child.hp = child.maxHp = child.maxHp * spec.split.hp;
        if (e.flying) { child.flying = false; }
      }
    }
    if (spec.bomb) {
      const hit = this.towers.filter((t) => dist(t, e) <= spec.bomb.radius);
      for (const t of hit) t.disabledUntil = this.time + spec.bomb.stun;
      this.emit("bomb", { x: e.x, y: e.y, radius: spec.bomb.radius, towers: hit.length });
    }
  }

  targetsFor(tower, stats) {
    const list = this.enemies.filter((e) => e.hp > 0 && (stats.air || !e.flying) && dist(e, tower) <= stats.range && this.visible(e));
    if (!list.length) return list;
    const progress = (e) => (e.flying ? e.d * 1.2 : e.d);
    if (tower.targeting === "strong") list.sort((a, b) => b.hp - a.hp);
    else if (tower.targeting === "last") list.sort((a, b) => progress(a) - progress(b));
    else list.sort((a, b) => progress(b) - progress(a));
    return list;
  }

  /** Shadow ravens can only be targeted close to a tower. */
  visible(e) {
    const stealth = ENEMIES[e.kind].stealth;
    if (!stealth) return true;
    return this.towers.some((t) => dist(t, e) <= stealth);
  }

  /** Toxic engineers jam towers close to them. */
  jamFor(tower) {
    let f = 1;
    for (const e of this.enemies) {
      const jam = ENEMIES[e.kind].jam;
      if (jam && e.hp > 0 && dist(e, tower) <= jam.radius) f = Math.min(f, jam.factor);
    }
    return f;
  }

  /** Damage / rate multiplier from medic towers nearby. */
  buffFor(tower) {
    let b = 0;
    for (const m of this.towers) {
      if (m === tower || m.kind !== "medic") continue;
      const s = this.stats(m);
      if (dist(m, tower) <= s.range) b = Math.max(b, s.buff);
    }
    return 1 + b;
  }

  update(dt) {
    if (this.status !== "playing") return;
    this.time += dt;
    while (this.queue.length && this.queue[0].at <= this.time) {
      const s = this.queue.shift();
      this.spawn(s.kind, s.path);
    }
    for (const e of this.enemies) {
      if (e.hp <= 0) continue;
      if (e.regen) e.hp = Math.min(e.maxHp, e.hp + e.maxHp * e.regen * dt);
      const heal = ENEMIES[e.kind].heal;
      if (heal) for (const o of this.enemies) if (o !== e && o.hp > 0 && o.hp < o.maxHp && dist(o, e) <= 1.6) o.hp = Math.min(o.maxHp, o.hp + o.maxHp * heal * dt);
      if (e.dots.length) {
        e.dots = e.dots.filter((d) => d.until > this.time);
        for (const d of e.dots) this.damage(e, d.dps * dt, d.source, { pierce: true });
        if (e.hp <= 0) continue;
      }
      if (this.time < e.stunUntil) continue;
      const slow = this.time < e.slowUntil ? e.slowFactor : 1;
      e.d += e.speed * slow * dt;
      this.place(e);
      if (e.done) {
        e.hp = 0; e.leaked = true;
        const steal = ENEMIES[e.kind].steal;
        if (this.shields > 0) { this.shields--; this.emit("shielded", { enemy: e }); continue; }
        this.eggs = Math.max(0, this.eggs - steal);
        this.leaks++;
        const korn = Math.min(this.korn, ENEMIES[e.kind].stealKorn || 0);
        this.korn -= korn;
        this.emit("leak", { enemy: e, steal, korn });
        if (this.eggs <= 0 && !this.revived) {
          const reviver = this.towers.find((t) => this.stats(t).revive);
          if (reviver) { this.revived = true; this.eggs = this.stats(reviver).revive; this.emit("revive", { tower: reviver }); }
        }
      }
    }
    for (const z of this.zones) {
      for (const e of this.enemies) if (e.hp > 0 && !e.flying && dist(e, z) <= z.r) this.damage(e, z.dps * dt, z.source, { pierce: true });
    }
    this.zones = this.zones.filter((z) => z.until > this.time);
    for (const t of this.towers) this.act(t, dt);
    for (const p of this.projectiles) this.fly(p, dt);
    this.projectiles = this.projectiles.filter((p) => !p.done);
    this.enemies = this.enemies.filter((e) => e.hp > 0);
    if (this.eggs <= 0) { this.status = "ended"; this.emit("gameOver", { wave: this.wave, score: this.score }); return; }
    if (this.waveActive && !this.queue.length && !this.enemies.length) this.clearWave();
  }

  clearWave() {
    this.waveActive = false;
    let bonus = 20 + this.wave * 4, income = 0, healed = 0;
    for (const t of this.towers) {
      const s = this.stats(t);
      if (s.type === "econ") {
        income += s.income;
        if (s.interest) income += Math.min(200, Math.floor(this.korn * s.interest));
      }
      if (s.heal && this.eggs < START_EGGS) { this.eggs = Math.min(START_EGGS, this.eggs + s.heal); healed += s.heal; }
    }
    this.korn += bonus + income;
    this.score += this.wave * 60;
    this.emit("waveClear", { wave: this.wave, bonus, income, healed });
  }

  act(t, dt) {
    const s = this.stats(t);
    if (s.type === "econ" || s.type === "aura") { t.firing = false; return; }
    t.disabled = this.time < (t.disabledUntil || 0);
    if (t.disabled) { t.firing = false; return; }
    const buff = this.buffFor(t);
    t.jammed = this.jamFor(t);
    t.cooldown -= dt * buff * t.jammed;
    if (s.type === "pulse") {
      if (t.cooldown > 0) return;
      const inRange = this.enemies.filter((e) => e.hp > 0 && (s.air || !e.flying) && dist(e, t) <= s.splash);
      if (!inRange.length) return;
      t.cooldown = 1 / s.rate;
      for (const e of inRange) {
        this.damage(e, s.damage * buff, t);
        if (s.slow) this.applyEffects(e, { slow: s.slow, slowTime: s.slowTime });
        if (s.stun && !e.immune.includes("stun")) e.stunUntil = Math.max(e.stunUntil, this.time + s.stun);
        if (s.pull && !e.immune.includes("pull") && !e.flying) { e.d = Math.max(0, e.d - s.pull); this.place(e); }
      }
      this.emit("pulse", { tower: t, radius: s.splash, fx: s.pulseFx || (s.pull ? "hole" : "gravity") });
      return;
    }
    const targets = this.targetsFor(t, s);
    const target = targets[0];
    if (s.type === "beam") {
      if (!target) { t.target = null; t.firing = false; t.heat = Math.max(0, t.heat - dt * 2); return; }
      if (t.target !== target.id) { t.target = target.id; t.heat = 0; }
      t.heat = Math.min(4, t.heat + dt);
      t.angle = Math.atan2(target.y - t.y, target.x - t.x);
      this.damage(target, s.dps * buff * (1 + t.heat * 0.7) * dt, t);
      t.firing = true;
      return;
    }
    t.firing = false;
    if (!target) return;
    t.angle = Math.atan2(target.y - t.y, target.x - t.x);
    if (t.cooldown > 0) return;
    t.cooldown = 1 / s.rate;
    const dmg = s.damage * buff;
    if (s.type === "chain") {
      const hit = [target];
      let last = target;
      for (let i = 1; i < s.chain; i++) {
        const next = this.enemies.find((e) => e.hp > 0 && !hit.includes(e) && dist(e, last) < 1.9);
        if (!next) break;
        hit.push(next); last = next;
      }
      const points = [{ x: t.x, y: t.y }, ...hit.map((e) => ({ x: e.x, y: e.y }))];
      hit.forEach((e, i) => { this.damage(e, dmg * Math.pow(0.8, i), t); if (s.stun && !e.immune.includes("stun")) e.stunUntil = Math.max(e.stunUntil, this.time + s.stun); });
      this.emit("zap", { tower: t, points, emp: !!s.stun });
      return;
    }
    if (s.type === "sniper") {
      const crit = s.crit && this.random() < s.crit;
      this.damage(target, dmg * (crit ? s.critMult : 1), t, { pierce: s.pierce, crit });
      this.emit("snipe", { tower: t, x: target.x, y: target.y, crit });
      return;
    }
    if (s.type === "shell") {
      const shells = s.volley || 1;
      for (let i = 0; i < shells; i++) {
        const victim = targets[Math.min(i, targets.length - 1)];
        const lead = Math.min(1.2, dist(t, victim) / 3);
        const ahead = { ...victim, d: victim.d + victim.speed * lead };
        this.place(ahead);
        const spread = i ? 0.5 : 0;
        this.projectiles.push({ id: nextId++, kind: "shell", x: t.x, y: t.y, sx: t.x, sy: t.y, tx: ahead.x + (this.random() - 0.5) * spread, ty: ahead.y + (this.random() - 0.5) * spread, t: -i * 0.12, dur: lead, damage: dmg, splash: s.splash, zone: s.zone, tower: t });
      }
      this.emit("shoot", { tower: t });
      return;
    }
    // bullets (gatling, frost, wizard, rocket)
    const shots = s.multi ? targets.slice(0, s.multi) : [target];
    for (const victim of shots) {
      this.projectiles.push({ id: nextId++, kind: t.kind, x: t.x, y: t.y, target: victim.id, speed: s.speed, damage: dmg, splash: s.splash, slow: s.slow, slowTime: s.slowTime,
        poison: s.poison ? s.poison * buff : 0, poisonTime: s.poisonTime, freeze: s.freeze, freezeTime: s.freezeTime, magic: s.magic, chain: s.chain, cluster: s.cluster, zone: s.zone, branch: t.branch, tower: t });
    }
    this.emit("shoot", { tower: t });
  }

  fly(p, dt) {
    if (p.kind === "shell") {
      p.t += dt;
      if (p.t < 0) return;
      const k = Math.min(1, p.t / p.dur);
      p.x = p.sx + (p.tx - p.sx) * k; p.y = p.sy + (p.ty - p.sy) * k; p.h = Math.sin(k * Math.PI) * 1.4;
      if (k >= 1) { p.done = true; this.explode(p); }
      return;
    }
    const target = this.enemies.find((e) => e.id === p.target && e.hp > 0);
    if (!target) { p.done = true; return; }
    const d = dist(p, target), step = p.speed * dt;
    if (d <= step + 0.15) {
      p.done = true;
      this.impact(p, target);
      return;
    }
    p.angle = Math.atan2(target.y - p.y, target.x - p.x);
    p.x += ((target.x - p.x) / d) * step; p.y += ((target.y - p.y) / d) * step;
  }

  impact(p, target) {
    const opts = { magic: p.magic };
    if (p.splash) this.explode({ ...p, x: target.x, y: target.y });
    else {
      this.damage(target, p.damage, p.tower, opts);
      this.applyEffects(target, p);
    }
    if (p.chain > 1) {
      const hit = [target];
      let last = target;
      for (let i = 1; i < p.chain; i++) {
        const next = this.enemies.find((e) => e.hp > 0 && !hit.includes(e) && dist(e, last) < 1.9);
        if (!next) break;
        hit.push(next); last = next;
        this.damage(next, p.damage * 0.7, p.tower, opts);
      }
      this.emit("zap", { tower: p.tower, points: hit.map((e) => ({ x: e.x, y: e.y })), magic: true });
    }
    this.emit("hit", { kind: p.kind, branch: p.branch, x: target.x, y: target.y });
  }

  applyEffects(e, p) {
    if (e.hp <= 0) return;
    if (p.slow && !e.immune.includes("slow")) {
      e.slowFactor = this.time < e.slowUntil ? Math.min(e.slowFactor, 1 - p.slow) : 1 - p.slow;
      e.slowUntil = Math.max(e.slowUntil, this.time + p.slowTime);
    }
    if (p.poison) e.dots.push({ dps: p.poison, until: this.time + p.poisonTime, source: p.tower, kind: "poison" });
    if (p.freeze && this.random() < p.freeze && !e.immune.includes("freeze")) { e.stunUntil = this.time + p.freezeTime; e.frozenUntil = this.time + p.freezeTime; this.emit("freeze", { x: e.x, y: e.y }); }
  }

  explode(p) {
    const shell = p.kind === "shell";
    for (const e of this.enemies) {
      if (e.hp <= 0 || (shell && e.flying)) continue;
      const d = dist(e, p);
      if (d > p.splash) continue;
      this.damage(e, p.damage * (1 - (d / p.splash) * 0.5), p.tower, { magic: p.magic });
      this.applyEffects(e, p);
    }
    if (p.zone) this.zones.push({ ...p.zone, x: p.x, y: p.y, r: p.splash * 0.9, until: this.time + p.zone.time, born: this.time, source: p.tower });
    this.emit("explode", { kind: p.kind, branch: p.branch, x: p.x, y: p.y, radius: p.splash, zone: p.zone?.kind });
    if (p.cluster) {
      for (let i = 0; i < p.cluster; i++) {
        const a = (i / p.cluster) * Math.PI * 2;
        this.projectiles.push({ id: nextId++, kind: "shell", mini: true, x: p.x, y: p.y, sx: p.x, sy: p.y, tx: p.x + Math.cos(a) * 1.1, ty: p.y + Math.sin(a) * 1.1, t: 0, dur: 0.35, damage: p.damage * 0.4, splash: 0.6, tower: p.tower });
      }
    }
  }

  giveUp() { if (this.status === "playing") { this.status = "ended"; this.emit("gameOver", { wave: this.wave, score: this.score, gaveUp: true }); } }
}
