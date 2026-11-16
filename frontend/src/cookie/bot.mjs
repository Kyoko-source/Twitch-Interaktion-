// A simple player for balancing: clicks ~3×/s where hands are needed, buys the recommended
// upgrade as soon as it can. Used by the tests and runnable on its own: node src/cookie/bot.mjs
import { GOAL, TRIP_TIME, UPGRADES, capacities, actCut, actDeliver, actLoad, actPortion, actRoll, buy, derive, phaseOf, recommended, step, totalDough, createState, upgradeCost } from "./sim.js";

export function play({ clicksPerSecond = 3, maxHours = 8, log = false, stopAt = GOAL } = {}) {
  const s = createState();
  const phaseAt = { 1: 0 };
  const buys = [];
  let clickAcc = 0, trip = 0;
  const dt = 0.1;
  while (s.baked < stopAt && s.t < maxHours * 3600) {
    let d = derive(s.levels);
    // a walk to the dough mountain takes TRIP_TIME seconds; meanwhile the hands are busy
    if (trip > 0) { trip -= dt; if (trip <= 0) actPortion(s, d); clickAcc = 0; }
    else clickAcc += clicksPerSecond * dt;
    while (clickAcc >= 1 && trip <= 0) {
      clickAcc -= 1;
      // hands go to the station that needs them most and has something to work on
      const order = capacities(d).slice(0, 4).filter((c) => c.hand > 0).sort((a, b) => b.hand - a.hand).map((c) => c.id);
      let done = false;
      if (s.carry > 0 && s.ball < d.ballCap) { actDeliver(s, d); continue; }
      for (const id of [...order, "load", "cut", "roll", "portion"]) {
        if (id === "load" && s.tray > 0 && s.queue < d.queueCap && (order.includes("load") || s.tray >= Math.min(d.trayCap, 6))) { actLoad(s, d); done = true; }
        else if (id === "cut" && s.sheet > 0 && s.tray < d.trayCap) { actCut(s, d); done = true; }
        else if (id === "roll" && s.ball > 0 && s.sheet < d.sheetCap) { actRoll(s, d); done = true; }
        else if (id === "portion" && s.dough > 0 && s.ball + d.carryCap <= d.ballCap && (order.includes("portion") || s.ball < d.sheetSize)) { trip = TRIP_TIME; done = true; }
        if (done) break;
      }
    }
    step(s, dt);
    s.events.length = 0;
    const p = phaseOf(s);
    if (!phaseAt[p]) phaseAt[p] = s.t;
    for (let k = 0; k < 3; k++) {
      const r = recommended(s);
      if (!r || !buy(s, r.id)) break;
      buys.push({ t: Math.round(s.t), id: r.id, level: s.levels[r.id], baked: s.baked });
      d = derive(s.levels);
    }
    if (totalDough(s) !== GOAL) throw new Error(`dough balance broken at t=${s.t}`);
  }
  const d = derive(s.levels);
  const result = { seconds: Math.round(s.t), hours: +(s.t / 3600).toFixed(2), baked: s.baked, phaseAt, buys, finalRate: Math.round(Math.min(d.ovenRate, d.chuteRate)), owned: Object.keys(s.levels).length, of: UPGRADES.length, state: s };
  if (log) {
    console.log(`finished in ${result.hours} h, phases at`, Object.fromEntries(Object.entries(phaseAt).map(([k, v]) => [k, `${(v / 60).toFixed(1)} min`])));
    console.log(`owned ${result.owned}/${result.of} upgrades, ${UPGRADES.reduce((a, u) => a + (s.levels[u.id] || 0), 0)}/${UPGRADES.reduce((a, u) => a + u.max, 0)} levels, final rate ~${result.finalRate}/s`);
    const firsts = buys.filter((b, i) => i < 12 || b.level === 1);
    for (const b of firsts) console.log(`  ${(b.t / 60).toFixed(1).padStart(6)} min  ${String(b.baked).padStart(8)}  ${b.id} ${b.level}`);
    const missing = UPGRADES.filter((u) => (s.levels[u.id] || 0) < u.max).map((u) => `${u.id} ${s.levels[u.id] || 0}/${u.max} next ${upgradeCost(u, s.levels[u.id] || 0)}`);
    console.log("not maxed:", missing.join(", "));
  }
  return result;
}

if (import.meta.url === `file://${process.argv[1].replace(/\\/g, "/")}` || process.argv[1]?.endsWith("bot.mjs")) {
  play({ log: true, clicksPerSecond: Number(process.argv[2] || 3) });
}
