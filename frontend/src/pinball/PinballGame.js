import * as THREE from "three";
import RAPIER from "@dimforge/rapier3d-compat";
import { RoomEnvironment } from "three/examples/jsm/environments/RoomEnvironment.js";
import { EffectComposer } from "three/examples/jsm/postprocessing/EffectComposer.js";
import { RenderPass } from "three/examples/jsm/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/examples/jsm/postprocessing/UnrealBloomPass.js";
import { OutputPass } from "three/examples/jsm/postprocessing/OutputPass.js";
import { AudioManager } from "./AudioManager";

const STEP = 1 / 120;
const R = 0.12;
const SPAWN = { x: 2.07, y: 0.15, z: 3.48 };
const MINT = 0x7affd3,
  CORAL = 0xff5777,
  GOLD = 0xffda78;
const AXIS = new THREE.Vector3(0, 1, 0);

export class PinballGame {
  constructor(container, { audioEnabledRef, onSnapshot } = {}) {
    this.container = container;
    this.onSnapshot = onSnapshot || (() => {});
    this.audio = new AudioManager(audioEnabledRef || { current: true });
    this.balls = [];
    this.flippers = [];
    this.lamps = [];
    this.effects = [];
    this.specks = [];
    this.contacts = new Map();
    this.keys = { left: false, right: false, launch: false };
    this.status = "menu";
    this.score = 0;
    this.ball = 3;
    this.combo = 0;
    this.mult = 1;
    this.bank = 0;
    this.jackpot = 25000;
    this.time = 0;
    this.comboUntil = 0;
    this.plunger = 0;
    this.acc = 0;
    this.last = 0;
    this.hits = 0;
    this.drains = 0;
    this.bestCombo = 0;
    this.notice = "AFTER HOURS";
  }

  async start() {
    await RAPIER.init();
    if (this.disposed) return;
    this.world = new RAPIER.World({ x: 0, y: -9.81, z: 4.2 });
    this.world.timestep = STEP;
    this.world.integrationParameters.numSolverIterations = 8;
    this.world.integrationParameters.maxCcdSubsteps = 4;
    this.events = new RAPIER.EventQueue(true);
    this.initRenderer();
    this.buildTable();
    this.initParticles();
    this.bind();
    this.container.__pinballGame = this;
    this.resize();
    this.publish();
    this.frame = requestAnimationFrame((t) => this.loop(t));
  }

  initRenderer() {
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x0c1515);
    this.renderer = new THREE.WebGLRenderer({
      antialias: true,
      powerPreference: "high-performance",
      preserveDrawingBuffer: true,
    });
    this.renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 1.5));
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 0.9;
    this.renderer.domElement.className = "pinball3dCanvas";
    this.container.replaceChildren(this.renderer.domElement);
    this.camera = new THREE.OrthographicCamera(-3.5, 3.5, 5.4, -5.4, 0.1, 50);
    this.camera.position.set(0, 15, 5.9);
    this.camera.lookAt(0, 0, 0.15);
    const room = new RoomEnvironment(),
      pmrem = new THREE.PMREMGenerator(this.renderer);
    this.environment = pmrem.fromScene(room, 0.03);
    this.scene.environment = this.environment.texture;
    this.scene.environmentIntensity = 0.45;
    room.dispose();
    pmrem.dispose();
    this.scene.add(new THREE.HemisphereLight(0xd2fff0, 0x354745, 0.7));
    const light = new THREE.DirectionalLight(0xffedcb, 1.4);
    light.position.set(-3, 8, 3);
    this.scene.add(light);
    this.impactLight = new THREE.PointLight(MINT, 0, 9);
    this.scene.add(this.impactLight);
    this.composer = new EffectComposer(this.renderer);
    this.composer.addPass(new RenderPass(this.scene, this.camera));
    this.bloom = new UnrealBloomPass(
      new THREE.Vector2(500, 800),
      0.42,
      0.3,
      1.05,
    );
    this.composer.addPass(this.bloom);
    this.composer.addPass(new OutputPass());
    this.fx = document.createElement("div");
    this.fx.className = "pinballFX";
    this.container.appendChild(this.fx);
    this.banner = document.createElement("div");
    this.banner.className = "pinballBigCombo";
    this.fx.appendChild(this.banner);
  }

  mat(color, metal = 0.3, glow = 0) {
    return new THREE.MeshStandardMaterial({
      color,
      roughness: metal > 0.7 ? 0.22 : 0.4,
      metalness: metal,
      emissive: color,
      emissiveIntensity: glow,
    });
  }
  mesh(geometry, material, x, y, z) {
    const mesh = new THREE.Mesh(geometry, material);
    mesh.position.set(x, y, z);
    this.scene.add(mesh);
    return mesh;
  }
  box(x, z, w, d, color = 0x8aaba0, h = 0.38, y = h / 2) {
    const mesh = this.mesh(
      new THREE.BoxGeometry(w, h, d),
      this.mat(color, 0.7),
      x,
      y,
      z,
    );
    const body = this.world.createRigidBody(
      RAPIER.RigidBodyDesc.fixed().setTranslation(x, y, z),
    );
    const collider = this.world.createCollider(
      RAPIER.ColliderDesc.cuboid(w / 2, h / 2, d / 2)
        .setRestitution(0.45)
        .setFriction(0.05),
      body,
    );
    return { mesh, body, collider };
  }
  rail(a, b, color = 0xbacfc7, width = 0.14) {
    const angle = Math.atan2(b[1] - a[1], b[0] - a[0]);
    const rail = this.box(
      (a[0] + b[0]) / 2,
      (a[1] + b[1]) / 2,
      Math.hypot(b[0] - a[0], b[1] - a[1]),
      width,
      color,
    );
    const q = new THREE.Quaternion().setFromAxisAngle(AXIS, -angle);
    rail.mesh.quaternion.copy(q);
    rail.body.setRotation(q, true);
    for (const [x, z] of [a, b]) {
      this.mesh(
        new THREE.CylinderGeometry(width / 2, width / 2, 0.38, 12),
        rail.mesh.material,
        x,
        0.19,
        z,
      );
      this.world.createCollider(
        RAPIER.ColliderDesc.cylinder(0.19, width / 2)
          .setTranslation(x, 0.19, z)
          .setRestitution(0.45)
          .setFriction(0.05),
      );
    }
    return rail;
  }
  lamp(x, z, color, radius = 0.08) {
    const material = this.mat(color, 0.15, 0.45);
    const mesh = this.mesh(
      new THREE.CylinderGeometry(radius, radius, 0.018, 24),
      material,
      x,
      0.025,
      z,
    );
    const lamp = { mesh, material, pulse: 0, offset: this.lamps.length * 0.53 };
    this.lamps.push(lamp);
    return lamp;
  }
  label(text, x, y, z, w, h, color) {
    const canvas = document.createElement("canvas");
    canvas.width = 512;
    canvas.height = 128;
    const ctx = canvas.getContext("2d");
    ctx.fillStyle = color;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.font = "900 68px Arial";
    ctx.fillText(text, 256, 64, 500);
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    const mesh = this.mesh(
      new THREE.PlaneGeometry(w, h),
      new THREE.MeshBasicMaterial({
        map: texture,
        transparent: true,
        depthWrite: false,
      }),
      x,
      y,
      z,
    );
    mesh.rotation.x = -Math.PI / 2;
  }
  track(item) {
    item.lastHit = -1;
    item.collider.setActiveEvents(RAPIER.ActiveEvents.COLLISION_EVENTS);
    this.contacts.set(item.collider.handle, item);
    return item;
  }

  buildTable() {
    this.mesh(
      new THREE.BoxGeometry(5.25, 0.32, 9.5),
      this.mat(0x233832, 0.65),
      0,
      -0.4,
      0,
    );
    const canvas = document.createElement("canvas");
    canvas.width = 1024;
    canvas.height = 1792;
    const ctx = canvas.getContext("2d");
    ctx.fillStyle = "#142b25";
    ctx.fillRect(0, 0, 1024, 1792);
    ctx.strokeStyle = "#27483a";
    ctx.lineWidth = 2;
    for (let z = 0; z < 1800; z += 74)
      for (let x = 0; x < 1024; x += 74) {
        ctx.beginPath();
        ctx.arc(x + (z % 148 ? 37 : 0), z, 23, 0, Math.PI * 2);
        ctx.stroke();
      }
    ctx.strokeStyle = "#5a9d77";
    ctx.lineWidth = 8;
    for (const x of [100, 180, 260]) {
      ctx.beginPath();
      ctx.moveTo(x, 1450);
      ctx.bezierCurveTo(x + 60, 650, 700, 1200, 770, 420);
      ctx.stroke();
    }
    ctx.strokeStyle = "#aa5161";
    ctx.lineWidth = 16;
    ctx.beginPath();
    ctx.arc(440, 410, 310, Math.PI, Math.PI * 1.9);
    ctx.stroke();
    const map = new THREE.CanvasTexture(canvas);
    map.colorSpace = THREE.SRGBColorSpace;
    this.mesh(
      new THREE.BoxGeometry(4.8, 0.14, 8.25),
      new THREE.MeshStandardMaterial({ map, roughness: 0.7, metalness: 0.05 }),
      0,
      -0.07,
      -0.425,
    );
    this.world.createCollider(
      RAPIER.ColliderDesc.cuboid(2.4, 0.07, 4.125)
        .setTranslation(0, -0.07, -0.425)
        .setFriction(0.03),
    );
    this.rail([-2.4, 3.95], [-2.4, -3.48], 0x8aaba0, 0.2);
    this.rail([2.4, 3.95], [2.4, -3.48], 0x8aaba0, 0.2);
    this.rail([-2.4, -3.48], [-1.5, -4.4], 0x8aaba0, 0.2);
    this.rail([-1.5, -4.4], [1.48, -4.4], 0x8aaba0, 0.2);
    this.rail([1.48, -4.4], [2.4, -3.48], 0x8aaba0, 0.2);
    this.rail([1.76, 3.85], [1.76, -3.35], 0xa9cbbd, 0.12);
    this.box(2.07, 3.85, 0.52, 0.18, 0x596e64);
    this.gate = this.box(2.03, -3.35, 0.54, 0.08, 0xb6d4c1, 0.3);
    this.openGate();
    // The guides end at the outside pivots; the center is an open drain.
    this.rail([-2.32, 2.35], [-1.12, 3.0], 0x8aaba0, 0.16);
    this.rail([1.68, 2.45], [1.12, 3.0], 0x8aaba0, 0.16);
    this.sling([-2.23, 0.88], [-1.15, 1.9], [-2.14, 2.2], CORAL);
    this.sling([1.64, 0.88], [0.95, 1.9], [1.64, 2.2], MINT);
    this.mesh(
      new THREE.BoxGeometry(1.1, 0.1, 0.85),
      this.mat(0x020505),
      0,
      -0.32,
      4,
    );
    this.mesh(
      new THREE.BoxGeometry(5.2, 0.36, 0.38),
      this.mat(0x34564a, 0.8),
      0,
      -0.2,
      4.62,
    );
    this.flippers = [
      this.flipper("left", -1.12, 0.28, -0.57, CORAL),
      this.flipper("right", 1.12, Math.PI - 0.28, Math.PI + 0.57, MINT),
    ];
    this.bumpers = [
      this.bumper(-0.92, -2.1, GOLD, "PEP"),
      this.bumper(0.02, -1.55, MINT, "JACK"),
      this.bumper(0.94, -2.1, CORAL, "PLE"),
    ];
    this.targets = [
      [-2.12, -0.85],
      [-2.12, 0.02],
      [-0.8, -3.45],
      [0.05, -3.45],
      [0.9, -3.45],
    ].map(([x, z], i) => {
      const target = this.box(
        x,
        z,
        i < 2 ? 0.12 : 0.36,
        i < 2 ? 0.42 : 0.12,
        GOLD,
        0.28,
      );
      Object.assign(target, {
        kind: "target",
        index: i,
        lamp: this.lamp(x + (i < 2 ? 0.21 : 0), z + (i < 2 ? 0 : 0.3), GOLD),
      });
      return this.track(target);
    });
    for (let i = 0; i < 18; i++) {
      this.lamp(-2.28, -3.1 + i * 0.37, i % 2 ? CORAL : GOLD, 0.035);
      this.lamp(1.6, -3.1 + i * 0.32, i % 2 ? MINT : GOLD, 0.035);
    }
    for (let i = 0; i < 5; i++) this.lamp(-0.7 + i * 0.34, 0.35, MINT);
    this.label("PEPPLE", 0, 0.032, 0.95, 2.8, 0.57, "#e1fff0");
    this.label("AFTER HOURS", 0, 0.034, 1.37, 2, 0.24, "#7affd3");
    this.label("JACKPOT", 0, 0.034, -0.45, 1.7, 0.3, "#ffda78");
    this.plungerMesh = this.mesh(
      new THREE.CylinderGeometry(0.105, 0.105, 0.48, 20),
      this.mat(0xc5d8ce, 0.95),
      SPAWN.x,
      0.15,
      3.9,
    );
    this.plungerMesh.rotation.x = Math.PI / 2;
    this.plungerLamp = this.lamp(SPAWN.x, 3.14, GOLD);
    this.drainSensor = this.world.createCollider(
      RAPIER.ColliderDesc.cuboid(2.3, 0.5, 0.8)
        .setTranslation(-0.1, -0.55, 4.1)
        .setSensor(true),
    );
  }
  sling(a, b, c, color) {
    const shape = new THREE.Shape();
    shape.moveTo(a[0], -a[1]);
    shape.lineTo(b[0], -b[1]);
    shape.lineTo(c[0], -c[1]);
    shape.closePath();
    const mesh = this.mesh(
      new THREE.ExtrudeGeometry(shape, {
        depth: 0.18,
        bevelEnabled: true,
        bevelSegments: 2,
        bevelSize: 0.025,
        bevelThickness: 0.025,
      }),
      this.mat(color, 0.35, 0.2),
      0,
      0.08,
      0,
    );
    mesh.rotation.x = -Math.PI / 2;
    const vertices = new Float32Array([
      a[0],
      0.07,
      a[1],
      b[0],
      0.07,
      b[1],
      c[0],
      0.07,
      c[1],
      a[0],
      0.28,
      a[1],
      b[0],
      0.28,
      b[1],
      c[0],
      0.28,
      c[1],
    ]);
    const collider = this.world.createCollider(
      RAPIER.ColliderDesc.convexHull(vertices)
        .setRestitution(0.75)
        .setFriction(0.05),
    );
    return this.track({ mesh, collider, kind: "sling", color });
  }
  bumper(x, z, color, name) {
    const body = this.world.createRigidBody(
      RAPIER.RigidBodyDesc.fixed().setTranslation(x, 0.17, z),
    );
    const collider = this.world.createCollider(
      RAPIER.ColliderDesc.cylinder(0.17, 0.33)
        .setRestitution(0.85)
        .setFriction(0),
      body,
    );
    this.mesh(
      new THREE.CylinderGeometry(0.35, 0.4, 0.13, 48),
      this.mat(0xc1d6ca, 0.95),
      x,
      0.08,
      z,
    );
    const mesh = this.mesh(
      new THREE.CylinderGeometry(0.3, 0.32, 0.19, 48),
      this.mat(color, 0.4, 0.25),
      x,
      0.25,
      z,
    );
    const ring = this.mesh(
      new THREE.TorusGeometry(0.31, 0.045, 10, 48),
      this.mat(color, 0.2, 2.4),
      x,
      0.36,
      z,
    );
    ring.rotation.x = -Math.PI / 2;
    this.label(name, x, 0.36, z, 0.48, 0.15, "#10271f");
    return this.track({
      body,
      collider,
      mesh,
      ring,
      x,
      z,
      color,
      kind: "bumper",
      name,
      pulse: 0,
    });
  }
  flipper(side, x, rest, active, color) {
    const len = 0.9,
      body = this.world.createRigidBody(
        RAPIER.RigidBodyDesc.kinematicPositionBased(),
      );
    const collider = this.world.createCollider(
      RAPIER.ColliderDesc.roundCuboid(len / 2 - 0.055, 0.025, 0.035, 0.055)
        .setRestitution(0.32)
        .setFriction(0.12),
      body,
    );
    const mesh = new THREE.Group();
    this.scene.add(mesh);
    const core = new THREE.Mesh(
      new THREE.CapsuleGeometry(0.09, len - 0.18, 6, 12),
      this.mat(0xd8e7da, 0.9),
    );
    core.rotation.z = Math.PI / 2;
    mesh.add(core);
    const stripe = new THREE.Mesh(
      new THREE.BoxGeometry(len * 0.76, 0.025, 0.07),
      this.mat(color, 0.2, 2),
    );
    stripe.position.y = 0.09;
    mesh.add(stripe);
    this.mesh(
      new THREE.CylinderGeometry(0.14, 0.14, 0.25, 24),
      this.mat(0xcbded1, 0.9),
      x,
      0.14,
      3,
    );
    const f = {
      side,
      pivotX: x,
      pivotZ: 3,
      len,
      rest,
      active,
      angle: rest,
      mesh,
      body,
      collider,
    };
    this.track({ collider, kind: "flipper", flipper: f });
    this.syncFlipper(f, true);
    return f;
  }
  syncFlipper(f, instant = false) {
    const pos = {
        x: f.pivotX + (Math.cos(f.angle) * f.len) / 2,
        y: 0.16,
        z: 3 + (Math.sin(f.angle) * f.len) / 2,
      },
      q = new THREE.Quaternion().setFromAxisAngle(AXIS, -f.angle);
    if (instant) {
      f.body.setTranslation(pos, true);
      f.body.setRotation(q, true);
    } else {
      f.body.setNextKinematicTranslation(pos);
      f.body.setNextKinematicRotation(q);
    }
    f.mesh.position.copy(pos);
    f.mesh.quaternion.copy(q);
  }
  spawnBall(ready = true, x = SPAWN.x, z = SPAWN.z) {
    if (ready) this.openGate();
    const desc = (
      ready
        ? RAPIER.RigidBodyDesc.kinematicPositionBased()
        : RAPIER.RigidBodyDesc.dynamic()
    )
      .setTranslation(x, 0.15, z)
      .setCcdEnabled(true)
      .setCanSleep(false)
      .enabledTranslations(true, false, true)
      .setLinearDamping(0.045);
    const body = this.world.createRigidBody(desc);
    const collider = this.world.createCollider(
      RAPIER.ColliderDesc.ball(R)
        .setMass(1)
        .setRestitution(0.48)
        .setFriction(0.05)
        .setActiveEvents(RAPIER.ActiveEvents.COLLISION_EVENTS),
      body,
    );
    const mesh = this.mesh(
      new THREE.SphereGeometry(R, 28, 20),
      new THREE.MeshStandardMaterial({
        color: 0xffffff,
        metalness: 0.94,
        roughness: 0.13,
        envMapIntensity: 2.8,
      }),
      x,
      0.15,
      z,
    );
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute(
      "position",
      new THREE.BufferAttribute(new Float32Array(72), 3),
    );
    const trail = new THREE.Line(
      geometry,
      new THREE.LineBasicMaterial({
        color: MINT,
        transparent: true,
        opacity: 0.38,
        blending: THREE.AdditiveBlending,
        depthWrite: false,
      }),
    );
    trail.frustumCulled = false;
    this.scene.add(trail);
    const ball = {
      body,
      collider,
      mesh,
      trail,
      ready,
      falling: false,
      entered: false,
      history: [],
    };
    this.balls.push(ball);
    return ball;
  }
  reset() {
    this.bestCombo = 0;
    this.balls.slice().forEach((b) => this.deleteBall(b));
    this.score = 0;
    this.ball = 3;
    this.combo = 0;
    this.mult = 1;
    this.bank = 0;
    this.jackpot = 25000;
    this.comboUntil = 0;
    this.plunger = 0;
    this.hits = 0;
    this.drains = 0;
    this.respawnAt = 0;
    this.multiballAt = 0;
    this.paused = false;
    this.saveUntil = 0;
    this.keys = { left: false, right: false, launch: false };
    this.status = "ready";
    this.notice = "SHOOT YOUR SHOT";
    this.flippers.forEach((f) => {
      f.angle = f.rest;
      this.syncFlipper(f, true);
    });
    this.spawnBall();
    this.audio.ensure();
    this.announce("BALL 1", "AFTER HOURS", MINT);
    this.publish();
  }
  charge(down) {
    this.audio.ensure();
    if (this.status !== "ready" || this.paused) return;
    if (!down && !this.keys.launch) return;
    this.keys.launch = down;
    if (!down) this.launch();
  }
  launch() {
    const b = this.balls.find((b) => b.ready);
    if (!b || this.paused || this.status !== "ready") return;
    b.ready = false;
    b.launchedAt = this.time;
    b.body.setBodyType(RAPIER.RigidBodyType.Dynamic, true);
    b.body.setEnabledTranslations(true, false, true, true);
    b.body.enableCcd(true);
    b.body.setLinvel(
      { x: 0, y: 0, z: -(12.5 + Math.min(1, this.plunger) * 2.5) },
      true,
    );
    this.status = "play";
    this.notice = "BALL SAVE";
    this.saveUntil = this.time + 2.5;
    this.plunger = 0;
    this.keys.launch = false;
    this.audio.play("plunger");
    this.publish();
  }
  setFlipper(side, pressed) {
    if (this.paused) return;
    if (pressed && !this.keys[side]) this.audio.play("flipper");
    this.keys[side] = pressed;
  }
  togglePause() {
    if (["menu", "gameover"].includes(this.status)) return;
    this.paused = !this.paused;
    this.keys = { left: false, right: false, launch: false };
    this.last = 0;
    this.acc = 0;
    this.audio.setRolling(0);
    this.publish();
  }
  openGate() {
    this.gate.collider.setEnabled(false);
    this.gate.mesh.position.set(1.76, 0.15, -3.62);
    this.gate.mesh.rotation.y = Math.PI / 2;
  }
  closeGate() {
    this.gate.mesh.position.set(2.03, 0.15, -3.35);
    this.gate.mesh.rotation.y = 0;
    this.gate.collider.setEnabled(true);
  }
  nudge(direction) {
    if (
      this.status !== "play" ||
      this.paused ||
      this.time < (this.nextNudge || 0)
    )
      return;
    this.nextNudge = this.time + 1.2;
    this.balls
      .filter((b) => !b.ready && !b.falling)
      .forEach((b) =>
        b.body.applyImpulse({ x: direction * 0.9, y: 0, z: -0.6 }, true),
      );
    this.shake = 0.04;
  }
  bind() {
    this.onKeyDown = (e) => {
      if (
        /^(INPUT|TEXTAREA|SELECT)$/.test(
          document.activeElement?.tagName || "",
        ) ||
        document.activeElement?.isContentEditable
      )
        return;
      if (["Space", "ArrowLeft", "ArrowRight"].includes(e.code))
        e.preventDefault();
      if (e.repeat) return;
      if (["KeyA", "ArrowLeft"].includes(e.code)) this.setFlipper("left", true);
      if (["KeyD", "ArrowRight"].includes(e.code))
        this.setFlipper("right", true);
      if (e.code === "Space") this.charge(true);
      if (["KeyP", "Escape"].includes(e.code)) this.togglePause();
      if (["KeyQ", "KeyE"].includes(e.code))
        this.nudge(e.code === "KeyQ" ? -1 : 1);
      if (e.code === "F3") {
        this.debug = !this.debug;
        e.preventDefault();
      }
      this.audio.ensure();
    };
    this.onKeyUp = (e) => {
      if (["KeyA", "ArrowLeft"].includes(e.code))
        this.setFlipper("left", false);
      if (["KeyD", "ArrowRight"].includes(e.code))
        this.setFlipper("right", false);
      if (e.code === "Space") {
        e.preventDefault();
        this.charge(false);
      }
    };
    this.onBlur = () => {
      if (!this.paused && ["ready", "play", "drain"].includes(this.status))
        this.togglePause();
    };
    this.onVisibility = () => {
      if (document.hidden) this.onBlur();
    };
    window.addEventListener("keydown", this.onKeyDown);
    window.addEventListener("keyup", this.onKeyUp);
    window.addEventListener("blur", this.onBlur);
    document.addEventListener("visibilitychange", this.onVisibility);
    this.observer = new ResizeObserver(() => this.resize());
    this.observer.observe(this.container);
  }

  step() {
    this.time += STEP;
    if (this.status === "ready" && this.keys.launch)
      this.plunger = Math.min(1, this.plunger + STEP * 0.9);
    this.flippers.forEach((f) => {
      const target = this.keys[f.side] ? f.active : f.rest;
      const before = f.angle;
      f.angle +=
        Math.sign(target - f.angle) *
        Math.min(
          Math.abs(target - f.angle),
          STEP * (this.keys[f.side] ? 17 : 8),
        );
      f.moving = this.keys[f.side] && Math.abs(f.angle - before) > 0.001;
      this.syncFlipper(f);
    });
    this.world.step(this.events);
    this.events.drainCollisionEvents((a, b, started) => {
      if (!started) return;
      const ball = this.balls.find(
        (ball) => ball.collider.handle === a || ball.collider.handle === b,
      );
      if (!ball || ball.ready || ball.falling) return;
      const item = this.contacts.get(ball.collider.handle === a ? b : a);
      if (item) this.contact(ball, item);
    });
    for (const ball of this.balls.slice()) {
      if (ball.ready) continue;
      const p = ball.body.translation(),
        v = ball.body.linvel(),
        speed = Math.hypot(v.x, v.y, v.z);
      if (speed > 16)
        ball.body.setLinvel(
          {
            x: (v.x * 16) / speed,
            y: (v.y * 16) / speed,
            z: (v.z * 16) / speed,
          },
          true,
        );
      if (!ball.entered && p.x < 1.5 && p.z < -2.8) {
        ball.entered = true;
        this.closeGate();
        this.addScore(750, "SKILLSHOT", p, GOLD);
      }
      if (
        !ball.entered &&
        p.x > 1.8 &&
        p.z > 3.2 &&
        speed < 0.15 &&
        this.time - ball.launchedAt > 1
      ) {
        ball.ready = true;
        ball.body.setBodyType(
          RAPIER.RigidBodyType.KinematicPositionBased,
          true,
        );
        this.status = "ready";
        this.notice = "SHOOT AGAIN";
      }
      // The ball physically leaves the floor before descending into the drain sensor.
      if (!ball.falling && p.z > 3.77 && p.x < 1.72) {
        ball.falling = true;
        ball.body.setEnabledTranslations(true, true, true, true);
      }
      if (
        (ball.falling &&
          this.world.intersectionPair(ball.collider, this.drainSensor)) ||
        p.y < -0.9 ||
        p.z > 4.95
      )
        this.drain(ball);
    }
    if (this.time > this.comboUntil) {
      this.combo = 0;
      this.mult = 1;
    }
    if (this.respawnAt && this.time >= this.respawnAt) {
      this.respawnAt = 0;
      this.spawnBall();
      this.status = "ready";
      this.notice = "SHOOT YOUR SHOT";
      this.publish();
    }
    if (this.multiballAt && this.time >= this.multiballAt) {
      this.multiballAt = 0;
      const b = this.spawnBall(false, -0.8, -3.2);
      b.entered = true;
      b.body.setLinvel({ x: 1.8, y: 0, z: 3.4 }, true);
      this.announce("MULTIBALL", "DOUBLE TROUBLE", CORAL);
      this.audio.play("jackpot");
    }
  }
  contact(ball, item) {
    if (this.time - item.lastHit < 0.13) return;
    item.lastHit = this.time;
    const p = ball.body.translation();
    if (item.kind === "flipper") {
      const f = item.flipper;
      // Holding a flipper no longer provides an automatic powered rescue.
      if (!this.keys[f.side] || !f.moving) return;
      const t = Math.max(
          0.15,
          Math.min(1, Math.hypot(p.x - f.pivotX, p.z - 3) / f.len),
        ),
        v = ball.body.linvel();
      if (v.z > -6 || f.moving) {
        ball.body.setLinvel(
          {
            x: (f.side === "left" ? 1 : -1) * (1.3 + t * 2.9),
            y: 0,
            z: -(8.2 + t * 4.4),
          },
          true,
        );
        this.burst(p, 0xffffff, 8);
      }
      return;
    }
    if (item.kind === "bumper") {
      const dx = p.x - item.x,
        dz = p.z - item.z,
        len = Math.hypot(dx, dz) || 1,
        v = ball.body.linvel(),
        kick = Math.max(0, 7.2 - ((v.x * dx) / len + (v.z * dz) / len));
      ball.body.applyImpulse(
        { x: (dx / len) * kick, y: 0, z: (dz / len) * kick },
        true,
      );
      item.pulse = 1;
      if (item.name === "JACK" && this.bank === 31) {
        const prize = this.jackpot;
        const awarded = this.addScore(prize, "JACKPOT", p, GOLD);
        this.announce("JACKPOT", "+" + awarded.toLocaleString("de-DE"), GOLD);
        this.bank = 0;
        this.jackpot = 25000;
        this.audio.play("jackpot");
        if (this.balls.length === 1 && !this.multiballAt)
          this.multiballAt = this.time + 0.8;
      } else {
        this.addScore(500, item.name, p, item.color);
        this.audio.play("bumper");
      }
    } else if (item.kind === "target") {
      const previousBank = this.bank;
      this.bank |= 1 << item.index;
      item.lamp.pulse = 1.2;
      this.addScore(1000, "TARGET", p, GOLD);
      this.audio.play("target");
      if (this.bank === 31 && previousBank !== 31)
        this.announce("JACKPOT LIT", "HIT JACK", GOLD);
    } else if (item.kind === "sling") {
      const v = ball.body.linvel();
      ball.body.setLinvel(
        { x: (p.x < 0 ? 1 : -1) * 4.8, y: 0, z: Math.min(v.z, -2.6) },
        true,
      );
      this.addScore(250, "SLING", p, item.color);
      this.audio.play("sling");
    }
  }
  addScore(points, label, p, color = MINT) {
    if (this.status !== "play") return;
    this.combo = this.time < this.comboUntil ? this.combo + 1 : 1;
    this.bestCombo = Math.max(this.bestCombo, this.combo);
    this.comboUntil = this.time + 2.2;
    this.mult = Math.min(6, 1 + Math.floor(this.combo / 4));
    const awarded = points * this.mult;
    this.score += awarded;
    this.jackpot += Math.round(points * 0.2);
    this.hits++;
    this.burst(p, color, this.mult > 2 ? 24 : 14);
    this.popup(awarded, label, p, color);
    this.flash = 1;
    this.shake = 0.02;
    this.impactLight.color.setHex(color);
    this.impactLight.position.set(p.x, 1.5, p.z);
    if (this.combo >= 3)
      this.announce(
        this.combo + " HIT COMBO",
        "x" + this.mult + "  +" + awarded.toLocaleString("de-DE"),
        color,
      );
    if (this.combo >= 3 && this.combo % 3 === 0)
      this.audio.play("combo", this.mult);
    this.notice = label;
    this.publish();
    return awarded;
  }
  drain(ball) {
    this.deleteBall(ball);
    this.drains++;
    if (this.balls.length) return;
    const saved = this.time < (this.saveUntil || 0);
    if (!saved) this.ball--;
    this.combo = 0;
    this.mult = 1;
    this.comboUntil = 0;
    this.plunger = 0;
    this.audio.play("drain");
    if (this.ball <= 0) {
      this.status = "gameover";
      this.notice = "GAME OVER";
      this.announce("GAME OVER", this.score.toLocaleString("de-DE"), CORAL);
    } else {
      this.status = "drain";
      this.respawnAt = this.time + 1;
      this.announce(
        saved ? "BALL SAVED" : "DRAIN",
        saved ? "SHOOT AGAIN" : this.ball + " BALLS LEFT",
        saved ? MINT : CORAL,
      );
    }
    this.publish();
  }
  deleteBall(ball) {
    this.scene.remove(ball.mesh, ball.trail);
    ball.mesh.geometry.dispose();
    ball.mesh.material.dispose();
    ball.trail.geometry.dispose();
    ball.trail.material.dispose();
    this.world.removeRigidBody(ball.body);
    this.balls = this.balls.filter((b) => b !== ball);
  }

  initParticles() {
    this.positions = new Float32Array(1152);
    this.colors = new Float32Array(1152);
    const g = new THREE.BufferGeometry();
    g.setAttribute("position", new THREE.BufferAttribute(this.positions, 3));
    g.setAttribute("color", new THREE.BufferAttribute(this.colors, 3));
    g.setDrawRange(0, 0);
    this.particles = new THREE.Points(
      g,
      new THREE.PointsMaterial({
        size: 0.055,
        vertexColors: true,
        transparent: true,
        opacity: 0.9,
        blending: THREE.AdditiveBlending,
        depthWrite: false,
      }),
    );
    this.particles.frustumCulled = false;
    this.scene.add(this.particles);
  }
  burst(p, hex, count) {
    const color = new THREE.Color(hex);
    for (let i = 0; i < count; i++) {
      const a = Math.random() * Math.PI * 2;
      this.specks.push({
        x: p.x,
        y: 0.3,
        z: p.z,
        vx: Math.cos(a) * (1 + Math.random() * 2),
        vy: 1 + Math.random() * 2,
        vz: Math.sin(a) * (1 + Math.random() * 2),
        life: 0.6,
        color,
      });
    }
    this.specks = this.specks.slice(-384);
    const ring = this.mesh(
      new THREE.TorusGeometry(0.16, 0.012, 5, 32),
      new THREE.MeshBasicMaterial({
        color: hex,
        transparent: true,
        opacity: 0.9,
        blending: THREE.AdditiveBlending,
        depthWrite: false,
      }),
      p.x,
      0.06,
      p.z,
    );
    ring.rotation.x = -Math.PI / 2;
    this.effects.push({ mesh: ring, life: 0.5 });
  }
  popup(points, label, p, color) {
    const pos = new THREE.Vector3(p.x, 0.45, p.z).project(this.camera),
      e = document.createElement("div");
    e.className = "pinballFloat";
    e.style.left = (pos.x + 1) * 50 + "%";
    e.style.top = (1 - pos.y) * 50 + "%";
    e.style.color = "#" + color.toString(16).padStart(6, "0");
    const name = document.createElement("span"),
      amount = document.createElement("strong");
    name.textContent = label;
    amount.textContent = "+" + points.toLocaleString("de-DE");
    e.append(name, amount);
    this.fx.appendChild(e);
    this.effects.push({ element: e, life: 0.95 });
  }
  announce(title, subtitle, color) {
    const main = document.createElement("strong"),
      sub = document.createElement("span");
    main.textContent = title;
    sub.textContent = subtitle;
    this.banner.replaceChildren(main, sub);
    this.banner.style.color = "#" + color.toString(16).padStart(6, "0");
    this.bannerAnimation?.cancel();
    this.bannerAnimation = this.banner.animate(
      [
        { opacity: 0, transform: "translate(-50%,-50%) scale(.72)" },
        {
          opacity: 1,
          transform: "translate(-50%,-50%) scale(1.08)",
          offset: 0.15,
        },
        {
          opacity: 1,
          transform: "translate(-50%,-50%) scale(1)",
          offset: 0.65,
        },
        { opacity: 0, transform: "translate(-50%,-60%) scale(1.03)" },
      ],
      { duration: 1300, fill: "forwards", easing: "ease-out" },
    );
  }
  visuals(dt) {
    this.balls.forEach((b) => {
      const p = b.body.translation();
      b.mesh.position.copy(p);
      b.mesh.quaternion.copy(b.body.rotation());
      if (!b.ready) {
        b.history.unshift(new THREE.Vector3(p.x, p.y, p.z));
        b.history = b.history.slice(0, 24);
      }
      const a = b.trail.geometry.attributes.position.array;
      for (let i = 0; i < 24; i++) {
        const q = b.history[i] || b.mesh.position;
        a.set([q.x, q.y, q.z], i * 3);
      }
      b.trail.visible = !b.ready && !b.falling;
      b.trail.geometry.attributes.position.needsUpdate = true;
    });
    this.lamps.forEach((l) => {
      l.pulse = Math.max(0, l.pulse - dt * 2.5);
      l.material.emissiveIntensity =
        0.4 +
        Math.max(0, Math.sin(this.time * 3 + l.offset)) * 0.7 +
        l.pulse * 3;
    });
    this.targets.forEach((t) => {
      if (this.bank & (1 << t.index)) t.lamp.material.emissiveIntensity = 2.8;
    });
    this.bumpers.forEach((b) => {
      b.pulse = Math.max(0, b.pulse - dt * 3);
      b.mesh.position.y = 0.25 - b.pulse * 0.05;
      b.ring.material.emissiveIntensity = 1.3 + b.pulse * 5;
      b.ring.scale.setScalar(1 + b.pulse * 0.15);
    });
    this.plungerMesh.position.z = 3.9 + this.plunger * 0.25;
    this.plungerLamp.material.emissiveIntensity = 0.4 + this.plunger * 4;
    this.flash = Math.max(0, (this.flash || 0) - dt * 4);
    this.impactLight.intensity = this.flash * 1.6;
    this.bloom.strength = 0.42 + this.flash * 0.1;
    this.shake = Math.max(0, (this.shake || 0) - dt * 0.2);
    this.camera.position.x = Math.sin(this.time * 80) * this.shake;
    this.specks = this.specks.filter((p) => p.life > 0);
    this.specks.forEach((p, i) => {
      p.life -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.z += p.vz * dt;
      p.vy -= dt * 6;
      this.positions.set([p.x, p.y, p.z], i * 3);
      this.colors.set(
        [p.color.r * p.life, p.color.g * p.life, p.color.b * p.life],
        i * 3,
      );
    });
    this.particles.geometry.setDrawRange(0, this.specks.length);
    this.particles.geometry.attributes.position.needsUpdate = true;
    this.particles.geometry.attributes.color.needsUpdate = true;
    this.effects = this.effects.filter((e) => {
      e.life -= dt;
      if (e.mesh) {
        e.mesh.scale.addScalar(dt * 4);
        e.mesh.material.opacity = Math.max(0, e.life * 1.8);
      }
      if (e.life > 0) return true;
      e.element?.remove();
      if (e.mesh) {
        this.scene.remove(e.mesh);
        e.mesh.geometry.dispose();
        e.mesh.material.dispose();
      }
      return false;
    });
    this.audio.setRolling(
      Math.max(
        0,
        ...this.balls
          .filter((b) => !b.ready)
          .map((b) => {
            const v = b.body.linvel();
            return Math.hypot(v.x, v.z);
          }),
      ),
    );
  }
  drawDebug() {
    if (!this.debug) {
      if (this.debugMesh) this.debugMesh.visible = false;
      return;
    }
    const data = this.world.debugRender();
    if (!this.debugMesh) {
      this.debugMesh = new THREE.LineSegments(
        new THREE.BufferGeometry(),
        new THREE.LineBasicMaterial({ color: 0xeaff7c, depthTest: false }),
      );
      this.debugMesh.renderOrder = 99;
      this.scene.add(this.debugMesh);
    }
    this.debugMesh.visible = true;
    this.debugMesh.geometry.setAttribute(
      "position",
      new THREE.BufferAttribute(data.vertices, 3),
    );
    this.debugMesh.geometry.computeBoundingSphere();
  }
  loop(t) {
    if (this.disposed) return;
    const dt = Math.min(0.05, Math.max(0, (t - (this.last || t)) / 1000));
    this.last = t;
    if (!this.paused) {
      this.acc += dt;
      while (this.acc >= STEP) {
        this.step();
        this.acc -= STEP;
      }
      this.visuals(dt);
    }
    this.drawDebug();
    this.composer.render();
    if (t - (this.lastSnapshot || 0) > 100) {
      this.publish();
      this.lastSnapshot = t;
    }
    this.frame = requestAnimationFrame((t) => this.loop(t));
  }
  publish() {
    this.onSnapshot({
      status: this.paused ? "paused" : this.status,
      score: this.score,
      balls: this.ball,
      combo: this.combo,
      mult: this.mult,
      jackpot: this.jackpot,
      bank: this.bank,
      plunger: this.plunger,
      comboRemaining: Math.max(0, (this.comboUntil - this.time) / 3.2),
      ballSave: this.time < (this.saveUntil || 0) && this.status === "play",
      notice: this.notice,
      level: 1 + Math.floor(this.score / 25000),
      streak: this.bestCombo,
    });
  }
  getPhysicsDiagnostics() {
    return {
      physicsHz: 120,
      ballRadius: R,
      maxSpeed: 16,
      hits: this.hits,
      drains: this.drains,
      drainGap: 0.3,
      liveBalls: this.balls.map((b) => ({
        ready: b.ready,
        entered: b.entered,
        falling: b.falling,
        ccd: b.body.isCcdEnabled(),
        position: b.body.translation(),
        velocity: b.body.linvel(),
      })),
    };
  }
  resize() {
    if (!this.renderer || this.disposed) return;
    const r = this.container.getBoundingClientRect(),
      w = Math.max(1, r.width),
      h = Math.max(1, r.height),
      view = Math.max(9.8, 5.7 / (w / h));
    this.camera.left = (-view * w) / h / 2;
    this.camera.right = -this.camera.left;
    this.camera.top = view / 2;
    this.camera.bottom = -view / 2;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h, false);
    this.composer.setSize(w, h);
  }
  dispose() {
    if (this.disposed) return;
    this.disposed = true;
    cancelAnimationFrame(this.frame);
    window.removeEventListener("keydown", this.onKeyDown);
    window.removeEventListener("keyup", this.onKeyUp);
    window.removeEventListener("blur", this.onBlur);
    document.removeEventListener("visibilitychange", this.onVisibility);
    this.observer?.disconnect();
    this.bannerAnimation?.cancel();
    this.audio.dispose();
    this.scene?.traverse((o) => {
      o.geometry?.dispose();
      if (o.material)
        for (const m of Array.isArray(o.material) ? o.material : [o.material]) {
          m.map?.dispose();
          m.dispose();
        }
    });
    this.environment?.dispose();
    this.bloom?.dispose();
    this.composer?.dispose();
    this.renderer?.dispose();
    this.events?.free();
    this.world?.free();
    if (this.container.__pinballGame === this)
      delete this.container.__pinballGame;
    this.container.replaceChildren();
  }
}
