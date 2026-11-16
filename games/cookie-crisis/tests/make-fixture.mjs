// Writes reference numbers from the website simulation for the Godot self-test (parity check).
import { writeFileSync } from "node:fs";
import * as sim from "../../../frontend/src/cookie/sim.js";

const levelSets = [{}, { eimer: 1, form: 2, bandtempo: 3 }, { portionierer: 3, walze: 1, stanzpresse: 1, motor: 2, blechschieber: 1, transport: 2 },
  { portionierer: 5, zufuhr: 2, steuerung: 3, ausstechwalze: 2, platzierung: 2, syncband: 2, durchlauf: 1, mehrspur: 2, sammelstation: 2, teigrolle: 3 },
  { portionierer: 5, zufuhr: 3, steuerung: 4, extruder: 2, industrie: 2, etagen: 1, vollauto: 1, rentier: 1, turboofen: 1, schwebend: 1, megafabrik: 1 }];
const derived = levelSets.map((levels) => { const d = sim.derive(levels); return { levels, d, throughput: sim.throughput(d) }; });
// deterministic play: hand work, then buys, then machines
const s = sim.createState();
for (let i = 0; i < 6; i++) { sim.actTake(s); sim.actDeliver(s); for (let k = 0; k < 3; k++) sim.actRoll(s); for (let k = 0; k < 8; k++) sim.actCut(s); sim.actLoad(s); sim.step(s, 3); }
sim.step(s, 30);
s.talers += 0;
const after = { dough: s.dough, ball: s.ball, sheet: s.sheet, tray: s.tray, queue: s.queue, exit: s.exit, baked: s.baked, talers: s.talers, t: s.t };
writeFileSync(new URL("./fixture.json", import.meta.url), JSON.stringify({ derived, after }, null, 1));
console.log("fixture", after);
