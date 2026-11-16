// Santa's Cookie Crisis – 3D first-person renderer (three.js). You are the elf: walk with WASD,
// drag to look around, click a station to work there. Your own hands are in front of the camera.
// Reads the simulation state, never changes it. Units are metres.
import * as THREE from "three";
import { FALL_TIME, GOAL, OVEN_SLOTS, derive, phaseOf } from "./sim.js";

const BENCH_Y = 0.9;
const BELT = { y: 1.18, z: -0.95, x0: -2.3, oven0: -1.2, oven1: 1.2, x1: 1.62, floorH: 0.75, laneGap: 0.24 };
const JAR = { x: 1.95, z: -0.95, r: 0.32, h: 0.95 };
const BAKE_STEPS = 10;
const MAX_COOKIES = 4500;
const ROOM = { 1: [3.6, 3.2, 3.2], 2: [4.2, 3.6, 3.4], 3: [5.5, 4.5, 4], 4: [8, 6.5, 6], 5: [9, 7, 7] }; // half width, depth, height

export const STATIONS = {
  portion: { label: "Teig nehmen", pos: [0.95, BENCH_Y + 0.12, 0], size: [0.5, 0.3, 0.5] },
  roll: { label: "Ausrollen", pos: [0.15, BENCH_Y + 0.08, 0], size: [0.55, 0.22, 0.5] },
  cut: { label: "Ausstechen", pos: [-0.45, BENCH_Y + 0.08, 0], size: [0.5, 0.22, 0.5] },
  load: { label: "Aufs Band", pos: [-1.2, BENCH_Y + 0.06, 0], size: [0.6, 0.2, 0.45] },
};

const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const ease = (t) => Math.sin(Math.PI * clamp(t));
const bakeColor = (t) => new THREE.Color().lerpColors(new THREE.Color("#f6e2b8"), new THREE.Color("#c27a2c"), t);

function starShape(r, inner = 0.5, points = 5) {
  const s = new THREE.Shape();
  for (let i = 0; i < points * 2; i++) {
    const rad = i % 2 ? r * inner : r, a = -Math.PI / 2 + (i * Math.PI) / points;
    if (i) s.lineTo(Math.cos(a) * rad, Math.sin(a) * rad); else s.moveTo(Math.cos(a) * rad, Math.sin(a) * rad);
  }
  s.closePath();
  return s;
}

function textSprite(text, color = "#ffd23f") {
  const cv = document.createElement("canvas");
  cv.width = 256; cv.height = 96;
  const c = cv.getContext("2d");
  c.font = "bold 54px sans-serif"; c.textAlign = "center"; c.textBaseline = "middle";
  c.lineWidth = 10; c.strokeStyle = "rgba(60,30,0,.85)"; c.strokeText(text, 128, 48);
  c.fillStyle = color; c.fillText(text, 128, 48);
  const tex = new THREE.CanvasTexture(cv);
  tex.colorSpace = THREE.SRGBColorSpace;
  const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, transparent: true, depthTest: false }));
  sp.scale.set(0.5, 0.19, 1);
  sp.renderOrder = 10;
  return sp;
}

export function createRenderer(canvas) {
  const gl = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: "high-performance" });
  gl.shadowMap.enabled = true;
  gl.shadowMap.type = THREE.PCFSoftShadowMap;
  gl.toneMapping = THREE.ACESFilmicToneMapping;
  gl.toneMappingExposure = 1.05;
  const scene = new THREE.Scene();
  scene.background = new THREE.Color("#140b07");
  scene.fog = new THREE.Fog("#140b07", 9, 26);
  const camera = new THREE.PerspectiveCamera(68, 16 / 9, 0.03, 60);
  const player = { x: 0, z: 1.25, yaw: 0, pitch: -0.32 };
  scene.add(camera);

  const M = {
    wood: new THREE.MeshStandardMaterial({ color: "#8a5a33", roughness: 0.8 }),
    woodDark: new THREE.MeshStandardMaterial({ color: "#5a3a22", roughness: 0.85 }),
    wall: new THREE.MeshStandardMaterial({ color: "#6b4428", roughness: 0.95 }),
    floor: new THREE.MeshStandardMaterial({ color: "#5a3a22", roughness: 0.9 }),
    metal: new THREE.MeshStandardMaterial({ color: "#a9b2bc", metalness: 0.7, roughness: 0.35 }),
    steel: new THREE.MeshStandardMaterial({ color: "#5f6b76", metalness: 0.6, roughness: 0.45 }),
    rubber: new THREE.MeshStandardMaterial({ color: "#262626", roughness: 0.7 }),
    brick: new THREE.MeshStandardMaterial({ color: "#8b3a2a", roughness: 0.9 }),
    dough: new THREE.MeshStandardMaterial({ color: "#f2dcae", roughness: 0.9 }),
    ceramic: new THREE.MeshStandardMaterial({ color: "#ece6dc", roughness: 0.4 }),
    red: new THREE.MeshStandardMaterial({ color: "#c81d2a", roughness: 0.6 }),
    green: new THREE.MeshStandardMaterial({ color: "#1f7a3e", roughness: 0.8 }),
    white: new THREE.MeshStandardMaterial({ color: "#fbf7f2", roughness: 0.9 }),
    skin: new THREE.MeshStandardMaterial({ color: "#f2c19c", roughness: 0.7 }),
    gold: new THREE.MeshStandardMaterial({ color: "#ffcf4a", metalness: 0.8, roughness: 0.25, emissive: "#3a2600" }),
    glass: new THREE.MeshPhysicalMaterial({ color: "#d8ecff", transparent: true, opacity: 0.22, roughness: 0.05, metalness: 0, side: THREE.DoubleSide, depthWrite: false }),
    ovenGlow: new THREE.MeshStandardMaterial({ color: "#ff8a2a", emissive: "#ff6a00", emissiveIntensity: 1.4 }),
    sky: new THREE.MeshBasicMaterial({ color: "#13264a" }),
    snowGround: new THREE.MeshBasicMaterial({ color: "#e8f0fb" }),
  };
  const box = (w, h, d, mat) => { const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat); m.castShadow = true; m.receiveShadow = true; return m; };
  const cyl = (r1, r2, h, mat, seg = 24) => { const m = new THREE.Mesh(new THREE.CylinderGeometry(r1, r2, h, seg), mat); m.castShadow = true; m.receiveShadow = true; return m; };
  const at = (m, x, y, z) => { m.position.set(x, y, z); return m; };

  // ------------------------------------------------------------ lights
  scene.add(new THREE.HemisphereLight("#ffe1b8", "#2a1608", 0.55));
  const sun = new THREE.DirectionalLight("#ffd9a8", 1.0);
  sun.position.set(-2, 5, 3); sun.castShadow = true; sun.shadow.mapSize.set(1024, 1024);
  Object.assign(sun.shadow.camera, { left: -5, right: 5, top: 5, bottom: -5, near: 0.5, far: 15 });
  scene.add(sun);
  const ovenLight = new THREE.PointLight("#ff8a3a", 2.2, 5, 1.6); ovenLight.position.set(0, BELT.y + 0.1, BELT.z + 0.45); scene.add(ovenLight);
  const candleLights = [new THREE.PointLight("#ffc46a", 0.7, 2.2, 2), new THREE.PointLight("#ffc46a", 0.7, 2.2, 2)];
  candleLights[0].position.set(-1.55, BENCH_Y + 0.3, 0.3); candleLights[1].position.set(1.45, BENCH_Y + 0.3, 0.3);
  candleLights.forEach((l) => scene.add(l));

  // ------------------------------------------------------------ room (rebuilt when the bakery grows)
  let room = null, roomPhase = 0;
  const twinkle = [];
  const snowFlakes = [];
  function buildRoom(phase) {
    if (room) { scene.remove(room); room.traverse((o) => { if (o.geometry) o.geometry.dispose(); }); }
    twinkle.length = 0; snowFlakes.length = 0;
    room = new THREE.Group();
    const [hw, hd, h] = ROOM[phase];
    M.wall.color.set(phase >= 5 ? "#2e2656" : phase >= 4 ? "#3e434c" : phase === 3 ? "#7a3b2e" : "#6b4428");
    M.floor.color.set(phase >= 4 ? "#3a3d44" : "#5a3a22");
    const floor = new THREE.Mesh(new THREE.PlaneGeometry(hw * 2, hd * 2 + 1.5), M.floor);
    floor.rotation.x = -Math.PI / 2; floor.position.z = 0.75 - 0.75; floor.receiveShadow = true; room.add(floor);
    for (let i = -hw; i < hw; i += 0.5) { const plank = box(0.01, 0.002, hd * 2, M.woodDark); room.add(at(plank, i, 0.001, 0)); }
    const back = new THREE.Mesh(new THREE.PlaneGeometry(hw * 2, h), M.wall); at(back, 0, h / 2, -hd); back.receiveShadow = true; room.add(back);
    const left = new THREE.Mesh(new THREE.PlaneGeometry(hd * 2, h), M.wall); left.rotation.y = Math.PI / 2; at(left, -hw, h / 2, 0); room.add(left);
    const right = new THREE.Mesh(new THREE.PlaneGeometry(hd * 2, h), M.wall); right.rotation.y = -Math.PI / 2; at(right, hw, h / 2, 0); room.add(right);
    const front = new THREE.Mesh(new THREE.PlaneGeometry(hw * 2, h), M.wall); front.rotation.y = Math.PI; at(front, 0, h / 2, hd); room.add(front);
    const ceil = new THREE.Mesh(new THREE.PlaneGeometry(hw * 2, hd * 2), M.woodDark); ceil.rotation.x = Math.PI / 2; at(ceil, 0, h, 0); room.add(ceil);
    for (let x = -hw + 0.8; x < hw; x += 1.6) room.add(at(box(0.18, 0.22, hd * 2, phase >= 4 ? M.steel : M.woodDark), x, h - 0.11, 0));
    // windows with a snowy night outside
    const wins = phase <= 2 ? [[-2.2, 1.9], [2.4, 1.9]] : [[-3.5, 2.2], [0.2, 2.4], [3.6, 2.2]].map(([x, y]) => [x * (hw / 5.5), y]);
    for (const [wx, wy] of wins) {
      const w = 1.1, hh = 0.9;
      const sky = new THREE.Mesh(new THREE.PlaneGeometry(w, hh), new THREE.MeshBasicMaterial({ color: phase === 5 ? "#1a0f45" : "#13264a" })); at(sky, wx, wy, -hd + 0.01); room.add(sky);
      const hill = new THREE.Mesh(new THREE.PlaneGeometry(w, 0.25), M.snowGround); at(hill, wx, wy - hh / 2 + 0.12, -hd + 0.015); room.add(hill);
      for (let k = 0; k < 3; k++) { const tree = new THREE.Mesh(new THREE.ConeGeometry(0.07, 0.24, 6), new THREE.MeshBasicMaterial({ color: "#1d4b33" })); at(tree, wx - 0.35 + k * 0.33, wy - hh / 2 + 0.3, -hd + 0.02); room.add(tree); }
      const frame = new THREE.Group();
      for (const [fw, fh, fx, fy] of [[w + 0.14, 0.07, 0, hh / 2 + 0.035], [w + 0.14, 0.07, 0, -hh / 2 - 0.035], [0.07, hh, -w / 2 - 0.035, 0], [0.07, hh, w / 2 + 0.035, 0], [0.04, hh, 0, 0], [w, 0.04, 0, 0]]) frame.add(at(box(fw, fh, 0.08, phase >= 5 ? M.gold : M.woodDark), fx, fy, 0));
      frame.add(at(box(w + 0.3, 0.05, 0.22, M.white), 0, -hh / 2 - 0.09, 0.08));
      at(frame, wx, wy, -hd + 0.04); room.add(frame);
      for (let k = 0; k < 26; k++) { const f = new THREE.Mesh(new THREE.SphereGeometry(0.008 + Math.random() * 0.008, 5, 4), new THREE.MeshBasicMaterial({ color: "#ffffff" })); f.userData = { x0: wx - w / 2, w, top: wy + hh / 2, bottom: wy - hh / 2, v: 0.1 + Math.random() * 0.15, ph: Math.random() * 6 }; at(f, wx - w / 2 + Math.random() * w, wy - hh / 2 + Math.random() * hh, -hd + 0.025); snowFlakes.push(f); room.add(f); }
      if (phase === 5) { const aur = new THREE.Mesh(new THREE.PlaneGeometry(w, 0.3), new THREE.MeshBasicMaterial({ color: "#4dffb0", transparent: true, opacity: 0.35 })); at(aur, wx, wy + 0.2, -hd + 0.018); room.add(aur); }
    }
    // garland with fairy lights along the back wall
    const pts = []; for (let i = 0; i <= 40; i++) { const x = -hw + (i / 40) * hw * 2; pts.push(new THREE.Vector3(x, h - 0.35 - Math.abs(Math.sin(i / 3)) * 0.18, -hd + 0.08)); }
    const curve = new THREE.CatmullRomCurve3(pts);
    room.add(new THREE.Mesh(new THREE.TubeGeometry(curve, 120, 0.06, 6), new THREE.MeshStandardMaterial({ color: "#1d5a32", roughness: 1 })));
    const cols = ["#ff4040", "#ffd23f", "#45ff8f", "#45b8ff", "#ff6ad5"];
    for (let i = 0; i < 46; i++) { const p = curve.getPoint(i / 45); const mat = new THREE.MeshStandardMaterial({ color: cols[i % 5], emissive: cols[i % 5], emissiveIntensity: 1.5 }); const b = new THREE.Mesh(new THREE.SphereGeometry(0.03, 8, 6), mat); at(b, p.x, p.y - 0.06, p.z + 0.03); twinkle.push(b); room.add(b); }
    // wreath on the back wall and a shelf with cookie jars (cosy phases)
    if (phase <= 3) {
      const wreath = new THREE.Mesh(new THREE.TorusGeometry(0.28, 0.08, 10, 28), new THREE.MeshStandardMaterial({ color: "#1d5a32", roughness: 1 })); at(wreath, -0.2 * hw, 2.1, -hd + 0.08); room.add(wreath);
      const bow = box(0.16, 0.1, 0.04, M.red); at(bow, -0.2 * hw, 2.36, -hd + 0.16); room.add(bow);
      for (let a = 0; a < 6.28; a += 0.8) room.add(at(new THREE.Mesh(new THREE.SphereGeometry(0.03, 8, 6), M.red), -0.2 * hw + Math.cos(a) * 0.3, 2.1 + Math.sin(a) * 0.3, -hd + 0.15));
    }
    if (phase >= 5) for (let x = -hw + 1.5; x < hw; x += 3) { const arch = new THREE.Mesh(new THREE.TorusGeometry(1.2, 0.05, 8, 40, Math.PI), M.gold); at(arch, x, h - 1.4, -hd + 0.1); room.add(arch); }
    scene.add(room);
    roomPhase = phase;
    scene.fog.near = phase >= 4 ? 14 : 9; scene.fog.far = phase >= 4 ? 34 : 24;
  }

  // ------------------------------------------------------------ fixed furniture: bench, belt, oven, chute, jar
  const fixed = new THREE.Group(); scene.add(fixed);
  const bench = new THREE.Group();
  bench.add(at(box(3.4, 0.08, 1.1, M.wood), 0, BENCH_Y - 0.04, 0));
  for (const [x, z] of [[-1.6, -0.45], [1.6, -0.45], [-1.6, 0.45], [1.6, 0.45]]) bench.add(at(box(0.08, BENCH_Y - 0.08, 0.08, M.woodDark), x, (BENCH_Y - 0.08) / 2, z));
  bench.add(at(box(3.3, 0.04, 0.9, M.woodDark), 0, 0.22, 0));
  fixed.add(bench);
  // candles on the bench
  const flames = [];
  for (const x of [-1.55, 1.45]) {
    fixed.add(at(cyl(0.025, 0.025, 0.16, M.white, 12), x, BENCH_Y + 0.08, 0.35));
    const fl = new THREE.Mesh(new THREE.SphereGeometry(0.018, 10, 8), new THREE.MeshBasicMaterial({ color: "#ffcf5a" })); fl.scale.y = 1.8; at(fl, x, BENCH_Y + 0.19, 0.35); flames.push(fl); fixed.add(fl);
  }
  // dough bowl
  const bowlPts = []; for (let i = 0; i <= 10; i++) { const a = (i / 10) * Math.PI / 2; bowlPts.push(new THREE.Vector2(Math.sin(a) * 0.22 + 0.02, -Math.cos(a) * 0.15)); }
  const bowl = new THREE.Mesh(new THREE.LatheGeometry(bowlPts, 28), new THREE.MeshStandardMaterial({ color: "#ece6dc", roughness: 0.4, side: THREE.DoubleSide })); at(bowl, 0.95, BENCH_Y + 0.15, 0); bowl.castShadow = true; fixed.add(bowl);
  fixed.add(at(cyl(0.245, 0.24, 0.035, M.red, 28), 0.95, BENCH_Y + 0.1, 0));
  const doughMass = new THREE.Mesh(new THREE.SphereGeometry(0.2, 24, 12, 0, Math.PI * 2, 0, Math.PI / 2), M.dough); doughMass.scale.y = 0.5; at(doughMass, 0.95, BENCH_Y + 0.06, 0); fixed.add(doughMass);
  // tray (Blech)
  const tray = new THREE.Group();
  tray.add(at(box(0.62, 0.015, 0.42, M.metal), 0, 0, 0));
  for (const [w, d, x, z] of [[0.62, 0.02, 0, 0.21], [0.62, 0.02, 0, -0.21], [0.02, 0.42, 0.31, 0], [0.02, 0.42, -0.31, 0]]) tray.add(at(box(w, 0.035, d, M.metal), x, 0.017, z));
  at(tray, -1.2, BENCH_Y + 0.01, 0.02); fixed.add(tray);
  // the rolled sheet, the ball being rolled, dough balls
  const sheet = box(0.7, 0.012, 0.4, M.dough); at(sheet, -0.25, BENCH_Y + 0.007, 0.02); fixed.add(sheet);
  const rolling = new THREE.Mesh(new THREE.SphereGeometry(0.09, 20, 14), M.dough); fixed.add(rolling);
  const balls = []; for (let i = 0; i < 5; i++) { const b = new THREE.Mesh(new THREE.SphereGeometry(0.06, 16, 12), M.dough); b.castShadow = true; at(b, 0.48 + (i % 2) * 0.13, BENCH_Y + 0.05, -0.12 + Math.floor(i / 2) * 0.13); balls.push(b); fixed.add(b); }
  // rolling pin and star cutter (hand tools)
  const pin = new THREE.Group();
  const pinBody = cyl(0.04, 0.04, 0.5, new THREE.MeshStandardMaterial({ color: "#d9a066", roughness: 0.6 })); pinBody.rotation.z = Math.PI / 2; pin.add(pinBody);
  for (const s of [-1, 1]) { const handle = cyl(0.018, 0.018, 0.12, M.woodDark); handle.rotation.z = Math.PI / 2; at(handle, s * 0.31, 0, 0); pin.add(handle); }
  fixed.add(pin);
  const cutter = new THREE.Mesh(new THREE.ExtrudeGeometry(starShape(0.06, 0.5), { depth: 0.04, bevelEnabled: false }), new THREE.MeshStandardMaterial({ color: "#cfd6dd", metalness: 0.8, roughness: 0.3, side: THREE.DoubleSide, wireframe: false }));
  cutter.rotation.x = -Math.PI / 2; cutter.castShadow = true; fixed.add(cutter);
  // belt + oven + funnel + jar: built per layout (lanes/floors change)
  const lineGroup = new THREE.Group(); scene.add(lineGroup);
  let lineKey = "";
  const beltStripes = [];
  function buildLine(d, L, phase) {
    const floors = Math.min(3, d.floors), lanes = Math.min(4, d.lanes);
    const key = `${floors}:${lanes}:${phase}:${L.turboofen || 0}:${L.goldstrasse || 0}:${L.schwebend || 0}`;
    if (key === lineKey) return;
    lineKey = key;
    lineGroup.clear(); beltStripes.length = 0;
    const len = BELT.x1 - BELT.x0, ovenLen = BELT.oven1 - BELT.oven0;
    const beltMat = L.goldstrasse ? M.gold : M.rubber;
    for (let f = 0; f < floors; f++) {
      const y = BELT.y + f * BELT.floorH;
      for (let l = 0; l < lanes; l++) {
        const z = BELT.z - l * BELT.laneGap;
        const floating = f > 0 && L.schwebend;
        lineGroup.add(at(box(len, 0.03, 0.2, floating ? new THREE.MeshStandardMaterial({ color: "#5b4bb0", emissive: "#2a1d70", emissiveIntensity: 0.6 }) : beltMat), BELT.x0 + len / 2, y - 0.015, z));
        for (let k = 0; k < 24; k++) { const st = box(0.012, 0.004, 0.2, M.steel); at(st, BELT.x0 + (k / 24) * len, y + 0.001, z); st.userData.k = k; beltStripes.push(st); lineGroup.add(st); }
        if (!floating) for (let x = BELT.x0 + 0.2; x < BELT.x1; x += 0.8) lineGroup.add(at(box(0.05, y - 0.03, 0.05, M.steel), x, (y - 0.03) / 2, z));
      }
      // oven tunnel around the belts, with a big glass front
      const depth = 0.32 + (lanes - 1) * BELT.laneGap, zc = BELT.z - ((lanes - 1) * BELT.laneGap) / 2;
      const ovenMat = L.turboofen ? new THREE.MeshStandardMaterial({ color: "#9b2a1a", roughness: 0.6, metalness: 0.2 }) : phase >= 4 ? M.steel : M.brick;
      lineGroup.add(at(box(ovenLen + 0.2, 0.06, depth + 0.12, ovenMat), 0, y + 0.42, zc));             // roof
      lineGroup.add(at(box(ovenLen + 0.2, 0.46, 0.06, ovenMat), 0, y + 0.19, zc - depth / 2 - 0.05));  // back wall
      lineGroup.add(at(box(0.1, 0.46, depth + 0.12, ovenMat), BELT.oven0 - 0.05, y + 0.19, zc));
      lineGroup.add(at(box(0.1, 0.46, depth + 0.12, ovenMat), BELT.oven1 + 0.05, y + 0.19, zc));
      const glowPanel = new THREE.Mesh(new THREE.PlaneGeometry(ovenLen, 0.36), M.ovenGlow); at(glowPanel, 0, y + 0.2, zc - depth / 2 - 0.015); lineGroup.add(glowPanel);
      const rod = box(ovenLen - 0.1, 0.02, 0.02, new THREE.MeshStandardMaterial({ color: "#ff4a1a", emissive: "#ff3a00", emissiveIntensity: 2 })); at(rod, 0, y + 0.36, zc); lineGroup.add(rod);
      const glass = new THREE.Mesh(new THREE.PlaneGeometry(ovenLen, 0.42), M.glass); at(glass, 0, y + 0.2, zc + depth / 2 + 0.06); lineGroup.add(glass);
      lineGroup.add(at(box(ovenLen + 0.2, 0.04, 0.06, ovenMat), 0, y + 0.42, zc + depth / 2 + 0.06));
      if (f === floors - 1) { const chimney = box(0.18, 0.5, 0.18, ovenMat); at(chimney, -0.8, y + 0.7, zc); lineGroup.add(chimney); }
    }
    // funnel + jar (the chute)
    const funnel = new THREE.Mesh(new THREE.CylinderGeometry(0.34 + Math.min(4, L.schacht || 0) * 0.03, 0.09, 0.3, 24, 1, true), L.goldstrasse ? M.gold : phase >= 4 ? M.metal : new THREE.MeshStandardMaterial({ color: "#a0703f", side: THREE.DoubleSide, roughness: 0.6 }));
    funnel.material.side = THREE.DoubleSide;
    at(funnel, JAR.x, JAR.h + 0.32, JAR.z); lineGroup.add(funnel);
    const jarMesh = new THREE.Mesh(new THREE.CylinderGeometry(JAR.r, JAR.r, JAR.h, 32, 1, true), M.glass); at(jarMesh, JAR.x, JAR.h / 2, JAR.z); lineGroup.add(jarMesh);
    lineGroup.add(at(cyl(JAR.r + 0.02, JAR.r + 0.02, 0.04, M.red, 32), JAR.x, 0.02, JAR.z));
    lineGroup.add(at(cyl(JAR.r + 0.02, JAR.r + 0.02, 0.03, M.red, 32), JAR.x, JAR.h, JAR.z));
  }
  // pile inside the jar
  const pile = new THREE.Mesh(new THREE.CylinderGeometry(JAR.r - 0.02, JAR.r - 0.02, 1, 28), new THREE.MeshStandardMaterial({ color: "#c98a3d", roughness: 0.9 }));
  scene.add(pile);

  // ------------------------------------------------------------ machines (one group per upgrade id, shown when owned)
  const machines = {};
  const mach = (id, build) => { const g = new THREE.Group(); build(g); g.visible = false; machines[id] = g; scene.add(g); return g; };
  const moving = {};
  mach("portionierer", (g) => {
    const hop = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.06, 0.32, 20, 1, true), new THREE.MeshStandardMaterial({ color: "#b9c2cc", metalness: 0.6, roughness: 0.35, side: THREE.DoubleSide }));
    at(hop, 0.95, 1.55, 0); g.add(hop);
    for (const x of [0.72, 1.18]) g.add(at(box(0.03, 0.75, 0.03, M.steel), x, 1.3, -0.18));
    g.add(at(box(0.5, 0.03, 0.03, M.steel), 0.95, 1.68, -0.18));
    moving.drop = new THREE.Mesh(new THREE.SphereGeometry(0.05, 12, 10), M.dough); g.add(moving.drop);
  });
  mach("zufuhr", (g) => { const p = cyl(0.05, 0.05, 2.4, M.steel, 12); p.rotation.z = Math.PI / 2; at(p, 2.2, 1.75, 0); g.add(p); g.add(at(cyl(0.05, 0.05, 0.12, M.steel, 12), 1.0, 1.69, 0)); });
  mach("extruder", (g) => { g.add(at(box(0.6, 0.45, 0.5, new THREE.MeshStandardMaterial({ color: "#6c7a89", metalness: 0.5, roughness: 0.4 })), 0.95, 1.95, -0.05)); g.add(at(box(0.2, 0.06, 0.06, M.red), 0.95, 2.0, 0.22)); });
  mach("beschleuniger", (g) => { for (let i = 0; i < 6; i++) { const s = new THREE.Mesh(new THREE.OctahedronGeometry(0.035), new THREE.MeshStandardMaterial({ color: "#fff0a0", emissive: "#ffd23f", emissiveIntensity: 2 })); s.userData.i = i; g.add(s); } });
  mach("walze", (g) => {
    moving.rollers = [];
    for (const y of [BENCH_Y + 0.05, BENCH_Y + 0.15]) { const r = cyl(0.045, 0.045, 0.62, M.metal, 20); r.rotation.x = Math.PI / 2; at(r, 0.15, y, 0.02); moving.rollers.push(r); g.add(r); }
    for (const z of [-0.32, 0.36]) g.add(at(box(0.16, 0.26, 0.04, M.steel), 0.15, BENCH_Y + 0.12, z));
    moving.crank = new THREE.Group(); moving.crank.add(at(box(0.02, 0.14, 0.02, M.steel), 0, 0.07, 0)); moving.crank.add(at(cyl(0.02, 0.02, 0.06, M.red, 10), 0, 0.14, 0.03)); at(moving.crank, 0.15, BENCH_Y + 0.15, 0.4); g.add(moving.crank);
  });
  mach("stanzpresse", (g) => {
    const col = new THREE.MeshStandardMaterial({ color: "#8d6e63", roughness: 0.6 });
    for (const x of [-0.72, -0.18]) g.add(at(box(0.05, 0.6, 0.05, col), x, BENCH_Y + 0.3, -0.15));
    g.add(at(box(0.62, 0.06, 0.12, col), -0.45, BENCH_Y + 0.6, -0.15));
    moving.stamp = new THREE.Group(); moving.stamp.add(at(box(0.04, 0.3, 0.04, M.metal), 0, 0.15, 0)); moving.stamp.add(at(box(0.42, 0.04, 0.3, M.metal), 0, 0, 0.12)); at(moving.stamp, -0.45, BENCH_Y + 0.25, -0.1); g.add(moving.stamp);
  });
  mach("ausstechwalze", (g) => { moving.drum = cyl(0.08, 0.08, 0.4, M.steel, 16); moving.drum.rotation.x = Math.PI / 2; at(moving.drum, -0.45, BENCH_Y + 0.1, 0.02); g.add(moving.drum); });
  mach("industrie", (g) => { const m = new THREE.MeshStandardMaterial({ color: "#6c7a89", metalness: 0.5, roughness: 0.4 }); for (const x of [-0.8, -0.1]) g.add(at(box(0.06, 0.5, 0.06, m), x, BENCH_Y + 0.25, 0.3)); g.add(at(box(0.76, 0.05, 0.06, m), -0.45, BENCH_Y + 0.5, 0.3)); g.add(at(box(0.5, 0.04, 0.04, new THREE.MeshStandardMaterial({ color: "#ffd23f", emissive: "#a07000" })), -0.45, BENCH_Y + 0.47, 0.33)); });
  mach("ultra", (g) => { const ring = new THREE.Mesh(new THREE.TorusGeometry(0.26, 0.02, 8, 30), new THREE.MeshStandardMaterial({ color: "#ffe27a", emissive: "#ffb000", emissiveIntensity: 1.6 })); ring.rotation.x = Math.PI / 2; at(ring, -0.45, BENCH_Y + 0.5, -0.05); g.add(ring); moving.ultra = ring; });
  mach("steuerung", (g) => {
    g.add(at(box(0.7, 1.1, 0.4, new THREE.MeshStandardMaterial({ color: "#2b2f36", roughness: 0.5 })), -2.55, 0.55, 0.1));
    moving.lamps = [];
    for (let k = 0; k < 12; k++) { const lamp = new THREE.Mesh(new THREE.SphereGeometry(0.025, 8, 6), new THREE.MeshStandardMaterial({ color: "#444", emissive: ["#4ade80", "#ffd23f", "#ff5a5a"][k % 3], emissiveIntensity: 0 })); at(lamp, -2.75 + (k % 4) * 0.13, 0.95 + Math.floor(k / 4) * 0.1, 0.31); moving.lamps.push(lamp); g.add(lamp); }
    moving.gearA = cyl(0.14, 0.14, 0.04, M.metal, 12); moving.gearA.rotation.x = Math.PI / 2; at(moving.gearA, -2.5, 0.55, 0.32); g.add(moving.gearA);
  });
  mach("blechschieber", (g) => { g.add(at(box(0.08, 0.06, 0.4, M.steel), -1.6, BENCH_Y + 0.04, 0.02)); moving.pusher = box(0.04, 0.08, 0.36, M.red); at(moving.pusher, -1.53, BENCH_Y + 0.05, 0.02); g.add(moving.pusher); });
  mach("transport", (g) => { const b = box(0.24, 0.03, 1.3, M.rubber); b.rotation.x = -0.25; at(b, -1.9, BENCH_Y + 0.13, -0.45); g.add(b); g.add(at(box(0.04, 0.9, 0.04, M.steel), -1.9, 0.5, -0.9)); });
  mach("platzierung", (g) => { const base = cyl(0.12, 0.15, 0.1, M.steel); at(base, -1.75, BELT.y + 0.05, BELT.z + 0.35); g.add(base); moving.arm = new THREE.Group(); moving.arm.add(at(box(0.06, 0.06, 0.5, new THREE.MeshStandardMaterial({ color: "#e0a030", roughness: 0.5 })), 0, 0.1, -0.22)); at(moving.arm, -1.75, BELT.y + 0.1, BELT.z + 0.35); g.add(moving.arm); });
  mach("verteiler", (g) => { g.add(at(box(0.3, 0.25, 0.9, M.steel), -2.05, BELT.y + 0.15, BELT.z - 0.3)); });
  mach("portale", (g) => { moving.portal = new THREE.Mesh(new THREE.TorusGeometry(0.28, 0.035, 10, 40), new THREE.MeshStandardMaterial({ color: "#c08bff", emissive: "#9a4dff", emissiveIntensity: 2 })); moving.portal.rotation.y = Math.PI / 2; at(moving.portal, -2.2, BELT.y + 0.3, BELT.z); g.add(moving.portal); });
  mach("motor", (g) => { g.add(at(box(0.3, 0.28, 0.3, new THREE.MeshStandardMaterial({ color: "#36474f", metalness: 0.4, roughness: 0.5 })), BELT.x0 + 0.1, BELT.y - 0.2, BELT.z + 0.22)); moving.motorWheel = cyl(0.1, 0.1, 0.04, M.metal, 10); moving.motorWheel.rotation.x = Math.PI / 2; at(moving.motorWheel, BELT.x0 + 0.1, BELT.y - 0.2, BELT.z + 0.38); g.add(moving.motorWheel); });
  mach("hochleistung", (g) => { g.add(at(box(0.22, 0.22, 0.22, new THREE.MeshStandardMaterial({ color: "#3c6e9e", metalness: 0.4, roughness: 0.4 })), 0.52, BENCH_Y + 0.12, 0.38)); });
  mach("magnet", (g) => { g.add(at(box(BELT.x1 - BELT.x0, 0.02, 0.24, new THREE.MeshStandardMaterial({ color: "#3a7bff", emissive: "#2a6bff", emissiveIntensity: 1.2 })), (BELT.x0 + BELT.x1) / 2, BELT.y - 0.06, BELT.z)); });
  mach("sammelstation", (g) => { g.add(at(cyl(JAR.r + 0.08, JAR.r + 0.1, 0.1, M.steel, 28), JAR.x, 0.05, JAR.z)); });
  mach("sensoren", (g) => { moving.laser = box(0.7, 0.008, 0.008, new THREE.MeshBasicMaterial({ color: "#ff2a2a" })); at(moving.laser, JAR.x, JAR.h + 0.5, JAR.z); g.add(moving.laser); });
  mach("rentier", (g) => {
    g.add(at(cyl(0.3, 0.35, 0.5, new THREE.MeshStandardMaterial({ color: "#3a2d6b", roughness: 0.5 })), -2.6, 0.25, -1.6));
    moving.crystal = new THREE.Mesh(new THREE.OctahedronGeometry(0.22), new THREE.MeshStandardMaterial({ color: "#a8e6ff", emissive: "#5cc8ff", emissiveIntensity: 1.6, transparent: true, opacity: 0.9 })); at(moving.crystal, -2.6, 0.85, -1.6); g.add(moving.crystal);
    for (const s of [-1, 1]) { const antler = cyl(0.015, 0.02, 0.4, M.gold, 8); antler.rotation.z = s * 0.6; at(antler, -2.6 + s * 0.2, 1.15, -1.6); g.add(antler); }
  });
  mach("vollauto", (g) => { for (let i = 0; i < 5; i++) g.add(at(new THREE.Mesh(new THREE.SphereGeometry(0.04, 8, 6), new THREE.MeshStandardMaterial({ color: "#4ade80", emissive: "#4ade80", emissiveIntensity: 2 })), -1.6 + i * 0.8, BELT.y + 0.55, BELT.z + 0.2)); });
  mach("megafabrik", (g) => { for (const x of [-3, 3]) { const banner = new THREE.Mesh(new THREE.PlaneGeometry(1, 2.2), new THREE.MeshStandardMaterial({ color: "#c81d2a", side: THREE.DoubleSide })); at(banner, x, 3.4, -4); g.add(banner); g.add(at(new THREE.Mesh(new THREE.OctahedronGeometry(0.2), M.gold), x, 2.3, -3.95)); } });

  // ------------------------------------------------------------ cookies (one instanced mesh for all of them)
  const starGeo = new THREE.ExtrudeGeometry(starShape(0.038, 0.52), { depth: 0.012, bevelEnabled: true, bevelThickness: 0.004, bevelSize: 0.004, bevelSegments: 2 });
  starGeo.rotateX(-Math.PI / 2);
  const cookieMat = new THREE.MeshStandardMaterial({ roughness: 0.75 });
  const cookies = new THREE.InstancedMesh(starGeo, cookieMat, MAX_COOKIES);
  cookies.castShadow = true; cookies.frustumCulled = false;
  cookies.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
  scene.add(cookies);
  const bakeCols = Array.from({ length: BAKE_STEPS }, (_, i) => bakeColor(i / (BAKE_STEPS - 1)));
  const goldCol = new THREE.Color("#ffd84a");
  const tmp = new THREE.Object3D();
  let ci = 0;
  function put(x, y, z, col, rot = 0, tilt = 0, s = 1) {
    if (ci >= MAX_COOKIES) return;
    tmp.position.set(x, y, z); tmp.rotation.set(tilt, rot, 0); tmp.scale.setScalar(s); tmp.updateMatrix();
    cookies.setMatrixAt(ci, tmp.matrix); cookies.setColorAt(ci, col); ci++;
  }

  // ------------------------------------------------------------ the elf's hands (attached to the camera)
  function makeArm(side) {
    const g = new THREE.Group();
    const sleeve = cyl(0.045, 0.055, 0.32, M.green, 16); sleeve.rotation.x = Math.PI / 2; at(sleeve, 0, 0, 0.17); g.add(sleeve);
    const cuff = cyl(0.056, 0.056, 0.045, M.red, 16); cuff.rotation.x = Math.PI / 2; g.add(cuff);
    const fur = new THREE.Mesh(new THREE.TorusGeometry(0.052, 0.016, 8, 18), M.white); fur.position.z = -0.024; g.add(fur);
    const hand = new THREE.Group();
    const palm = new THREE.Mesh(new THREE.SphereGeometry(0.04, 14, 10), M.skin); palm.scale.set(1, 0.6, 1.25); hand.add(palm);
    for (let i = 0; i < 4; i++) { const f = cyl(0.009, 0.008, 0.05, M.skin, 8); f.rotation.x = Math.PI / 2 - 0.3; at(f, -0.022 + i * 0.0145, -0.004, -0.055); hand.add(f); }
    const thumb = cyl(0.01, 0.009, 0.04, M.skin, 8); thumb.rotation.set(Math.PI / 2, 0, side * 0.9); at(thumb, side * -0.037, 0, -0.022); hand.add(thumb);
    at(hand, 0, 0, -0.06); g.add(hand);
    g.traverse((o) => { o.castShadow = false; });
    camera.add(g);
    return g;
  }
  const armL = makeArm(-1), armR = makeArm(1);

  // ------------------------------------------------------------ hover outline, pops, sparks
  const outline = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(1, 1, 1)), new THREE.LineBasicMaterial({ color: "#ffd23f" }));
  outline.visible = false; scene.add(outline);
  const hoverLabel = textSprite(" "); hoverLabel.visible = false; scene.add(hoverLabel);
  let hoverKey = "";
  const pops = [];
  const sparks = new THREE.Points(new THREE.BufferGeometry(), new THREE.PointsMaterial({ size: 0.05, vertexColors: true, transparent: true, depthWrite: false }));
  const sparkData = [];
  sparks.frustumCulled = false; scene.add(sparks);

  // ------------------------------------------------------------ input: walk + look
  const keys = new Set();
  let drag = null, focused = false;
  const onKey = (e, down) => {
    if (!focused && document.activeElement !== canvas) return;
    const k = e.key.toLowerCase();
    if (["w", "a", "s", "d", "arrowup", "arrowdown", "arrowleft", "arrowright"].includes(k)) { e.preventDefault(); if (down) keys.add(k); else keys.delete(k); }
  };
  const kd = (e) => onKey(e, true), ku = (e) => onKey(e, false);
  window.addEventListener("keydown", kd); window.addEventListener("keyup", ku);
  const pd = (e) => { drag = { x: e.clientX, y: e.clientY, moved: 0 }; focused = true; };
  const pm = (e) => {
    if (!drag || !(e.buttons & 1)) return;
    const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
    drag.moved += Math.abs(dx) + Math.abs(dy); drag.x = e.clientX; drag.y = e.clientY;
    player.yaw -= dx * 0.005; player.pitch = clamp(player.pitch - dy * 0.004, -1.2, 0.9);
  };
  const pu = () => { setTimeout(() => { drag = null; }, 0); };
  canvas.addEventListener("pointerdown", pd); window.addEventListener("pointermove", pm); window.addEventListener("pointerup", pu);
  canvas.addEventListener("blur", () => { focused = false; keys.clear(); });

  // ------------------------------------------------------------ station hit boxes
  const raycaster = new THREE.Raycaster();
  const hitBoxes = Object.entries(STATIONS).map(([id, st]) => {
    const m = new THREE.Mesh(new THREE.BoxGeometry(...st.size), new THREE.MeshBasicMaterial({ visible: false }));
    m.position.set(...st.pos); m.userData = { id, label: st.label }; scene.add(m);
    return m;
  });
  function hit(px, py) {
    if (drag && drag.moved > 6) return { id: "drag" };
    const rect = canvas.getBoundingClientRect();
    raycaster.setFromCamera(new THREE.Vector2((px / rect.width) * 2 - 1, -(py / rect.height) * 2 + 1), camera);
    const h = raycaster.intersectObjects(hitBoxes, false)[0];
    return h ? { id: h.object.userData.id, label: h.object.userData.label, mesh: h.object } : null;
  }
  function setHover(h) {
    if (!h || h.id === "drag" || !h.mesh) { outline.visible = false; hoverLabel.visible = false; hoverKey = ""; return; }
    outline.visible = true; outline.position.copy(h.mesh.position); outline.scale.set(...STATIONS[h.id].size);
    if (hoverKey !== h.id) {
      hoverKey = h.id;
      scene.remove(hoverLabel); hoverLabel.material.map.dispose();
      const sp = textSprite(h.label); hoverLabel.material = sp.material; hoverLabel.scale.copy(sp.scale); scene.add(hoverLabel);
    }
    hoverLabel.visible = true; hoverLabel.position.set(h.mesh.position.x, h.mesh.position.y + 0.32, h.mesh.position.z);
  }

  // ------------------------------------------------------------ events from the simulation
  const anim = { roll: 0, rolled: 0, cut: 0, press: 0, load: 0, portion: 0, crank: 0, push: 0, blocked: 0 };
  let landAcc = 0, landT = 0, finaleT = -1;
  function burst(x, y, z, n, color, speed = 1.6) {
    for (let i = 0; i < n; i++) sparkData.push({ p: new THREE.Vector3(x, y, z), v: new THREE.Vector3((Math.random() - 0.5) * speed, Math.random() * speed * 1.2, (Math.random() - 0.5) * speed), life: 0, max: 1 + Math.random() * 0.6, c: new THREE.Color(color || `hsl(${Math.random() * 360},90%,65%)`) });
  }
  function onEvents(events) {
    for (const e of events) {
      if (e.type in anim) anim[e.type] = 1;
      if (e.type === "rolled") anim.roll = 1;
      if (e.type === "portion") burst(0.95, BENCH_Y + 0.25, 0, 10, "#ffffff", 0.5);
      if (e.type === "cut" || e.type === "press") burst(-0.45, BENCH_Y + 0.05, 0.02, 8, "#ffffff", 0.5);
      if (e.type === "land") landAcc += e.n;
      if (e.type === "machine" || e.type === "buy") burst(player.x, 1.6, player.z - 1, 40, "#ffd23f", 2);
      if (e.type === "finale") finaleT = 0;
    }
  }

  // ------------------------------------------------------------ resize
  function resize() {
    const rect = canvas.getBoundingClientRect();
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    gl.setPixelRatio(dpr);
    gl.setSize(Math.max(1, rect.width), Math.max(1, rect.height), false);
    camera.aspect = Math.max(0.5, rect.width / Math.max(1, rect.height));
    camera.fov = camera.aspect < 1 ? 82 : 68;
    camera.updateProjectionMatrix();
  }

  // ------------------------------------------------------------ frame
  let last = performance.now();
  function frame(s, now = performance.now()) {
    const dt = Math.min(0.05, (now - last) / 1000); last = now;
    const t = now / 1000;
    const d = derive(s.levels);
    const L = s.levels;
    const phase = phaseOf(s);
    if (phase !== roomPhase) buildRoom(phase);
    buildLine(d, L, phase);
    for (const k in anim) anim[k] = Math.max(0, anim[k] - dt * 2.6);

    // walking (stay inside the room, not through the bench)
    const [hw, hd] = ROOM[phase];
    const speed = 2.2 * dt;
    let fx = 0, fz = 0;
    if (keys.has("w") || keys.has("arrowup")) fz -= 1;
    if (keys.has("s") || keys.has("arrowdown")) fz += 1;
    if (keys.has("a") || keys.has("arrowleft")) fx -= 1;
    if (keys.has("d") || keys.has("arrowright")) fx += 1;
    if (fx || fz) {
      const sin = Math.sin(player.yaw), cos = Math.cos(player.yaw);
      let nx = player.x + (fx * cos + fz * sin) * speed, nz = player.z + (-fx * sin + fz * cos) * speed;
      nx = clamp(nx, -hw + 0.4, hw - 0.4); nz = clamp(nz, -hd + 0.4, hd - 0.4);
      if (Math.abs(nx) < 1.85 && nz > -1.35 && nz < 0.75) nz = player.z > 0 ? 0.75 : -1.35; // bench and belt block the way
      player.x = nx; player.z = nz;
    }
    const bob = fx || fz ? Math.sin(t * 9) * 0.02 : Math.sin(t * 1.6) * 0.004;
    camera.position.set(player.x, 1.55 + bob, player.z);
    camera.rotation.set(player.pitch, player.yaw, 0, "YXZ");

    // hands: rest low at the sides, reach forward for the current action
    const restL = new THREE.Vector3(-0.22, -0.2, -0.46), restR = new THREE.Vector3(0.22, -0.2, -0.46);
    const reach = (v, dx, dy, dz, k) => v.set(v.x + dx * k, v.y + dy * k, v.z + dz * k);
    const lp = restL.clone(), rp = restR.clone();
    const rollK = ease(1 - Math.max(anim.roll, anim.crank));
    if (rollK > 0) { const sw = Math.sin(t * 18) * 0.06; reach(lp, 0.08, 0.02, -0.2 + sw, rollK); reach(rp, -0.08, 0.02, -0.2 + sw, rollK); }
    const cutK = ease(1 - Math.max(anim.cut, anim.press)); if (cutK > 0) reach(lp, 0.12, -0.08 * cutK + 0.04, -0.22, cutK);
    const porK = ease(1 - anim.portion); if (porK > 0) reach(rp, 0.04, 0.04, -0.25, porK);
    const loadK = ease(1 - anim.load); if (loadK > 0) { reach(lp, 0.06, 0.15, -0.25, loadK); reach(rp, -0.06, 0.15, -0.25, loadK); }
    armL.position.copy(lp); armR.position.copy(rp);
    armL.rotation.set(0.55 - cutK * 0.25, 0.22, 0.15); armR.rotation.set(0.55, -0.22, -0.15);

    // bench state
    const fill = s.dough / GOAL;
    doughMass.scale.set(0.55 + fill * 0.45, 0.25 + fill * 0.45, 0.55 + fill * 0.45);
    const nBalls = Math.min(5, Math.ceil(s.ball / d.sheetSize));
    balls.forEach((b, i) => { b.visible = i < nBalls && !(i === 0 && s.rollProgress > 0); });
    rolling.visible = s.rollProgress > 0 && s.ball > 0;
    if (rolling.visible) { const p = s.rollProgress; rolling.scale.set(1 + p * 2.6, 0.7 - p * 0.55, 1 + p * 1.4); rolling.position.set(0.15, BENCH_Y + 0.04 - p * 0.02, 0.02); }
    sheet.visible = s.sheet > 0;
    if (sheet.visible) { const k = clamp(s.sheet / (d.sheetSize * 2), 0.25, 1); sheet.scale.x = k; sheet.position.x = -0.6 + 0.35 * k; }
    pin.visible = !d.walze && !d.autoRoll;
    const pinScale = 1 + 0.15 * (L.nudelholz || 0);
    pin.scale.set(1, 1, 1); pinBody.scale.y = pinScale;
    if (rollK > 0) pin.position.set(0.15, BENCH_Y + 0.05, 0.02 + Math.sin(t * 18) * 0.12); else pin.position.set(0.25, BENCH_Y + 0.045, 0.38);
    pin.rotation.set(0, Math.PI / 2, rollK > 0 ? t * 8 : 0);
    cutter.visible = !d.pressSize && !d.autoCut;
    cutter.position.set(-0.45, BENCH_Y + 0.03 + (cutK > 0 ? 0.12 - cutK * 0.12 : 0.0), cutK > 0 ? 0.02 : 0.32);
    const lift = ease(1 - anim.load) * 0.25;
    tray.position.set(-1.2, BENCH_Y + 0.01 + lift, 0.02 - lift * 2.2);
    flames.forEach((f, i) => { f.scale.y = 1.8 + Math.sin(t * 13 + i) * 0.25; });
    candleLights.forEach((l, i) => { l.intensity = 0.6 + Math.sin(t * 11 + i * 2) * 0.08; });
    ovenLight.intensity = 2 + Math.sin(t * 3) * 0.25 + (finaleT >= 0 ? 1.5 : 0);
    twinkle.forEach((b, i) => { b.material.emissiveIntensity = Math.sin(t * 2 + i * 1.7) > -0.3 ? 1.6 : 0.1; });
    for (const f of snowFlakes) { const u = f.userData; f.position.y -= u.v * dt; f.position.x += Math.sin(t + u.ph) * 0.02 * dt; if (f.position.y < u.bottom) { f.position.y = u.top; f.position.x = u.x0 + Math.random() * u.w; } }

    // machines
    for (const [id, g] of Object.entries(machines)) g.visible = (L[id] || 0) > 0;
    machines.walze.visible = d.walze || d.autoRoll > 0;
    machines.stanzpresse.visible = d.pressSize > 0 || d.autoCut > 0;
    const working = s.dough > 0 || s.ball > 0 || s.sheet > 0;
    if (moving.drop) { const k = (t * (L.extruder ? 2.4 : 1.2)) % 1; moving.drop.visible = working && d.autoPortion > 0; moving.drop.position.set(0.95, 1.38 - k * 0.38, 0); }
    if (moving.rollers) { const spin = d.autoRoll ? t * 6 : anim.crank * 12; moving.rollers.forEach((r, i) => { r.rotation.y = (i ? -1 : 1) * spin; }); moving.crank.rotation.z = spin; }
    if (moving.stamp) { const cyc = d.autoCut && working ? (Math.sin(t * Math.min(14, 4 + d.autoCut / 60)) + 1) / 2 : ease(1 - anim.press); moving.stamp.position.y = BENCH_Y + 0.25 - cyc * 0.2; }
    if (moving.drum) moving.drum.rotation.y = t * 5;
    if (moving.ultra) moving.ultra.rotation.z = t * 3;
    if (moving.lamps) moving.lamps.forEach((l, k) => { l.material.emissiveIntensity = Math.sin(t * 5 + k * 1.7) > 0 ? 1.8 : 0; });
    if (moving.gearA) moving.gearA.rotation.y = t * 2;
    if (moving.pusher) moving.pusher.position.x = -1.53 + ease(1 - anim.push) * 0.25;
    if (moving.arm) moving.arm.rotation.y = Math.sin(t * 3) * 0.9;
    if (moving.portal) { moving.portal.rotation.x = t * 2; moving.portal.material.emissive.setHSL((t * 0.2) % 1, 0.9, 0.55); }
    if (moving.motorWheel) moving.motorWheel.rotation.y = t * d.speed * 4;
    if (moving.laser) moving.laser.visible = Math.sin(t * 9) > -0.6;
    if (moving.crystal) { moving.crystal.rotation.y = t; moving.crystal.position.y = 0.85 + Math.sin(t * 2) * 0.05; }
    if (machines.beschleuniger.visible) machines.beschleuniger.children.forEach((c, i) => c.position.set(0.95 + Math.cos(t * 2 + i) * 0.3, 1.75 + Math.sin(t * 3 + i) * 0.08, Math.sin(t * 2 + i) * 0.3));
    const beltOffset = (t * d.speed * ((BELT.oven1 - BELT.oven0) / OVEN_SLOTS)) % ((BELT.x1 - BELT.x0) / 24);
    for (const st of beltStripes) st.position.x = BELT.x0 + (st.userData.k / 24) * (BELT.x1 - BELT.x0) + beltOffset;

    // ---------------- cookies
    ci = 0;
    const raw = bakeCols[0], baked = bakeCols[BAKE_STEPS - 1];
    // on the tray
    const trayShow = Math.min(s.tray, 40);
    for (let i = 0; i < trayShow; i++) put(-1.2 - 0.25 + (i % 8) * 0.07, BENCH_Y + 0.025 + lift + Math.floor(i / 40) * 0.015, 0.02 - 0.15 + Math.floor(i / 8) * 0.075 - lift * 2.2, raw, i * 0.7);
    // waiting in front of the oven (backlog)
    const wait = Math.min(s.queue, 120);
    for (let i = 0; i < wait; i++) put(BELT.x0 + 0.15 + (i % 12) * 0.07, BELT.y + 0.01 + Math.floor(i / 36) * 0.015, BELT.z - 0.07 + (Math.floor(i / 12) % 3) * 0.07, raw, i * 0.9);
    // on the belts inside the oven, colour by how far they got
    const floors = Math.min(3, d.floors), lanes = Math.min(4, d.lanes), rows = Math.min(3, Math.round(d.perRow));
    const ovenLen = BELT.oven1 - BELT.oven0, slotW = ovenLen / OVEN_SLOTS;
    const cells = OVEN_SLOTS * 3;
    const occ = new Float32Array(cells + 1);
    for (const [pos, n] of s.belt) occ[Math.min(cells, Math.max(0, Math.floor(pos * 3)))] += n;
    const perCell = floors * lanes * rows;
    const finale = s.finished != null;
    if (finale) { const shift = Math.floor(t * d.speed * 3); for (let k = 0; k < cells; k++) if ((k + shift) % 2 === 0) occ[k] = Math.max(occ[k], perCell); }
    for (let k = 0; k < cells; k++) {
      let n = Math.min(occ[k], perCell);
      if (n <= 0) continue;
      const pos = (k + 0.5) / 3;
      const bake = Math.min(BAKE_STEPS - 1, Math.floor((pos / OVEN_SLOTS) * BAKE_STEPS));
      const col = finale || (L.goldstrasse && bake > 6) ? goldCol : bakeCols[bake];
      for (let slot = 0; slot < perCell && n > 0; slot++, n--) {
        const f = Math.floor(slot / (lanes * rows)), l = Math.floor(slot / rows) % lanes, r = slot % rows;
        put(BELT.oven0 + pos * slotW, BELT.y + f * BELT.floorH + 0.01, BELT.z - l * BELT.laneGap - 0.06 + r * 0.06, col, k * 1.3);
      }
    }
    // baked cookies waiting at the belt end
    const out = Math.min(s.exit, 30);
    for (let i = 0; i < out; i++) put(BELT.oven1 + 0.1 + (i % 5) * 0.06, BELT.y + 0.01 + Math.floor(i / 15) * 0.015, BELT.z - 0.06 + (Math.floor(i / 5) % 3) * 0.06, baked, i);
    // falling: off the belt end, through the funnel into the jar – the taler comes on landing
    let fallN = 0;
    for (const [land, n] of s.falling) {
      const k = clamp(1 - (land - s.t) / FALL_TIME);
      for (let r = 0; r < Math.min(n, 3) && fallN < 90; r++, fallN++) {
        const f = (r + Math.floor(land * 7)) % floors;
        const y0 = BELT.y + f * BELT.floorH;
        const x = BELT.x1 + (JAR.x - BELT.x1) * Math.min(1, k * 1.6) + (r - 1) * 0.03;
        const yTop = Math.max(0.12, pile.position.y + pile.scale.y / 2);
        const y = y0 + 0.02 - (y0 - yTop) * k * k;
        put(x, y, JAR.z + (r - 1) * 0.05, finale ? goldCol : baked, land * 9 + r, k * 6);
      }
    }
    // the pile in the jar
    const frac = clamp(s.baked / GOAL);
    const pileH = s.baked > 0 ? 0.03 + Math.sqrt(frac) * (JAR.h - 0.1) : 0.001;
    pile.scale.y = pileH; pile.position.set(JAR.x, pileH / 2 + 0.04, JAR.z); pile.visible = s.baked > 0;
    for (let i = 0; i < Math.min(s.baked, 40); i++) { const a = i * 2.4, rr = (i % 7) * 0.035; put(JAR.x + Math.cos(a) * rr, pileH + 0.045 + (i % 3) * 0.008, JAR.z + Math.sin(a) * rr, baked, a, (i % 5) * 0.3); }
    cookies.count = ci;
    cookies.instanceMatrix.needsUpdate = true;
    if (cookies.instanceColor) cookies.instanceColor.needsUpdate = true;

    // +N taler pops above the jar
    landT += dt;
    if (landAcc > 0 && landT > 0.2) {
      const sp = textSprite(`+${Math.round(landAcc).toLocaleString("de-DE")} 🍫`);
      sp.position.set(JAR.x + (Math.random() - 0.5) * 0.2, JAR.h + 0.7, JAR.z + 0.2);
      scene.add(sp); pops.push({ sp, life: 0 });
      landAcc = 0; landT = 0;
      while (pops.length > 10) { const p = pops.shift(); scene.remove(p.sp); p.sp.material.map.dispose(); p.sp.material.dispose(); }
    }
    for (let i = pops.length - 1; i >= 0; i--) {
      const p = pops[i]; p.life += dt; p.sp.position.y += dt * 0.35; p.sp.material.opacity = 1 - p.life / 1.2;
      if (p.life > 1.2) { scene.remove(p.sp); p.sp.material.map.dispose(); p.sp.material.dispose(); pops.splice(i, 1); }
    }
    // finale fireworks
    if (finaleT >= 0) { finaleT += dt; if (Math.random() < dt * 5) burst((Math.random() - 0.5) * 6, 2.2 + Math.random(), -2 + Math.random(), 50, null, 2.6); }
    for (let i = sparkData.length - 1; i >= 0; i--) { const p = sparkData[i]; p.life += dt; if (p.life > p.max) { sparkData.splice(i, 1); continue; } p.v.y -= 2.2 * dt; p.p.addScaledVector(p.v, dt); }
    const pos = new Float32Array(sparkData.length * 3), col = new Float32Array(sparkData.length * 3);
    sparkData.forEach((p, i) => { pos.set([p.p.x, p.p.y, p.p.z], i * 3); const a = 1 - p.life / p.max; col.set([p.c.r * a, p.c.g * a, p.c.b * a], i * 3); });
    sparks.geometry.setAttribute("position", new THREE.BufferAttribute(pos, 3));
    sparks.geometry.setAttribute("color", new THREE.BufferAttribute(col, 3));

    gl.render(scene, camera);
  }

  resize();
  buildRoom(1);
  return {
    frame, resize, onEvents, hit, setHover,
    startFinale() { if (finaleT < 0) finaleT = 0; },
    isDragging: () => Boolean(drag && drag.moved > 6),
    dispose() {
      window.removeEventListener("keydown", kd); window.removeEventListener("keyup", ku);
      window.removeEventListener("pointermove", pm); window.removeEventListener("pointerup", pu);
      gl.dispose();
    },
  };
}

export function fmt(n) {
  return Math.round(n).toLocaleString("de-DE");
}
