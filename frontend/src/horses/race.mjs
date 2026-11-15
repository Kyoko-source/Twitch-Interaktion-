// Pure race playback: where every horse is at race time t, the live standings, and the
// commentator that turns them into big shouted callouts. The script comes from the server.

export function lapsAt(race, horse, t) {
  const shape = race.shapes[horse], finish = race.finish[horse];
  if (t <= 0) return 0;
  if (t >= finish) {
    const d = t - finish;
    return race.laps + 0.06 * (1 - Math.exp(-d / 1.4));   // coasting after the line
  }
  const u = (t / finish) * (shape.length - 1);
  const i = Math.min(Math.floor(u), shape.length - 2);
  return race.laps * (shape[i] + (shape[i + 1] - shape[i]) * (u - i));
}

// Laps per second, for gallop cadence and the commentator.
export function speedAt(race, horse, t) {
  if (t >= race.finish[horse]) return Math.max(0, 0.04 * Math.exp(-(t - race.finish[horse]) / 1.4));
  return (lapsAt(race, horse, t + 0.05) - lapsAt(race, horse, Math.max(0, t - 0.05))) / 0.1;
}

export function standings(race, t) {
  const pos = race.shapes.map((_, h) => lapsAt(race, h, t));
  return pos.map((p, h) => h).sort((a, b) => pos[b] - pos[a]);
}

export function raceEnd(race) { return Math.max(...race.finish); }

const pick = (list, rnd) => list[Math.floor(rnd() * list.length)];
const LEAD = ["{N} ÜBERNIMMT DIE FÜHRUNG!", "{N} SCHIEBT SICH AN DIE SPITZE!", "NEUER SPITZENREITER: {N}!", "{N} REISST DAS RENNEN AN SICH!", "{N} GEHT AN DIE SPITZE!"];
const FILL = ["WAS FÜR EIN TEMPO!", "DIE TRIBÜNEN BEBEN!", "HIER IST NOCH ALLES DRIN!", "DAS FELD RÜCKT ZUSAMMEN!", "DIE MENGE TOBT!", "STAUB, SCHWEISS UND HUFDONNER!"];
const SURGE = ["{N} SETZT ZUM ANGRIFF AN!", "{N} DREHT AUF!", "{N} KOMMT VON HINTEN!", "{N} GIBT JETZT ALLES!", "{N} FLIEGT ÜBER DIE BAHN!"];

/**
 * Feed it race time every frame; it returns the callouts that start at this moment.
 * Callout: { text, tone, sound, big }. Tones: go, lead, mine, lap, final, hot, sad, win, photo.
 */
export class Commentator {
  constructor(race, chosen, names, rnd = Math.random) {
    Object.assign(this, { race, chosen, names, rnd });
    this.leader = -1; this.leaderSince = 0; this.lastLeadCall = -9; this.lastCall = -9;
    this.lap = 0; this.started = false; this.home = false; this.neck = false; this.finished = false;
    this.myRank = 0; this.myRankCalled = 0; this.myCallAt = -9; this.winnerCalled = false;
  }

  name(h) { return this.names[h].toUpperCase(); }

  update(t) {
    const out = [];
    const say = (text, tone, sound, big = false) => { out.push({ text, tone, sound, big }); this.lastCall = t; };
    const { race, chosen } = this;
    if (!this.started && t >= 0) { this.started = true; say("UND AB GEHT DIE POST!", "go", "go", true); return out; }
    if (t < 0) return out;
    const order = standings(race, t);
    const lead = order[0], lp = lapsAt(race, lead, t), second = lapsAt(race, order[1], t);
    const winner = race.winner, tw = race.finish[winner];

    if (!this.winnerCalled && t >= tw) {
      this.winnerCalled = true;
      const gap = race.finish[race.order[1]] - tw;
      if (gap < 0.2) say("FOTOFINISH!!!", "photo", "photo", true);
      say(winner === chosen ? `DEIN PFERD ${this.name(winner)} GEWINNT!!!` : `${this.name(winner)} GEWINNT!`, winner === chosen ? "win" : "lead", "win", true);
      return out;
    }
    if (t >= tw) return out;

    const lap = Math.floor(lp);
    if (lap > this.lap && lap < race.laps) {
      this.lap = lap;
      say(lap === race.laps - 1 ? "LETZTE RUNDE!!!" : `RUNDE ${lap + 1} VON ${race.laps}!`, lap === race.laps - 1 ? "final" : "lap", "lap", true);
      return out;
    }
    if (!this.home && lp > race.laps - 0.2) { this.home = true; say("ZIELGERADE!!! JETZT WIRD'S ENG!", "final", "final", true); return out; }

    if (lead !== this.leader) { this.leader = lead; this.leaderSince = t; }
    if (lead !== this.announced && t - this.leaderSince > 0.35 && t - this.lastLeadCall > 1.5 && t > 1.2) {
      this.announced = lead; this.lastLeadCall = t;
      if (lead === chosen) say(`DEIN PFERD ${this.name(lead)} FÜHRT!!!`, "mine", "mine", true);
      else say(pick(LEAD, this.rnd).replace("{N}", this.name(lead)), "lead", "lead");
      return out;
    }

    if (!this.neck && lp > race.laps - 0.45 && lp - second < 0.012) { this.neck = true; say("KOPF AN KOPF!!!", "hot", "hot", true); return out; }

    const rank = order.indexOf(chosen) + 1;
    if (!this.myRankCalled) this.myRankCalled = rank;
    if (t - this.myCallAt > 3 && t - this.lastCall > 1.2 && rank > 1) {
      if (rank <= this.myRankCalled - 2) {
        this.myRankCalled = rank; this.myCallAt = t;
        say(`${this.name(chosen)} STÜRMT NACH VORNE – PLATZ ${rank}!`, "mine", "mine");
        return out;
      }
      if (rank >= this.myRankCalled + 3) {
        this.myRankCalled = rank; this.myCallAt = t;
        say(`${this.name(chosen)} FÄLLT ZURÜCK – PLATZ ${rank}…`, "sad", "sad");
        return out;
      }
    }

    if (t - this.lastCall > 4.2) {
      const speeds = race.shapes.map((_, h) => speedAt(race, h, t));
      const fastest = speeds.indexOf(Math.max(...speeds));
      if (this.rnd() < 0.6 && fastest !== lead) say(pick(SURGE, this.rnd).replace("{N}", this.name(fastest)), "hot", "hype");
      else say(pick(FILL, this.rnd), "hot", "hype");
    }
    return out;
  }
}

// A made-up race for the overlay preview, built like the server's scripts.
export function demoRace(rnd = Math.random, laps = 5) {
  const n = 50;
  const winner = Math.floor(rnd() * 9);
  const others = [...Array(9).keys()].filter((h) => h !== winner).sort(() => rnd() - 0.5);
  const order = [winner, ...others];
  const finish = Array(9).fill(0);
  let t = 66 + rnd() * 6;
  finish[winner] = t;
  t += 0.05 + rnd() * 0.4;
  others.forEach((h, i) => { finish[h] = t; t += 0.06 + rnd() * (i < 3 ? 0.3 : 0.55); });
  const shapes = order.map(() => null);
  for (let h = 0; h < 9; h++) {
    const speeds = [];
    let v = 1, burst = 0, left = 0;
    for (let k = 0; k < n; k++) {
      v = (v + (rnd() - 0.5) * 0.08) * 0.82 + 0.18;
      if (left <= 0 && rnd() < 0.09) { burst = (rnd() < 0.5 ? -1 : 1) * (0.09 + rnd() * 0.11); left = 2 + Math.floor(rnd() * 3); }
      speeds.push(Math.max(0.55, v + (left-- > 0 ? burst : 0)));
    }
    const total = speeds.reduce((a, b) => a + b, 0);
    let run = 0;
    shapes[h] = [0, ...speeds.map((s) => (run += s) / total)];
    shapes[h][n] = 1;
  }
  return { winner, order, finish, shapes, laps };
}
