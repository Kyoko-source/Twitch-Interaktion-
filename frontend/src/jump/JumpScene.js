import Phaser from "phaser/dist/phaser-arcade-physics.min.js";
import { JumpAudio } from "./audio.js";

const W = 960;
const H = 540;
const GROUND = 444;
const PLAYER_X = 164;
const BEST_KEY = "chicken-jump-best-v2";
const MILESTONE = 250;
const DAY_LENGTH = 1600;

// Frames in /assets/jump/sprites.webp (cut from the Chicken Jump concept sheet).
const FRAMES = {
  run: [0, 0, 275, 309], flap: [279, 0, 242, 273], duck: [525, 0, 282, 204],
  fence0: [811, 0, 311, 192], fence1: [0, 313, 326, 212], fence2: [330, 313, 318, 203], fence3: [652, 313, 277, 210],
  bird0: [933, 313, 251, 149], bird1: [0, 529, 230, 145], bird2: [234, 529, 203, 144],
  feather: [648, 529, 80, 46], "feather-gold": [732, 529, 80, 46], "feather-white": [816, 529, 80, 46],
};
// visual scale, hitbox (w, h), whether it is tall
const FENCES = [
  { frame: "fence0", scale: 0.27, hit: [56, 46], tall: false },
  { frame: "fence2", scale: 0.27, hit: [58, 48], tall: false },
  { frame: "fence1", scale: 0.31, hit: [62, 60], tall: true },
  { frame: "fence3", scale: 0.3, hit: [54, 58], tall: true },
];
const POWERS = {
  shield: { label: "SCHILD", color: 0x7ad8ff, css: "#7ad8ff", time: 0 },
  magnet: { label: "MAGNET", color: 0xff5a6a, css: "#ff7a8a", time: 9 },
  star: { label: "DOPPELPUNKTE", color: 0xffd84a, css: "#ffd84a", time: 8 },
};
const lerp = (a, b, t) => a + (b - a) * t;
const lerpColor = (a, b, t) => {
  const ar = (a >> 16) & 255, ag = (a >> 8) & 255, ab = a & 255;
  return (Math.round(lerp(ar, (b >> 16) & 255, t)) << 16) | (Math.round(lerp(ag, (b >> 8) & 255, t)) << 8) | Math.round(lerp(ab, b & 255, t));
};

class JumpScene extends Phaser.Scene {
  constructor(onSnapshot, onReady, onLoading) {
    super("meadow-run");
    this.onSnapshot = onSnapshot;
    this.onReady = onReady;
    this.onLoading = onLoading;
    this.mode = "menu";
    this.audio = new JumpAudio();
    this.duck = false;
    this.queuedJump = 0;
    this.jumpHeld = false;
    this.runId = 0;
    this.best = 0;
    try { this.best = Number(localStorage.getItem(BEST_KEY)) || 0; } catch { /* Storage is optional. */ }
  }

  get muted() { return this.audio.muted; }
  set muted(value) { this.audio.setMuted(value); if (!value && this.mode === "play") { this.audio.unlock(); this.audio.music(this.powers?.star > 0 ? "frenzy" : "run"); } }

  preload() {
    this.onLoading?.(35);
    this.load.on("progress", (value) => this.onLoading?.(35 + Math.round(value * 60)));
    this.load.image("jump-sprites", "/assets/jump/sprites.webp", { timeout: 12000 });
    this.load.image("jump-panorama", "/assets/jump/panorama.webp", { timeout: 12000 });
    this.load.image("jump-ground", "/assets/jump/ground.webp", { timeout: 12000 });
  }

  create() {
    if (!this.textures.exists("jump-sprites")) { this.onReady(this); return; }
    const atlas = this.textures.get("jump-sprites");
    for (const [name, [x, y, w, h]] of Object.entries(FRAMES)) atlas.add(name, 0, x, y, w, h);
    this.makeTextures();
    this.buildScenery();
    const ground = this.add.rectangle(W / 2, GROUND + 24, W, 48, 0x000000, 0);
    this.physics.add.existing(ground, true);
    this.player = this.physics.add.sprite(PLAYER_X, GROUND, "player-body").setOrigin(0.5, 1).setAlpha(0);
    this.player.body.setSize(34, 66).setOffset(15, 24).setCollideWorldBounds(false);
    this.physics.add.collider(this.player, ground);
    this.obstacles = this.physics.add.group({ allowGravity: false, immovable: true });
    this.coins = this.physics.add.group({ allowGravity: false, immovable: true });
    this.pickups = this.physics.add.group({ allowGravity: false, immovable: true });
    this.physics.add.overlap(this.player, this.obstacles, (_player, obstacle) => this.crash(obstacle));
    this.physics.add.overlap(this.player, this.coins, (_player, coin) => this.collect(coin));
    this.physics.add.overlap(this.player, this.pickups, (_player, pickup) => this.takePower(pickup));
    this.buildChicken();
    this.buildFx();
    this.buildHud();
    this.bindInput();
    this.resetRun();
    this.physics.world.pause();
    this.publish();
    this.onReady(this);
    this.game.canvas.__jumpScene = this;
    this.events.once("shutdown", () => {
      window.removeEventListener("blur", this.onBlur);
      document.removeEventListener("visibilitychange", this.onVisibility);
      this.audio.destroy();
      delete this.game.canvas.__jumpScene;
    });
  }

  // ------------------------------------------------------------------ textures
  makeTextures() {
    const g = this.make.graphics({ x: 0, y: 0, add: false });
    g.fillStyle(0xffffff).fillRect(0, 0, 64, 90);
    g.generateTexture("player-body", 64, 90);
    // invisible hitbox textures (generated up front: the graphics object is destroyed below)
    for (const [w, h] of [...FENCES.map((f) => f.hit), [50, 22], [26, 26], [44, 44]]) {
      g.clear(); g.fillStyle(0xffffff).fillRect(0, 0, w, h); g.generateTexture(`hit-${w}x${h}`, w, h);
    }
    this.hit = (w, h) => `hit-${w}x${h}`;
    g.clear(); g.fillStyle(0xffffff).fillCircle(4, 4, 4); g.generateTexture("speck", 8, 8);
    const glow = this.textures.createCanvas("glow", 64, 64), gc = glow.getContext();
    const grad = gc.createRadialGradient(32, 32, 0, 32, 32, 32);
    grad.addColorStop(0, "rgba(255,255,255,1)"); grad.addColorStop(0.25, "rgba(255,255,255,0.6)"); grad.addColorStop(0.6, "rgba(255,255,255,0.15)"); grad.addColorStop(1, "rgba(255,255,255,0)");
    gc.fillStyle = grad; gc.fillRect(0, 0, 64, 64); glow.refresh();
    g.clear(); g.fillStyle(0xffffff);
    g.beginPath();
    for (let i = 0; i < 10; i += 1) { const r = i % 2 ? 4 : 11, a = (i / 10) * Math.PI * 2 - Math.PI / 2; g.lineTo(12 + Math.cos(a) * r, 12 + Math.sin(a) * r); }
    g.closePath(); g.fillPath(); g.generateTexture("spark", 24, 24);
    g.clear(); g.fillStyle(0xc9a26a).fillCircle(10, 10, 10); g.fillStyle(0xe8cfa0, 0.8).fillCircle(8, 7, 6); g.generateTexture("dust", 20, 20);
    g.clear(); g.fillStyle(0x8a5a2a).fillRect(0, 0, 14, 5); g.fillStyle(0xb07a3a).fillRect(0, 0, 14, 2); g.generateTexture("splinter", 14, 5);
    g.clear(); g.fillStyle(0xffffff).fillRect(0, 0, 70, 2); g.generateTexture("speedline", 70, 2);
    // power-up icons in a glossy bubble
    const bubble = (key, color, draw) => {
      g.clear();
      g.fillStyle(color, 0.28).fillCircle(32, 32, 31);
      g.lineStyle(3, 0xffffff, 0.9).strokeCircle(32, 32, 29);
      g.fillStyle(0xffffff, 0.55).fillEllipse(22, 18, 16, 9);
      draw();
      g.generateTexture(key, 64, 64);
    };
    bubble("pu-shield", 0x7ad8ff, () => {
      g.fillStyle(0xfff4dc).fillEllipse(32, 35, 26, 32);
      g.lineStyle(3, 0x2a8ad8).strokeEllipse(32, 35, 26, 32);
      g.fillStyle(0x2a8ad8).fillTriangle(32, 26, 24, 31, 40, 31); g.fillRect(28, 31, 8, 10);
    });
    bubble("pu-magnet", 0xff5a6a, () => {
      g.lineStyle(9, 0xd8303a).beginPath(); g.arc(32, 30, 11, Math.PI, 0, false); g.strokePath();
      g.fillStyle(0xd8303a).fillRect(17, 29, 9, 12).fillRect(38, 29, 9, 12);
      g.fillStyle(0xe8eef4).fillRect(17, 39, 9, 6).fillRect(38, 39, 9, 6);
    });
    bubble("pu-star", 0xffd84a, () => {
      g.fillStyle(0xffd84a); g.lineStyle(2, 0xa86a00);
      g.beginPath();
      for (let i = 0; i < 10; i += 1) { const r = i % 2 ? 7 : 16, a = (i / 10) * Math.PI * 2 - Math.PI / 2; g.lineTo(32 + Math.cos(a) * r, 33 + Math.sin(a) * r); }
      g.closePath(); g.fillPath(); g.strokePath();
    });
    g.destroy();
  }

  // ------------------------------------------------------------------ world
  buildScenery() {
    this.cameras.main.setBackgroundColor("#2a1f3a");
    // mirrored panorama so it loops without a seam
    const src = this.textures.get("jump-panorama").getSourceImage();
    const canvas = this.textures.createCanvas("jump-pano-loop", src.width * 2, src.height);
    const c = canvas.getContext();
    c.drawImage(src, 0, 0);
    c.save(); c.translate(src.width * 2, 0); c.scale(-1, 1); c.drawImage(src, 0, 0); c.restore();
    canvas.refresh();
    // sky gradient above the panorama, which is shown at a sharper 1.55x
    this.panoScale = 1.55;
    const panoH = Math.round(src.height * this.panoScale), panoTop = GROUND + 4 - panoH;
    const sky = this.add.graphics();
    sky.fillGradientStyle(0x1e1646, 0x1e1646, 0x5f447c, 0x5f447c, 1).fillRect(0, 0, W, panoTop + 2);
    this.pano = this.add.tileSprite(0, panoTop, W, panoH, "jump-pano-loop").setOrigin(0, 0).setTileScale(this.panoScale);
    const blend = this.add.graphics();
    blend.fillGradientStyle(0x5f447c, 0x5f447c, 0x5f447c, 0x5f447c, 1, 1, 0, 0).fillRect(0, panoTop, W, 34);
    // day/night tint over the backdrop
    this.skyTint = this.add.rectangle(0, 0, W, GROUND + 4, 0x0c1238, 0).setOrigin(0, 0).setDepth(1);
    this.skyGlow = this.add.rectangle(0, 0, W, GROUND + 4, 0xffb070, 0).setOrigin(0, 0).setDepth(1).setBlendMode(Phaser.BlendModes.ADD);
    this.stars = this.add.graphics().setDepth(1);
    for (let i = 0; i < 90; i += 1) {
      const x = Math.random() * W, y = Math.random() * 230, r = Math.random() < 0.15 ? 1.8 : 1;
      this.stars.fillStyle(0xffffff, 0.5 + Math.random() * 0.5).fillCircle(x, y, r);
    }
    this.stars.setAlpha(0);
    this.moon = this.add.container(620, 110).setDepth(1).setAlpha(0);
    this.moon.add([this.add.circle(0, 0, 46, 0xfff6d8, 0.12), this.add.circle(0, 0, 30, 0xfff6d8, 0.2), this.add.circle(0, 0, 22, 0xfff3d0), this.add.circle(-7, -4, 5, 0xe8dcb0), this.add.circle(6, 7, 3.5, 0xe8dcb0)]);
    this.clouds = [];
    for (let i = 0; i < 6; i += 1) {
      const cloud = this.add.container(i * 190 + Math.random() * 60, 40 + (i % 3) * 34).setDepth(1);
      const a = 0.16 + (i % 2) * 0.08;
      cloud.add([this.add.ellipse(0, 6, 120, 26, 0xffffff, a), this.add.ellipse(-22, -4, 54, 34, 0xffffff, a), this.add.ellipse(18, -9, 64, 42, 0xffffff, a)]);
      cloud.speed = 0.02 + (i % 3) * 0.012;
      this.clouds.push(cloud);
    }
    // mid layer: dark hedges on the horizon
    this.hedges = [];
    for (let i = 0; i < 9; i += 1) {
      const hedge = this.add.container(i * 130 + (i % 3) * 20, GROUND - 6).setDepth(2).setScale(0.6 + (i % 3) * 0.12);
      const tone = i % 2 ? 0x24502e : 0x2c5c34;
      hedge.add([this.add.ellipse(0, 0, 90, 30, tone), this.add.ellipse(-24, -10, 46, 34, tone), this.add.ellipse(20, -13, 52, 38, tone), this.add.ellipse(10, -22, 26, 16, 0x3e7a44, 0.7)]);
      if (i % 3 === 0) hedge.add([this.add.circle(-18, -16, 2.5, 0xffe066), this.add.circle(12, -22, 2.5, 0xff8ab0)]);
      this.hedges.push(hedge);
    }
    this.add.rectangle(0, GROUND + 60, W, H - GROUND, 0x2a1c12).setOrigin(0, 0).setDepth(3);
    this.ground = this.add.tileSprite(0, GROUND - 13, W, 100, "jump-ground").setOrigin(0, 0).setDepth(3);
    this.groundTint = this.add.rectangle(0, GROUND - 13, W, H - GROUND + 13, 0x0c1238, 0).setOrigin(0, 0).setDepth(3);
    // foreground tufts that rush past fastest
    this.tufts = [];
    for (let i = 0; i < 12; i += 1) {
      const tuft = this.add.graphics({ x: i * 90 + Math.random() * 40, y: H - 4 }).setDepth(20);
      const col = i % 2 ? 0x3e8a3a : 0x5aa83e;
      tuft.fillStyle(col).fillTriangle(-10, 0, -4, -26, 0, 0).fillTriangle(-3, 0, 4, -34, 7, 0).fillTriangle(4, 0, 14, -22, 14, 0);
      if (i % 4 === 0) tuft.fillStyle(0xffe066).fillCircle(4, -34, 3.5);
      this.tufts.push(tuft);
    }
    this.fireflies = Array.from({ length: 16 }, (_, i) => {
      const f = this.add.image(Math.random() * W, 250 + Math.random() * 170, "glow").setDepth(6).setScale(0.2).setTint(0xfff27a).setBlendMode(Phaser.BlendModes.ADD).setAlpha(0);
      f.seed = i * 1.7; return f;
    });
  }

  buildChicken() {
    this.shadow = this.add.ellipse(PLAYER_X, GROUND + 3, 70, 12, 0x1a120a, 0.3).setDepth(7);
    this.aura = this.add.image(PLAYER_X, GROUND - 40, "glow").setDepth(7).setScale(2.2).setAlpha(0).setBlendMode(Phaser.BlendModes.ADD);
    this.chicken = this.add.image(PLAYER_X, GROUND, "jump-sprites", "run").setOrigin(0.52, 0.97).setScale(0.31).setDepth(9);
    this.chickenGlow = this.add.image(PLAYER_X, GROUND, "jump-sprites", "run").setOrigin(0.52, 0.97).setScale(0.31).setDepth(10).setBlendMode(Phaser.BlendModes.ADD).setAlpha(0);
    this.shieldRing = this.add.container(PLAYER_X, GROUND - 46).setDepth(11).setAlpha(0);
    this.shieldRing.add([this.add.circle(0, 0, 58, 0x7ad8ff, 0.14).setStrokeStyle(3, 0xbff0ff, 0.9), this.add.ellipse(-20, -26, 26, 12, 0xffffff, 0.45)]);
  }

  buildFx() {
    this.dust = this.add.particles(0, 0, "dust", {
      emitting: false, lifespan: 520, speedX: { min: -160, max: -60 }, speedY: { min: -60, max: -10 },
      scale: { start: 0.7, end: 0.1 }, alpha: { start: 0.55, end: 0 }, gravityY: 60,
    }).setDepth(8);
    this.sparks = this.add.particles(0, 0, "spark", {
      emitting: false, lifespan: 620, speed: { min: 80, max: 260 }, rotate: { min: 0, max: 360 },
      scale: { start: 0.8, end: 0 }, alpha: { start: 1, end: 0 }, gravityY: 240, blendMode: "ADD",
    }).setDepth(14);
    this.feathers = this.add.particles(0, 0, "jump-sprites", {
      frame: "feather-white", emitting: false, lifespan: 1400, speed: { min: 60, max: 280 }, rotate: { min: 0, max: 360 },
      scale: { start: 0.42, end: 0.2 }, alpha: { start: 1, end: 0 }, gravityY: 180,
    }).setDepth(14);
    this.splinters = this.add.particles(0, 0, "splinter", {
      emitting: false, lifespan: 900, speed: { min: 140, max: 420 }, angle: { min: 200, max: 340 }, rotate: { min: 0, max: 360 },
      scale: { start: 1.3, end: 0.6 }, alpha: { start: 1, end: 0 }, gravityY: 900,
    }).setDepth(14);
    this.trail = this.add.particles(0, 0, "glow", {
      emitting: false, lifespan: 420, speedX: { min: -260, max: -180 }, speedY: { min: -20, max: 20 },
      scale: { start: 0.55, end: 0 }, alpha: { start: 0.8, end: 0 }, blendMode: "ADD",
      tint: [0xff5a5a, 0xffa84a, 0xffe84a, 0x5aff8a, 0x5ac8ff, 0xb05aff],
    }).setDepth(8);
    this.rings = [];
    this.speedLines = Array.from({ length: 14 }, () => this.add.image(-200, 0, "speedline").setDepth(19).setAlpha(0));
  }

  buildHud() {
    const style = (size, color = "#fffbe8", stroke = "#3a1f0a") => ({ fontFamily: "Fredoka, Nunito, Arial Rounded MT Bold, Arial", fontSize: `${size}px`, fontStyle: "bold", color, stroke, strokeThickness: Math.max(3, size / 6) });
    this.style = style;
    this.banner = this.add.text(W / 2, 150, "", style(44, "#fff3b0", "#7a2a10")).setOrigin(0.5).setDepth(30).setAlpha(0);
    this.subBanner = this.add.text(W / 2, 196, "", style(20, "#ffffff", "#3a1f0a")).setOrigin(0.5).setDepth(30).setAlpha(0);
    this.comboText = this.add.text(W / 2, 92, "", style(26, "#fffbe8", "#1a5a4a")).setOrigin(0.5).setDepth(30).setAlpha(0);
    this.speedText = this.add.text(W - 22, 20, "", style(15, "#ffffff", "#2a1a3a")).setOrigin(1, 0).setDepth(30);
    this.distText = this.add.text(W - 22, 42, "", style(13, "#ffe9b0", "#2a1a3a")).setOrigin(1, 0).setDepth(30);
    this.powerHud = this.add.container(22, 20).setDepth(30);
    this.milestoneBar = this.add.graphics().setDepth(30);
  }

  // ------------------------------------------------------------------ input
  bindInput() {
    const editable = () => /^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement?.tagName || "") || document.activeElement?.isContentEditable;
    this.input.keyboard.on("keydown", (event) => {
      if (editable()) return;
      const key = event.code;
      if (["Space", "ArrowUp", "ArrowDown", "KeyW", "KeyS"].includes(key)) event.preventDefault();
      if (event.repeat) return;
      if (["Space", "ArrowUp", "KeyW"].includes(key)) {
        if (this.mode === "menu" || (this.mode === "gameover" && this.canRestart)) this.startRun();
        else if (this.mode === "paused") this.togglePause();
        else this.pressJump();
      }
      if (["ArrowDown", "KeyS"].includes(key)) this.setDuck(true);
      if (["Escape", "KeyP"].includes(key)) this.togglePause();
    });
    this.input.keyboard.on("keyup", (event) => {
      if (["Space", "ArrowUp", "KeyW"].includes(event.code)) this.releaseJump();
      if (["ArrowDown", "KeyS"].includes(event.code)) this.setDuck(false);
    });
    this.input.on("pointerdown", () => { if (this.mode === "play") this.pressJump(); });
    this.input.on("pointerup", () => this.releaseJump());
    this.onBlur = () => { if (this.mode === "play") this.togglePause(); };
    this.onVisibility = () => { if (document.hidden) this.onBlur(); };
    window.addEventListener("blur", this.onBlur);
    document.addEventListener("visibilitychange", this.onVisibility);
  }

  // ------------------------------------------------------------------ run state
  resetRun() {
    this.runId += 1;
    this.obstacles.clear(true, true);
    this.coins.clear(true, true);
    this.pickups.clear(true, true);
    this.tweens.killTweensOf([this.chicken, this.chickenGlow, this.banner, this.subBanner, this.comboText]);
    this.elapsed = 0;
    this.distance = 0;
    this.score = 0;
    this.pepples = 0;
    this.chain = 0;
    this.combo = 1;
    this.maxCombo = 1;
    this.nearMisses = 0;
    this.speed = 300;
    this.nextPattern = 1.8;
    this.nextPower = 14 + Math.random() * 4;
    this.pattern = 0;
    this.duck = false;
    this.jumpHeld = false;
    this.queuedJump = 0;
    this.chainLeft = 0;
    this.wasGrounded = true;
    this.doubleUsed = false;
    this.spin = 0;
    this.invuln = 0;
    this.powers = { shield: 0, magnet: 0, star: 0 };
    this.milestone = 0;
    this.record = false;
    this.canRestart = true;
    this.snapshotClock = 0;
    this.dustClock = 0;
    this.player.body.reset(PLAYER_X, GROUND);
    this.player.body.setVelocity(0, 0);
    this.comboText.setAlpha(0);
    this.banner.setAlpha(0);
    this.subBanner.setAlpha(0);
    this.chicken.setAlpha(1).setRotation(0).setPosition(PLAYER_X, GROUND).setFrame("run").clearTint();
    this.chickenGlow.setAlpha(0);
    this.cameras.main.resetFX();
    this.renderPowerHud();
  }

  startRun() {
    this.onRewardRunStart?.();
    this.audio.unlock();
    this.resetRun();
    this.bestAtStart = this.best;
    this.mode = "play";
    this.physics.world.resume();
    this.audio.setRate(1);
    this.audio.play("start");
    this.audio.voice("vo-go", 0.3);
    this.audio.music("run");
    this.showBanner("LOS!", "Leertaste springen · in der Luft nochmal = Doppelsprung", "#c8ffb0");
    this.publish();
  }

  pressJump() {
    if (this.mode !== "play") return;
    this.audio.unlock();
    this.jumpHeld = true;
    const grounded = this.player.body.blocked.down || this.player.body.touching.down;
    if (!grounded && !this.doubleUsed && this.player.y < GROUND - 18) {
      this.doubleUsed = true;
      this.duck = false;
      this.player.setVelocityY(-600);
      this.spin = 1;
      this.feathers.explode(8, this.player.x - 10, this.player.y - 30);
      this.ring(this.player.x, this.player.y - 20, 0xffffff);
      this.audio.play("double", { rate: 1.1 });
      return;
    }
    this.queuedJump = 0.13;
  }

  releaseJump() {
    this.jumpHeld = false;
    if (this.mode === "play" && this.player.body.velocity.y < -480) this.player.setVelocityY(-480);
  }

  setDuck(value) {
    const next = value && this.mode === "play";
    // ducking in the air dives down fast
    if (next && !this.duck && this.mode === "play" && this.player.y < GROUND - 10) this.player.setVelocityY(Math.max(this.player.body.velocity.y, 650));
    this.duck = next;
  }

  togglePause() {
    if (!["play", "paused"].includes(this.mode)) return;
    this.mode = this.mode === "play" ? "paused" : "play";
    this.duck = false;
    this.queuedJump = 0;
    this.jumpHeld = false;
    if (this.mode === "paused") { this.physics.world.pause(); this.tweens.pauseAll(); this.audio.pause(true); }
    else { this.physics.world.resume(); this.tweens.resumeAll(); this.audio.unlock(); this.audio.pause(false); }
    this.publish();
  }

  // ------------------------------------------------------------------ spawning
  tier() { return this.elapsed < 30 ? 1 : this.elapsed < 70 ? 2 : 3; }

  addFence(x, variant) {
    const spec = FENCES[variant];
    const obstacle = this.obstacles.create(x, GROUND, this.hit(spec.hit[0], spec.hit[1])).setOrigin(0.5, 1).setVisible(false);
    obstacle.body.setAllowGravity(false).setImmovable(true);
    obstacle.kind = "fence";
    obstacle.tall = spec.tall;
    obstacle.scored = false;
    obstacle.minGap = Infinity;
    obstacle.art = this.add.image(x, GROUND + 4, "jump-sprites", spec.frame).setOrigin(0.5, 0.93).setScale(spec.scale).setDepth(7);
    obstacle.on("destroy", () => obstacle.art?.destroy());
    obstacle.setVelocityX(-this.speed);
    this.pattern += 1;
    return obstacle;
  }

  addBird(x, y, swoop = 0) {
    const obstacle = this.obstacles.create(x, y, this.hit(50, 22)).setVisible(false);
    obstacle.body.setAllowGravity(false).setImmovable(true);
    obstacle.kind = "bird";
    obstacle.baseY = y;
    obstacle.swoop = swoop;
    obstacle.scored = false;
    obstacle.minGap = Infinity;
    obstacle.phase = Math.random() * 6;
    obstacle.art = this.add.image(x, y, "jump-sprites", `bird${Math.floor(Math.random() * 3)}`).setScale(0.36).setDepth(12).setFlipX(false);
    obstacle.on("destroy", () => obstacle.art?.destroy());
    obstacle.setVelocityX(-this.speed);
    this.pattern += 1;
    return obstacle;
  }

  addCoin(x, y) {
    const coin = this.coins.create(x, y, this.hit(26, 26)).setVisible(false);
    coin.body.setAllowGravity(false).setImmovable(true);
    coin.art = this.add.image(x, y, "jump-sprites", "feather-gold").setScale(0.46).setDepth(6);
    coin.glow = this.add.image(x, y, "glow").setScale(0.75).setTint(0xffd84a).setAlpha(0.5).setBlendMode(Phaser.BlendModes.ADD).setDepth(5);
    coin.on("destroy", () => { coin.art?.destroy(); coin.glow?.destroy(); });
    coin.baseY = y;
    coin.phase = x * 0.05;
    coin.setVelocityX(-this.speed);
    return coin;
  }

  coinArc(x0, count, top) {
    for (let i = 0; i < count; i += 1) this.addCoin(x0 + i * 38, GROUND - top - Math.sin((i / (count - 1)) * Math.PI) * 38);
  }

  spawnPattern() {
    const tier = this.tier();
    const x = W + 85;
    const roll = Math.random();
    let extra = 0;
    if (this.pattern >= 3 && this.pattern % 4 === 3) {
      // bird you must duck under (or jump high over), feathers under it
      const swoop = tier >= 2 && roll < 0.4 ? 1 : 0;
      this.addBird(x, GROUND - 70, swoop);
      for (let i = 0; i < 5; i += 1) this.addCoin(x - 74 + i * 38, GROUND - 20);
      if (tier >= 3 && roll > 0.6) { this.addBird(x + 70, GROUND - 150); extra = 0.2; }
    } else if (tier >= 2 && roll < 0.3) {
      // double fence: two jumps or one long double jump
      const gap = tier >= 3 ? 230 : 260;
      this.addFence(x, Math.floor(Math.random() * 2));
      this.addFence(x + gap, tier >= 3 ? 2 + Math.floor(Math.random() * 2) : Math.floor(Math.random() * 2));
      this.coinArc(x - 74, 5, 95);
      this.coinArc(x + gap - 74, 5, 95);
      extra = gap / this.speed;
    } else if (tier >= 3 && roll < 0.5) {
      // fence followed by a low bird: jump, land, duck
      this.addFence(x, 2 + Math.floor(Math.random() * 2));
      this.addBird(x + 300, GROUND - 70);
      this.coinArc(x - 74, 5, 105);
      extra = 300 / this.speed;
    } else if (tier >= 2 && roll < 0.55) {
      // tall fence with a high feather row for the double jump
      this.addFence(x, 2 + Math.floor(Math.random() * 2));
      for (let i = 0; i < 6; i += 1) this.addCoin(x - 95 + i * 38, GROUND - 190 - Math.sin((i / 5) * Math.PI) * 30);
    } else {
      const tall = this.pattern > 5 && this.pattern % 3 === 2;
      this.addFence(x, tall ? 2 + Math.floor(Math.random() * 2) : Math.floor(Math.random() * 2));
      this.coinArc(x - 74, 5, tall ? 110 : 95);
    }
    const pace = tier === 1 ? 1 : tier === 2 ? 0.93 : 0.86;
    this.nextPattern = (1.65 + Math.random() * 0.45) * pace + extra;
  }

  spawnPower() {
    const kinds = Object.keys(POWERS).filter((k) => !(k === "shield" && this.powers.shield));
    const kind = kinds[Math.floor(Math.random() * kinds.length)];
    const y = GROUND - 120 - Math.random() * 40;
    const pickup = this.pickups.create(W + 60, y, this.hit(44, 44)).setVisible(false);
    pickup.body.setAllowGravity(false).setImmovable(true);
    pickup.kind = kind;
    pickup.baseY = y;
    pickup.art = this.add.image(W + 60, y, `pu-${kind}`).setDepth(13).setScale(0.9);
    pickup.halo = this.add.image(W + 60, y, "glow").setDepth(12).setScale(1.8).setTint(POWERS[kind].color).setAlpha(0.6).setBlendMode(Phaser.BlendModes.ADD);
    pickup.on("destroy", () => { pickup.art?.destroy(); pickup.halo?.destroy(); });
    pickup.setVelocityX(-this.speed);
    this.nextPower = 16 + Math.random() * 9;
  }

  // ------------------------------------------------------------------ events
  gain(points) { const value = points * (this.powers.star > 0 ? 2 : 1); this.score += value; return value; }

  floatText(x, y, text, color = "#ffffff", size = 18) {
    const t = this.add.text(x, y, text, this.style(size, color, "#3a1f0a")).setOrigin(0.5).setDepth(31);
    this.tweens.add({ targets: t, y: y - 46, alpha: 0, scale: 1.25, duration: 820, ease: "Cubic.easeOut", onComplete: () => t.destroy() });
  }

  ring(x, y, color, size = 70) {
    const r = this.add.circle(x, y, 10, color, 0).setStrokeStyle(4, color, 0.9).setDepth(14);
    this.tweens.add({ targets: r, radius: size, alpha: 0, duration: 420, ease: "Cubic.easeOut", onComplete: () => r.destroy() });
  }

  showBanner(text, sub = "", color = "#fff3b0") {
    this.tweens.killTweensOf([this.banner, this.subBanner]);
    this.banner.setText(text).setColor(color).setAlpha(1).setScale(0.3);
    this.subBanner.setText(sub).setAlpha(sub ? 1 : 0);
    this.tweens.add({ targets: this.banner, scale: 1, duration: 380, ease: "Back.easeOut" });
    this.tweens.add({ targets: [this.banner, this.subBanner], alpha: 0, delay: 1400, duration: 500 });
  }

  collect(coin) {
    if (this.mode !== "play" || !coin.active) return;
    this.sparks.setParticleTint(0xffd84a);
    this.sparks.explode(6, coin.x, coin.y);
    this.ring(coin.x, coin.y, 0xffe066, 30);
    coin.destroy();
    this.pepples += 1;
    this.chain += 1;
    this.chainLeft = 2.8;
    const before = this.combo;
    this.combo = Math.min(8, 1 + Math.floor(this.chain / 5));
    this.maxCombo = Math.max(this.maxCombo, this.combo);
    const value = this.gain(20 * this.combo);
    this.floatText(coin.x, coin.y - 12, `+${value}`, this.combo > 1 ? "#ffe066" : "#ffffff", 15);
    this.audio.play(`coin-${Math.min(5, this.combo)}`, { rate: 1 + (this.chain % 5) * 0.05 });
    if (this.combo > before) {
      this.audio.play("combo", { rate: 0.9 + this.combo * 0.06 });
      if (this.combo === 5) this.audio.voice("vo-combo");
      this.tweens.killTweensOf(this.comboText);
      this.comboText.setText(`FEDER-KETTE  x${this.combo}`).setAlpha(1).setScale(1.5);
      this.tweens.add({ targets: this.comboText, scale: 1, duration: 260, ease: "Back.easeOut" });
      this.tweens.add({ targets: this.comboText, alpha: 0, delay: 900, duration: 500 });
    }
  }

  takePower(pickup) {
    if (this.mode !== "play" || !pickup.active) return;
    const kind = pickup.kind, spec = POWERS[kind];
    this.sparks.setParticleTint(spec.color);
    this.sparks.explode(18, pickup.x, pickup.y);
    this.ring(pickup.x, pickup.y, spec.color, 110);
    pickup.destroy();
    this.cameras.main.flash(160, (spec.color >> 16) & 255, (spec.color >> 8) & 255, spec.color & 255);
    this.audio.play("powerup");
    this.audio.voice("vo-power", 0.15);
    if (kind === "shield") { this.powers.shield = 1; this.audio.play("shield", { delay: 0.1 }); }
    else this.powers[kind] = spec.time;
    if (kind === "magnet") this.audio.play("magnet");
    if (kind === "star") { this.audio.play("frenzy"); this.audio.music("frenzy"); }
    this.showBanner(spec.label, kind === "shield" ? "Ein Treffer wird abgefangen" : kind === "magnet" ? "Federn fliegen zu dir" : "Alle Punkte doppelt", spec.css);
    this.renderPowerHud();
  }

  crash(obstacle) {
    if (this.mode !== "play" || this.invuln > 0 || !obstacle.active) return;
    if (this.powers.shield) {
      // the shield takes the hit and the fence/bird is smashed
      this.powers.shield = 0;
      this.invuln = 1.2;
      this.splinters.explode(26, obstacle.x, obstacle.y - 20);
      if (obstacle.kind === "bird") this.feathers.explode(14, obstacle.x, obstacle.y);
      this.ring(this.player.x, this.player.y - 40, 0x7ad8ff, 140);
      this.cameras.main.shake(160, 0.008);
      this.audio.play("smash"); this.audio.play("save", { delay: 0.05 });
      this.floatText(obstacle.x, obstacle.y - 60, "GERETTET!", "#9af0ff", 22);
      obstacle.destroy();
      this.renderPowerHud();
      return;
    }
    this.mode = "gameover";
    this.canRestart = false;
    this.physics.world.pause();
    this.queuedJump = 0;
    const run = this.runId;
    this.cameras.main.shake(260, 0.012);
    this.cameras.main.flash(120, 255, 236, 200);
    obstacle.art?.setTint(0xff9a8a);
    this.splinters.explode(obstacle.kind === "fence" ? 18 : 0, obstacle.x, obstacle.y - 30);
    this.feathers.explode(26, this.player.x, this.player.y - 40);
    this.sparks.setParticleTint(0xffffff);
    this.sparks.explode(14, this.player.x + 20, this.player.y - 40);
    this.audio.play("crash"); this.audio.play("drain", { delay: 0.1 }); this.audio.music(null);
    this.chicken.setFrame("flap");
    this.chickenGlow.setAlpha(0);
    this.tweens.add({ targets: this.chicken, x: this.chicken.x - 70, y: this.chicken.y - 110, rotation: -2.6, duration: 420, ease: "Quad.easeOut" });
    this.tweens.add({ targets: this.chicken, y: GROUND + 40, alpha: 0.85, delay: 420, duration: 380, ease: "Quad.easeIn" });
    this.best = Math.max(this.best, this.score);
    this.record = this.score > 0 && this.score > this.bestAtStart;
    try { localStorage.setItem(BEST_KEY, String(this.best)); } catch { /* Storage is optional. */ }
    this.time.delayedCall(850, () => {
      if (run !== this.runId) return;
      this.canRestart = true;
      this.audio.play("over");
      this.audio.voice(this.record ? "vo-record" : "vo-over");
      this.publish();
    });
  }

  milestoneReached(m) {
    const bonus = this.gain(100);
    this.showBanner(`${m} m!`, `+${bonus} Punkte · schneller!`, "#fff3b0");
    this.audio.play("milestone");
    if (m % 1000 === 0) this.audio.voice("vo-level", 0.3);
    this.sparks.setParticleTint([0xffe066, 0xffffff, 0xff9a5a]);
    for (let i = 0; i < 3; i += 1) this.time.delayedCall(i * 120, () => this.sparks.explode(14, 260 + i * 220, 140));
    this.audio.setRate(Math.min(1.14, 1 + (m / MILESTONE) * 0.02));
  }

  nearMiss(obstacle) {
    this.nearMisses += 1;
    const value = this.gain(30);
    this.floatText(PLAYER_X + 30, this.player.y - 100, `KNAPP! +${value}`, "#7affd8", 20);
    this.audio.play("near");
    this.sparks.setParticleTint(0x7affd8);
    this.sparks.explode(8, obstacle.x, obstacle.kind === "fence" ? GROUND - 50 : obstacle.y);
  }

  // ------------------------------------------------------------------ loop
  update(_time, delta) {
    const dt = Math.min(delta, 50) / 1000;
    const playing = this.mode === "play";
    if (playing) {
      this.elapsed += dt;
      this.distance += this.speed * dt / 18;
      this.speed = Math.min(640, 300 + this.elapsed * 3);
      this.score += (Math.floor(this.distance) - Math.floor(this.distance - this.speed * dt / 18)) * (this.powers.star > 0 ? 2 : 1);
      const grounded = this.player.body.blocked.down || this.player.body.touching.down;
      this.queuedJump = Math.max(0, this.queuedJump - dt);
      if (this.queuedJump > 0 && grounded) {
        this.queuedJump = 0;
        this.duck = false;
        this.player.setVelocityY(-700);
        this.doubleUsed = false;
        this.dust.explode(10, PLAYER_X - 6, GROUND - 4);
        this.stretch = 1;
        this.audio.play("jump", { rate: 0.95 + Math.random() * 0.1 });
      }
      if (grounded) this.doubleUsed = false;
      const ducking = this.duck && grounded;
      this.player.body.setSize(ducking ? 46 : 34, ducking ? 28 : 66).setOffset(ducking ? 9 : 15, ducking ? 62 : 24);
      if (grounded && !this.wasGrounded) {
        this.dust.explode(12, PLAYER_X, GROUND - 4);
        this.landSquash = 1;
        this.spin = 0;
        this.audio.play("land");
      }
      this.wasGrounded = grounded;
      this.landSquash = Math.max(0, (this.landSquash || 0) - dt * 6);
      this.stretch = Math.max(0, (this.stretch || 0) - dt * 4);
      this.invuln = Math.max(0, this.invuln - dt);
      // running dust
      this.dustClock -= dt;
      if (grounded && this.dustClock <= 0) { this.dust.explode(ducking ? 3 : 1, PLAYER_X - 18, GROUND - 2); this.dustClock = ducking ? 0.03 : 0.07; }
      // power timers
      for (const key of ["magnet", "star"]) {
        if (this.powers[key] > 0) {
          this.powers[key] = Math.max(0, this.powers[key] - dt);
          if (this.powers[key] === 0) { this.audio.play("expire"); if (key === "star") this.audio.music("run"); }
        }
      }
      if (this.powers.star > 0) this.trail.explode(1, this.player.x - 20, this.player.y - 40 + Math.random() * 20);
      this.nextPattern -= dt;
      if (this.nextPattern <= 0) this.spawnPattern();
      if (this.elapsed > 10) { this.nextPower -= dt; if (this.nextPower <= 0) this.spawnPower(); }
      const body = this.player.body;
      this.obstacles.getChildren().slice().forEach((obstacle) => {
        obstacle.setVelocityX(-this.speed);
        if (obstacle.kind === "bird") {
          obstacle.phase += dt * 9;
          if (obstacle.swoop) obstacle.y = obstacle.baseY - 30 + Math.sin(this.elapsed * 3.2 + obstacle.phase * 0.1) * 34;
          obstacle.art.setPosition(obstacle.x, obstacle.y + Math.sin(obstacle.phase) * 3);
          obstacle.art.setScale(0.36, 0.36 * (0.82 + Math.abs(Math.sin(obstacle.phase)) * 0.22));
          obstacle.art.rotation = Math.sin(obstacle.phase * 0.5) * 0.06;
        } else obstacle.art.x = obstacle.x;
        // closest vertical clearance while overlapping horizontally
        if (Math.abs(obstacle.x - PLAYER_X) < obstacle.width / 2 + body.width / 2) {
          const top = obstacle.y - (obstacle.kind === "fence" ? obstacle.height : obstacle.height / 2);
          const bottom = obstacle.kind === "fence" ? obstacle.y : obstacle.y + obstacle.height / 2;
          const gap = body.bottom <= top ? top - body.bottom : body.top >= bottom ? body.top - bottom : 0;
          obstacle.minGap = Math.min(obstacle.minGap, gap);
        }
        if (!obstacle.scored && obstacle.x + 40 < PLAYER_X - 22) {
          obstacle.scored = true;
          this.gain(50);
          this.audio.play("pass", { rate: 1 + Math.random() * 0.1 });
          if (obstacle.minGap < 18) this.nearMiss(obstacle);
        }
        if (obstacle.x < -120) obstacle.destroy();
      });
      const magnet = this.powers.magnet > 0;
      this.coins.getChildren().slice().forEach((coin) => {
        coin.phase += dt * 4;
        const dx = this.player.x - coin.x, dy = this.player.y - 40 - coin.y, dist = Math.hypot(dx, dy);
        if (magnet && dist < 320) {
          coin.pulled = true;
          coin.setVelocity((dx / dist) * 720, (dy / dist) * 720);
        } else if (!coin.pulled) coin.setVelocityX(-this.speed);
        const bobY = coin.pulled ? 0 : Math.sin(coin.phase) * 4;
        coin.art.setPosition(coin.x, coin.y + bobY).setRotation(Math.sin(coin.phase * 0.8) * 0.3);
        coin.glow.setPosition(coin.x, coin.y + bobY).setAlpha(0.35 + Math.sin(coin.phase * 1.5) * 0.15);
        if (coin.x < -30) coin.destroy();
      });
      this.pickups.getChildren().slice().forEach((p) => {
        p.setVelocityX(-this.speed * 0.85);
        p.y = p.baseY + Math.sin(this.elapsed * 3) * 10;
        p.art.setPosition(p.x, p.y).setRotation(Math.sin(this.elapsed * 2) * 0.15);
        p.halo.setPosition(p.x, p.y).setScale(1.7 + Math.sin(this.elapsed * 6) * 0.2);
        if (p.x < -60) p.destroy();
      });
      this.chainLeft = Math.max(0, this.chainLeft - dt);
      if (this.chainLeft === 0) { this.chain = 0; this.combo = 1; }
      const m = Math.floor(this.distance / MILESTONE) * MILESTONE;
      if (m > this.milestone) { this.milestone = m; this.milestoneReached(m); }
      this.scrollScenery(dt);
      this.updateHud(dt);
      this.snapshotClock += dt;
      if (this.snapshotClock > 0.12) { this.snapshotClock = 0; this.renderPowerHud(); this.publish(); }
    }
    if (this.mode !== "paused") {
      this.animateChicken(playing ? this.elapsed : _time / 1000, playing, dt);
      this.ambient(_time / 1000, dt, playing);
    }
  }

  scrollScenery(dt) {
    const s = this.speed * dt;
    this.pano.tilePositionX += (s * 0.07) / this.panoScale;
    this.ground.tilePositionX += s;
    this.clouds.forEach((cloud) => { cloud.x -= s * cloud.speed; if (cloud.x < -120) cloud.x += W + 240; });
    this.hedges.forEach((hedge) => { hedge.x -= s * 0.45; if (hedge.x < -80) hedge.x += 130 * 9; });
    this.tufts.forEach((tuft) => { tuft.x -= s * 1.35; if (tuft.x < -30) tuft.x += 90 * 12; });
    // speed lines from 420 px/s on
    const fast = Phaser.Math.Clamp((this.speed - 400) / 200, 0, 1) + (this.powers.star > 0 ? 0.6 : 0);
    this.speedLines.forEach((line) => {
      if (line.x < -100 && Math.random() < fast * 0.08) { line.setPosition(W + 40, 40 + Math.random() * (GROUND - 60)).setAlpha(0.15 + Math.random() * 0.3).setScale(0.6 + Math.random(), 1); }
      if (line.x > -100) line.x -= s * 3.2;
    });
  }

  ambient(time, dt, playing) {
    // day/night: sunset → night → dawn → sunset
    const t = (this.distance % DAY_LENGTH) / DAY_LENGTH;
    const night = t < 0.25 ? 0 : t < 0.4 ? (t - 0.25) / 0.15 : t < 0.65 ? 1 : t < 0.8 ? 1 - (t - 0.65) / 0.15 : 0;
    const dawn = t > 0.65 && t < 0.95 ? Math.sin(((t - 0.65) / 0.3) * Math.PI) : 0;
    this.skyTint.setFillStyle(0x0c1238, night * 0.62);
    this.groundTint.setFillStyle(0x0c1238, night * 0.42);
    this.skyGlow.setFillStyle(0xff9a5a, dawn * 0.16);
    this.stars.setAlpha(night * (0.85 + Math.sin(time * 2) * 0.15));
    this.moon.setAlpha(night).setY(130 - night * 30);
    this.hedges.forEach((h) => h.setAlpha(0.92 - night * 0.3));
    this.clouds.forEach((c) => c.setAlpha(1 - night * 0.6));
    this.fireflies.forEach((f) => {
      f.x -= (playing ? this.speed * dt * 0.3 : 0) + Math.sin(time + f.seed) * 0.4;
      f.y += Math.cos(time * 1.3 + f.seed) * 0.5;
      if (f.x < -10) { f.x = W + 10; f.y = 250 + Math.random() * 170; }
      f.setAlpha(night * (0.5 + Math.sin(time * 4 + f.seed * 3) * 0.5));
    });
  }

  animateChicken(time, playing, dt) {
    if (this.mode === "gameover") return;
    const airborne = playing && this.player.y < GROUND - 4;
    const ducking = playing && this.duck && !airborne;
    const stride = time * (playing ? this.speed / 26 : 2);
    const bob = playing && !airborne && !ducking ? Math.abs(Math.sin(stride)) * 4 : playing ? 0 : Math.sin(time * 2.8) * 1.5;
    const frame = ducking ? "duck" : airborne ? "flap" : playing && Math.sin(stride) > 0.35 ? "flap" : "run";
    if (this.chicken.frame.name !== frame) { this.chicken.setFrame(frame); this.chickenGlow.setFrame(frame); }
    const base = ducking ? 0.27 : 0.31;
    const squash = this.landSquash || 0, stretch = this.stretch || 0;
    let sx = base * (1 + squash * 0.14 - stretch * 0.08), sy = base * (1 - squash * 0.16 + stretch * 0.12);
    let rot = 0;
    if (airborne) {
      const vy = this.player.body.velocity.y;
      rot = Phaser.Math.Clamp(vy / 2400, -0.22, 0.3);
      if (this.spin > 0) { this.spin = Math.max(0, this.spin - dt * 2.4); rot -= (1 - this.spin) * Math.PI * 2; }
    } else if (playing && !ducking) rot = Math.sin(stride) * 0.04;
    this.chicken.setPosition(this.player.x, this.player.y - bob).setScale(sx, sy).setRotation(rot);
    const blink = this.invuln > 0 && Math.floor(this.invuln * 14) % 2 === 0;
    this.chicken.setAlpha(blink ? 0.35 : 1);
    const star = this.powers?.star > 0;
    this.chickenGlow.setPosition(this.chicken.x, this.chicken.y).setScale(sx, sy).setRotation(rot)
      .setTint(Phaser.Display.Color.HSVToRGB((time * 0.6) % 1, 0.7, 1).color).setAlpha(star ? 0.35 + Math.sin(time * 10) * 0.12 : 0);
    this.aura.setPosition(this.player.x, this.player.y - 40).setAlpha(star ? 0.45 : this.powers?.magnet > 0 ? 0.3 : 0).setTint(star ? 0xffd84a : 0xff5a6a);
    const shield = this.powers?.shield;
    this.shieldRing.setPosition(this.player.x, this.player.y - (ducking ? 26 : 46)).setAlpha(shield ? 0.8 + Math.sin(time * 5) * 0.2 : 0).setScale(ducking ? 0.8 : 1).setRotation(time * 0.6);
    const elevation = Math.max(0, GROUND - this.player.y);
    this.shadow.setPosition(this.player.x, GROUND + 3).setScale(Math.max(0.35, 1 - elevation / 260), 1).setAlpha(Math.max(0.08, 0.3 - elevation / 700));
  }

  updateHud() {
    this.speedText.setText(`${Math.floor(this.speed / 18)} m/s`);
    const next = (Math.floor(this.distance / MILESTONE) + 1) * MILESTONE;
    this.distText.setText(`nächstes Ziel ${next} m`);
    const progress = (this.distance % MILESTONE) / MILESTONE;
    this.milestoneBar.clear();
    this.milestoneBar.fillStyle(0x000000, 0.35).fillRoundedRect(W - 182, 64, 160, 7, 3);
    this.milestoneBar.fillStyle(0xffd84a, 1).fillRoundedRect(W - 182, 64, Math.max(6, 160 * progress), 7, 3);
  }

  renderPowerHud() {
    if (!this.powerHud) return;
    this.powerHud.removeAll(true);
    let x = 0;
    for (const key of ["shield", "magnet", "star"]) {
      const value = this.powers?.[key];
      if (!value) continue;
      const icon = this.add.image(x + 22, 22, `pu-${key}`).setScale(0.62);
      const ring = this.add.graphics();
      if (key !== "shield") {
        ring.lineStyle(4, POWERS[key].color, 1).beginPath();
        ring.arc(x + 22, 22, 24, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (value / POWERS[key].time), false);
        ring.strokePath();
      }
      this.powerHud.add([ring, icon]);
      x += 56;
    }
    if (this.powers?.star > 0) this.powerHud.add(this.add.text(x + 2, 8, "x2", this.style(24, "#ffd84a", "#5a2a00")));
  }

  publish() {
    this.onSnapshot({
      status: this.mode, score: this.score, distance: this.distance, pepples: this.pepples, combo: this.combo,
      best: Math.max(this.best, this.score), maxCombo: this.maxCombo, nearMisses: this.nearMisses, record: this.record,
    });
  }
}

export function mountJumpGame(parent, onSnapshot, onReady, onLoading) {
  return new Phaser.Game({
    type: Phaser.AUTO, parent, width: W, height: H, backgroundColor: "#2a1f3a",
    render: { antialias: true, roundPixels: false },
    scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
    physics: { default: "arcade", arcade: { gravity: { x: 0, y: 1800 }, fps: 120, fixedStep: true, debug: false } },
    input: { keyboard: { capture: [] }, activePointers: 3 },
    loader: { maxRetries: 0 },
    scene: new JumpScene(onSnapshot, onReady, onLoading),
  });
}
