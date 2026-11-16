// Santa's Cookie Crisis – 3D first-person world (three.js + Blender assets from
// tools/model-cookie-crisis-v1.py). You are the elf: walk out of the log-cabin bakery to the
// 25 t dough mountain, grab dough with your hands, carry it to the workbench, and so on.
// The renderer reads the simulation state and never changes it; actions go through `perform`.
import * as THREE from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
import { clone as cloneSkinned } from "three/examples/jsm/utils/SkeletonUtils.js";
import { FALL_TIME, GOAL, OVEN_SLOTS, derive, phaseOf } from "./sim.js";

const ASSETS = "/assets/cookie/";
// The production line sits inside the bakery; LINE is its origin in world space.
const LINE = new THREE.Vector3(-1, 0, -1);
const BENCH_Y = 0.9;
const BELT = { y: 1.18, z: -0.95, x0: -2.3, oven0: -1.2, oven1: 1.2, x1: 1.62, floorH: 0.75, laneGap: 0.24 };
const JAR = { x: 1.95, z: -0.95, r: 0.32, h: 0.95 };
const MOUNTAIN = new THREE.Vector3(2.5, 0, 18);
const BAKE_STEPS = 10;
const MAX_COOKIES = 4500;
const REACH = 3.2;
const EYE = 1.6;

// Places the elf walks to for an action (world x, z, yaw) and where the action can be done.
const SPOTS = {
  mountain: { x: 2.5, z: 12.6, yaw: Math.PI, outside: true },
  bench: { x: -0.6, z: 0.1, yaw: 0, outside: false },
  tray: { x: -2.1, z: 0.1, yaw: 0, outside: false },
};
const ACTION_SPOT = { take: "mountain", deliver: "bench", roll: "bench", cut: "bench", load: "tray" };
const LABELS = { take: "Teig greifen", deliver: "Teig ablegen", roll: "Ausrollen", cut: "Ausstechen", load: "Blech aufs Band" };

const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const ease = (t) => Math.sin(Math.PI * clamp(t));
const lw = (x, y, z) => new THREE.Vector3(LINE.x + x, LINE.y + y, LINE.z + z); // line → world

function starShape(r, inner = 0.5, points = 5) {
  const s = new THREE.Shape();
  for (let i = 0; i < points * 2; i++) {
    const rad = i % 2 ? r * inner : r, a = -Math.PI / 2 + (i * Math.PI) / points;
    if (i) s.lineTo(Math.cos(a) * rad, Math.sin(a) * rad); else s.moveTo(Math.cos(a) * rad, Math.sin(a) * rad);
  }
  s.closePath();
  return s;
}

function textSprite(text, color = "#ffd23f", w = 0.5) {
  const cv = document.createElement("canvas");
  cv.width = 320; cv.height = 96;
  const c = cv.getContext("2d");
  c.font = "bold 56px sans-serif"; c.textAlign = "center"; c.textBaseline = "middle";
  c.lineWidth = 10; c.strokeStyle = "rgba(60,30,0,.85)"; c.strokeText(text, 160, 48);
  c.fillStyle = color; c.fillText(text, 160, 48);
  const tex = new THREE.CanvasTexture(cv); tex.colorSpace = THREE.SRGBColorSpace;
  const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, transparent: true, depthTest: false }));
  sp.scale.set(w, w * 0.3, 1); sp.renderOrder = 10;
  return sp;
}

// Solid things you cannot walk through (x0, z0, x1, z1) in world space.
const WALLS = [
  [-7.3, -6.3, 7.3, -5.7], [-7.3, -6.3, -6.7, 4.3], [6.7, -6.3, 7.3, 4.3], [-7.3, 3.7, 1.6, 4.3], [3.4, 3.7, 7.3, 4.3],
  [-2.8, -1.6, 0.8, -0.4],        // workbench
  [-3.5, -3.0, 0.8, -1.65],        // belt and oven
  [0.55, -2.4, 1.4, -1.5],         // jar
  [-1.45, 5.5, -1.15, 14.2], [4.45, 5.5, 4.75, 14.2], // fence
];

export function createRenderer(canvas, { perform, onStep } = {}) {
  const gl = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: "high-performance" });
  gl.shadowMap.enabled = true;
  gl.shadowMap.type = THREE.PCFSoftShadowMap;
  gl.toneMapping = THREE.ACESFilmicToneMapping;
  gl.toneMappingExposure = 1.15;
  const scene = new THREE.Scene();
  scene.background = new THREE.Color("#0b1430");
  scene.fog = new THREE.FogExp2("#16223e", 0.022);
  const camera = new THREE.PerspectiveCamera(70, 16 / 9, 0.03, 160);
  scene.add(camera);
  const player = { x: 0.2, z: 1.2, yaw: 0.5, pitch: -0.2 };

  // ------------------------------------------------------------ sky, moon, stars, lights
  const stars = new THREE.BufferGeometry();
  const starPos = new Float32Array(1500 * 3);
  for (let i = 0; i < 1500; i++) { const a = Math.random() * Math.PI * 2, e = Math.random() * 1.2 + 0.15, r = 120; starPos.set([Math.cos(a) * Math.cos(e) * r, Math.sin(e) * r, Math.sin(a) * Math.cos(e) * r], i * 3); }
  stars.setAttribute("position", new THREE.BufferAttribute(starPos, 3));
  scene.add(new THREE.Points(stars, new THREE.PointsMaterial({ color: "#ffffff", size: 0.6, sizeAttenuation: true, fog: false })));
  const moon = new THREE.Mesh(new THREE.SphereGeometry(4, 24, 16), new THREE.MeshBasicMaterial({ color: "#fff6d8", fog: false }));
  moon.position.set(-60, 70, -80); scene.add(moon);
  scene.add(new THREE.HemisphereLight("#7d93c9", "#2a1d18", 0.55));
  const moonLight = new THREE.DirectionalLight("#b9c8ff", 0.9);
  moonLight.position.set(-20, 30, 20); moonLight.castShadow = true; moonLight.shadow.mapSize.set(2048, 2048);
  Object.assign(moonLight.shadow.camera, { left: -20, right: 20, top: 26, bottom: -12, near: 1, far: 80 });
  moonLight.shadow.bias = -0.0005;
  scene.add(moonLight);
  const inside = [new THREE.PointLight("#ffbf6e", 2.6, 9, 1.4), new THREE.PointLight("#ffbf6e", 1.8, 8, 1.4)];
  inside[0].position.set(-1, 3.4, 0.5); inside[1].position.set(4, 3.2, -3);
  inside.forEach((l) => scene.add(l));
  const ovenLight = new THREE.PointLight("#ff8a3a", 3, 5, 1.6); ovenLight.position.copy(lw(0, BELT.y + 0.1, BELT.z + 0.5)); scene.add(ovenLight);
  for (const [x, z] of [[0.6, 5.2], [4.4, 5.2], [-1.0, 10], [4.4, 12], [1.5, 15.5]]) { const l = new THREE.PointLight("#ffc46a", 2.2, 7, 1.6); l.position.set(x, 2.35, z); scene.add(l); }
  const mountainLight = new THREE.PointLight("#ffd9a0", 1.5, 14, 1.4); mountainLight.position.set(2.5, 4.5, 13); scene.add(mountainLight);

  // falling snow around the player
  const snowCount = 1400;
  const snowGeo = new THREE.BufferGeometry();
  const snowPos = new Float32Array(snowCount * 3);
  for (let i = 0; i < snowCount; i++) snowPos.set([(Math.random() - 0.5) * 40, Math.random() * 14, (Math.random() - 0.5) * 40], i * 3);
  snowGeo.setAttribute("position", new THREE.BufferAttribute(snowPos, 3));
  const snow = new THREE.Points(snowGeo, new THREE.PointsMaterial({ color: "#ffffff", size: 0.05, transparent: true, opacity: 0.85, depthWrite: false }));
  snow.frustumCulled = false; scene.add(snow);

  // ------------------------------------------------------------ asset loading
  const loader = new GLTFLoader();
  const nodes = {};
  let loaded = false;
  const ready = Promise.all(["world", "mountain", "props", "machines", "elf-arm", "parts", "interior"].map((name) => loader.loadAsync(`${ASSETS}${name}.glb`).then((g) => {
    g.scene.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
    for (const child of [...g.scene.children]) nodes[child.name] = child;
    if (name === "world" || name === "mountain") scene.add(g.scene);
  }))).then(() => { setup(); loaded = true; });

  const clone = (name) => { const n = nodes[name]; if (!n) return new THREE.Group(); const c = n.clone(true); c.position.set(0, 0, 0); c.rotation.set(0, 0, 0); return c; };
  const M = {
    steel: new THREE.MeshStandardMaterial({ color: "#a9b2bc", metalness: 0.7, roughness: 0.35 }),
    rubber: new THREE.MeshStandardMaterial({ color: "#1d1d1d", roughness: 0.7 }),
    gold: new THREE.MeshStandardMaterial({ color: "#ffcf4a", metalness: 0.8, roughness: 0.25, emissive: "#3a2600" }),
    glass: new THREE.MeshPhysicalMaterial({ color: "#d8ecff", transparent: true, opacity: 0.2, roughness: 0.05, side: THREE.DoubleSide, depthWrite: false }),
    glow: new THREE.MeshStandardMaterial({ color: "#ff8a2a", emissive: "#ff6a00", emissiveIntensity: 1.6 }),
    dough: new THREE.MeshStandardMaterial({ color: "#f2dcae", roughness: 0.85 }),
    pile: new THREE.MeshStandardMaterial({ color: "#c98a3d", roughness: 0.9 }),
    red: new THREE.MeshStandardMaterial({ color: "#a3121c", roughness: 0.6 }),
    board: new THREE.MeshStandardMaterial({ color: "#c08a52", roughness: 0.7 }),
  };
  const box = (w, h, d, mat) => { const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat); m.castShadow = true; m.receiveShadow = true; return m; };
  const at = (o, v) => { o.position.copy(v); return o; };

  // ------------------------------------------------------------ scene pieces (built after loading)
  const line = new THREE.Group(); line.position.copy(LINE); scene.add(line);
  const parts = {};
  const machines = {};
  const beltGroup = new THREE.Group(); line.add(beltGroup);
  let beltKey = "";
  const beltStripes = [];
  const balls = [];
  let mountainNode = null, armL = null, armR = null, carried = null, bucket = null, barrow = null, pipe = null, pipeBlobs = null;
  let pipeCurve = null;

  function setup() {
    mountainNode = nodes.Mountain;
    for (const n of ["Mountain", "Chunks", "MountainSign"]) if (nodes[n]) nodes[n].position.add(MOUNTAIN);
    const bench = clone("Workbench"); line.add(bench);
    const shelf = clone("Shelf"); shelf.position.set(-0.5, 1.75, -1.9); shelf.visible = false; line.add(shelf);
    for (const x of [-1.55, 1.45]) { const c = clone("Candle"); c.position.set(x, BENCH_Y, 0.38); line.add(c); }
    const stool = clone("Stool"); stool.position.set(2.6, 0, 0.6); line.add(stool);
    const deco = (name, x, y, z, ry = 0, sc = 1) => { const n = clone(name); n.position.set(x, y, z); n.rotation.y = ry; n.scale.setScalar(sc); scene.add(n); return n; };
    deco("ChristmasTree", 5.3, 0, 1.9); deco("Presents", 5.3, 0, 1.9);
    deco("Rug", -0.9, 0, 1.4, 0, 1.2);
    for (const [x, z] of [[-3.5, 1], [0.5, 1.6], [4, -2.5], [-4.5, -3.5]]) deco("HangingLantern", x, 3.6, z);
    deco("BeamGarland", 0, 4.05, -5.75); deco("BeamGarland", 0, 4.05, 3.75, Math.PI);
    deco("WallShelf", 6.75, 2.0, -3, -Math.PI / 2); deco("WallShelf", -6.75, 2.0, 1.5, Math.PI / 2);
    deco("Stockings", 4.6, 2.3, -5.78);
    deco("FlourSack", -3.3, 0, 0.6, 0.4); deco("FlourSack", -3.75, 0, 0.2, 1.2, 0.85);
    const treeLight = new THREE.PointLight("#ffd27a", 1.6, 5, 1.6); treeLight.position.set(5.3, 1.6, 1.9); scene.add(treeLight); parts.treeLight = treeLight;
    // quest arrow: a bouncing golden arrow above the next thing to do
    const arrow = new THREE.Group();
    const arrowMat = new THREE.MeshStandardMaterial({ color: "#ffd23f", emissive: "#ffb000", emissiveIntensity: 1.4 });
    const head = new THREE.Mesh(new THREE.ConeGeometry(0.12, 0.22, 16), arrowMat); head.rotation.x = Math.PI; arrow.add(head);
    const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.04, 0.22, 10), arrowMat); shaft.position.y = 0.2; arrow.add(shaft);
    arrow.visible = false; scene.add(arrow); parts.arrow = arrow;
    parts.flyBlob = clone("DoughBlob"); parts.flyBlob.visible = false; scene.add(parts.flyBlob);
    parts.pin = clone("RollingPin"); line.add(parts.pin);
    parts.cutter = clone("StarCutter"); line.add(parts.cutter);
    parts.tray = clone("Tray"); line.add(parts.tray);
    parts.board = box(0.55, 0.025, 0.45, M.board); parts.board.position.set(0.92, BENCH_Y + 0.012, 0.02); line.add(parts.board);
    parts.sheet = box(0.7, 0.012, 0.4, M.dough); parts.sheet.position.set(-0.25, BENCH_Y + 0.007, 0.02); line.add(parts.sheet);
    parts.rolling = new THREE.Mesh(new THREE.SphereGeometry(0.09, 20, 14), M.dough); line.add(parts.rolling);
    for (let i = 0; i < 6; i++) { const b = clone("DoughBlob"); b.scale.setScalar(0.85); b.position.set(0.78 + (i % 3) * 0.13, BENCH_Y + 0.07, -0.08 + Math.floor(i / 3) * 0.16); balls.push(b); line.add(b); }
    // candle flames
    parts.flames = [-1.55, 1.45].map((x) => { const f = new THREE.Mesh(new THREE.SphereGeometry(0.018, 10, 8), new THREE.MeshBasicMaterial({ color: "#ffcf5a" })); f.scale.y = 1.8; f.position.set(x, BENCH_Y + 0.19, 0.38); line.add(f); return f; });
    // chute: funnel + glass jar + pile
    const funnel = new THREE.Mesh(new THREE.CylinderGeometry(0.36, 0.09, 0.3, 28, 1, true), new THREE.MeshStandardMaterial({ color: "#a0703f", side: THREE.DoubleSide, roughness: 0.5, metalness: 0.3 }));
    funnel.position.set(JAR.x, JAR.h + 0.32, JAR.z); line.add(funnel); parts.funnel = funnel;
    const jar = new THREE.Mesh(new THREE.CylinderGeometry(JAR.r, JAR.r, JAR.h, 36, 1, true), M.glass); jar.position.set(JAR.x, JAR.h / 2, JAR.z); line.add(jar);
    for (const y of [0.02, JAR.h]) { const ring = new THREE.Mesh(new THREE.CylinderGeometry(JAR.r + 0.02, JAR.r + 0.02, 0.04, 36), M.red); ring.position.set(JAR.x, y, JAR.z); line.add(ring); }
    parts.pile = new THREE.Mesh(new THREE.CylinderGeometry(JAR.r - 0.02, JAR.r - 0.02, 1, 30), M.pile); line.add(parts.pile);
    // machines from machines.glb, placed along the line
    const place = (id, node, x, y, z, ry = 0, s = 1) => { const n = clone(node); n.position.set(x, y, z); n.rotation.y = ry; n.scale.setScalar(s); n.visible = false; line.add(n); (machines[id] ||= []).push(n); return n; };
    place("portionierer", "HopperBody", 0.95, 1.7, 0.02);
    place("extruder", "Extruder", 0.95, 1.75, -0.15, 0, 0.75);
    place("walze", "RollerFrame", 0.15, BENCH_Y, 0.02);
    parts.rollers = [0.05, 0.15].map((y) => place("walze", "Roller", 0.15, BENCH_Y + y, 0.02));
    parts.flywheel = place("walze", "Flywheel", 0.15, BENCH_Y + 0.2, 0.4);
    place("stanzpresse", "PressFrame", -0.45, BENCH_Y, -0.05);
    parts.stamp = place("stanzpresse", "PressStamp", -0.45, BENCH_Y + 0.62, -0.05);
    parts.lever = place("stanzpresse", "PressLever", -0.17, BENCH_Y + 0.6, -0.05);
    place("steuerung", "ControlPanel", -2.75, 0, 0.3, Math.PI / 2);
    place("platzierung", "ArmBase", -1.85, BELT.y - 0.05, BELT.z + 0.45);
    parts.armUpper = place("platzierung", "ArmUpper", -1.85, BELT.y + 0.25, BELT.z + 0.45);
    parts.claw = place("platzierung", "ArmClaw", -1.85, BELT.y + 0.35, BELT.z + 0.05);
    place("portale", "Portal", -2.35, BELT.y + 0.3, BELT.z, Math.PI / 2);
    place("rentier", "Generator", -2.9, 0, -2.6, 0, 1.2);
    place("motor", "Gear", BELT.x0 + 0.1, BELT.y - 0.2, BELT.z + 0.3);
    place("syncband", "Gear", BELT.oven1 + 0.2, BELT.y - 0.25, BELT.z + 0.25);
    place("hochleistung", "Gear", 0.55, BENCH_Y + 0.15, 0.36, 0, 0.7);
    // the pump outside at the mountain, with a pipe into the bakery down to the hopper
    const pump = clone("Pump"); pump.position.set(5.6, 0, 12.4); pump.rotation.y = -Math.PI / 2; pump.visible = false; scene.add(pump); (machines.portionierer ||= []).push(pump);
    pipeCurve = new THREE.CatmullRomCurve3([new THREE.Vector3(4.5, 0.3, 14.5), new THREE.Vector3(5.6, 0.6, 12.6), new THREE.Vector3(5.6, 0.9, 6), new THREE.Vector3(5.6, 3.3, 4.6), new THREE.Vector3(5.6, 3.6, 3), new THREE.Vector3(0, 3.6, -1), lw(0.95, 2.1, 0.02)], false, "catmullrom", 0.1);
    pipe = new THREE.Mesh(new THREE.TubeGeometry(pipeCurve, 160, 0.07, 10), M.steel); pipe.castShadow = true; pipe.visible = false; scene.add(pipe);
    pipeBlobs = new THREE.InstancedMesh(new THREE.SphereGeometry(0.05, 8, 6), M.dough, 40); pipeBlobs.visible = false; scene.add(pipeBlobs);
    // the elf's arms (right as modelled, left mirrored) in front of the camera
    armR = cloneSkinned(nodes.ElfRig); armL = cloneSkinned(nodes.ElfRig);
    armL.scale.set(-0.85, 0.85, 0.85); armR.scale.setScalar(0.85);
    for (const a of [armL, armR]) {
      a.traverse((o) => { if (o.isMesh) { o.castShadow = false; o.renderOrder = 5; o.frustumCulled = false; } });
      a.userData.bones = {};
      a.traverse((o) => { if (o.isBone) { a.userData.bones[o.name] = o; o.userData.rest = o.quaternion.clone(); } });
      camera.add(a);
    }
    carried = clone("DoughBlob"); carried.visible = false; camera.add(carried);
    bucket = clone("Bucket"); bucket.visible = false; bucket.scale.setScalar(0.55); camera.add(bucket);
    barrow = clone("Wheelbarrow"); barrow.visible = false; barrow.scale.setScalar(0.85); camera.add(barrow);
    parts.barrowDough = clone("DoughBlob"); parts.barrowDough.scale.set(3.2, 1.4, 4); parts.barrowDough.position.set(0, 0.62, 0); barrow.add(parts.barrowDough);
    parts.bucketDough = clone("DoughBlob"); parts.bucketDough.scale.set(1.6, 0.8, 1.6); parts.bucketDough.position.set(0, 0.3, 0); bucket.add(parts.bucketDough);
    // hit targets
    targets.push(...[nodes.Mountain, nodes.Chunks].filter(Boolean).map((n) => { n.userData.action = "take"; return n; }));
    for (const [id, pos, size] of [["deliver", [0.92, BENCH_Y + 0.1, 0.02], [0.6, 0.25, 0.55]], ["roll", [0.15, BENCH_Y + 0.08, 0.02], [0.55, 0.22, 0.5]], ["cut", [-0.45, BENCH_Y + 0.08, 0.02], [0.5, 0.22, 0.5]], ["load", [-1.2, BENCH_Y + 0.06, 0.02], [0.7, 0.2, 0.5]]]) {
      const m = new THREE.Mesh(new THREE.BoxGeometry(...size), new THREE.MeshBasicMaterial({ visible: false })); m.position.set(...pos); m.userData.action = id; line.add(m); targets.push(m);
    }
  }

  function buildBelts(d, L, phase) {
    const floors = Math.min(3, d.floors), lanes = Math.min(4, d.lanes);
    const key = `${floors}:${lanes}:${phase >= 4}:${L.turboofen || 0}:${L.goldstrasse || 0}:${L.schwebend || 0}`;
    if (key === beltKey || !loaded) return;
    beltKey = key;
    beltGroup.clear(); beltStripes.length = 0;
    const len = BELT.x1 - BELT.x0, ovenLen = BELT.oven1 - BELT.oven0;
    const beltMat = L.goldstrasse ? M.gold : M.rubber;
    for (let f = 0; f < floors; f++) {
      const y = BELT.y + f * BELT.floorH;
      for (let l = 0; l < lanes; l++) {
        const z = BELT.z - l * BELT.laneGap;
        const floating = f > 0 && L.schwebend;
        beltGroup.add(at(box(len, 0.03, 0.2, floating ? new THREE.MeshStandardMaterial({ color: "#5b4bb0", emissive: "#2a1d70", emissiveIntensity: 0.6 }) : beltMat), new THREE.Vector3(BELT.x0 + len / 2, y - 0.015, z)));
        for (let k = 0; k < 24; k++) { const st = box(0.012, 0.004, 0.2, M.steel); st.position.set(BELT.x0 + (k / 24) * len, y + 0.001, z); st.userData.k = k; beltStripes.push(st); beltGroup.add(st); }
        if (!floating) for (let x = BELT.x0 + 0.2; x < BELT.x1; x += 0.8) beltGroup.add(at(box(0.05, y - 0.03, 0.05, M.steel), new THREE.Vector3(x, (y - 0.03) / 2, z)));
      }
      // oven: brick modules from props.glb along the belt, a glowing back and a glass front
      const depth = 0.32 + (lanes - 1) * BELT.laneGap, zc = BELT.z - ((lanes - 1) * BELT.laneGap) / 2;
      for (let i = 0; i < 3; i++) {
        const mod = clone("OvenModule"); mod.scale.set(ovenLen / 3, 1, depth / 0.5); mod.position.set(BELT.oven0 + ovenLen / 6 + (i * ovenLen) / 3, y, zc);
        if (L.turboofen) mod.traverse((o) => { if (o.isMesh && o.material.name === "Oven brick") { o.material = o.material.clone(); o.material.color.set("#8a1d12"); } });
        beltGroup.add(mod);
      }
      const back = new THREE.Mesh(new THREE.PlaneGeometry(ovenLen, 0.36), M.glow); back.position.set(0, y + 0.2, zc - depth / 2 + 0.04); beltGroup.add(back);
      const glass = new THREE.Mesh(new THREE.PlaneGeometry(ovenLen, 0.42), M.glass); glass.position.set(0, y + 0.22, zc + depth / 2 + 0.02); beltGroup.add(glass);
    }
  }

  // Finger curl: 0 = open hand, 1 = fist. The thumb has its own amount.
  const qTmp = new THREE.Quaternion(), xAxis = new THREE.Vector3(1, 0, 0), zAxis = new THREE.Vector3(0, 0, 1);
  function grip(arm, curl, thumb = curl, spread = 0) {
    const b = arm?.userData.bones;
    if (!b) return;
    for (const f of ["index", "middle", "ring", "little"]) for (let j = 1; j <= 3; j++) {
      const bone = b[`${f}${j}`]; if (!bone) continue;
      qTmp.setFromAxisAngle(xAxis, -curl * (j === 1 ? 1.1 : j === 2 ? 1.3 : 0.9));
      bone.quaternion.copy(bone.userData.rest).multiply(qTmp);
      if (j === 1 && spread) bone.quaternion.multiply(qTmp.setFromAxisAngle(zAxis, spread * ({ index: 0.12, middle: 0.03, ring: -0.06, little: -0.15 })[f]));
    }
    for (let j = 1; j <= 3; j++) { const bone = b[`thumb${j}`]; if (!bone) continue; qTmp.setFromAxisAngle(xAxis, -thumb * (j === 1 ? 0.5 : 0.8)); bone.quaternion.copy(bone.userData.rest).multiply(qTmp); }
  }

  // ------------------------------------------------------------ cookies (instanced)
  const starGeo = new THREE.ExtrudeGeometry(starShape(0.038, 0.52), { depth: 0.012, bevelEnabled: true, bevelThickness: 0.004, bevelSize: 0.004, bevelSegments: 2 });
  starGeo.rotateX(-Math.PI / 2);
  const cookies = new THREE.InstancedMesh(starGeo, new THREE.MeshStandardMaterial({ roughness: 0.75 }), MAX_COOKIES);
  cookies.castShadow = true; cookies.frustumCulled = false; cookies.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
  line.add(cookies);
  const bakeCols = Array.from({ length: BAKE_STEPS }, (_, i) => new THREE.Color().lerpColors(new THREE.Color("#f6e2b8"), new THREE.Color("#c27a2c"), i / (BAKE_STEPS - 1)));
  const goldCol = new THREE.Color("#ffd84a");
  const tmp = new THREE.Object3D();
  let ci = 0;
  const put = (x, y, z, col, rot = 0, tilt = 0) => {
    if (ci >= MAX_COOKIES) return;
    tmp.position.set(x, y, z); tmp.rotation.set(tilt, rot, 0); tmp.updateMatrix();
    cookies.setMatrixAt(ci, tmp.matrix); cookies.setColorAt(ci, col); ci++;
  };

  // ------------------------------------------------------------ pops, sparks, hover
  const pops = [];
  const sparkData = [];
  const sparks = new THREE.Points(new THREE.BufferGeometry(), new THREE.PointsMaterial({ size: 0.05, vertexColors: true, transparent: true, depthWrite: false }));
  sparks.frustumCulled = false; scene.add(sparks);
  const burst = (p, n, color, speed = 1.6) => { for (let i = 0; i < n; i++) sparkData.push({ p: p.clone(), v: new THREE.Vector3((Math.random() - 0.5) * speed, Math.random() * speed * 1.2, (Math.random() - 0.5) * speed), life: 0, max: 1 + Math.random() * 0.6, c: new THREE.Color(color || `hsl(${Math.random() * 360},90%,65%)`) }); };

  // ------------------------------------------------------------ input: pointer lock, look, walk
  const keys = new Set();
  let locked = false, drag = null, auto = null;
  const targets = [];
  const raycaster = new THREE.Raycaster();
  raycaster.far = 12;
  const onKey = (e, down) => {
    if (!locked && document.activeElement !== canvas) return;
    const k = e.key.toLowerCase();
    if (["w", "a", "s", "d", "arrowup", "arrowdown", "arrowleft", "arrowright", "shift"].includes(k)) { e.preventDefault(); if (down) { keys.add(k); auto = null; } else keys.delete(k); }
  };
  const kd = (e) => onKey(e, true), ku = (e) => onKey(e, false);
  window.addEventListener("keydown", kd); window.addEventListener("keyup", ku);
  const lockChange = () => { locked = document.pointerLockElement === canvas; if (!locked) keys.clear(); };
  document.addEventListener("pointerlockchange", lockChange);
  const mm = (e) => {
    if (locked) { player.yaw -= e.movementX * 0.0022; player.pitch = clamp(player.pitch - e.movementY * 0.0022, -1.35, 1.2); return; }
    if (drag && e.buttons & 1) { const dx = e.clientX - drag.x, dy = e.clientY - drag.y; drag.moved += Math.abs(dx) + Math.abs(dy); drag.x = e.clientX; drag.y = e.clientY; player.yaw -= dx * 0.005; player.pitch = clamp(player.pitch - dy * 0.004, -1.35, 1.2); }
  };
  const pd = (e) => { drag = { x: e.clientX, y: e.clientY, moved: 0 }; };
  const pu = () => { setTimeout(() => { drag = null; }, 0); };
  canvas.addEventListener("pointerdown", pd); window.addEventListener("pointermove", mm); window.addEventListener("pointerup", pu);

  function lookTarget(px, py) {
    if (!loaded) return null;
    const rect = canvas.getBoundingClientRect();
    const ndc = locked || px == null ? new THREE.Vector2(0, 0) : new THREE.Vector2((px / rect.width) * 2 - 1, -(py / rect.height) * 2 + 1);
    raycaster.setFromCamera(ndc, camera);
    const hit = raycaster.intersectObjects(targets, true)[0];
    if (!hit) return null;
    let o = hit.object; while (o && !o.userData.action) o = o.parent;
    if (!o) return null;
    return { id: o.userData.action, label: LABELS[o.userData.action], near: hit.distance <= REACH, distance: hit.distance };
  }

  // ------------------------------------------------------------ auto walk (buttons, touch, space bar)
  const insideHouse = (x, z) => x > -7 && x < 7 && z > -6 && z < 4;
  function route(to) {
    const spot = SPOTS[to];
    const pts = [];
    const nowIn = insideHouse(player.x, player.z);
    if (nowIn && spot.outside) pts.push({ x: 2.5, z: 2.8 }, { x: 2.5, z: 5.6 });
    if (!nowIn && !spot.outside) pts.push({ x: 2.5, z: 5.6 }, { x: 2.5, z: 2.8 });
    pts.push({ x: spot.x, z: spot.z, yaw: spot.yaw });
    return pts;
  }
  function request(action) {
    const spot = SPOTS[ACTION_SPOT[action]];
    const dx = player.x - spot.x, dz = player.z - spot.z;
    if (Math.hypot(dx, dz) < 1.3) { perform?.(action); return; }
    auto = { pts: route(ACTION_SPOT[action]), then: action };
  }

  function interact(px, py) {
    if (drag && drag.moved > 6) return false;
    const t = lookTarget(px, py);
    if (!t) return false;
    if (t.near) perform?.(t.id); else request(t.id);
    return true;
  }

  // ------------------------------------------------------------ events
  const anim = { roll: 0, rolled: 0, cut: 0, press: 0, load: 0, portion: 0, take: 0, crank: 0, push: 0, blocked: 0 };
  let landAcc = 0, landT = 0, finaleT = -1, stepT = 0, fly = null, quest = null;
  function onEvents(events) {
    for (const e of events) {
      if (e.type in anim) anim[e.type] = 1;
      if (e.type === "rolled") anim.roll = 1;
      if (e.type === "take" && mountainNode) { burst(new THREE.Vector3(player.x, 1.2, player.z + 0.8), 14, "#fff6e0", 0.8); fly = { t: 0, from: new THREE.Vector3(player.x - Math.sin(player.yaw) * 1.6, 1.0, player.z - Math.cos(player.yaw) * 1.6) }; }
      if (e.type === "cut" || e.type === "press") burst(lw(-0.45, BENCH_Y + 0.05, 0.02), 8, "#ffffff", 0.5);
      if (e.type === "land") landAcc += e.n;
      if (e.type === "machine" || e.type === "buy") burst(new THREE.Vector3(player.x, 1.8, player.z), 40, "#ffd23f", 2);
      if (e.type === "finale") finaleT = 0;
    }
  }

  function resize() {
    const rect = canvas.getBoundingClientRect();
    gl.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
    gl.setSize(Math.max(1, rect.width), Math.max(1, rect.height), false);
    camera.aspect = Math.max(0.5, rect.width / Math.max(1, rect.height));
    camera.fov = camera.aspect < 1 ? 84 : 70;
    camera.updateProjectionMatrix();
  }

  function collide(nx, nz) {
    const r = 0.3;
    const blocked = (x, z) => WALLS.some(([x0, z0, x1, z1]) => x > x0 - r && x < x1 + r && z > z0 - r && z < z1 + r) || Math.hypot((x - MOUNTAIN.x) / 4.4, (z - MOUNTAIN.z) / 4.1) < 1 * mountainScale || Math.hypot(x, z - 4) > 34;
    let x = player.x, z = player.z;
    if (!blocked(nx, z)) x = nx;
    if (!blocked(x, nz)) z = nz;
    return [x, z];
  }

  // ------------------------------------------------------------ frame
  let last = performance.now(), mountainScale = 1;
  function frame(s, now = performance.now()) {
    const dt = Math.min(0.05, (now - last) / 1000); last = now;
    const t = now / 1000;
    if (!loaded) { gl.render(scene, camera); return; }
    const d = derive(s.levels), L = s.levels, phase = phaseOf(s);
    buildBelts(d, L, phase);
    for (const k in anim) anim[k] = Math.max(0, anim[k] - dt * 2.4);

    // ---- movement
    let fx = 0, fz = 0;
    if (keys.has("w") || keys.has("arrowup")) fz -= 1;
    if (keys.has("s") || keys.has("arrowdown")) fz += 1;
    if (keys.has("a") || keys.has("arrowleft")) fx -= 1;
    if (keys.has("d") || keys.has("arrowright")) fx += 1;
    const run = keys.has("shift") ? 1.6 : 1;
    let moving = false;
    if (fx || fz) {
      const sp = 3.6 * run * dt, sin = Math.sin(player.yaw), cos = Math.cos(player.yaw);
      [player.x, player.z] = collide(player.x + (fx * cos + fz * sin) * sp, player.z + (-fx * sin + fz * cos) * sp);
      moving = true;
    } else if (auto) {
      const p = auto.pts[0];
      const dx = p.x - player.x, dz = p.z - player.z, dist = Math.hypot(dx, dz);
      const want = Math.atan2(-dx, -dz);
      let dy = ((want - player.yaw + Math.PI * 3) % (Math.PI * 2)) - Math.PI;
      player.yaw += dy * Math.min(1, dt * 7);
      player.pitch += (-0.15 - player.pitch) * Math.min(1, dt * 4);
      if (dist < 0.15) {
        auto.pts.shift();
        if (!auto.pts.length) { if (p.yaw != null) player.yaw = p.yaw; player.pitch = -0.45; const then = auto.then; auto = null; perform?.(then); }
      } else { const sp = Math.min(dist, 4.2 * dt); player.x += (dx / dist) * sp; player.z += (dz / dist) * sp; moving = true; }
    }
    if (moving) { stepT += dt; if (stepT > 0.42) { stepT = 0; onStep?.(!insideHouse(player.x, player.z)); } }
    const bob = moving ? Math.sin(t * 10) * 0.025 : Math.sin(t * 1.6) * 0.004;
    camera.position.set(player.x, EYE + bob, player.z);
    camera.rotation.set(player.pitch, player.yaw, 0, "YXZ");
    // snow follows the player
    const sp = snowGeo.attributes.position;
    for (let i = 0; i < snowCount; i++) {
      let y = sp.getY(i) - dt * (0.6 + (i % 5) * 0.12);
      let x = sp.getX(i) + Math.sin(t + i) * dt * 0.15;
      if (y < 0) { y = 14; x = player.x + (Math.random() - 0.5) * 40; sp.setZ(i, player.z + (Math.random() - 0.5) * 40); }
      sp.setX(i, x); sp.setY(i, y);
    }
    sp.needsUpdate = true;

    // ---- the mountain shrinks as the dough is used
    mountainScale = 0.18 + 0.82 * Math.cbrt(s.dough / GOAL);
    if (mountainNode) { mountainNode.scale.set(mountainScale, Math.max(0.05, mountainScale), mountainScale); }
    if (nodes.Chunks) nodes.Chunks.visible = s.dough > 0;

    // ---- arms: rest, reach for the action, carry what you hold
    const restL = new THREE.Vector3(-0.21, -0.25, -0.46), restR = new THREE.Vector3(0.21, -0.25, -0.46);
    const lp = restL.clone(), rp = restR.clone();
    let rotL = 0.35, rotR = 0.35;
    const reach = (v, dx, dy, dz, k) => v.set(v.x + dx * k, v.y + dy * k, v.z + dz * k);
    const take = ease(1 - anim.take), roll = ease(1 - Math.max(anim.roll, anim.crank)), cut = ease(1 - Math.max(anim.cut, anim.press)), load = ease(1 - anim.load), put2 = ease(1 - anim.portion);
    if (take) { reach(lp, 0.06, -0.08, -0.22, take); reach(rp, -0.06, -0.08, -0.22, take); rotL = rotR = 0.35 + take * 0.6; }
    if (roll) { const sw = Math.sin(t * 16) * 0.07; reach(lp, 0.06, -0.05, -0.18 + sw, roll); reach(rp, -0.06, -0.05, -0.18 + sw, roll); rotL = rotR = 0.35 + roll * 0.5; }
    if (cut) { reach(rp, -0.08, -0.1 * cut, -0.2, cut); rotR = 0.35 + cut * 0.7; }
    if (load || put2) { const k = Math.max(load, put2); reach(lp, 0.05, 0.05, -0.25, k); reach(rp, -0.05, 0.05, -0.25, k); }
    if (s.carry > 0 && !d.walze && !L.schubkarre && !L.eimer) { reach(lp, 0.12, 0.04, -0.06, 1); reach(rp, -0.12, 0.04, -0.06, 1); }
    if (moving) { lp.y += Math.sin(t * 10) * 0.012; rp.y -= Math.sin(t * 10) * 0.012; }
    armL.position.copy(lp); armR.position.copy(rp);
    armL.rotation.set(rotL, -0.12, 0); armR.rotation.set(rotR, 0.12, 0);
    const holding = s.carry > 0;
    const handsHold = holding && !L.eimer && !L.schubkarre;
    carried.visible = handsHold;
    carried.scale.setScalar(1.25 * (0.6 + 0.4 * s.carry / d.carryCap));
    carried.position.set(0, -0.21 + Math.sin(t * 10) * (moving ? 0.008 : 0), -0.58);
    // finger poses by action
    let gL = 0.18, gR = 0.18, thL = 0.15, thR = 0.15, spr = 0.4;
    if (handsHold) { gL = gR = 0.62; thL = thR = 0.55; spr = 0; }
    if (take) { const open = take > 0.5 ? 0 : 1 - take * 2; gL = gR = 0.1 + open * 0.55; spr = 1 - open; }
    if (roll) { gL = gR = 0.95; thL = thR = 0.85; spr = 0; }
    if (cut) { gR = 1.05; thR = 0.9; }
    if (load || put2) { gL = gR = 0.45; thL = thR = 0.3; spr = 0.2; }
    if (barrow.visible || bucket.visible) { gL = gR = 0.95; thL = thR = 0.9; }
    grip(armL, gL, thL, spr); grip(armR, gR, thR, spr);
    // a dough chunk flies from the mountain into your hands
    if (fly) {
      fly.t += dt * 3;
      const target = new THREE.Vector3(0, -0.2, -0.58).applyMatrix4(camera.matrixWorld);
      parts.flyBlob.visible = fly.t < 1; parts.flyBlob.position.lerpVectors(fly.from, target, Math.min(1, fly.t)); parts.flyBlob.position.y += Math.sin(Math.min(1, fly.t) * Math.PI) * 0.4;
      parts.flyBlob.scale.setScalar(1.6); parts.flyBlob.rotation.set(fly.t * 5, fly.t * 3, 0);
      if (fly.t >= 1) fly = null;
    }
    bucket.visible = Boolean(L.eimer) && !L.schubkarre && !d.autoPortion; bucket.position.set(-0.26, -0.55, -0.45); parts.bucketDough.visible = holding;
    barrow.visible = Boolean(L.schubkarre) && !d.autoPortion && (holding || !insideHouse(player.x, player.z)); barrow.position.set(0, -1.45, -1.15); barrow.rotation.set(0.1, Math.PI, 0); parts.barrowDough.visible = holding;
    if (barrow.visible) { armL.position.set(-0.27, -0.42, -0.45); armR.position.set(0.27, -0.42, -0.45); }

    // ---- bench
    const nBalls = Math.min(6, Math.ceil(s.ball / d.sheetSize));
    balls.forEach((b, i) => { b.visible = i < nBalls && !(i === 0 && s.rollProgress > 0); });
    parts.rolling.visible = s.rollProgress > 0 && s.ball > 0;
    if (parts.rolling.visible) { const p = s.rollProgress; parts.rolling.scale.set(1 + p * 2.6, 0.7 - p * 0.55, 1 + p * 1.4); parts.rolling.position.set(0.15, BENCH_Y + 0.04 - p * 0.02, 0.02); }
    parts.sheet.visible = s.sheet > 0;
    if (parts.sheet.visible) { const k = clamp(s.sheet / (d.sheetSize * 2), 0.25, 1); parts.sheet.scale.x = k; parts.sheet.position.x = -0.6 + 0.35 * k; }
    parts.pin.visible = !d.walze && !d.autoRoll;
    if (roll) parts.pin.position.set(0.15, BENCH_Y + 0.05, 0.02 + Math.sin(t * 16) * 0.12); else parts.pin.position.set(0.3, BENCH_Y + 0.045, 0.38);
    parts.pin.rotation.set(roll ? t * 8 : 0, 0, 0);
    parts.cutter.visible = !d.pressSize && !d.autoCut;
    parts.cutter.position.set(-0.45, BENCH_Y + 0.005 + (cut ? 0.1 - cut * 0.1 : 0), cut ? 0.02 : 0.34);
    const lift = load * 0.25;
    parts.tray.position.set(-1.2, BENCH_Y + 0.01 + lift, 0.02 - lift * 2.2);
    parts.flames.forEach((f, i) => { f.scale.y = 1.8 + Math.sin(t * 13 + i) * 0.25; });
    ovenLight.intensity = 2.6 + Math.sin(t * 3) * 0.3 + (finaleT >= 0 ? 1.5 : 0);

    // ---- machines
    for (const [id, list] of Object.entries(machines)) list.forEach((n) => { n.visible = (L[id] || 0) > 0; });
    (machines.walze || []).forEach((n) => { n.visible = d.walze || d.autoRoll > 0; });
    (machines.stanzpresse || []).forEach((n) => { n.visible = d.pressSize > 0 || d.autoCut > 0; });
    const working = s.dough > 0 || s.ball > 0 || s.sheet > 0;
    (machines.motor || []).forEach((n) => { n.rotation.z = t * d.speed * 3; });
    (machines.syncband || []).forEach((n) => { n.rotation.z = -t * d.speed * 3; });
    (machines.hochleistung || []).forEach((n) => { n.rotation.z = t * 6; });
    (machines.portale || []).forEach((n) => { n.rotation.z = t * 1.5; });
    (machines.rentier || []).forEach((n) => { n.rotation.y = t * 0.6; });
    (machines.platzierung || []).forEach((n) => { n.rotation.y = Math.sin(t * 3) * 0.9; });
    const cyc = d.autoCut && working ? (Math.sin(t * Math.min(14, 4 + d.autoCut / 60)) + 1) / 2 : ease(1 - anim.press);
    if (parts.stamp) parts.stamp.position.y = BENCH_Y + 0.62 - cyc * 0.3;
    if (parts.lever) parts.lever.rotation.z = -cyc * 0.9;
    const spin = d.autoRoll ? t * 7 : (anim.crank + roll) * 6 + t * 0.2;
    (parts.rollers || []).forEach((r, i) => { r.rotation.z = (i ? -1 : 1) * spin; });
    if (parts.flywheel) parts.flywheel.rotation.z = spin;
    if (parts.armUpper) { const sw = Math.sin(t * 2.4); parts.armUpper.rotation.y = sw * 0.9; parts.claw.position.set(-1.85 - Math.sin(sw * 0.9) * 0.4, BELT.y + 0.35 + Math.abs(Math.sin(t * 4.8)) * 0.05, BELT.z + 0.45 - Math.cos(sw * 0.9) * 0.4); parts.claw.rotation.y = sw * 0.9; }
    if (parts.treeLight) parts.treeLight.intensity = 1.4 + Math.sin(t * 2.2) * 0.3;
    // quest arrow above the next step
    const qpos = { take: new THREE.Vector3(MOUNTAIN.x, 2.6 * mountainScale + 0.7, MOUNTAIN.z - 3.6 * mountainScale), deliver: lw(0.92, BENCH_Y + 0.55, 0.02), roll: lw(0.15, BENCH_Y + 0.55, 0.02), cut: lw(-0.45, BENCH_Y + 0.75, 0.02), load: lw(-1.2, BENCH_Y + 0.55, 0.02) }[quest];
    parts.arrow.visible = Boolean(qpos) && finaleT < 0;
    if (qpos) { parts.arrow.position.copy(qpos); parts.arrow.position.y += Math.abs(Math.sin(t * 3)) * 0.15; parts.arrow.rotation.y = t * 2; }
    const pumping = (L.portionierer || 0) > 0;
    pipe.visible = pumping; pipeBlobs.visible = pumping && s.dough > 0;
    if (pipeBlobs.visible) { for (let i = 0; i < 40; i++) { const u = ((t * 0.06 * (1 + (L.zufuhr || 0))) + i / 40) % 1; tmp.position.copy(pipeCurve.getPointAt(u)); tmp.rotation.set(0, 0, 0); tmp.updateMatrix(); pipeBlobs.setMatrixAt(i, tmp.matrix); } pipeBlobs.instanceMatrix.needsUpdate = true; }
    const beltOffset = (t * d.speed * ((BELT.oven1 - BELT.oven0) / OVEN_SLOTS)) % ((BELT.x1 - BELT.x0) / 24);
    for (const st of beltStripes) st.position.x = BELT.x0 + (st.userData.k / 24) * (BELT.x1 - BELT.x0) + beltOffset;

    // ---- cookies
    ci = 0;
    const raw = bakeCols[0], baked = bakeCols[BAKE_STEPS - 1];
    for (let i = 0; i < Math.min(s.tray, 40); i++) put(-1.45 + (i % 8) * 0.07, BENCH_Y + 0.025 + lift, -0.13 + Math.floor(i / 8) * 0.075 - lift * 2.2, raw, i * 0.7);
    for (let i = 0; i < Math.min(s.queue, 120); i++) put(BELT.x0 + 0.15 + (i % 12) * 0.07, BELT.y + 0.01 + Math.floor(i / 36) * 0.015, BELT.z - 0.07 + (Math.floor(i / 12) % 3) * 0.07, raw, i * 0.9);
    const floors = Math.min(3, d.floors), lanes = Math.min(4, d.lanes), rows = Math.min(3, Math.round(d.perRow));
    const slotW = (BELT.oven1 - BELT.oven0) / OVEN_SLOTS, cells = OVEN_SLOTS * 3;
    const occ = new Float32Array(cells + 1);
    for (const [pos, n] of s.belt) occ[Math.min(cells, Math.max(0, Math.floor(pos * 3)))] += n;
    const perCell = floors * lanes * rows, finale = s.finished != null;
    if (finale) { const shift = Math.floor(t * d.speed * 3); for (let k = 0; k < cells; k++) if ((k + shift) % 2 === 0) occ[k] = Math.max(occ[k], perCell); }
    for (let k = 0; k < cells; k++) {
      let n = Math.min(occ[k], perCell);
      if (n <= 0) continue;
      const pos = (k + 0.5) / 3, bake = Math.min(BAKE_STEPS - 1, Math.floor((pos / OVEN_SLOTS) * BAKE_STEPS));
      const col = finale || (L.goldstrasse && bake > 6) ? goldCol : bakeCols[bake];
      for (let slot = 0; slot < perCell && n > 0; slot++, n--) {
        const f = Math.floor(slot / (lanes * rows)), l = Math.floor(slot / rows) % lanes, r = slot % rows;
        put(BELT.oven0 + pos * slotW, BELT.y + f * BELT.floorH + 0.01, BELT.z - l * BELT.laneGap - 0.06 + r * 0.06, col, k * 1.3);
      }
    }
    for (let i = 0; i < Math.min(s.exit, 30); i++) put(BELT.oven1 + 0.1 + (i % 5) * 0.06, BELT.y + 0.01 + Math.floor(i / 15) * 0.015, BELT.z - 0.06 + (Math.floor(i / 5) % 3) * 0.06, baked, i);
    const frac = clamp(s.baked / GOAL);
    const pileH = s.baked > 0 ? 0.03 + Math.sqrt(frac) * (JAR.h - 0.1) : 0.001;
    parts.pile.scale.y = pileH; parts.pile.position.set(JAR.x, pileH / 2 + 0.04, JAR.z); parts.pile.visible = s.baked > 0;
    let fallN = 0;
    for (const [land, n] of s.falling) {
      const k = clamp(1 - (land - s.t) / FALL_TIME);
      for (let r = 0; r < Math.min(n, 3) && fallN < 90; r++, fallN++) {
        const f = (r + Math.floor(land * 7)) % floors, y0 = BELT.y + f * BELT.floorH;
        put(BELT.x1 + (JAR.x - BELT.x1) * Math.min(1, k * 1.6) + (r - 1) * 0.03, y0 + 0.02 - (y0 - pileH - 0.05) * k * k, JAR.z + (r - 1) * 0.05, finale ? goldCol : baked, land * 9 + r, k * 6);
      }
    }
    for (let i = 0; i < Math.min(s.baked, 40); i++) { const a = i * 2.4, rr = (i % 7) * 0.035; put(JAR.x + Math.cos(a) * rr, pileH + 0.045 + (i % 3) * 0.008, JAR.z + Math.sin(a) * rr, baked, a, (i % 5) * 0.3); }
    cookies.count = ci; cookies.instanceMatrix.needsUpdate = true;
    if (cookies.instanceColor) cookies.instanceColor.needsUpdate = true;

    // ---- +N taler pops above the jar
    landT += dt;
    if (landAcc > 0 && landT > 0.2) {
      const p = textSprite(`+${Math.round(landAcc).toLocaleString("de-DE")} 🍫`);
      p.position.copy(lw(JAR.x + (Math.random() - 0.5) * 0.2, JAR.h + 0.75, JAR.z + 0.2)); scene.add(p); pops.push({ sp: p, life: 0 });
      landAcc = 0; landT = 0;
      while (pops.length > 10) { const q = pops.shift(); scene.remove(q.sp); q.sp.material.map.dispose(); q.sp.material.dispose(); }
    }
    for (let i = pops.length - 1; i >= 0; i--) { const p = pops[i]; p.life += dt; p.sp.position.y += dt * 0.35; p.sp.material.opacity = 1 - p.life / 1.2; if (p.life > 1.2) { scene.remove(p.sp); p.sp.material.map.dispose(); p.sp.material.dispose(); pops.splice(i, 1); } }
    if (finaleT >= 0) { finaleT += dt; if (Math.random() < dt * 5) burst(new THREE.Vector3((Math.random() - 0.5) * 16, 8 + Math.random() * 4, 6 + (Math.random() - 0.5) * 12), 60, null, 4); }
    for (let i = sparkData.length - 1; i >= 0; i--) { const p = sparkData[i]; p.life += dt; if (p.life > p.max) { sparkData.splice(i, 1); continue; } p.v.y -= 2.2 * dt; p.p.addScaledVector(p.v, dt); }
    const pos = new Float32Array(sparkData.length * 3), col = new Float32Array(sparkData.length * 3);
    sparkData.forEach((p, i) => { pos.set([p.p.x, p.p.y, p.p.z], i * 3); const a = 1 - p.life / p.max; col.set([p.c.r * a, p.c.g * a, p.c.b * a], i * 3); });
    sparks.geometry.setAttribute("position", new THREE.BufferAttribute(pos, 3));
    sparks.geometry.setAttribute("color", new THREE.BufferAttribute(col, 3));
    gl.render(scene, camera);
  }

  resize();
  return {
    ready, frame, resize, onEvents, interact, request,
    target: (px, py) => lookTarget(px, py),
    setQuest(id) { quest = id; },
    ovenDistance: () => Math.hypot(player.x - lw(0, 0, 0).x, player.z - lw(0, 0, BELT.z).z),
    isLocked: () => locked,
    isDragging: () => Boolean(drag && drag.moved > 6),
    isOutside: () => !insideHouse(player.x, player.z),
    lock() { if (canvas.requestPointerLock) { try { const p = canvas.requestPointerLock(); if (p?.catch) p.catch(() => {}); } catch { /* not allowed here */ } } },
    startFinale() { if (finaleT < 0) finaleT = 0; },
    dispose() {
      window.removeEventListener("keydown", kd); window.removeEventListener("keyup", ku);
      window.removeEventListener("pointermove", mm); window.removeEventListener("pointerup", pu);
      document.removeEventListener("pointerlockchange", lockChange);
      if (document.pointerLockElement === canvas) document.exitPointerLock();
      gl.dispose();
    },
  };
}

export function fmt(n) {
  return Math.round(n).toLocaleString("de-DE");
}
