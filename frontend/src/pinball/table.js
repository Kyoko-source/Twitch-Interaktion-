import { World } from "./physics.js";

// Playfield layout. Units: x 0..10, y 0..20 (y grows toward the player).
// The lower playfield is symmetric around x = 4.65; the shooter lane sits at x 9.0..9.7.
export const CX = 4.65;
const M = (x) => CX * 2 - x;

export const LAYOUT = {
  wallL: 0.3, wallR: 9.0, outer: 9.7, arc: { cx: 5, cy: 5, r: 4.7 },
  plungerRest: { x: 9.35, y: 19.25 },
  plungerTop: 19.55,
  flippers: { left: { x: 2.95, y: 17.5 }, right: { x: M(2.95), y: 17.5 }, len: 1.5 },
  bumpers: [
    { id: "bumper0", x: 3.85, y: 4.7 },
    { id: "bumper1", x: 5.45, y: 4.7 },
    { id: "bumper2", x: 4.65, y: 6.15 },
  ],
  bumperR: 0.5,
  lanes: [5.425, 6.275, 7.125],
  laneGuides: [5.0, 5.85, 6.7, 7.55],
  scoop: { x: 4.65, y: 8.15 },
  alcove: { x0: 3.9, x1: 5.4, top: 7.7, bottom: 9.7 },
  drops: [
    { id: "drop0", x0: 3.96, x1: 4.4 },
    { id: "drop1", x0: 4.43, x1: 4.87 },
    { id: "drop2", x0: 4.9, x1: 5.34 },
  ],
  dropY: 9.78,
  // Ramp mouths: the ball enters between the guides; a fast enough shot is handed to the
  // scripted ramp ride, a weak one hits the flap at "back" and rolls out again.
  rampL: { x0: 1.15, x1: 2.45, back: 7.9, mouth: 9.3 },
  rampR: { x0: M(2.45), x1: M(1.15), back: 7.9, mouth: 9.3 },
  orbitWallL: 1.15, orbitWallR: M(1.15),
  slingL: [[1.95, 13.35], [1.95, 15.2], [2.9, 15.95]],
  guideL: [[1.05, 14.0], [1.05, 15.55], [3.08, 17.19]],
  deflectL: [[0.3, 10.9], [0.95, 11.9]],
};

// 3D wire-ramp paths [x, y, height]. Played back on rails, released into the inlanes.
export const HABITRAILS = {
  rampL: { points: [[1.8, 9.0, 0.05], [1.8, 7.6, 0.5], [1.75, 5.25, 1.15], [1.55, 4.2, 1.45], [0.85, 4.1, 1.5], [0.6, 5.2, 1.4], [0.62, 8.5, 1.1], [0.75, 11.5, 0.75], [1.3, 13.0, 0.3], [1.5, 13.75, 0.02]], exit: { x: 1.5, y: 13.8, vx: 0.6, vy: 6.5 } },
  rampR: { points: [[M(1.8), 9.0, 0.05], [M(1.8), 7.6, 0.5], [M(1.75), 5.25, 1.15], [M(1.55), 4.2, 1.45], [M(0.85), 4.1, 1.5], [M(0.6), 5.2, 1.4], [M(0.62), 8.5, 1.1], [M(0.75), 11.5, 0.75], [M(1.3), 13.0, 0.3], [M(1.5), 13.75, 0.02]], exit: { x: M(1.5), y: 13.8, vx: -0.6, vy: 6.5 } },
};

export function buildTable() {
  const w = new World();
  const L = LAYOUT;
  const vis = (v, o = {}) => ({ vis: v, ...o });
  const rubber = { e: 0.62, f: 0.1, vis: "rubber", r: 0.08 };

  // Cabinet: side walls, top arc and shooter lane.
  w.seg([L.wallL, 20.6], [L.wallL, L.arc.cy], vis("cabinet", { r: 0.08, e: 0.35 }));
  w.arc(L.arc.cx, L.arc.cy, L.arc.r, Math.PI, Math.PI * 2, 48, vis("rail", { r: 0.07, e: 0.25, f: 0.03 }));
  w.seg([L.outer, L.arc.cy], [L.outer, 20.6], vis("cabinet", { r: 0.08, e: 0.3 }));
  w.seg([L.wallR, 6.1], [L.wallR, 20.6], vis("rail", { r: 0.06, e: 0.3 }));
  // One-way gate at the top of the shooter lane: balls go up through it, never back down.
  const gate = w.seg([L.outer, 5.25], [L.wallR, 6.05], vis("gate", { r: 0.04, e: 0.2, f: 0.02 }));
  { const nx = -(gate.b.y - gate.a.y), ny = gate.b.x - gate.a.x, l = Math.hypot(nx, ny); gate.oneWay = { x: nx / l, y: ny / l }; }
  // Plunger tip.
  const plunger = w.seg([L.wallR + 0.02, L.plungerTop], [L.outer - 0.02, L.plungerTop], vis("plunger", { r: 0.03, e: 0.1 }));

  // Orbit inner walls double as the outer ramp walls.
  w.seg([L.orbitWallL, 5.0], [L.orbitWallL, L.rampL.mouth], vis("rail"));
  w.seg([L.orbitWallR, 5.0], [L.orbitWallR, L.rampR.mouth], vis("rail"));
  for (const r of [L.rampL, L.rampR]) {
    const left = r === L.rampL;
    const inner = left ? r.x1 : r.x0;
    // The flap slopes toward the playfield centre so a ball landing on it from above rolls off.
    const high = left ? [r.x0, r.back - 0.45] : [r.x1, r.back - 0.45];
    const low = left ? [r.x1, r.back] : [r.x0, r.back];
    w.seg([inner, r.back], [inner, r.mouth], vis("rampWall"));
    w.seg(high, low, vis("rampFlap", { e: 0.2 }));
    w.zone(r.x0, r.back - 0.45, r.x1, r.mouth, 30, { id: left ? "rampL" : "rampR", ramp: true });
  }
  const rampSensors = {
    rampL: w.lineSensor([L.rampL.x0, L.rampL.mouth - 0.25], [L.rampL.x1, L.rampL.mouth - 0.25], { id: "rampL" }),
    rampR: w.lineSensor([L.rampR.x0, L.rampR.mouth - 0.25], [L.rampR.x1, L.rampR.mouth - 0.25], { id: "rampR" }),
  };

  // VIP alcove with the scoop behind three drop targets.
  const A = L.alcove;
  // Peaked roof: nothing can come to rest on top of the alcove.
  w.path([[A.x0, A.bottom], [A.x0, A.top], [(A.x0 + A.x1) / 2, A.top - 0.4], [A.x1, A.top], [A.x1, A.bottom]], vis("rail", { e: 0.3 }));
  w.circle(A.x0, A.bottom, 0.1, { ...rubber, kind: "post" });
  w.circle(A.x1, A.bottom, 0.1, { ...rubber, kind: "post" });
  const drops = L.drops.map((d, i) => w.seg([d.x0, L.dropY], [d.x1, L.dropY], { r: 0.07, e: 0.3, kind: "drop", id: d.id, index: i, vis: "drop" }));
  const scoop = w.circleSensor(L.scoop.x, L.scoop.y, 0.34, { id: "scoop" });

  // Pop bumpers.
  const bumpers = L.bumpers.map((b, i) => w.circle(b.x, b.y, L.bumperR, { id: b.id, index: i, kind: "bumper", e: 0.4, kick: 16.5, kickMin: 0.3, vis: "bumper" }));

  // Top lanes.
  for (const x of L.laneGuides) { w.seg([x, 1.9], [x, 2.75], vis("guide", { r: 0.07, e: 0.4 })); }
  const lanes = L.lanes.map((x, i) => w.circleSensor(x, 2.45, 0.3, { id: "lane" + i, index: i }));

  // Orbits and spinner.
  const spinner = w.lineSensor([L.wallL, 7.4], [L.orbitWallL, 7.4], { id: "spinner" });
  const orbitL = w.lineSensor([L.wallL, 6.2], [L.orbitWallL, 6.2], { id: "orbitL" });
  const orbitR = w.lineSensor([L.orbitWallR, 6.6], [L.wallR, 6.6], { id: "orbitR" });

  // Lower playfield: deflectors, inlane guides, slingshots, flippers.
  const lower = [];
  for (const mirror of [false, true]) {
    const P = (p) => (mirror ? [M(p[0]), p[1]] : p);
    lower.push(...w.path(L.deflectL.map(P), vis("rail", { e: 0.3 })));
    lower.push(...w.path(L.guideL.map(P), vis("rail", { e: 0.25 })));
    w.circle(...P(L.guideL[0]), 0.1, { ...rubber, kind: "post" });
    const [a, b, c] = L.slingL.map(P);
    lower.push(w.seg(a, b, { ...rubber, e: 0.45 }), w.seg(b, c, { ...rubber, e: 0.45 }));
    const dx = c[0] - a[0], dy = c[1] - a[1], len = Math.hypot(dx, dy);
    let nx = dy / len, ny = -dx / len;
    if ((mirror && nx > 0) || (!mirror && nx < 0)) { nx = -nx; ny = -ny; }
    // Kick a little flatter than the face normal so sling-to-sling volleys lose height and end.
    const tilt = mirror ? -0.22 : 0.22, kx = nx * Math.cos(tilt) - ny * Math.sin(tilt), ky = nx * Math.sin(tilt) + ny * Math.cos(tilt);
    lower.push(w.seg(a, c, { ...rubber, kind: "sling", id: mirror ? "slingR" : "slingL", kick: 11.5, kickMin: 2.2, kickNormal: { x: kx, y: ky } }));
    w.circle(...a, 0.11, { ...rubber, kind: "post" });
    w.circle(...c, 0.11, { ...rubber, kind: "post" });
    w.circle(...b, 0.1, { ...rubber, kind: "post" });
  }
  const flipL = w.flipper(L.flippers.left.x, L.flippers.left.y, L.flippers.len, 1, { id: "flipL" });
  const flipR = w.flipper(L.flippers.right.x, L.flippers.right.y, L.flippers.len, -1, { id: "flipR" });

  const inlanes = {
    inlaneL: w.lineSensor([1.1, 14.6], [1.9, 14.6], { id: "inlaneL" }),
    inlaneR: w.lineSensor([M(1.9), 14.6], [M(1.1), 14.6], { id: "inlaneR" }),
    outlaneL: w.lineSensor([L.wallL, 15.2], [1.0, 15.2], { id: "outlaneL" }),
    outlaneR: w.lineSensor([M(1.0), 15.2], [L.wallR, 15.2], { id: "outlaneR" }),
  };
  const kickback = w.lineSensor([L.wallL, 18.2], [1.0, 18.2], { id: "kickback" });

  return { world: w, gate, plunger, drops, scoop, bumpers, lanes, spinner, orbitL, orbitR, flipL, flipR, rampSensors, inlanes, kickback, lower };
}
