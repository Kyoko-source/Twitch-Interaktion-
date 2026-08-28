import * as THREE from "three";
import RAPIER from "@dimforge/rapier3d-compat";
import { AudioManager } from "./AudioManager";

const FIXED_STEP = 1 / 120;
const BALL_RADIUS = 0.115;
const TABLE = { width: 4.8, length: 8.2, top: -3.75, bottom: 3.75, left: -2.15, right: 2.15, laneX: 1.82 };

const MATERIALS = {
  wood: { color: 0x3a160c, roughness: 0.45, metalness: 0.1 },
  rail: { color: 0xd8c6a0, roughness: 0.18, metalness: 0.9 },
  rubber: { color: 0x111018, roughness: 0.72, metalness: 0.02 },
  plastic: { color: 0xff4fa2, roughness: 0.28, metalness: 0.08, emissive: 0x39112a },
  cyan: { color: 0x62f4df, roughness: 0.22, metalness: 0.1, emissive: 0x0d766c },
  gold: { color: 0xffcc72, roughness: 0.22, metalness: 0.55, emissive: 0x4a2508 },
};

export class PinballGame {
  constructor(container, { audioEnabledRef, onSnapshot, onMessage } = {}) {
    this.container = container;
    this.onSnapshot = onSnapshot || (() => {});
    this.onMessage = onMessage || (() => {});
    this.audio = new AudioManager(audioEnabledRef || { current: true });
    this.keys = { left: false, right: false, launch: false, nudgeL: false, nudgeR: false, nudgeF: false };
    this.score = 0;
    this.ball = 3;
    this.mult = 1;
    this.locks = 0;
    this.jackpot = 25000;
    this.comboT = 0;
    this.status = "ready";
    this.notice = "PEPPLE 3D PINBALL";
    this.plunger = 0;
    this.acc = 0;
    this.last = 0;
    this.disposed = false;
    this.balls = [];
    this.effects = [];
    this.targets = [];
    this.bumpers = [];
    this.rollovers = [];
    this.ramps = [];
    this.scoops = [];
    this.flippers = [];
    this.debug = false;
    this.tilt = { heat: 0, warning: 0, active: false };
    this.snapshotT = 0;
  }

  async start() {
    await RAPIER.init();
    this.initThree();
    this.initPhysics();
    this.buildTable();
    this.bind();
    this.spawnBall(true);
    this.resize();
    this.frame = requestAnimationFrame((t) => this.loop(t));
    this.emitSnapshot();
  }

  initThree() {
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x09050b);
    this.camera = new THREE.PerspectiveCamera(42, 1, 0.1, 80);
    this.camera.position.set(0, 6.0, 6.35);
    this.camera.lookAt(0, 0, -0.35);
    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false, powerPreference: "high-performance" });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFShadowMap;
    this.container.replaceChildren(this.renderer.domElement);
    this.renderer.domElement.className = "pinball3dCanvas";
    this.scene.add(new THREE.HemisphereLight(0xffd8ad, 0x14102a, 1.25));
    const key = new THREE.SpotLight(0xffc47a, 3.4, 20, 0.78, 0.6, 1.1);
    key.position.set(-1.6, 7.4, 4.6);
    key.castShadow = true;
    this.scene.add(key);
    const neon = new THREE.PointLight(0xff4fa2, 2.3, 8);
    neon.position.set(0, 1.7, -0.8);
    this.scene.add(neon);
    this.cameraModes = [
      { p: new THREE.Vector3(0, 6.0, 6.35), l: new THREE.Vector3(0, 0, -0.35) },
      { p: new THREE.Vector3(0, 9.6, 0.25), l: new THREE.Vector3(0, 0, 0) },
      { p: new THREE.Vector3(-2.8, 4.3, 5.6), l: new THREE.Vector3(0, 0, -0.5) },
    ];
    this.cameraMode = 0;
  }

  initPhysics() {
    this.world = new RAPIER.World({ x: 0, y: -9.81, z: 3.7 });
    this.world.integrationParameters.dt = FIXED_STEP;
  }

  mat(kind) {
    return new THREE.MeshStandardMaterial(MATERIALS[kind] || MATERIALS.rubber);
  }

  addBox(name, pos, size, mat = "rubber", fixed = true, sensor = false) {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(size.x, size.y, size.z), this.mat(mat));
    mesh.position.copy(pos);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    this.scene.add(mesh);
    const desc = fixed ? RAPIER.RigidBodyDesc.fixed() : RAPIER.RigidBodyDesc.dynamic();
    desc.setTranslation(pos.x, pos.y, pos.z);
    const body = this.world.createRigidBody(desc);
    const col = RAPIER.ColliderDesc.cuboid(size.x / 2, size.y / 2, size.z / 2).setRestitution(0.55).setFriction(0.32);
    if (sensor) col.setSensor(true);
    const collider = this.world.createCollider(col, body);
    return { name, mesh, body, collider, size };
  }

  addCylinder(name, pos, radius, height, mat = "rubber", sensor = false) {
    const mesh = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, height, 40), this.mat(mat));
    mesh.position.copy(pos);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    this.scene.add(mesh);
    const bodyDesc = RAPIER.RigidBodyDesc.fixed().setTranslation(pos.x, pos.y, pos.z);
    const body = this.world.createRigidBody(bodyDesc);
    const col = RAPIER.ColliderDesc.cylinder(height / 2, radius).setRestitution(0.72).setFriction(0.22);
    if (sensor) col.setSensor(true);
    const collider = this.world.createCollider(col, body);
    return { name, mesh, body, collider, radius };
  }

  addLightInsert(x, z, color, label) {
    const mesh = new THREE.Mesh(new THREE.CylinderGeometry(0.13, 0.13, 0.025, 28), new THREE.MeshStandardMaterial({
      color,
      emissive: color,
      emissiveIntensity: 1.2,
      roughness: 0.22,
      metalness: 0.1,
    }));
    mesh.position.set(x, 0.065, z);
    this.scene.add(mesh);
    const light = new THREE.PointLight(color, 0.8, 1.25);
    light.position.set(x, 0.22, z);
    this.scene.add(light);
    return { mesh, light, label };
  }

  buildTable() {
    this.playfield = new THREE.Group();
    this.scene.add(this.playfield);
    const floor = new THREE.Mesh(new THREE.BoxGeometry(TABLE.width, 0.12, TABLE.length), this.makePlayfieldMaterial());
    floor.position.set(0, -0.06, 0);
    floor.receiveShadow = true;
    this.scene.add(floor);
    this.world.createCollider(RAPIER.ColliderDesc.cuboid(TABLE.width / 2, 0.06, TABLE.length / 2).setFriction(0.24).setRestitution(0.34), this.world.createRigidBody(RAPIER.RigidBodyDesc.fixed().setTranslation(0, -0.06, 0)));

    this.addBox("left-wall", new THREE.Vector3(TABLE.left - 0.08, 0.2, 0), new THREE.Vector3(0.16, 0.42, TABLE.length), "wood");
    this.addBox("right-wall", new THREE.Vector3(TABLE.right + 0.08, 0.2, 0), new THREE.Vector3(0.16, 0.42, TABLE.length), "wood");
    this.addBox("top-wall", new THREE.Vector3(0, 0.2, TABLE.top - 0.08), new THREE.Vector3(TABLE.width, 0.42, 0.16), "wood");
    this.addBox("left-outlane", new THREE.Vector3(-1.85, 0.16, 2.25), new THREE.Vector3(0.16, 0.32, 1.9), "rubber");
    this.addBox("right-outlane", new THREE.Vector3(1.85, 0.16, 2.25), new THREE.Vector3(0.16, 0.32, 1.9), "rubber");
    this.addBox("shooter-left", new THREE.Vector3(TABLE.laneX - 0.18, 0.16, 0.8), new THREE.Vector3(0.08, 0.32, 5.6), "rail");
    this.addBox("shooter-right", new THREE.Vector3(TABLE.right - 0.12, 0.16, 0.8), new THREE.Vector3(0.08, 0.32, 5.7), "rail");
    this.addBox("plunger-rail", new THREE.Vector3(2.0, 0.09, 3.25), new THREE.Vector3(0.42, 0.18, 0.08), "rail");
    this.addBox("apron", new THREE.Vector3(0, 0.08, 3.54), new THREE.Vector3(2.15, 0.16, 0.24), "gold");

    this.buildCabinet();
    this.buildFlippers();
    this.buildToys();
    this.buildDisplay();
  }

  makePlayfieldMaterial() {
    const canvas = document.createElement("canvas");
    canvas.width = 1024;
    canvas.height = 1748;
    const ctx = canvas.getContext("2d");
    const grd = ctx.createLinearGradient(0, 0, 0, canvas.height);
    grd.addColorStop(0, "#140d20");
    grd.addColorStop(0.42, "#2b1028");
    grd.addColorStop(0.78, "#160d18");
    grd.addColorStop(1, "#080608");
    ctx.fillStyle = grd;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.strokeStyle = "rgba(255,205,112,.26)";
    ctx.lineWidth = 3;
    for (let i = -8; i <= 8; i += 1) {
      ctx.beginPath();
      ctx.moveTo(canvas.width / 2 + i * 70, canvas.height - 70);
      ctx.quadraticCurveTo(canvas.width / 2 + i * 28, canvas.height * 0.55, canvas.width / 2 + i * 96, 120);
      ctx.stroke();
    }
    ctx.strokeStyle = "rgba(98,244,223,.45)";
    ctx.lineWidth = 18;
    ctx.beginPath();
    ctx.moveTo(210, 1200);
    ctx.bezierCurveTo(280, 880, 520, 720, 770, 580);
    ctx.stroke();
    ctx.strokeStyle = "rgba(255,79,162,.46)";
    ctx.lineWidth = 10;
    ctx.beginPath();
    ctx.moveTo(790, 260);
    ctx.bezierCurveTo(650, 120, 360, 100, 205, 280);
    ctx.stroke();
    ctx.fillStyle = "rgba(255,236,194,.92)";
    ctx.font = "900 105px Arial";
    ctx.textAlign = "center";
    ctx.fillText("PEPPLE", canvas.width / 2, 1170);
    ctx.font = "800 42px Arial";
    ctx.fillStyle = "rgba(255,202,112,.92)";
    ctx.fillText("LOCK  RAMP  JACKPOT", canvas.width / 2, 1240);
    const tex = new THREE.CanvasTexture(canvas);
    tex.colorSpace = THREE.SRGBColorSpace;
    tex.anisotropy = 8;
    return new THREE.MeshStandardMaterial({ map: tex, roughness: 0.34, metalness: 0.04 });
  }

  buildCabinet() {
    const frame = new THREE.Mesh(new THREE.BoxGeometry(5.4, 0.35, 8.9), new THREE.MeshStandardMaterial({ color: 0x39180d, roughness: 0.44, metalness: 0.08 }));
    frame.position.set(0, -0.24, 0.08);
    frame.receiveShadow = true;
    this.scene.add(frame);
    const glass = new THREE.Mesh(new THREE.BoxGeometry(4.85, 0.025, 8.15), new THREE.MeshPhysicalMaterial({
      color: 0xdaf7ff,
      roughness: 0.03,
      metalness: 0,
      transparent: true,
      opacity: 0.12,
      transmission: 0.45,
    }));
    glass.position.set(0, 0.48, 0);
    this.scene.add(glass);
  }

  buildFlippers() {
    this.flippers = [
      this.createFlipper("left", -0.82, 3.06, -0.16, -0.88),
      this.createFlipper("right", 0.82, 3.06, Math.PI + 0.16, Math.PI + 0.88),
    ];
  }

  createFlipper(side, pivotX, pivotZ, rest, active) {
    const len = 0.98;
    const width = 0.22;
    const mat = new THREE.MeshStandardMaterial({ color: side === "left" ? 0xff4f9b : 0x60f5dd, emissive: side === "left" ? 0x50122d : 0x0d5d57, roughness: 0.3, metalness: 0.25 });
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(len, 0.16, width), mat);
    mesh.castShadow = true;
    this.scene.add(mesh);
    const body = this.world.createRigidBody(RAPIER.RigidBodyDesc.kinematicPositionBased());
    const collider = this.world.createCollider(RAPIER.ColliderDesc.cuboid(len / 2, 0.08, width / 2).setRestitution(0.2).setFriction(0.65), body);
    const joint = this.addCylinder(`${side}-pivot`, new THREE.Vector3(pivotX, 0.16, pivotZ), 0.15, 0.22, "gold");
    const f = { side, pivotX, pivotZ, rest, active, angle: rest, target: rest, len, mesh, body, collider, joint };
    this.syncFlipper(f, true);
    return f;
  }

  syncFlipper(f, instant = false) {
    const centerX = f.pivotX + Math.cos(f.angle) * f.len * 0.5;
    const centerZ = f.pivotZ + Math.sin(f.angle) * f.len * 0.5;
    const q = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), -f.angle);
    f.mesh.position.set(centerX, 0.17, centerZ);
    f.mesh.quaternion.copy(q);
    const rot = { x: q.x, y: q.y, z: q.z, w: q.w };
    const pos = { x: centerX, y: 0.17, z: centerZ };
    if (instant) {
      f.body.setTranslation(pos, true);
      f.body.setRotation(rot, true);
    } else {
      f.body.setNextKinematicTranslation(pos);
      f.body.setNextKinematicRotation(rot);
    }
  }

  buildToys() {
    this.bumpers = [
      this.createBumper(-0.82, -2.05, 0xffc66d, "PEP"),
      this.createBumper(0, -1.82, 0x62f4df, "JACK"),
      this.createBumper(0.82, -2.05, 0xff4fa2, "PLE"),
    ];
    [-1.5, -0.9, -0.3, 0.3, 0.9, 1.5].forEach((x, i) => {
      const sensor = this.addBox(`rollover-${i}`, new THREE.Vector3(x, 0.06, -3.18), new THREE.Vector3(0.28, 0.08, 0.12), "gold", true, true);
      const light = this.addLightInsert(x, -3.04, 0xffcc72, "rollover");
      this.rollovers.push({ ...sensor, light, hit: false, score: 100 });
    });
    [
      [-1.38, -0.85], [-1.34, 0.22], [-1.08, 1.4],
      [1.38, -0.85], [1.34, 0.22], [1.08, 1.4],
      [-0.42, 0.52], [0, 0.52], [0.42, 0.52],
    ].forEach(([x, z], i) => {
      const post = this.addCylinder(`post-${i}`, new THREE.Vector3(x, 0.14, z), 0.095, 0.28, i % 2 ? "cyan" : "gold");
      this.targets.push({ ...post, score: 250, label: "TARGET" });
    });
    this.addBox("left-sling", new THREE.Vector3(-1.18, 0.18, 1.72), new THREE.Vector3(1.05, 0.28, 0.16), "plastic");
    this.addBox("right-sling", new THREE.Vector3(1.18, 0.18, 1.72), new THREE.Vector3(1.05, 0.28, 0.16), "plastic");
    this.scoops.push(this.addCylinder("scoop", new THREE.Vector3(1.05, 0.05, -0.55), 0.22, 0.08, "rubber", true));
    this.scoops.push(this.addCylinder("lock", new THREE.Vector3(1.28, 0.05, 0.68), 0.22, 0.08, "rubber", true));
    this.buildRamp();
  }

  createBumper(x, z, color, label) {
    const base = this.addCylinder(`bumper-${label}`, new THREE.Vector3(x, 0.18, z), 0.32, 0.32, "gold");
    base.mesh.material = new THREE.MeshStandardMaterial({ color, emissive: color, emissiveIntensity: 0.6, roughness: 0.25, metalness: 0.35 });
    const light = new THREE.PointLight(color, 1.4, 1.6);
    light.position.set(x, 0.72, z);
    this.scene.add(light);
    return { ...base, label, light, pulse: 0, score: 500 };
  }

  buildRamp() {
    const rampMat = new THREE.MeshPhysicalMaterial({ color: 0x8ff7e8, roughness: 0.08, transparent: true, opacity: 0.38, transmission: 0.45, metalness: 0.05 });
    const points = [
      new THREE.Vector3(-1.42, 0.18, 1.0),
      new THREE.Vector3(-1.0, 0.42, 0.0),
      new THREE.Vector3(-0.15, 0.72, -0.78),
      new THREE.Vector3(0.85, 0.58, -1.28),
      new THREE.Vector3(1.44, 0.22, -2.22),
    ];
    const curve = new THREE.CatmullRomCurve3(points);
    const tube = new THREE.Mesh(new THREE.TubeGeometry(curve, 48, 0.07, 10, false), rampMat);
    tube.castShadow = true;
    this.scene.add(tube);
    points.forEach((p, i) => {
      const seg = this.addBox(`ramp-col-${i}`, p, new THREE.Vector3(0.34, 0.08, 0.34), "cyan");
      seg.collider.setSensor(true);
      this.ramps.push({ ...seg, score: 1500 });
    });
  }

  buildDisplay() {
    const panel = new THREE.Mesh(new THREE.BoxGeometry(3.9, 0.18, 0.55), new THREE.MeshStandardMaterial({ color: 0x090406, emissive: 0x1a0900, roughness: 0.4 }));
    panel.position.set(0, 0.55, -3.78);
    this.scene.add(panel);
    this.displayCanvas = document.createElement("canvas");
    this.displayCanvas.width = 1024;
    this.displayCanvas.height = 160;
    this.displayTexture = new THREE.CanvasTexture(this.displayCanvas);
    const dmd = new THREE.Mesh(new THREE.PlaneGeometry(3.6, 0.42), new THREE.MeshBasicMaterial({ map: this.displayTexture, transparent: true }));
    dmd.position.set(0, 0.66, -3.48);
    dmd.rotation.x = -0.22;
    this.scene.add(dmd);
  }

  spawnBall(ready = false, x = 1.97, z = 3.2) {
    const mesh = new THREE.Mesh(new THREE.SphereGeometry(BALL_RADIUS, 36, 24), new THREE.MeshStandardMaterial({ color: 0xdfe7ef, roughness: 0.18, metalness: 1 }));
    mesh.castShadow = true;
    this.scene.add(mesh);
    const body = this.world.createRigidBody(RAPIER.RigidBodyDesc.dynamic().setTranslation(x, 0.35, z).setCanSleep(false).setCcdEnabled(true));
    body.setLinearDamping(0.08);
    body.setAngularDamping(0.05);
    const collider = this.world.createCollider(RAPIER.ColliderDesc.ball(BALL_RADIUS).setDensity(7.8).setRestitution(0.52).setFriction(0.14), body);
    const ball = { mesh, body, collider, ready, locked: false, lastSafe: new THREE.Vector3(x, 0.35, z) };
    this.balls.push(ball);
    this.status = ready ? "ready" : "play";
    this.notice = ready ? "HOLD SPACE" : "SHOOT AGAIN";
    return ball;
  }

  launch() {
    if (this.status !== "ready" || !this.balls[0]) return;
    const ball = this.balls[0];
    const power = Math.max(0.25, this.plunger);
    ball.ready = false;
    ball.body.setTranslation({ x: 1.97, y: 0.35, z: 3.2 }, true);
    ball.body.setLinvel({ x: -0.25 - power * 0.6, y: 0.35, z: -13.5 - power * 9.5 }, true);
    ball.body.setAngvel({ x: -30 * power, y: 0, z: 0 }, true);
    this.status = "play";
    this.notice = power > 0.8 ? "SKILLSHOT" : "LAUNCH";
    this.addScore(0, this.notice);
    this.flash(1.2, 0xffcc72, 1.4);
    this.audio.play("plunger", 0.9 + power);
    this.plunger = 0;
  }

  bind() {
    this.onKeyDown = (event) => {
      if (event.code === "Space") { this.keys.launch = true; event.preventDefault(); }
      if (event.key === "a" || event.key === "A" || event.key === "ArrowLeft") this.keys.left = true;
      if (event.key === "d" || event.key === "D" || event.key === "ArrowRight") this.keys.right = true;
      if (event.key === "q" || event.key === "Q") this.nudge(-1);
      if (event.key === "e" || event.key === "E") this.nudge(1);
      if (event.key === "w" || event.key === "W") this.nudge(0);
      if (event.key === "c" || event.key === "C") this.switchCamera();
      if (event.key === "F3") { this.debug = !this.debug; event.preventDefault(); }
      this.audio.ensure();
    };
    this.onKeyUp = (event) => {
      if (event.code === "Space") { this.keys.launch = false; this.launch(); event.preventDefault(); }
      if (event.key === "a" || event.key === "A" || event.key === "ArrowLeft") { this.keys.left = false; this.audio.play("flipperDown"); }
      if (event.key === "d" || event.key === "D" || event.key === "ArrowRight") { this.keys.right = false; this.audio.play("flipperDown"); }
    };
    this.onResize = () => this.resize();
    window.addEventListener("keydown", this.onKeyDown);
    window.addEventListener("keyup", this.onKeyUp);
    window.addEventListener("resize", this.onResize);
  }

  nudge(dir) {
    if (this.tilt.active) return;
    this.tilt.heat += 1;
    if (this.tilt.heat > 5) {
      this.tilt.active = true;
      this.notice = "TILT";
      this.audio.play("tilt");
      return;
    }
    if (this.tilt.heat > 3) this.notice = "WARNING";
    this.balls.forEach((ball) => ball.body.applyImpulse({ x: dir * 1.6, y: 0, z: dir === 0 ? -1.2 : 0.5 }, true));
  }

  switchCamera() {
    this.cameraMode = (this.cameraMode + 1) % this.cameraModes.length;
    const mode = this.cameraModes[this.cameraMode];
    this.camera.position.copy(mode.p);
    this.camera.lookAt(mode.l);
  }

  step(dt) {
    if (this.status === "ready") {
      if (this.keys.launch) this.plunger = Math.min(1, this.plunger + dt * 0.95);
      this.balls.forEach((ball) => {
        if (!ball.ready) return;
        ball.body.setTranslation({ x: 1.97, y: 0.35, z: 3.2 }, true);
        ball.body.setLinvel({ x: 0, y: 0, z: 0 }, true);
      });
    }
    this.updateFlippers(dt);
    this.world.step();
    this.handleContacts();
    this.updateBalls();
    this.updateEffects(dt);
    this.comboT = Math.max(0, this.comboT - dt);
    this.tilt.heat = Math.max(0, this.tilt.heat - dt * 0.35);
  }

  updateFlippers(dt) {
    this.flippers.forEach((f) => {
      const was = Math.abs(f.angle - f.active) < 0.04;
      const pressed = f.side === "left" ? this.keys.left : this.keys.right;
      f.target = this.tilt.active ? f.rest : (pressed ? f.active : f.rest);
      const speed = pressed ? 18 : 10;
      f.angle += Math.sign(f.target - f.angle) * Math.min(Math.abs(f.target - f.angle), speed * dt);
      this.syncFlipper(f);
      if (pressed && !was && Math.abs(f.angle - f.active) < 0.2) this.audio.play("flipper");
    });
  }

  handleContacts() {
    this.balls.forEach((ball) => {
      const p = ball.body.translation();
      this.bumpers.forEach((bumper) => {
        const d = Math.hypot(p.x - bumper.body.translation().x, p.z - bumper.body.translation().z);
        if (d < bumper.radius + BALL_RADIUS + 0.04 && (bumper.cooldown || 0) <= 0) {
          const dx = p.x - bumper.body.translation().x;
          const dz = p.z - bumper.body.translation().z;
          const len = Math.hypot(dx, dz) || 1;
          ball.body.applyImpulse({ x: (dx / len) * 3.2, y: 0.1, z: (dz / len) * 3.2 }, true);
          bumper.cooldown = 0.16;
          bumper.pulse = 1;
          this.addScore(500, bumper.label);
          this.flash(0.65, bumper.mesh.material.color.getHex(), 1.8);
          this.audio.play("bumper", 1.1);
        }
        bumper.cooldown = Math.max(0, (bumper.cooldown || 0) - FIXED_STEP);
      });
      [...this.targets, ...this.rollovers].forEach((target) => {
        const t = target.body.translation();
        if (Math.abs(p.x - t.x) < 0.22 && Math.abs(p.z - t.z) < 0.22 && (target.cooldown || 0) <= 0) {
          target.cooldown = 0.28;
          this.addScore(target.score || 250, target.label || "TARGET");
          this.audio.play(target.label === "rollover" ? "target" : "sling");
          this.spark(p.x, p.z, 0xffcc72);
        }
        target.cooldown = Math.max(0, (target.cooldown || 0) - FIXED_STEP);
      });
      this.ramps.forEach((ramp) => {
        const t = ramp.body.translation();
        if (Math.abs(p.x - t.x) < 0.26 && Math.abs(p.z - t.z) < 0.26 && (ramp.cooldown || 0) <= 0) {
          ramp.cooldown = 1.2;
          this.addScore(1500, "RAMP");
          this.audio.play("ramp");
          this.flash(0.8, 0x62f4df, 1.2);
        }
        ramp.cooldown = Math.max(0, (ramp.cooldown || 0) - FIXED_STEP);
      });
      this.scoops.forEach((scoop) => {
        const t = scoop.body.translation();
        if (Math.hypot(p.x - t.x, p.z - t.z) < 0.28 && (scoop.cooldown || 0) <= 0) {
          scoop.cooldown = 1.5;
          if (scoop.name === "lock") this.lockBall(ball);
          else this.kickFromScoop(ball);
        }
        scoop.cooldown = Math.max(0, (scoop.cooldown || 0) - FIXED_STEP);
      });
    });
  }

  lockBall(ball) {
    this.locks += 1;
    this.addScore(5000, `LOCK ${this.locks}`);
    this.audio.play("lock");
    if (this.locks >= 3) {
      this.multiball();
    } else {
      this.kickFromScoop(ball);
    }
  }

  kickFromScoop(ball) {
    ball.body.setTranslation({ x: 1.0, y: 0.36, z: -0.9 }, true);
    ball.body.setLinvel({ x: -4.2, y: 0.35, z: -5.8 }, true);
    this.addScore(2500, "SCOOP");
  }

  multiball() {
    this.notice = "MULTIBALL";
    this.locks = 0;
    this.flash(1.4, 0xff4fa2, 3.4);
    this.audio.play("jackpot");
    this.spawnBall(false, -0.9, -1.0).body.setLinvel({ x: 3.6, y: 0.2, z: -4.5 }, true);
    this.spawnBall(false, 0.6, -2.2).body.setLinvel({ x: -3.2, y: 0.2, z: 4.5 }, true);
  }

  updateBalls() {
    let rolling = 0;
    this.balls.forEach((ball) => {
      const p = ball.body.translation();
      const r = ball.body.rotation();
      ball.mesh.position.set(p.x, p.y, p.z);
      ball.mesh.quaternion.set(r.x, r.y, r.z, r.w);
      const v = ball.body.linvel();
      rolling = Math.max(rolling, Math.hypot(v.x, v.z));
      if (p.z < 2.8 && p.y > -0.2) ball.lastSafe.set(p.x, p.y, p.z);
      if (p.y < -1 || p.z > TABLE.bottom + 0.55) ball.drained = true;
      const stuckNearTopRight = p.x > 1.15 && p.z < -2.35 && Math.hypot(v.x, v.z) < 0.45;
      if (stuckNearTopRight) {
        ball.stuck = (ball.stuck || 0) + 1;
        if (ball.stuck > 30) ball.body.applyImpulse({ x: -2.4, y: 0.1, z: 1.4 }, true);
      } else {
        ball.stuck = 0;
      }
    });
    this.audio.setRolling(rolling);
    const drained = this.balls.filter((ball) => ball.drained);
    if (drained.length) this.removeDrained(drained);
  }

  removeDrained(drained) {
    drained.forEach((ball) => {
      this.scene.remove(ball.mesh);
      this.world.removeCollider(ball.collider, true);
      this.world.removeRigidBody(ball.body);
    });
    this.balls = this.balls.filter((ball) => !ball.drained);
    this.audio.play("drain");
    if (this.balls.length > 0) return;
    this.ball -= 1;
    if (this.ball <= 0) {
      this.status = "gameover";
      this.notice = "GAME OVER";
      this.onMessage(`Game Over: ${this.score.toLocaleString("de-DE")} Punkte`);
      this.emitSnapshot(true);
      return;
    }
    this.spawnBall(true);
    this.notice = `BALL ${this.ball}`;
  }

  addScore(points, label) {
    if (points) {
      if (this.comboT > 0) this.mult = Math.min(5, this.mult + 1);
      else this.mult = 1;
      this.comboT = 2.8;
      this.score += points * this.mult;
      this.jackpot += Math.round(points * 0.25);
    }
    this.notice = label;
    this.spark(0, -0.4, label === "JACKPOT" ? 0xffcc72 : 0x62f4df);
  }

  flash(life, color, intensity = 1) {
    this.effects.push({ type: "flash", life, max: life, color, intensity });
  }

  spark(x, z, color) {
    for (let i = 0; i < 18; i += 1) {
      const mesh = new THREE.Mesh(new THREE.SphereGeometry(0.025 + Math.random() * 0.025, 8, 6), new THREE.MeshBasicMaterial({ color, transparent: true }));
      mesh.position.set(x + (Math.random() - 0.5) * 0.25, 0.42, z + (Math.random() - 0.5) * 0.25);
      this.scene.add(mesh);
      this.effects.push({ type: "spark", mesh, life: 0.45, max: 0.45, vx: (Math.random() - 0.5) * 2.4, vy: 0.5 + Math.random() * 1.4, vz: (Math.random() - 0.5) * 2.4 });
    }
  }

  updateEffects(dt) {
    this.effects.forEach((e) => {
      e.life -= dt;
      if (e.mesh) {
        e.mesh.position.x += e.vx * dt;
        e.mesh.position.y += e.vy * dt;
        e.mesh.position.z += e.vz * dt;
        e.vy -= 3.2 * dt;
        e.mesh.material.opacity = Math.max(0, e.life / e.max);
      }
    });
    this.effects = this.effects.filter((e) => {
      if (e.life > 0) return true;
      if (e.mesh) this.scene.remove(e.mesh);
      return false;
    });
  }

  drawDisplay() {
    const ctx = this.displayCanvas.getContext("2d");
    ctx.clearRect(0, 0, 1024, 160);
    ctx.fillStyle = "#090300";
    ctx.fillRect(0, 0, 1024, 160);
    ctx.fillStyle = "#ffb33c";
    ctx.font = "900 34px monospace";
    ctx.fillText(`SCORE ${this.score.toLocaleString("de-DE")}`, 36, 58);
    ctx.font = "900 26px monospace";
    ctx.fillText(`BALL ${this.ball}   x${this.mult}   LOCK ${this.locks}/3   JACKPOT ${this.jackpot.toLocaleString("de-DE")}`, 36, 106);
    ctx.fillStyle = "#ffe0a0";
    ctx.fillText(this.notice, 36, 142);
    this.displayTexture.needsUpdate = true;
  }

  loop(t) {
    if (this.disposed) return;
    const now = t / 1000;
    const dt = Math.min(0.05, now - (this.last || now));
    this.last = now;
    this.acc += dt;
    while (this.acc >= FIXED_STEP) {
      this.step(FIXED_STEP);
      this.acc -= FIXED_STEP;
    }
    this.drawDisplay();
    this.renderer.render(this.scene, this.camera);
    this.snapshotT += dt;
    if (this.snapshotT > 0.16) {
      this.snapshotT = 0;
      this.emitSnapshot();
    }
    this.frame = requestAnimationFrame((nt) => this.loop(nt));
  }

  emitSnapshot(force = false) {
    if (!force && !this.onSnapshot) return;
    this.onSnapshot({
      score: this.score,
      level: Math.max(1, Math.floor(this.score / 25000) + 1),
      balls: this.ball,
      streak: this.comboT > 0 ? this.mult : 0,
      mult: this.mult,
      jackpot: this.jackpot,
      locked: this.locks,
      bonus: 0,
      status: this.status,
    });
  }

  resize() {
    const rect = this.container.getBoundingClientRect();
    const width = Math.max(320, rect.width);
    const height = Math.max(520, rect.height);
    this.renderer.setSize(width, height, false);
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
  }

  dispose() {
    this.disposed = true;
    cancelAnimationFrame(this.frame);
    window.removeEventListener("keydown", this.onKeyDown);
    window.removeEventListener("keyup", this.onKeyUp);
    window.removeEventListener("resize", this.onResize);
    this.audio.dispose();
    this.renderer.dispose();
    this.container.replaceChildren();
  }
}
