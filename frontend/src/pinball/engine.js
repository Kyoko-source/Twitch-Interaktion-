import { SUBSTEP } from "./physics.js";
import { buildTable, HABITRAILS, LAYOUT } from "./table.js";

// Game rules on top of the physics table. Runs headless (node tests use it directly);
// the renderer, DMD and audio only listen to `emit` events and read the public state.

export const MISSIONS = [
  { id: "ramps", name: "RAMPENFIEBER", goal: 4, time: 40, hint: "4 RAMPEN" },
  { id: "bumpers", name: "TANZFLAECHE", goal: 25, time: 35, hint: "25 BUMPER" },
  { id: "orbits", name: "SCHLEIFENJAGD", goal: 3, time: 40, hint: "3 ORBITS" },
  { id: "drops", name: "VIP-STURM", goal: 6, time: 40, hint: "6 VIP-ZIELE" },
  { id: "combo", name: "COMBO-KOENIG", goal: 3, time: 45, hint: "3-FACH COMBO" },
];
export const BALLS_PER_GAME = 3;
const RAMP_MIN_SPEED = 15;
const PLUNGER_MIN = 22, PLUNGER_MAX = 38, PLUNGER_FILL = 1.35;
const REPLAY_AT = 6_000_000;
const MAJOR = ["rampL", "rampR", "orbitL", "orbitR"];
const fmt = (n) => Math.round(n).toLocaleString("de-DE");

export class PinballEngine {
  constructor({ random = Math.random } = {}) {
    this.random = random;
    this.listeners = [];
    this.table = buildTable();
    this.world = this.table.world;
    this.world.random = random;
    this.time = 0;
    this.acc = 0;
    this.status = "attract";
    this.score = 0;
    this.messages = [];
    this.lamps = {};
    this.plungerCharge = 0;
    this.plungerHeld = false;
    this.bindWorld();
    this.resetGameState();
  }

  on(fn) { this.listeners.push(fn); return () => { this.listeners = this.listeners.filter((f) => f !== fn); }; }
  emit(type, data = {}) { for (const fn of this.listeners) fn(type, data); }
  say(title, sub = "", ms = 1600, style = "zoom", priority = 1) {
    // Higher priority messages replace lower ones; equal ones queue (max 3 waiting).
    if (this.messages.length && priority > this.messages[0].priority) this.messages = [];
    this.messages.push({ title, sub, ms, style, priority, born: this.time });
    if (this.messages.length > 4) this.messages.splice(1, this.messages.length - 4);
  }

  resetGameState() {
    this.bothHints = 0;
    this.score = 0;
    this.ball = 1;
    this.extraBalls = 0;
    this.replayAwarded = false;
    this.missionsDone = new Set();
    this.missionLit = false;
    this.mission = null;
    this.orbitsTowardMission = 0;
    this.wizard = false;
    this.wizardLevel = 0;
    this.locks = 0;
    this.multiball = false;
    this.multiballsPlayed = 0;
    this.extraBallLit = false;
    this.skillValue = 500_000;
    this.stats = { ramps: 0, orbits: 0, bumpers: 0, drops: 0, lanes: 0, spins: 0, jackpots: 0, bestCombo: 0, missions: 0, bestStreak: 0 };
    this.streak = 0;
    this.resetBallState();
  }

  resetBallState() {
    this.bonusX = 1;
    this.ballStats = { ramps: 0, orbits: 0, bumpers: 0, drops: 0, spins: 0 };
    this.lanesLit = [false, false, false];
    this.bumperLevel = 0;
    this.bumperHits = 0;
    this.kickbackLit = true;
    this.tiltMeter = 0;
    this.tilted = false;
    this.flipPresses = [];
    this.spamWarnedAt = undefined;
    this.ballSaveUntil = 0;
    this.ballSaveArmed = true;
    this.combo = 0;
    this.lastMajorAt = -99;
    this.skillLane = Math.floor(this.random() * 3);
    this.skillActive = true;
    this.vipLit = false;
    this.vipUntil = 0;
    this.jackpots = {};
    this.superLit = false;
    this.lastSwitch = this.time;
    this.orbitStart = null;
    this.raiseDrops();
  }

  // ------------------------------------------------------------- public controls
  start() {
    for (const b of [...this.world.balls]) this.world.removeBall(b);
    this.resetGameState();
    this.status = "ready";
    this.serveBall();
    this.say("SPIEL STARTET", "BALL 1 VON " + BALLS_PER_GAME, 1800, "zoom", 2);
    this.emit("gameStart");
  }

  setFlipper(side, down) {
    const f = side === "left" ? this.table.flipL : this.table.flipR;
    if (f.pressed === down) return;
    const live = ["ready", "play"].includes(this.status) && !this.tilted;
    f.pressed = down && live;
    if (down && live) {
      // Only one flipper at a time: holding both up would make the table far too easy.
      // The newer press wins and the other bat drops.
      const other = side === "left" ? this.table.flipR : this.table.flipL;
      if (other.pressed) {
        other.pressed = false;
        this.emit("flipper", { side: side === "left" ? "right" : "left", up: false });
        this.emit("flipperBlocked", { side });
        this.bothHints = (this.bothHints || 0) + 1;
        if (this.bothHints <= 2) this.say("NUR EIN FLIPPER!", "BEIDE ZUGLEICH GEHT NICHT", 1500, "flash", 6);
      }
      this.emit("flipper", { side, up: true });
      if (this.status === "play") this.checkFlipperSpam();
      // Lane change: rotate the lit top lanes like a real machine.
      if (this.lanesLit.some(Boolean) && !this.lanesLit.every(Boolean)) {
        const l = this.lanesLit;
        this.lanesLit = side === "left" ? [l[1], l[2], l[0]] : [l[2], l[0], l[1]];
      }
      if (this.skillActive && this.status === "ready") this.skillLane = (this.skillLane + (side === "left" ? 2 : 1)) % 3;
    } else if (!down && live) this.emit("flipper", { side, up: false });
  }

  setPlunger(down) {
    if (down) { this.plungerHeld = true; return; }
    if (!this.plungerHeld) return;
    this.plungerHeld = false;
    const ball = this.ballInLane();
    const charge = this.plungerCharge;
    this.plungerCharge = 0;
    this.emit("plunger", { charge });
    if (!ball || this.tilted) return;
    ball.vy = -(PLUNGER_MIN + (PLUNGER_MAX - PLUNGER_MIN) * charge);
    ball.vx = 0;
    if (this.status === "ready") { this.status = "play"; this.launchedAt = this.time; }
    this.emit("launch", { charge });
  }

  // Hammering both flippers non-stop is spam: first a warning, keep going and the ball is lost.
  checkFlipperSpam() {
    const now = this.time;
    this.flipPresses = (this.flipPresses || []).filter((t) => now - t < 1.5);
    this.flipPresses.push(now);
    if (this.flipPresses.length < 11) return;
    this.flipPresses = [];
    if (this.spamWarnedAt !== undefined && now - this.spamWarnedAt < 8) {
      this.spamWarnedAt = undefined;
      this.tilt("SPAM-TILT", "FLIPPER-SPAM VERBOTEN");
      this.emit("spamTilt");
      return;
    }
    this.spamWarnedAt = now;
    this.say("NICHT SPAMMEN!", "NOCHMAL = BALL WEG", 2200, "flash", 7);
    this.emit("spamWarning");
  }

  nudge(dir) {
    if (this.status !== "play" || this.tilted) return;
    if (this.time - (this.lastNudge || -9) < 0.35) return;
    this.lastNudge = this.time;
    for (const b of this.freeBalls()) { b.vx += dir * 1.7; b.vy -= 1.1; }
    this.tiltMeter += 1;
    this.emit("nudge", { dir });
    if (this.tiltMeter >= 2.7) this.tilt();
    else if (this.tiltMeter >= 1.9) { this.say("WARNUNG", "NICHT SO WILD!", 1200, "flash", 3); this.emit("tiltWarning"); }
  }

  // ------------------------------------------------------------- helpers
  freeBalls() { return this.world.balls.filter((b) => !b.held && !b.rail); }
  ballInLane() { return this.world.balls.find((b) => !b.held && !b.rail && b.x > LAYOUT.wallR && b.y > 18.4 && Math.abs(b.vy) < 1.5); }
  liveBallCount() { return this.world.balls.length + (this.pendingServes || 0); }
  addScore(points, { combo = false } = {}) {
    if (this.tilted || !["play", "ready"].includes(this.status)) return 0;
    const value = Math.round(points * (this.wizard ? 2 : 1));
    this.score += value;
    if (!this.replayAwarded && this.score >= REPLAY_AT) {
      this.replayAwarded = true;
      this.extraBalls++;
      this.say("REPLAY", "EXTRA BALL!", 2200, "flash", 4);
      this.emit("extraBall", { replay: true });
    }
    return value;
  }
  switchHit() {
    this.lastSwitch = this.time;
    if (this.status === "play" && !this.tilted) {
      // osu!-style hit streak: every switch counts, losing the ball breaks it.
      this.streak++;
      this.stats.bestStreak = Math.max(this.stats.bestStreak, this.streak);
      const s = this.streak;
      if (s === 10 || s === 25 || s === 50 || s === 75 || (s >= 100 && s % 50 === 0)) this.emit("streak", { count: s });
    }
    if (this.skillActive && this.status === "play" && this.time - (this.launchedAt || 0) > 0.2) this.skillActive = false;
    if (this.ballSaveArmed && this.status === "play") { this.ballSaveArmed = false; this.ballSaveUntil = this.time + 8; }
  }

  serveBall({ auto = false, power = 36 } = {}) {
    const b = this.world.addBall(LAYOUT.plungerRest.x, LAYOUT.plungerRest.y, 0, 0);
    if (auto) { b.vy = -power; this.emit("launch", { charge: 1, auto: true }); }
    return b;
  }

  raiseDrops() {
    for (const d of this.table.drops) d.enabled = true;
    this.vipLit = false;
    this.dropsResetPending = false;
    this.emit("dropsReset");
  }

  // ------------------------------------------------------------- physics events
  bindWorld() {
    const w = this.world;
    w.on("hit", (b, item, speed) => {
      if (item.kind === "bumper") this.bumper(item, b);
      else if (item.kind === "drop") this.dropHit(item);
      else if (item.kind === "flipper") this.emit("flipperHit", { speed });
      else if (speed > 4) this.emit("collide", { speed, kind: item.vis || item.kind, x: b.x, y: b.y });
    });
    w.on("kick", (b, item) => {
      if (item.kind === "sling") { this.switchHit(); this.addScore(110); this.emit("sling", { id: item.id, x: b.x, y: b.y }); }
    });
    w.on("ballClick", (b, speed) => this.emit("collide", { speed, kind: "ball" }));
    w.on("sensor", (b, s, dir, speed) => this.sensor(b, s, dir, speed));
  }

  bumper(item, b) {
    if (this.tilted) return;
    this.switchHit();
    this.bumperHits++;
    this.stats.bumpers++; this.ballStats.bumpers++;
    if (this.bumperHits % 25 === 0 && this.bumperLevel < 5) {
      this.bumperLevel++;
      this.say("TANZFLAECHE", `LEVEL ${this.bumperLevel + 1}`, 1200, "flash");
      this.emit("bumperLevel", { level: this.bumperLevel });
    }
    const v = this.addScore(1000 + this.bumperLevel * 500);
    this.progressMission("bumpers", 1);
    this.emit("bumper", { id: item.id, index: item.index, x: item.x, y: item.y, value: v });
  }

  dropHit(item) {
    if (!item.enabled || this.tilted) return;
    item.enabled = false;
    this.switchHit();
    this.stats.drops++; this.ballStats.drops++;
    const v = this.addScore(5000);
    this.progressMission("drops", 1);
    this.emit("drop", { index: item.index, value: v });
    if (this.table.drops.every((d) => !d.enabled)) {
      this.addScore(25_000);
      if (!this.multiball) {
        this.vipLit = true;
        this.vipUntil = this.time + 25;
        this.say("VIP OFFEN", this.locks === 2 ? "MULTIBALL BEREIT" : `LOCK ${this.locks + 1} BEREIT`, 1800, "zoom", 2);
        this.emit("vipLit");
      }
    }
  }

  sensor(b, s, dir, speed) {
    if (this.tilted && s.id !== "scoop") return;
    const id = s.id;
    if (id.startsWith("lane")) return this.lane(s.index);
    if (id === "spinner") return this.spinner(speed);
    if (id === "orbitL" || id === "orbitR") return this.orbitSensor(id, dir);
    if ((id === "rampL" || id === "rampR") && dir < 0) {
      if (speed >= RAMP_MIN_SPEED) this.startRamp(b, id);
      else { this.emit("rampFail", { id }); this.switchHit(); }
      return;
    }
    if (id === "scoop") return this.scoop(b);
    if (id === "inlaneL" || id === "inlaneR") { this.switchHit(); this.addScore(1000); this.emit("rollover", { id }); return; }
    if (id === "outlaneL" || id === "outlaneR") { if (dir > 0) { this.switchHit(); this.addScore(5000); this.emit("outlane", { id }); } return; }
    if (id === "kickback" && dir > 0 && this.kickbackLit) {
      this.kickbackLit = false;
      b.vy = -25; b.vx = 0.4;
      this.addScore(10_000);
      this.say("KICKBACK", "", 900, "flash");
      this.emit("kickback");
    }
  }

  lane(i) {
    const skill = this.skillActive && this.status === "play";
    this.switchHit();
    this.stats.lanes++;
    if (skill) {
      this.skillActive = false;
      if (i === this.skillLane) {
        const v = this.addScore(this.skillValue);
        this.say("SKILL SHOT", fmt(v), 2000, "flash", 3);
        this.emit("skillShot", { value: v });
        this.skillValue += 250_000;
      }
    }
    this.addScore(this.lanesLit[i] ? 1000 : 5000);
    this.lanesLit[i] = true;
    this.emit("lane", { index: i });
    if (this.lanesLit.every(Boolean)) {
      this.bonusX = Math.min(9, this.bonusX + 1);
      this.kickbackLit = true;
      this.addScore(25_000);
      this.say("BONUS " + this.bonusX + "X", "KICKBACK AN", 1400, "zoom", 2);
      this.emit("lanesComplete", { bonusX: this.bonusX });
      this.lanesLit = [false, false, false];
    }
  }

  spinner(speed) {
    this.switchHit();
    const spins = Math.max(1, Math.round(speed / 2.6));
    this.stats.spins += spins; this.ballStats.spins += spins;
    this.addScore(spins * 300);
    this.emit("spinner", { spins });
  }

  orbitSensor(id, dir) {
    this.switchHit();
    const up = dir < 0;
    if (up) { this.orbitStart = { id, at: this.time }; return; }
    if (this.orbitStart && this.orbitStart.id !== id && this.time - this.orbitStart.at < 2.5) {
      const shot = this.orbitStart.id === "orbitL" ? "orbitL" : "orbitR";
      this.orbitStart = null;
      this.stats.orbits++; this.ballStats.orbits++;
      this.orbitsTowardMission++;
      this.major(shot, 20_000 + Math.min(20, this.stats.orbits) * 2500, "ORBIT");
      this.progressMission("orbits", 1);
      if (!this.mission && !this.missionLit && !this.wizard && this.orbitsTowardMission >= 2 && this.missionsDone.size < MISSIONS.length) {
        this.missionLit = true;
        this.orbitsTowardMission = 0;
        this.say("MISSION BEREIT", "LINKE RAMPE!", 1800, "zoom", 2);
        this.emit("missionLit");
      }
    }
  }

  startRamp(b, id) {
    this.switchHit();
    const path = HABITRAILS[id];
    const pts = path.points;
    const lens = [0];
    for (let i = 1; i < pts.length; i++) lens.push(lens[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1], (pts[i][2] - pts[i - 1][2]) * 2));
    b.rail = { id, pts, lens, total: lens[lens.length - 1], s: 0, speed: 12, exit: path.exit };
    this.stats.ramps++; this.ballStats.ramps++;
    this.emit("ramp", { id });
    // Mission start / extra ball collection take priority over plain ramp value.
    if (id === "rampL" && this.missionLit && !this.mission && !this.multiball) this.startMission();
    if (id === "rampR" && this.extraBallLit) {
      this.extraBallLit = false;
      this.extraBalls++;
      this.say("EXTRA BALL", "", 2400, "flash", 4);
      this.emit("extraBall", {});
    }
    this.major(id, 25_000 + Math.min(20, this.stats.ramps) * 5000, id === "rampL" ? "DJ-RAMPE" : "NEON-RAMPE");
    this.progressMission("ramps", 1);
  }

  major(shot, value, label) {
    this.combo = this.time - this.lastMajorAt < 4.5 ? this.combo + 1 : 1;
    this.lastMajorAt = this.time;
    this.stats.bestCombo = Math.max(this.stats.bestCombo, this.combo);
    let v = this.addScore(value * this.combo);
    if (this.combo >= 2) {
      this.say(`${this.combo}-FACH COMBO`, fmt(v), 1400, "zoom", 2);
      this.emit("combo", { count: this.combo });
      if (this.mission?.id === "combo" && this.combo > this.mission.progress) this.progressMission("combo", this.combo - this.mission.progress);
    } else this.say(label, fmt(v), 900, "slide", 1);
    if (this.wizard) {
      const w = this.addScore(1_000_000 * (1 + this.wizardLevel * 0.5));
      this.say("LAST CALL", fmt(w), 1400, "flash", 3);
      this.emit("jackpot", { value: w, wizard: true });
    } else if (this.multiball && this.jackpots[shot]) {
      this.jackpots[shot] = false;
      const jv = this.addScore(this.jackpotValue);
      this.stats.jackpots++;
      this.say("JACKPOT", fmt(jv), 2000, "flash", 4);
      this.emit("jackpot", { value: jv });
      if (MAJOR.every((m) => !this.jackpots[m])) {
        this.superLit = true;
        this.say("SUPER JACKPOT", "VIP-SCOOP!", 2000, "zoom", 4);
        this.emit("superLit");
      }
    }
    this.emit("major", { shot, combo: this.combo, value: v });
  }

  scoop(b) {
    if (b.held || b.rail || this.time < (b.ignoreScoopUntil || 0)) return;
    this.switchHit();
    b.held = { until: this.time + 1.4 };
    b.vx = 0; b.vy = 0;
    b.x = LAYOUT.scoop.x; b.y = LAYOUT.scoop.y;
    this.emit("scoopIn");
    if (this.tilted) return;
    if (this.multiball && this.superLit) {
      this.superLit = false;
      const v = this.addScore(this.jackpotValue * 4);
      this.say("SUPER JACKPOT", fmt(v), 2600, "flash", 5);
      this.emit("superJackpot", { value: v });
      this.jackpotValue += 250_000;
      for (const m of MAJOR) this.jackpots[m] = true;
      b.held.until = this.time + 2.2;
      return;
    }
    if (this.vipLit && !this.multiball && !this.wizard) {
      this.vipLit = false;
      this.locks++;
      this.addScore(100_000);
      if (this.locks >= 3) { b.held.until = this.time + 2.4; this.startMultiball(); }
      else { this.say(`BALL ${this.locks} GESPERRT`, this.locks === 2 ? "NOCH EINER!" : "VIP LOUNGE", 1800, "zoom", 3); this.emit("lock", { count: this.locks }); }
      this.dropsResetPending = true;
      return;
    }
    const v = this.addScore(15_000);
    this.say("VIP-SCOOP", fmt(v), 900, "slide");
    if (!this.multiball) this.dropsResetPending = true;
  }

  startMultiball() {
    this.multiball = true;
    this.multiballsPlayed++;
    this.locks = 0;
    this.jackpotValue = 500_000 + (this.multiballsPlayed - 1) * 250_000;
    for (const m of MAJOR) this.jackpots[m] = true;
    this.superLit = false;
    this.ballSaveUntil = this.time + 15;
    this.ballSaveArmed = false;
    for (const d of this.table.drops) d.enabled = false; // VIP door stays open
    this.say("MULTIBALL", "ALLE AUF DIE TANZFLAECHE", 2600, "flash", 5);
    this.emit("multiball");
    this.queueServes(2, 0.9);
  }

  startWizard() {
    this.wizard = true;
    this.multiball = true;
    this.jackpots = {};
    this.missionLit = false;
    this.mission = null;
    this.ballSaveUntil = this.time + 20;
    this.ballSaveArmed = false;
    for (const d of this.table.drops) d.enabled = false;
    this.say("LAST CALL", "JEDER SCHUSS 1 MIO", 3000, "flash", 6);
    this.emit("wizard");
    this.queueServes(3, 0.7);
  }

  queueServes(n, gap) {
    this.pendingServes = (this.pendingServes || 0) + n;
    for (let i = 0; i < n; i++) this.timers.push({ at: this.time + gap * (i + 1), fn: () => { this.pendingServes--; this.serveBall({ auto: true }); } });
  }

  startMission() {
    const next = MISSIONS.find((m) => !this.missionsDone.has(m.id));
    if (!next) return;
    this.missionLit = false;
    this.mission = { ...next, progress: 0, until: this.time + next.time };
    if (next.id === "combo") this.lastMajorAt = -99; // combos must be built after the start
    this.say(next.name, next.hint + ` IN ${next.time}S`, 2400, "zoom", 4);
    this.emit("missionStart", { mission: next });
  }

  progressMission(id, amount) {
    const m = this.mission;
    if (!m || m.id !== id || this.tilted) return;
    m.progress = Math.min(m.goal, m.progress + amount);
    this.emit("missionProgress", { progress: m.progress, goal: m.goal });
    if (m.progress >= m.goal) {
      this.missionsDone.add(m.id);
      this.stats.missions++;
      const v = this.addScore(750_000 + this.missionsDone.size * 250_000);
      this.mission = null;
      this.say("MISSION GESCHAFFT", fmt(v), 2600, "flash", 5);
      this.emit("missionComplete", { count: this.missionsDone.size });
      if (this.missionsDone.size === 2 || this.missionsDone.size === 4) {
        this.extraBallLit = true;
        this.timers.push({ at: this.time + 2.7, fn: () => { this.say("EXTRA BALL", "AN DER NEON-RAMPE", 1800, "zoom", 3); this.emit("extraBallLit"); } });
      }
      if (this.missionsDone.size >= MISSIONS.length) this.timers.push({ at: this.time + 2.8, fn: () => this.startWizard() });
    }
  }

  tilt(title = "TILT", sub = "") {
    this.tilted = true;
    this.table.flipL.pressed = false;
    this.table.flipR.pressed = false;
    this.mission = null;
    this.say(title, sub, 4000, "flash", 9);
    this.emit("tilt");
  }

  // ------------------------------------------------------------- simulation
  update(dt) {
    this.acc = Math.min(this.acc + dt, 0.1);
    while (this.acc >= SUBSTEP) {
      this.acc -= SUBSTEP;
      this.step(SUBSTEP);
    }
    if (this.messages.length && this.time - this.messages[0].born > this.messages[0].ms / 1000) {
      this.messages.shift();
      if (this.messages[0]) this.messages[0].born = this.time;
    }
    this.updateLamps();
  }

  step(dt) {
    this.time += dt;
    if (this.plungerHeld) this.plungerCharge = Math.min(1, this.plungerCharge + dt / PLUNGER_FILL);
    this.tiltMeter = Math.max(0, this.tiltMeter - dt * 0.35);
    this.world.step(dt);
    for (const b of [...this.world.balls]) {
      if (b.rail) this.advanceRail(b, dt);
      else if (b.held) { if (this.time >= b.held.until) this.ejectScoop(b); }
      else if (b.y > 19.8 && b.x < LAYOUT.wallR) this.drain(b);
      else if (b.x < -0.2 || b.x > 10.2 || b.y < -0.6 || b.y > 21) this.drain(b, true);
    }
    for (const due of this.timers.filter((t) => this.time >= t.at)) { this.timers = this.timers.filter((x) => x !== due); due.fn(); }
    if (this.status !== "play") return;
    if (this.mission && !this.mission.hurried && this.mission.until - this.time < 10) { this.mission.hurried = true; this.emit("missionHurry"); }
    if (this.mission && this.time > this.mission.until) {
      this.say("MISSION VORBEI", `${this.mission.progress}/${this.mission.goal}`, 1800, "zoom", 3);
      this.emit("missionFail");
      this.mission = null;
      this.missionLit = true; // retry right away from the left ramp
    }
    if (this.vipLit && !this.multiball && this.time > this.vipUntil) {
      this.say("VIP GESCHLOSSEN", "", 1200, "slide");
      this.vipLit = false;
      this.dropsResetPending = true;
      this.emit("vipClosed");
    }
    if (this.dropsResetPending && !this.multiball && !this.wizard && !this.world.balls.some((b) => b.held || (b.x > 3.7 && b.x < 5.6 && b.y > 7.5 && b.y < 10.3))) this.raiseDrops();
    if (this.multiball && this.liveBallCount() <= 1) this.endMultiball();
    if (this.time - this.lastSwitch > 7 && this.freeBalls().length && this.freeBalls().every((b) => Math.hypot(b.vx, b.vy) < 1.2 && !(b.x > LAYOUT.wallR && b.y > 18.4))) {
      this.lastSwitch = this.time;
      for (const b of this.freeBalls()) { b.vy -= 9; b.vx += (this.random() - 0.5) * 6; }
      this.emit("ballSearch");
    }
  }

  advanceRail(b, dt) {
    const r = b.rail;
    const frac = r.s / r.total;
    r.speed = frac < 0.35 ? Math.max(7, r.speed - dt * 9) : Math.min(17, r.speed + dt * 14);
    r.s += r.speed * dt;
    if (r.s >= r.total) {
      b.rail = null;
      b.x = r.exit.x; b.y = r.exit.y; b.vx = r.exit.vx; b.vy = r.exit.vy; b.height = 0;
      b.px = b.x; b.py = b.y;
      this.emit("railExit", { id: r.id });
      return;
    }
    let i = 1;
    while (i < r.lens.length - 1 && r.lens[i] < r.s) i++;
    const a = r.pts[i - 1], c = r.pts[i], t = (r.s - r.lens[i - 1]) / (r.lens[i] - r.lens[i - 1] || 1);
    b.x = a[0] + (c[0] - a[0]) * t; b.y = a[1] + (c[1] - a[1]) * t; b.height = a[2] + (c[2] - a[2]) * t;
    b.px = b.x; b.py = b.y;
  }

  ejectScoop(b) {
    b.held = null;
    b.x = LAYOUT.scoop.x; b.y = LAYOUT.scoop.y + 0.2;
    b.vx = -2.6 + this.random() * 0.5; b.vy = 9;
    b.px = b.x; b.py = b.y;
    b.ignoreScoopUntil = this.time + 0.8;
    this.emit("scoopOut");
  }

  breakStreak() {
    if (this.streak >= 15) this.emit("streakBreak", { count: this.streak });
    this.streak = 0;
  }

  drain(b, lost = false) {
    this.world.removeBall(b);
    this.emit("drainBall", { lost });
    if (this.status !== "play" && this.status !== "ready") return;
    if (this.world.balls.length + (this.pendingServes || 0) === 0) this.breakStreak();
    if (!this.tilted && (this.time < this.ballSaveUntil || lost || (this.ballSaveArmed && this.status === "play"))) {
      this.say("BALL GERETTET", "", 1500, "flash", 4);
      this.emit("ballSave");
      this.ballSaveArmed = false;
      this.queueServes(1, 0.8);
      return;
    }
    if (this.liveBallCount() > 0) return;
    this.endBall();
  }

  endMultiball() {
    this.multiball = false;
    this.superLit = false;
    this.jackpots = {};
    if (this.wizard) {
      this.wizard = false;
      this.wizardLevel++;
      this.missionsDone.clear();
      this.say("LAST CALL VORBEI", "NAECHSTE RUNDE!", 2200, "zoom", 4);
    } else this.say("MULTIBALL VORBEI", "", 1500, "slide", 2);
    this.raiseDrops();
    this.emit("multiballEnd");
  }

  endBall() {
    this.status = "bonus";
    this.mission = null;
    this.multiball = false;
    this.wizard = false;
    this.table.flipL.pressed = false; this.table.flipR.pressed = false;
    this.emit("drain");
    const s = this.ballStats;
    const lines = this.tilted ? [] : [
      ["RAMPEN", s.ramps * 10_000],
      ["ORBITS", s.orbits * 8_000],
      ["BUMPER", s.bumpers * 500],
      ["VIP-ZIELE", s.drops * 5_000],
      ["SPINNER", s.spins * 100],
    ].filter(([, v]) => v > 0);
    const base = lines.reduce((a, [, v]) => a + v, 0);
    const total = base * this.bonusX;
    // Casino-style count: every line gets time to roll up, then the multiplier slams in,
    // then the grand total rolls up. Nothing to count (tilt / empty ball) skips straight on.
    let at = this.time + 1.0;
    if (base > 0) {
      this.emit("bonusStart", { lines: lines.length, bonusX: this.bonusX });
      for (const [label, v] of lines) {
        this.timers.push({ at, fn: () => { this.say(label, fmt(v), 900, "count", 8); this.emit("bonusStep", { label, value: v }); } });
        at += 1.1;
      }
      this.timers.push({ at, fn: () => this.emit("bonusMult", { base, bonusX: this.bonusX }) });
      at += 0.9;
      this.timers.push({ at, fn: () => {
        this.say("BONUS " + this.bonusX + "X", fmt(total), 2600, "flash", 8);
        this.score += total;
        this.emit("bonusTotal", { total, base, bonusX: this.bonusX });
      } });
      at += 6.4; // the payout rolls ~3.8s, then the explosion gets its moment
    } else at += 1.0;
    this.timers.push({ at, fn: () => this.nextBall() });
  }

  nextBall() {
    if (this.extraBalls > 0) {
      this.extraBalls--;
      this.resetBallState();
      this.status = "ready";
      this.serveBall();
      this.say("NOCHMAL SCHIESSEN", "EXTRA BALL", 1800, "zoom", 5);
      this.emit("shootAgain");
      return;
    }
    if (this.ball >= BALLS_PER_GAME) {
      this.status = "gameover";
      this.say("GAME OVER", fmt(this.score), 6000, "zoom", 9);
      this.emit("gameOver", { score: this.score, stats: this.stats });
      return;
    }
    this.ball++;
    this.resetBallState();
    this.status = "ready";
    this.serveBall();
    this.say("BALL " + this.ball, this.ball === BALLS_PER_GAME ? "LETZTER BALL!" : "", 1600, "zoom", 5);
    this.emit("newBall", { ball: this.ball });
  }

  get timers() { return (this._timers ||= []); }
  set timers(v) { this._timers = v; }

  // ------------------------------------------------------------- lamps
  updateLamps() {
    const blink = (hz) => (Math.floor(this.time * hz * 2) % 2 === 0 ? 1 : 0.15);
    const L = {};
    const play = ["ready", "play"].includes(this.status);
    for (let i = 0; i < 3; i++) {
      L["lane" + i] = this.lanesLit[i] ? 1 : this.skillActive && this.skillLane === i && play ? blink(4) : 0.08;
      L["bonus" + (i + 2)] = this.bonusX >= i + 2 ? 1 : 0.08;
      L["lock" + i] = this.locks > i ? 1 : this.vipLit && this.locks === i ? blink(3) : 0.08;
    }
    for (const d of this.table.drops) L["drop" + d.index] = d.enabled ? (this.vipLit ? 0.1 : blink(1.2) * 0.8) : 0.08;
    L.vip = this.superLit ? blink(6) : this.vipLit ? blink(3) : 0.08;
    for (const m of MAJOR) L[m] = this.wizard ? blink(5) : this.multiball && this.jackpots[m] ? blink(4) : this.combo >= 1 && this.time - this.lastMajorAt < 4.5 ? blink(2) * 0.7 : 0.12;
    L.mission = this.mission ? blink(5) : this.missionLit ? blink(2) : 0.08;
    L.extraBall = this.extraBallLit ? blink(3) : 0.08;
    MISSIONS.forEach((m, i) => { L["m" + i] = this.missionsDone.has(m.id) ? 1 : this.mission?.id === m.id ? blink(4) : 0.08; });
    L.kickback = this.kickbackLit ? 1 : 0.08;
    L.shootAgain = this.time < this.ballSaveUntil ? blink(this.ballSaveUntil - this.time < 3 ? 6 : 2) : this.ballSaveArmed && this.status !== "attract" && this.status !== "gameover" ? 1 : 0.06;
    L.bumper = 0.4 + this.bumperLevel * 0.12;
    L.plunger = this.status === "ready" ? blink(1.5) : 0.1;
    this.lamps = L;
  }

  snapshot() {
    return {
      status: this.status,
      score: this.score,
      ball: this.ball,
      ballsTotal: BALLS_PER_GAME + this.extraBalls,
      extraBalls: this.extraBalls,
      bonusX: this.bonusX,
      locks: this.locks,
      multiball: this.multiball,
      wizard: this.wizard,
      mission: this.mission ? { name: this.mission.name, hint: this.mission.hint, progress: this.mission.progress, goal: this.mission.goal, left: Math.max(0, this.mission.until - this.time) } : null,
      missionLit: this.missionLit,
      missionsDone: MISSIONS.map((m) => this.missionsDone.has(m.id)),
      vipLit: this.vipLit,
      extraBallLit: this.extraBallLit,
      combo: this.time - this.lastMajorAt < 4.5 ? this.combo : 0,
      streak: this.streak,
      plunger: this.plungerCharge,
      ballSave: this.time < this.ballSaveUntil,
      tilt: this.tilted,
      tiltMeter: this.tiltMeter,
      stats: { ...this.stats },
    };
  }
}
