import * as THREE from "three";
import { HDRLoader } from "three/examples/jsm/loaders/HDRLoader.js";
import { EffectComposer } from "three/examples/jsm/postprocessing/EffectComposer.js";
import { RenderPass } from "three/examples/jsm/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/examples/jsm/postprocessing/UnrealBloomPass.js";
import { OutputPass } from "three/examples/jsm/postprocessing/OutputPass.js";
import { BALL_R } from "./physics.js";
import { CX, HABITRAILS, LAYOUT } from "./table.js";
import { INSERTS, insertMask, paintApron, paintPlayfield } from "./playfield.js";

const X = (x) => x - 5;
const Z = (y) => y - 10;
const UP = new THREE.Vector3(0, 1, 0);
const BUMPER_COLORS = [0xff3fb4, 0x3fe7ff, 0xffc94a];

function loadImage(src) {
  return new Promise((resolve) => { const img = new Image(); img.onload = () => resolve(img); img.onerror = () => resolve(null); img.src = src; });
}

export class PinballRenderer {
  constructor(container, engine, { quality = "high" } = {}) {
    this.container = container;
    this.engine = engine;
    this.quality = quality;
    this.balls = new Map();
    this.fx = [];
    this.flash = 0;
    this.flashColor = new THREE.Color(0xffffff);
    this.shake = 0;
    this.time = 0;
  }

  async init() {
    const r = (this.renderer = new THREE.WebGLRenderer({ antialias: false, powerPreference: "high-performance" }));
    r.setPixelRatio(Math.min(window.devicePixelRatio || 1, this.quality === "low" ? 1 : 1.75));
    r.toneMapping = THREE.ACESFilmicToneMapping;
    r.toneMappingExposure = 0.92;
    r.outputColorSpace = THREE.SRGBColorSpace;
    r.domElement.className = "pinballCanvas";
    this.container.prepend(r.domElement);
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x040108);
    this.camera = new THREE.PerspectiveCamera(30, 1, 0.5, 200);

    const [env, wood, mascot] = await Promise.all([
      new HDRLoader().loadAsync("/assets/pinball/env-colorful-studio.hdr").catch(() => null),
      new THREE.TextureLoader().loadAsync("/assets/pinball/walnut.jpg").catch(() => null),
      loadImage("/assets/pinball/mascot.webp"),
    ]);
    if (this.disposed) return;
    if (env) {
      const pm = new THREE.PMREMGenerator(r);
      this.envMap = pm.fromEquirectangular(env).texture;
      env.dispose(); pm.dispose();
      this.scene.environment = this.envMap;
      this.scene.environmentIntensity = 0.32;
    }
    if (wood) { wood.colorSpace = THREE.SRGBColorSpace; wood.wrapS = wood.wrapT = THREE.RepeatWrapping; }
    this.woodTex = wood;
    this.makeMaterials();
    await this.buildPlayfield(mascot);
    this.buildCabinet();
    this.buildWalls();
    this.buildToys();
    this.buildRamps();
    this.buildInserts();
    this.buildParticles();
    this.buildLights();

    const size = r.getDrawingBufferSize(new THREE.Vector2());
    const rt = new THREE.WebGLRenderTarget(size.x, size.y, { type: THREE.HalfFloatType, samples: this.quality === "low" ? 0 : 4 });
    this.composer = new EffectComposer(r, rt);
    this.composer.addPass(new RenderPass(this.scene, this.camera));
    this.bloom = new UnrealBloomPass(new THREE.Vector2(512, 512), 0.5, 0.35, 0.92);
    this.composer.addPass(this.bloom);
    this.composer.addPass(new OutputPass());
    this.observer = new ResizeObserver(() => this.resize());
    this.observer.observe(this.container);
    this.resize();
    this.unsub = this.engine.on((type, d) => this.onEvent(type, d));
  }

  makeMaterials() {
    this.mat = {
      chrome: new THREE.MeshStandardMaterial({ color: 0xe8e8f0, metalness: 1, roughness: 0.18 }),
      darkChrome: new THREE.MeshStandardMaterial({ color: 0x8a8a98, metalness: 1, roughness: 0.32 }),
      rubber: new THREE.MeshStandardMaterial({ color: 0x141018, roughness: 0.55, metalness: 0 }),
      whiteRubber: new THREE.MeshStandardMaterial({ color: 0xf2eef8, roughness: 0.5 }),
      plasticWhite: new THREE.MeshPhysicalMaterial({ color: 0xcfc6de, roughness: 0.25, clearcoat: 1, clearcoatRoughness: 0.1 }),
      clear: new THREE.MeshPhysicalMaterial({ color: 0xd8c8ff, roughness: 0.05, metalness: 0, transparent: true, opacity: 0.22, depthWrite: false, side: THREE.DoubleSide, clearcoat: 1 }),
      wood: new THREE.MeshStandardMaterial({ color: 0x8a6a58, map: this.woodTex, roughness: 0.6, metalness: 0 }),
      black: new THREE.MeshStandardMaterial({ color: 0x050307, roughness: 0.9 }),
      ball: new THREE.MeshStandardMaterial({ color: 0xffffff, metalness: 1, roughness: 0.04, envMapIntensity: 2.6 }),
    };
    if (!this.woodTex) this.mat.wood.color.set(0x3a2214);
  }

  box(w, h, d, mat, x, y, z) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
    m.position.set(x, y, z);
    this.scene.add(m);
    return m;
  }
  bar(a, b, thick, height, mat, y0 = 0) {
    const dx = b.x - a.x, dy = b.y - a.y, len = Math.hypot(dx, dy);
    const m = this.box(len + thick, height, thick, mat, X((a.x + b.x) / 2), y0 + height / 2, Z((a.y + b.y) / 2));
    m.rotation.y = -Math.atan2(dy, dx);
    return m;
  }

  async buildPlayfield(mascot) {
    const canvas = await paintPlayfield(mascot);
    const tex = new THREE.CanvasTexture(canvas);
    tex.colorSpace = THREE.SRGBColorSpace;
    tex.anisotropy = Math.min(8, this.renderer.capabilities.getMaxAnisotropy());
    const mat = new THREE.MeshPhysicalMaterial({ map: tex, roughness: 0.38, metalness: 0, clearcoat: 0.7, clearcoatRoughness: 0.08 });
    const pf = new THREE.Mesh(new THREE.PlaneGeometry(10, 20), mat);
    pf.rotation.x = -Math.PI / 2;
    this.scene.add(pf);
    // Apron hides the drain.
    const apronTex = new THREE.CanvasTexture(paintApron());
    apronTex.colorSpace = THREE.SRGBColorSpace;
    const side = new THREE.MeshStandardMaterial({ color: 0x1a0a2a, roughness: 0.4, metalness: 0.3 });
    const top = new THREE.MeshStandardMaterial({ map: apronTex, roughness: 0.45, metalness: 0.1 });
    const apron = new THREE.Mesh(new THREE.BoxGeometry(8.7, 0.32, 1.25), [side, side, top, side, side, side]);
    apron.position.set(X(LAYOUT.wallL + 8.7 / 2), 0.16, Z(20.0));
    this.scene.add(apron);
  }

  buildCabinet() {
    const w = this.mat.wood;
    if (this.woodTex) { const t = this.woodTex.clone(); t.repeat.set(1, 8); t.needsUpdate = true; w.map = t; }
    this.box(0.9, 1.7, 21.8, w, X(LAYOUT.wallL - 0.45 - 0.08), 0.45, 0.2);
    this.box(0.9, 1.7, 21.8, w, X(LAYOUT.outer + 0.45 + 0.08), 0.45, 0.2);
    this.box(11.8, 1.7, 0.7, w, 0, 0.45, Z(-0.35));
    this.box(11.8, 1.0, 0.6, w, 0, 0.1, Z(20.95));
    // Chrome side rails and lockdown bar.
    this.box(0.32, 0.12, 21.8, this.mat.chrome, X(LAYOUT.wallL - 0.4), 1.36, 0.2);
    this.box(0.32, 0.12, 21.8, this.mat.chrome, X(LAYOUT.outer + 0.4), 1.36, 0.2);
    const lock = this.box(11.4, 0.18, 0.4, this.mat.chrome, 0, 0.7, Z(20.85));
    lock.material = this.mat.darkChrome;
    // Floor around the machine so the bloom has something to sit on.
    const floor = new THREE.Mesh(new THREE.PlaneGeometry(80, 80), new THREE.MeshBasicMaterial({ color: 0x030106 }));
    floor.rotation.x = -Math.PI / 2; floor.position.y = -0.5;
    this.scene.add(floor);
  }

  buildWalls() {
    const w = this.engine.world;
    for (const s of w.segs) {
      switch (s.vis) {
        case "rail": this.bar(s.a, s.b, Math.max(0.09, s.r * 1.6), 0.42, this.mat.chrome); break;
        case "guide": this.bar(s.a, s.b, 0.12, 0.36, this.mat.chrome); break;
        case "rubber": this.bar(s.a, s.b, 0.12, 0.2, this.mat.rubber, 0.06); break;
        case "rampWall": this.bar(s.a, s.b, 0.06, 0.55, this.mat.clear); break;
        case "rampFlap": this.bar(s.a, s.b, 0.08, 0.3, this.mat.darkChrome); break;
        case "gate": this.bar(s.a, s.b, 0.03, 0.03, this.mat.chrome, 0.32); break;
        default: break;
      }
    }
    for (const c of w.circles) {
      if (c.kind !== "post") continue;
      const post = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.05, 0.55, 12), this.mat.chrome);
      post.position.set(X(c.x), 0.27, Z(c.y)); this.scene.add(post);
      const ring = new THREE.Mesh(new THREE.TorusGeometry(c.r, 0.045, 10, 24), this.mat.rubber);
      ring.rotation.x = Math.PI / 2; ring.position.set(X(c.x), 0.18, Z(c.y)); this.scene.add(ring);
      const cap = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.11, 0.08, 6), new THREE.MeshPhysicalMaterial({ color: 0xff3fb4, roughness: 0.2, clearcoat: 1, emissive: 0x551040 }));
      cap.position.set(X(c.x), 0.57, Z(c.y)); this.scene.add(cap);
    }
    // Slingshot plastics, lit from inside.
    this.slings = {};
    for (const mirror of [false, true]) {
      const pts = LAYOUT.slingL.map(([x, y]) => [mirror ? CX * 2 - x : x, y]);
      const shape = new THREE.Shape();
      pts.forEach(([x, y], i) => (i ? shape.lineTo(X(x), -Z(y)) : shape.moveTo(X(x), -Z(y))));
      shape.closePath();
      const geo = new THREE.ExtrudeGeometry(shape, { depth: 0.07, bevelEnabled: true, bevelSize: 0.05, bevelThickness: 0.03, bevelSegments: 2 });
      const mat = new THREE.MeshPhysicalMaterial({ color: mirror ? 0x3fe7ff : 0xff3fb4, transparent: true, opacity: 0.82, roughness: 0.15, clearcoat: 1, emissive: mirror ? 0x0a5a6a : 0x6a0a48, emissiveIntensity: 0.6 });
      const m = new THREE.Mesh(geo, mat);
      m.rotation.x = -Math.PI / 2; m.position.y = 0.42;
      this.scene.add(m);
      const lightPos = pts.reduce((a, [x, y]) => [a[0] + x / 3, a[1] + y / 3], [0, 0]);
      this.slings[mirror ? "slingR" : "slingL"] = { mat, base: 0.6, pulse: 0, pos: lightPos };
    }
  }

  buildToys() {
    // Pop bumpers.
    this.bumpers = LAYOUT.bumpers.map((b, i) => {
      const g = new THREE.Group();
      g.position.set(X(b.x), 0, Z(b.y));
      const color = BUMPER_COLORS[i];
      const base = new THREE.Mesh(new THREE.CylinderGeometry(0.58, 0.62, 0.08, 40), this.mat.plasticWhite); base.position.y = 0.04; g.add(base);
      const bodyMat = new THREE.MeshPhysicalMaterial({ color, transparent: true, opacity: 0.85, roughness: 0.15, clearcoat: 1, emissive: color, emissiveIntensity: 0.4 });
      const body = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.44, 0.34, 40), bodyMat); body.position.y = 0.25; g.add(body);
      const ring = new THREE.Mesh(new THREE.TorusGeometry(0.47, 0.035, 10, 40), this.mat.chrome); ring.rotation.x = Math.PI / 2; ring.position.y = 0.16; g.add(ring);
      const capTex = this.bumperCap(i);
      const capTop = new THREE.MeshPhysicalMaterial({ map: capTex, roughness: 0.2, clearcoat: 1, emissive: 0xffffff, emissiveMap: capTex, emissiveIntensity: 0.35 });
      const cap = new THREE.Mesh(new THREE.CylinderGeometry(0.52, 0.5, 0.1, 40), [this.mat.plasticWhite, capTop, this.mat.plasticWhite]);
      cap.position.y = 0.47; g.add(cap);
      this.scene.add(g);
      return { g, ring, bodyMat, capTop, pulse: 0, color: new THREE.Color(color) };
    });
    // Flippers.
    this.flippers = [this.engine.table.flipL, this.engine.table.flipR].map((f, i) => {
      const g = new THREE.Group();
      const outline = (r0, r1) => {
        const s = new THREE.Shape();
        s.moveTo(0, r0); s.absarc(0, 0, r0, Math.PI / 2, (Math.PI * 3) / 2, false);
        s.lineTo(f.len, -r1); s.absarc(f.len, 0, r1, -Math.PI / 2, Math.PI / 2, false); s.lineTo(0, r0);
        return s;
      };
      const body = new THREE.Mesh(new THREE.ExtrudeGeometry(outline(f.r0 - 0.02, f.r1 - 0.02), { depth: 0.3, bevelEnabled: true, bevelSize: 0.02, bevelThickness: 0.02, bevelSegments: 2 }), this.mat.plasticWhite);
      body.rotation.x = -Math.PI / 2; body.position.y = 0.04; g.add(body);
      const rubberMat = new THREE.MeshStandardMaterial({ color: i ? 0x22c8ff : 0xff2f8f, roughness: 0.45, emissive: i ? 0x053040 : 0x40051f });
      const rubber = new THREE.Mesh(new THREE.ExtrudeGeometry(outline(f.r0 + 0.02, f.r1 + 0.02), { depth: 0.12, bevelEnabled: false }), rubberMat);
      rubber.rotation.x = -Math.PI / 2; rubber.position.y = 0.12; g.add(rubber);
      const capM = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.1, 0.06, 16), this.mat.chrome); capM.position.y = 0.38; g.add(capM);
      g.position.set(X(f.px), 0, Z(f.py));
      this.scene.add(g);
      return { f, g };
    });
    // Drop targets.
    this.drops = this.engine.table.drops.map((d, i) => {
      const tex = this.letterTexture("VIP"[i], "#ffc94a", "#2a1203");
      const face = new THREE.MeshStandardMaterial({ map: tex, emissive: 0xffc94a, emissiveMap: tex, emissiveIntensity: 0.3, roughness: 0.35 });
      const side = new THREE.MeshStandardMaterial({ color: 0xffc94a, roughness: 0.4 });
      const m = new THREE.Mesh(new THREE.BoxGeometry(0.42, 0.44, 0.09), [side, side, side, side, face, side]);
      m.position.set(X((d.a.x + d.b.x) / 2), 0.22, Z(d.a.y));
      this.scene.add(m);
      return { m, face, seg: d, y: 0.22 };
    });
    // Scoop.
    const hole = new THREE.Mesh(new THREE.CircleGeometry(0.3, 32), new THREE.MeshBasicMaterial({ color: 0x000000 }));
    hole.rotation.x = -Math.PI / 2; hole.position.set(X(LAYOUT.scoop.x), 0.006, Z(LAYOUT.scoop.y)); this.scene.add(hole);
    const lip = new THREE.Mesh(new THREE.TorusGeometry(0.31, 0.035, 10, 32), this.mat.chrome);
    lip.rotation.x = Math.PI / 2; lip.position.set(X(LAYOUT.scoop.x), 0.02, Z(LAYOUT.scoop.y)); this.scene.add(lip);
    // Spinner across the left orbit.
    const sx = (LAYOUT.wallL + LAYOUT.orbitWallL) / 2, sz = Z(7.4);
    const width = LAYOUT.orbitWallL - LAYOUT.wallL - 0.04;
    this.box(width + 0.06, 0.02, 0.02, this.mat.chrome, X(sx), 0.62, sz);
    for (const x of [LAYOUT.wallL + 0.02, LAYOUT.orbitWallL - 0.02]) this.box(0.03, 0.62, 0.03, this.mat.chrome, X(x), 0.31, sz);
    const plate = new THREE.Mesh(new THREE.BoxGeometry(width - 0.06, 0.4, 0.025), [this.mat.chrome, this.mat.chrome, this.mat.chrome, this.mat.chrome, new THREE.MeshStandardMaterial({ map: this.letterTexture("★", "#ff3fb4", "#1a0628"), roughness: 0.3 }), this.mat.chrome]);
    plate.geometry.translate(0, -0.2, 0);
    this.spinner = { plate, angle: 0, speed: 0 };
    plate.position.set(X(sx), 0.6, sz); this.scene.add(plate);
    // Top lane rollover wires.
    for (const x of LAYOUT.lanes) {
      const wire = new THREE.Mesh(new THREE.TorusGeometry(0.16, 0.015, 6, 16, Math.PI), this.mat.chrome);
      wire.position.set(X(x), 0.01, Z(2.45)); wire.rotation.y = Math.PI / 2; this.scene.add(wire);
    }
    // Plunger.
    const px = X(LAYOUT.plungerRest.x);
    this.plunger = new THREE.Group();
    const rod = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.07, 1.3, 16), this.mat.chrome); rod.rotation.x = Math.PI / 2; rod.position.z = 0.65; this.plunger.add(rod);
    const tip = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.12, 0.12, 16), this.mat.rubber); tip.rotation.x = Math.PI / 2; this.plunger.add(tip);
    const knob = new THREE.Mesh(new THREE.SphereGeometry(0.2, 20, 16), new THREE.MeshPhysicalMaterial({ color: 0xff3fb4, roughness: 0.15, clearcoat: 1 })); knob.position.z = 1.45; knob.position.y = 0.05; this.plunger.add(knob);
    this.plunger.position.set(px, 0.2, Z(LAYOUT.plungerTop + 0.06));
    this.scene.add(this.plunger);
    // Ball shadow texture.
    const sc = document.createElement("canvas"); sc.width = sc.height = 64;
    const sctx = sc.getContext("2d"); const sg = sctx.createRadialGradient(32, 32, 2, 32, 32, 32);
    sg.addColorStop(0, "rgba(0,0,0,0.75)"); sg.addColorStop(1, "rgba(0,0,0,0)"); sctx.fillStyle = sg; sctx.fillRect(0, 0, 64, 64);
    this.shadowTex = new THREE.CanvasTexture(sc);
  }

  bumperCap(i) {
    const c = document.createElement("canvas"); c.width = c.height = 256;
    const ctx = c.getContext("2d");
    const col = ["#ff3fb4", "#3fe7ff", "#ffc94a"][i];
    const g = ctx.createRadialGradient(128, 128, 10, 128, 128, 128);
    g.addColorStop(0, "#ffffff"); g.addColorStop(0.55, col); g.addColorStop(1, "#1a0628");
    ctx.fillStyle = g; ctx.fillRect(0, 0, 256, 256);
    ctx.strokeStyle = "#1a0628"; ctx.lineWidth = 10; ctx.beginPath(); ctx.arc(128, 128, 112, 0, Math.PI * 2); ctx.stroke();
    ctx.fillStyle = "#1a0628"; ctx.font = "900 70px Inter, Arial"; ctx.textAlign = "center"; ctx.textBaseline = "middle";
    ctx.fillText(["DJ", "VIP", "BAR"][i], 128, 132);
    const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
  }
  letterTexture(ch, fg, bg) {
    const c = document.createElement("canvas"); c.width = c.height = 128;
    const ctx = c.getContext("2d");
    ctx.fillStyle = bg; ctx.fillRect(0, 0, 128, 128);
    ctx.strokeStyle = fg; ctx.lineWidth = 8; ctx.strokeRect(6, 6, 116, 116);
    ctx.fillStyle = fg; ctx.font = "900 84px Inter, Arial"; ctx.textAlign = "center"; ctx.textBaseline = "middle"; ctx.fillText(ch, 64, 70);
    const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
  }

  buildRamps() {
    this.rails = {};
    const rampColors = { rampL: 0xff3fb4, rampR: 0x3fe7ff };
    for (const [id, def] of Object.entries(HABITRAILS)) {
      const pts = def.points.map(([x, y, h]) => new THREE.Vector3(X(x), h + BALL_R, Z(y)));
      const curve = new THREE.CatmullRomCurve3(pts, false, "centripetal", 0.4);
      this.rails[id] = curve;
      // Plastic ramp floor for the climbing section (first three points), the rest is wireform.
      const floorPts = [new THREE.Vector3(pts[0].x, 0.02, Z(LAYOUT.rampL.mouth)), ...pts.slice(0, 3).map((p) => new THREE.Vector3(p.x, p.y - BALL_R, p.z))];
      const rampMat = new THREE.MeshPhysicalMaterial({ color: rampColors[id], transparent: true, opacity: 0.15, roughness: 0.05, clearcoat: 1, side: THREE.DoubleSide, depthWrite: false, emissive: rampColors[id], emissiveIntensity: 0.05 });
      this.scene.add(this.ribbon(floorPts, 1.22, 0.38, rampMat));
      // Chrome lips along the top edges of the plastic ramp walls.
      const lipCurve = new THREE.CatmullRomCurve3(floorPts, false, "centripetal", 0.3);
      for (const side of [-1, 1]) {
        const lp = [];
        for (let i = 0; i <= 24; i++) {
          const p = lipCurve.getPointAt(i / 24), t = lipCurve.getTangentAt(i / 24);
          const lat = new THREE.Vector3().crossVectors(t, UP).normalize();
          lp.push(p.clone().addScaledVector(lat, side * 0.61).add(new THREE.Vector3(0, 0.38, 0)));
        }
        this.scene.add(new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(lp), 40, 0.03, 6, false), this.mat.chrome));
      }
      // Wireform: three chrome wires along the ball path.
      const samples = 80, start = 2 / (def.points.length - 1) * 0.92;
      const offsets = [[0.21, -0.08], [-0.21, -0.08], [0, -0.27]];
      const wirePts = offsets.map(() => []);
      for (let i = 0; i <= samples; i++) {
        const u = start + ((1 - start) * i) / samples;
        const p = curve.getPointAt(u), t = curve.getTangentAt(u);
        const lat = new THREE.Vector3().crossVectors(t, UP).normalize();
        const down = new THREE.Vector3().crossVectors(lat, t).normalize();
        offsets.forEach(([l, d], k) => wirePts[k].push(p.clone().addScaledVector(lat, l).addScaledVector(down, -d)));
        if (i % 16 === 8 && p.y > 0.5) {
          const post = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.025, p.y, 6), this.mat.darkChrome);
          post.position.set(p.x, p.y / 2, p.z); this.scene.add(post);
        }
      }
      for (const wp of wirePts) {
        const tube = new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(wp), 120, 0.028, 6, false), this.mat.chrome);
        this.scene.add(tube);
      }
    }
  }

  ribbon(points, width, wall, mat) {
    const curve = new THREE.CatmullRomCurve3(points, false, "centripetal", 0.3);
    const n = 30, pos = [], idx = [];
    const sides = [[-width / 2, 0], [width / 2, 0], [-width / 2, wall], [width / 2, wall]];
    for (let i = 0; i <= n; i++) {
      const p = curve.getPointAt(i / n), t = curve.getTangentAt(i / n);
      const lat = new THREE.Vector3().crossVectors(t, UP).normalize();
      for (const [l, h] of sides) { const q = p.clone().addScaledVector(lat, l); q.y += h; pos.push(q.x, q.y, q.z); }
    }
    for (let i = 0; i < n; i++) {
      const a = i * 4, b = (i + 1) * 4;
      idx.push(a, b, a + 1, a + 1, b, b + 1); // floor
      idx.push(a, a + 2, b, b, a + 2, b + 2); // wall A
      idx.push(a + 1, b + 1, a + 3, a + 3, b + 1, b + 3); // wall B
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
    geo.setIndex(idx); geo.computeVertexNormals();
    return new THREE.Mesh(geo, mat);
  }

  buildInserts() {
    this.inserts = INSERTS.map((ins) => {
      const { canvas, size } = insertMask(ins);
      const tex = new THREE.CanvasTexture(canvas);
      const color = new THREE.Color(ins.color);
      const mat = new THREE.MeshBasicMaterial({ map: tex, color: color.clone(), transparent: true, opacity: 0, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false });
      const m = new THREE.Mesh(new THREE.PlaneGeometry(size, size), mat);
      m.rotation.x = -Math.PI / 2; m.position.set(X(ins.x), 0.012, Z(ins.y));
      this.scene.add(m);
      return { ins, mat, color, level: 0 };
    });
  }

  buildParticles() {
    const max = 400;
    this.pPos = new Float32Array(max * 3);
    this.pCol = new Float32Array(max * 3);
    this.parts = [];
    const geo = new THREE.BufferGeometry();
    geo.setAttribute("position", new THREE.BufferAttribute(this.pPos, 3));
    geo.setAttribute("color", new THREE.BufferAttribute(this.pCol, 3));
    geo.setDrawRange(0, 0);
    const c = document.createElement("canvas"); c.width = c.height = 32;
    const ctx = c.getContext("2d"); const g = ctx.createRadialGradient(16, 16, 0, 16, 16, 16);
    g.addColorStop(0, "#fff"); g.addColorStop(0.4, "#ffffffaa"); g.addColorStop(1, "#ffffff00"); ctx.fillStyle = g; ctx.fillRect(0, 0, 32, 32);
    this.points = new THREE.Points(geo, new THREE.PointsMaterial({ size: 0.14, map: new THREE.CanvasTexture(c), vertexColors: true, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false }));
    this.points.frustumCulled = false;
    this.scene.add(this.points);
  }

  burst(x, y, h, color, n = 18, speed = 3) {
    const col = new THREE.Color(color);
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2, s = speed * (0.4 + Math.random());
      this.parts.push({ x: X(x), y: h, z: Z(y), vx: Math.cos(a) * s, vy: 1.5 + Math.random() * 3, vz: Math.sin(a) * s, life: 0.5 + Math.random() * 0.4, max: 0.9, col });
    }
    if (this.parts.length > 400) this.parts.splice(0, this.parts.length - 400);
  }

  buildLights() {
    this.scene.add(new THREE.HemisphereLight(0x9a7cff, 0x12051c, 0.25));
    const key = new THREE.DirectionalLight(0xfff0dd, 0.85);
    key.position.set(0, 14, 9); this.scene.add(key);
    this.gi = [[-4.4, -4], [4.4, -4], [-4.4, 5], [4.4, 5]].map(([x, z], i) => {
      const l = new THREE.PointLight(i % 2 ? 0x3fe7ff : 0xff3fb4, 2.5, 8, 1.6); l.position.set(x, 1.6, z); this.scene.add(l); return l;
    });
    this.bumperLights = this.bumpers.map((b, i) => { const l = new THREE.PointLight(BUMPER_COLORS[i], 0, 3.2, 1.6); l.position.set(b.g.position.x, 0.7, b.g.position.z); this.scene.add(l); return l; });
    this.slingLights = Object.entries(this.slings).map(([id, s]) => { const l = new THREE.PointLight(id === "slingR" ? 0x3fe7ff : 0xff3fb4, 0, 3, 1.5); l.position.set(X(s.pos[0]), 0.8, Z(s.pos[1])); this.scene.add(l); s.light = l; return l; });
    this.flashLight = new THREE.PointLight(0xffffff, 0, 30, 1); this.flashLight.position.set(0, 6, 0); this.scene.add(this.flashLight);
  }

  // ------------------------------------------------------------- events
  onEvent(type, d) {
    const L = LAYOUT;
    switch (type) {
      case "bumper": { const b = this.bumpers[d.index]; if (b) { b.pulse = 1; this.burst(L.bumpers[d.index].x, L.bumpers[d.index].y, 0.5, b.color, 14, 3.5); } break; }
      case "sling": { const s = this.slings[d.id]; if (s) { s.pulse = 1; this.burst(d.x, d.y, 0.3, d.id === "slingR" ? 0x3fe7ff : 0xff3fb4, 10, 2.5); } break; }
      case "drop": { const dm = this.drops[d.index]; if (dm) this.burst((dm.seg.a.x + dm.seg.b.x) / 2, dm.seg.a.y, 0.3, 0xffc94a, 14, 2.5); break; }
      case "spinner": this.spinner.speed = Math.min(60, this.spinner.speed + d.spins * 4); break;
      case "jackpot": case "superJackpot": this.doFlash(0xffc94a, type === "superJackpot" ? 2 : 1.3); this.shake = 0.12; this.lampShow("sweep", 1.6); break;
      case "multiball": case "wizard": this.doFlash(0xff3fb4, 1.6); this.shake = 0.15; this.lampShow("strobe", 2.4); break;
      case "skillShot": this.doFlash(0x3fe7ff, 1.2); this.lampShow("sweep", 1.2); break;
      case "missionComplete": case "extraBall": this.doFlash(0x5dff8c, 1.2); this.lampShow("sweep", 1.5); break;
      case "missionStart": this.lampShow("chase", 1.5); break;
      case "combo": this.doFlash(0xb06bff, 0.5 + d.count * 0.15); break;
      case "lock": this.doFlash(0xb06bff, 0.9); this.shake = 0.06; break;
      case "kickback": this.shake = 0.08; this.burst(0.67, 18, 0.2, 0x5dff8c, 16, 3); break;
      case "tilt": this.lampShow("off", 99); this.shake = 0.2; break;
      case "newBall": case "shootAgain": case "gameStart": this.lampShowUntil = 0; this.lampShow("chase", 1); break;
      case "drain": this.lampShow("fade", 1.2); break;
      case "nudge": this.shake = 0.07; this.nudgeDir = d.dir; break;
      case "scoopIn": this.burst(L.scoop.x, L.scoop.y, 0.2, 0xffc94a, 12, 1.5); break;
      case "ramp": this.burst(d.id === "rampL" ? 1.8 : CX * 2 - 1.8, 9.2, 0.3, d.id === "rampL" ? 0xff3fb4 : 0x3fe7ff, 10, 2); break;
      default: break;
    }
  }
  doFlash(color, strength) { this.flash = Math.max(this.flash, strength); this.flashColor.set(color); }
  lampShow(kind, seconds) { this.show = { kind, until: this.time + seconds, start: this.time }; }

  // ------------------------------------------------------------- frame
  render(dt) {
    if (!this.composer) return;
    this.time += dt;
    const e = this.engine;
    // Flippers.
    for (const { f, g } of this.flippers) g.rotation.y = -f.angle;
    // Drop targets slide down.
    for (const d of this.drops) {
      const target = d.seg.enabled ? 0.22 : -0.26;
      d.y += (target - d.y) * Math.min(1, dt * (d.seg.enabled ? 10 : 22));
      d.m.position.y = d.y;
      d.face.emissiveIntensity = 0.15 + (e.lamps["drop" + d.seg.index] || 0) * 1.4;
    }
    // Bumpers.
    this.bumpers.forEach((b, i) => {
      b.pulse = Math.max(0, b.pulse - dt * 6);
      b.ring.position.y = 0.16 - b.pulse * 0.1;
      b.bodyMat.emissiveIntensity = 0.35 + (e.lamps.bumper || 0.4) * 0.4 + b.pulse * 2.5;
      b.capTop.emissiveIntensity = 0.3 + b.pulse * 1.6;
      this.bumperLights[i].intensity = b.pulse * 6;
    });
    for (const s of Object.values(this.slings)) {
      s.pulse = Math.max(0, s.pulse - dt * 5);
      s.mat.emissiveIntensity = s.base + s.pulse * 3;
      s.light.intensity = s.pulse * 5;
    }
    // Spinner.
    this.spinner.speed *= Math.pow(0.35, dt);
    if (this.spinner.speed < 0.5) { this.spinner.angle += (Math.round(this.spinner.angle / (Math.PI * 2)) * Math.PI * 2 - this.spinner.angle) * Math.min(1, dt * 4); }
    this.spinner.angle += this.spinner.speed * dt;
    this.spinner.plate.rotation.x = this.spinner.angle;
    // Plunger.
    this.plunger.position.z = Z(LAYOUT.plungerTop + 0.06) + e.plungerCharge * 0.55;
    // Balls.
    this.syncBalls(dt);
    this.updateInserts();
    this.updateParticles(dt);
    // Flash and shake.
    this.flash = Math.max(0, this.flash - dt * 2.2);
    this.flashLight.color.copy(this.flashColor);
    this.flashLight.intensity = this.flash * 14;
    this.bloom.strength = 0.5 + this.flash * 0.25;
    const giBase = e.tilted ? 0.3 : 2.5;
    this.gi.forEach((l, i) => { l.intensity = giBase + Math.sin(this.time * 1.3 + i) * 0.5 + this.flash * 3; });
    this.shake = Math.max(0, this.shake - dt * 0.6);
    const sh = this.shake * Math.sin(this.time * 70);
    this.camera.position.copy(this.camBase).add(new THREE.Vector3(sh * (this.nudgeDir || 1), sh * 0.3, 0));
    this.camera.lookAt(this.camTarget);
    this.composer.render(dt);
  }

  syncBalls(dt) {
    const live = new Set();
    let maxSpeed = 0, rollHeight = 0;
    for (const b of this.engine.world.balls) {
      live.add(b.id);
      let v = this.balls.get(b.id);
      if (!v) {
        const mesh = new THREE.Mesh(new THREE.SphereGeometry(BALL_R, 32, 24), this.mat.ball);
        const shadow = new THREE.Mesh(new THREE.PlaneGeometry(0.8, 0.8), new THREE.MeshBasicMaterial({ map: this.shadowTex, transparent: true, depthWrite: false }));
        shadow.rotation.x = -Math.PI / 2;
        this.scene.add(mesh, shadow);
        v = { mesh, shadow };
        this.balls.set(b.id, v);
      }
      let x = X(b.x), z = Z(b.y), h = 0;
      if (b.rail) {
        const p = this.rails[b.rail.id].getPointAt(Math.min(1, b.rail.s / b.rail.total));
        x = p.x; z = p.z; h = p.y - BALL_R;
      } else if (b.held) h = -0.14;
      else {
        for (const r of [LAYOUT.rampL, LAYOUT.rampR]) if (b.x > r.x0 && b.x < r.x1 && b.y < r.mouth && b.y > r.back - 0.5) h = Math.min(0.45, (r.mouth - b.y) * 0.29);
      }
      const prev = v.mesh.position.clone();
      v.mesh.position.set(x, BALL_R + h, z);
      const moved = v.mesh.position.clone().sub(prev);
      const dist = moved.length();
      if (dist > 1e-4 && dist < 2) {
        const axis = new THREE.Vector3(moved.z, 0, -moved.x).normalize();
        v.mesh.rotateOnWorldAxis(axis, dist / BALL_R);
      }
      v.shadow.position.set(x + 0.08, 0.004 + (b.rail ? Math.max(0, h - 0.02) * 0 : 0), z + 0.1);
      v.shadow.visible = !b.rail || h < 0.2;
      v.shadow.material.opacity = b.held ? 0 : 1;
      if (!b.rail && !b.held) { const s = Math.hypot(b.vx, b.vy); if (s > maxSpeed) { maxSpeed = s; rollHeight = h; } }
      else if (b.rail) { maxSpeed = Math.max(maxSpeed, b.rail.speed); rollHeight = 1; }
    }
    for (const [id, v] of this.balls) if (!live.has(id)) { this.scene.remove(v.mesh, v.shadow); v.mesh.geometry.dispose(); v.shadow.geometry.dispose(); v.shadow.material.dispose(); this.balls.delete(id); }
    this.rolling = { speed: maxSpeed, height: rollHeight };
  }

  updateInserts() {
    const lamps = this.engine.lamps;
    const show = this.show && this.time < this.show.until ? this.show : null;
    this.inserts.forEach((it, i) => {
      let lv = lamps[it.ins.lamp] ?? 0;
      if (show) {
        const k = this.time - show.start;
        if (show.kind === "sweep") lv = Math.max(lv, Math.max(0, 1 - Math.abs(((it.ins.y / 20) * 1.2 - (1 - (k % 0.8) / 0.8))) * 5));
        else if (show.kind === "strobe") lv = Math.floor(k * 12) % 2 ? 1 : 0.1;
        else if (show.kind === "chase") lv = Math.max(lv, (i + Math.floor(k * 20)) % 6 === 0 ? 1 : 0);
        else if (show.kind === "fade") lv *= Math.max(0, 1 - k / 1.2);
        else if (show.kind === "off") lv = 0;
      }
      it.level += (lv - it.level) * 0.5;
      it.mat.opacity = Math.min(1, it.level * 1.1);
      const k = 0.5 + it.level * 1.7;
      it.mat.color.setRGB(it.color.r * k, it.color.g * k, it.color.b * k);
    });
  }

  updateParticles(dt) {
    let n = 0;
    this.parts = this.parts.filter((p) => (p.life -= dt) > 0);
    for (const p of this.parts) {
      p.vy -= 9 * dt; p.x += p.vx * dt; p.y = Math.max(0.02, p.y + p.vy * dt); p.z += p.vz * dt;
      const a = p.life / p.max;
      this.pPos[n * 3] = p.x; this.pPos[n * 3 + 1] = p.y; this.pPos[n * 3 + 2] = p.z;
      this.pCol[n * 3] = p.col.r * a * 2; this.pCol[n * 3 + 1] = p.col.g * a * 2; this.pCol[n * 3 + 2] = p.col.b * a * 2;
      n++;
    }
    this.points.geometry.setDrawRange(0, n);
    this.points.geometry.attributes.position.needsUpdate = true;
    this.points.geometry.attributes.color.needsUpdate = true;
  }

  resize() {
    if (!this.renderer || this.disposed) return;
    const rect = this.container.getBoundingClientRect();
    const w = Math.max(1, rect.width), h = Math.max(1, rect.height);
    this.renderer.setSize(w, h, false);
    this.composer.setSize(w, h);
    this.camera.aspect = w / h;
    this.fitCamera();
  }

  fitCamera() {
    // Player's-eye view: look down the table from the front, then back off until it all fits.
    const target = new THREE.Vector3(0, 0, 0.9);
    const elev = (this.camera.aspect > 1.1 ? 64 : 60) * (Math.PI / 180);
    const dir = new THREE.Vector3(0, Math.sin(elev), Math.cos(elev));
    const corners = [];
    for (const x of [-5.2, 5.2]) for (const z of [-10.4, 10.9]) for (const y of [0, 1.4]) corners.push(new THREE.Vector3(x, y, z));
    let lo = 5, hi = 120;
    for (let i = 0; i < 28; i++) {
      const d = (lo + hi) / 2;
      this.camera.position.copy(target).addScaledVector(dir, d);
      this.camera.lookAt(target);
      this.camera.updateMatrixWorld(); this.camera.updateProjectionMatrix();
      const fits = corners.every((c) => { const p = c.clone().project(this.camera); return Math.abs(p.x) < 0.97 && Math.abs(p.y) < 0.97 && p.z < 1; });
      if (fits) hi = d; else lo = d;
    }
    this.camera.position.copy(target).addScaledVector(dir, hi);
    this.camBase = this.camera.position.clone();
    this.camTarget = target;
    this.camera.lookAt(target);
    this.camera.updateProjectionMatrix();
  }

  dispose() {
    this.disposed = true;
    this.unsub?.();
    this.observer?.disconnect();
    this.scene?.traverse((o) => {
      o.geometry?.dispose();
      const mats = Array.isArray(o.material) ? o.material : o.material ? [o.material] : [];
      for (const m of mats) { m.map?.dispose(); m.emissiveMap?.dispose(); m.dispose(); }
    });
    this.envMap?.dispose();
    this.composer?.dispose();
    this.renderer?.dispose();
    this.renderer?.domElement.remove();
  }
}
