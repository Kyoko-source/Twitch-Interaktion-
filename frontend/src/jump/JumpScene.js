import Phaser from "phaser";

const W = 960;
const H = 540;
const GROUND = 444;
const PLAYER_X = 164;
const BEST_KEY = "chicken-jump-best-v2";

class JumpScene extends Phaser.Scene {
  constructor(onSnapshot, onReady) {
    super("meadow-run");
    this.onSnapshot = onSnapshot;
    this.onReady = onReady;
    this.mode = "menu";
    this.muted = false;
    this.duck = false;
    this.queuedJump = 0;
    this.jumpHeld = false;
    this.best = 0;
    try { this.best = Number(localStorage.getItem(BEST_KEY)) || 0; } catch { /* Storage is optional. */ }
  }

  preload() {
    this.load.image("meadow-atlas", "/assets/chicken-jump-ai-v1.png");
  }

  create() {
    this.makeTextures();
    this.buildScenery();
    const ground = this.add.rectangle(W / 2, GROUND + 24, W, 48, 0x000000, 0);
    this.physics.add.existing(ground, true);
    this.player = this.physics.add.sprite(PLAYER_X, GROUND, "player-body").setOrigin(0.5, 1).setAlpha(0);
    this.player.body.setSize(34, 66).setOffset(15, 24).setCollideWorldBounds(false);
    this.physics.add.collider(this.player, ground);
    this.obstacles = this.physics.add.group({ allowGravity: false, immovable: true });
    this.coins = this.physics.add.group({ allowGravity: false, immovable: true });
    this.physics.add.overlap(this.player, this.obstacles, (_player, obstacle) => this.crash(obstacle));
    this.physics.add.overlap(this.player, this.coins, (_player, coin) => this.collect(coin));
    this.shadow = this.add.ellipse(PLAYER_X, GROUND + 3, 68, 12, 0x203c36, 0.22).setDepth(4);
    this.chicken = this.buildChicken();
    this.particles = this.add.particles(0, 0, "speck", {
      emitting: false, lifespan: 460, speed: { min: 35, max: 140 },
      angle: { min: 195, max: 345 }, gravityY: 350,
      scale: { start: 1, end: 0 }, alpha: { start: 0.85, end: 0 }, tint: [0xffd760, 0xffffff, 0x71edd3],
    }).setDepth(12);
    this.streakText = this.add.text(W / 2, 106, "", { fontFamily: "Arial", fontSize: "23px", fontStyle: "bold", color: "#fffbe8", stroke: "#275f55", strokeThickness: 4 }).setOrigin(0.5).setDepth(15);
    this.statusText = this.add.text(W - 28, 26, "", { fontFamily: "Arial", fontSize: "13px", color: "#214e43", fontStyle: "bold" }).setOrigin(1, 0).setDepth(15);
    this.bindInput();
    this.resetRun();
    this.physics.world.pause();
    this.publish();
    this.onReady(this);
    this.game.canvas.__jumpScene = this;
    this.events.once("shutdown", () => {
      window.removeEventListener("blur", this.onBlur);
      document.removeEventListener("visibilitychange", this.onVisibility);
      this.audio?.close();
      delete this.game.canvas.__jumpScene;
    });
  }

  makeTextures() {
    const g = this.make.graphics({ x: 0, y: 0, add: false });
    g.fillStyle(0xffffff).fillRect(0, 0, 64, 90);
    g.generateTexture("player-body", 64, 90);
    g.clear();
    g.fillStyle(0xffffff).fillCircle(4, 4, 4);
    g.generateTexture("speck", 8, 8);
    g.clear();
    g.fillStyle(0x177b6d).fillCircle(14, 14, 14);
    g.fillStyle(0x82ffe1).fillCircle(14, 13, 11);
    g.lineStyle(2, 0xeafff5).strokeCircle(14, 13, 8);
    g.fillStyle(0xffffff).fillEllipse(11, 9, 5, 4);
    g.generateTexture("pepple", 28, 28);
    [48, 62].forEach((height) => {
      g.clear();
      g.fillStyle(0x294c43).fillRoundedRect(0, 5, 68, height, 5);
      g.fillStyle(0xf1d57f).fillRoundedRect(4, 1, 10, height - 1, 3).fillRoundedRect(54, 1, 10, height - 1, 3);
      g.fillStyle(0xb77a43).fillRect(2, 18, 64, 10).fillRect(2, height - 16, 64, 10);
      g.fillStyle(0xffe8b2).fillRect(2, 18, 64, 3).fillRect(2, height - 16, 64, 3);
      g.fillStyle(0x506a51).fillCircle(9, 23, 2).fillCircle(59, 23, 2);
      g.generateTexture(`fence-${height}`, 68, height + 6);
    });
    for (let frame = 0; frame < 3; frame += 1) {
      g.clear();
      g.fillStyle(0x225d69).fillTriangle(5, 22, 27, 17, 22, 30);
      g.fillStyle(0x358f9a).fillEllipse(35, 24, 42, 22);
      g.fillStyle(0x86dfd5).fillEllipse(34, 28, 28, 12);
      g.fillStyle(0x174f63).fillEllipse(34, 18, 22, 14 + frame * 8);
      g.fillStyle(0xc5f8ed).fillCircle(53, 21, 11);
      g.fillStyle(0xffc953).fillTriangle(62, 20, 74, 24, 62, 27);
      g.fillStyle(0x142f38).fillCircle(56, 19, 2.5);
      g.generateTexture(`bird-${frame}`, 76, 48);
    }
    g.destroy();
  }

  buildScenery() {
    this.cameras.main.setBackgroundColor("#c5e9dc");
    const sky = this.add.graphics();
    sky.fillGradientStyle(0x9e839e, 0xc999a5, 0xffdfae, 0xffcf9b, 1).fillRect(0, 0, W, GROUND);
    this.clouds = [];
    for (let i = 0; i < 7; i += 1) {
      const cloud = this.add.container(i * 170, 48 + (i % 3) * 29);
      cloud.add([this.add.ellipse(0, 4, 100, 25, 0xffffff, 0.5), this.add.ellipse(0, -7, 49, 35, 0xffffff, 0.5)]);
      this.clouds.push(cloud);
    }
    const texture = this.textures.get("meadow-atlas");
    if (texture.key !== "__MISSING") {
      texture.add("landscape", 0, 20, 918, 1294, 232);
      this.landscapeSpan = 2476;
      this.landscapes = [0, this.landscapeSpan, this.landscapeSpan * 2].map((x) => this.add.image(x - 480, 0, "meadow-atlas", "landscape").setOrigin(0, 0).setDisplaySize(this.landscapeSpan + 1, GROUND));
    } else {
      this.landscapes = [];
    }
    const hills = this.add.graphics();
    hills.fillStyle(0x69aa78, 0.7).fillEllipse(180, 382, 620, 120).fillEllipse(850, 392, 800, 110);
    hills.fillStyle(0x3e8d70, 0.75).fillEllipse(450, 444, 1080, 130);
    this.fencePosts = [];
    for (let x = -30; x <= W + 90; x += 90) {
      const post = this.add.container(x, GROUND - 54);
      post.add([this.add.rectangle(0, 16, 6, 56, 0xe9dcb3), this.add.rectangle(45, 2, 92, 5, 0xe9dcb3), this.add.rectangle(45, 20, 92, 4, 0xc9c999)]);
      post.setAlpha(0.5);
      this.fencePosts.push(post);
    }
    const track = this.add.graphics().setDepth(3);
    track.fillStyle(0x6fb566).fillRect(0, GROUND - 1, W, 8);
    track.fillStyle(0xf1df9d).fillRect(0, GROUND + 7, W, 25);
    track.fillStyle(0xd9bd78).fillRect(0, GROUND + 32, W, 22);
    track.fillStyle(0x315e4d).fillRect(0, GROUND + 54, W, H - GROUND - 54);
    this.grasses = [];
    for (let i = 0; i < 49; i += 1) {
      const grass = this.add.graphics({ x: i * 23, y: GROUND }).setDepth(4);
      grass.lineStyle(2, i % 3 ? 0x4a9b5e : 0xb9d783).lineBetween(0, 0, -3, -7).lineBetween(0, 0, 4, -10);
      if (i % 7 === 0) grass.fillStyle(0xfff4b4).fillCircle(4, -10, 3);
      this.grasses.push(grass);
    }
    this.trackMarks = Array.from({ length: 20 }, (_, i) => this.add.ellipse(i * 55, GROUND + 23 + (i % 2) * 16, 12, 3, 0xad965e, 0.38).setDepth(4));
  }

  buildChicken() {
    const rig = this.add.container(PLAYER_X, GROUND).setDepth(8);
    const tail = this.add.container(-26, -33);
    [-0.45, 0, 0.4].forEach((angle, i) => tail.add(this.add.ellipse(-i * 3, -i * 5, 16, 35, i === 1 ? 0xfff3cf : 0xd9dfc3).setRotation(-0.7 + angle)));
    const feet = [-12, 12].map((x) => {
      const foot = this.add.container(x, -5);
      foot.add([this.add.rectangle(0, -2, 5, 19, 0xe5a63c), this.add.ellipse(6, 6, 24, 7, 0xf6b741)]);
      return foot;
    });
    const body = this.add.ellipse(-3, -35, 64, 55, 0xfff7df).setStrokeStyle(2, 0xd8dfc6);
    const belly = this.add.ellipse(3, -29, 44, 34, 0xffffff, 0.75);
    const wing = this.add.ellipse(-17, -32, 29, 35, 0xe0e5c9).setRotation(-0.35).setStrokeStyle(2, 0xc5d4b4);
    const head = this.add.container(18, -64);
    head.add([this.add.circle(0, 0, 22, 0xfff9e9), this.add.circle(-10, -21, 6, 0xe95657), this.add.circle(0, -25, 7, 0xf66960), this.add.circle(9, -21, 6, 0xe95657)]);
    head.add(this.add.triangle(25, 4, 0, 0, 18, 6, 0, 12, 0xf5b23b));
    head.add(this.add.ellipse(11, 9, 11, 7, 0xffb5a0, 0.65));
    this.eye = this.add.ellipse(9, -3, 10, 13, 0x193d38);
    head.add([this.eye, this.add.circle(11, -6, 2.5, 0xffffff)]);
    const scarf = this.add.container(16, -44);
    scarf.add([this.add.ellipse(0, 0, 34, 10, 0xf36b60), this.add.triangle(-29, 6, 0, 0, 24, 4, 0, 13, 0xe55658)]);
    rig.add([tail, ...feet, body, belly, head, scarf, wing]);
    this.rigParts = { tail, feet, body, belly, wing, head, scarf };
    return rig;
  }

  bindInput() {
    const editable = () => /^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement?.tagName || "") || document.activeElement?.isContentEditable;
    this.input.keyboard.on("keydown", (event) => {
      if (editable()) return;
      const key = event.code;
      if (["Space", "ArrowUp", "ArrowDown", "KeyW", "KeyS"].includes(key)) event.preventDefault();
      if (event.repeat) return;
      if (["Space", "ArrowUp", "KeyW"].includes(key)) {
        if (this.mode === "menu" || this.mode === "gameover") this.startRun();
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

  resetRun() {
    this.obstacles.clear(true, true);
    this.coins.clear(true, true);
    this.elapsed = 0;
    this.distance = 0;
    this.score = 0;
    this.pepples = 0;
    this.chain = 0;
    this.combo = 1;
    this.speed = 300;
    this.nextPattern = 1.8;
    this.pattern = 0;
    this.duck = false;
    this.jumpHeld = false;
    this.queuedJump = 0;
    this.chainLeft = 0;
    this.wasGrounded = true;
    this.snapshotClock = 0;
    this.player.body.reset(PLAYER_X, GROUND);
    this.player.body.setVelocity(0, 0);
    this.streakText.setText("");
    this.statusText.setText("");
    this.chicken.setAlpha(1).setRotation(0);
    this.cameras.main.resetFX();
  }

  startRun() {
    this.onRewardRunStart?.();
    this.ensureAudio();
    this.resetRun();
    this.mode = "play";
    this.physics.world.resume();
    this.tone(440, 0.08);
    this.publish();
  }

  pressJump() {
    if (this.mode !== "play") return;
    this.ensureAudio();
    this.jumpHeld = true;
    this.queuedJump = 0.13;
  }

  releaseJump() {
    this.jumpHeld = false;
    if (this.mode === "play" && this.player.body.velocity.y < -480) this.player.setVelocityY(-480);
  }

  setDuck(value) { this.duck = value && this.mode === "play"; }

  togglePause() {
    if (!["play", "paused"].includes(this.mode)) return;
    this.mode = this.mode === "play" ? "paused" : "play";
    this.duck = false;
    this.queuedJump = 0;
    this.jumpHeld = false;
    if (this.mode === "paused") this.physics.world.pause();
    else this.physics.world.resume();
    this.publish();
  }

  spawnPattern() {
    const type = this.pattern >= 3 && this.pattern % 4 === 3 ? "bird" : "fence";
    const height = this.pattern > 5 && this.pattern % 3 === 2 ? 62 : 48;
    const obstacle = this.obstacles.create(W + 85, type === "bird" ? GROUND - 64 : GROUND, type === "bird" ? "bird-0" : `fence-${height}`).setOrigin(0.5, type === "bird" ? 0.5 : 1).setDepth(7);
    obstacle.body.setAllowGravity(false).setImmovable(true);
    obstacle.kind = type;
    obstacle.scored = false;
    if (type === "bird") obstacle.body.setSize(52, 22).setOffset(13, 18);
    else obstacle.body.setSize(58, height - 4).setOffset(5, 7);
    obstacle.setVelocityX(-this.speed);
    for (let i = 0; i < 5; i += 1) {
      const x = W + 11 + i * 38;
      const y = type === "bird" ? GROUND - 20 : GROUND - 95 - Math.sin((i / 4) * Math.PI) * 35;
      const coin = this.coins.create(x, y, "pepple").setDepth(6);
      coin.body.setCircle(11, 3, 3).setAllowGravity(false).setImmovable(true);
      coin.setVelocityX(-this.speed);
      coin.phase = i;
    }
    this.pattern += 1;
    this.nextPattern = 1.65 + Math.random() * 0.45;
  }

  collect(coin) {
    if (this.mode !== "play" || !coin.active) return;
    this.particles.setParticleTint([0x71edd3, 0xffffff]).explode(7, coin.x, coin.y);
    coin.destroy();
    this.pepples += 1;
    this.chain += 1;
    this.chainLeft = 2.8;
    this.combo = Math.min(5, 1 + Math.floor(this.chain / 5));
    this.score += 20 * this.combo;
    this.tone(700 + this.combo * 100, 0.065, "sine", 0.045);
    if (this.chain % 5 === 0) {
      this.streakText.setText(`PEPPLE STREAK  x${this.combo}`).setAlpha(1);
      this.tweens.add({ targets: this.streakText, alpha: 0, duration: 650, delay: 450 });
    }
  }

  crash(obstacle) {
    if (this.mode !== "play") return;
    this.mode = "gameover";
    this.physics.world.pause();
    this.queuedJump = 0;
    this.cameras.main.shake(180, 0.006);
    this.cameras.main.flash(100, 255, 237, 192);
    this.chicken.setRotation(-0.3);
    obstacle.setTint(0xffa3a0);
    this.particles.setParticleTint([0xffffff, 0xf6d776]).explode(22, this.player.x, this.player.y - 36);
    this.tone(145, 0.23, "triangle", 0.07);
    this.best = Math.max(this.best, this.score);
    try { localStorage.setItem(BEST_KEY, String(this.best)); } catch { /* Storage is optional. */ }
    this.publish();
  }

  update(_time, delta) {
    const dt = Math.min(delta, 50) / 1000;
    const playing = this.mode === "play";
    if (playing) {
      this.elapsed += dt;
      this.distance += this.speed * dt / 18;
      this.speed = Math.min(530, 300 + this.elapsed * 2.5);
      this.score += Math.floor(this.distance) - Math.floor(this.distance - this.speed * dt / 18);
      const grounded = this.player.body.blocked.down || this.player.body.touching.down;
      this.queuedJump = Math.max(0, this.queuedJump - dt);
      if (this.queuedJump > 0 && grounded) {
        this.queuedJump = 0;
        this.duck = false;
        this.player.setVelocityY(-700);
        this.particles.setParticleTint([0xf6d776, 0xffffff]).explode(9, PLAYER_X - 12, GROUND);
        this.tone(530, 0.09);
      }
      const ducking = this.duck && grounded;
      this.player.body.setSize(ducking ? 46 : 34, ducking ? 28 : 66).setOffset(ducking ? 9 : 15, ducking ? 62 : 24);
      if (grounded && !this.wasGrounded) {
        this.particles.setParticleTint([0xf6d776, 0xffffff]).explode(7, PLAYER_X, GROUND);
        this.landSquash = 1;
        this.tone(200, 0.035, "triangle", 0.018);
      }
      this.wasGrounded = grounded;
      this.landSquash = Math.max(0, (this.landSquash || 0) - dt * 7);
      this.nextPattern -= dt;
      if (this.nextPattern <= 0) this.spawnPattern();
      this.obstacles.getChildren().slice().forEach((obstacle) => {
        obstacle.setVelocityX(-this.speed);
        if (obstacle.kind === "bird") obstacle.setTexture(`bird-${Math.floor(this.elapsed * 12) % 3}`);
        if (!obstacle.scored && obstacle.x + 40 < PLAYER_X - 22) {
          obstacle.scored = true;
          this.score += 50;
          this.tone(380, 0.04, "sine", 0.02);
        }
        if (obstacle.x < -100) obstacle.destroy();
      });
      this.coins.getChildren().slice().forEach((coin) => {
        coin.setVelocityX(-this.speed);
        if (coin.x < -30) coin.destroy();
      });
      this.chainLeft = Math.max(0, this.chainLeft - dt);
      if (this.chainLeft === 0) { this.chain = 0; this.combo = 1; }
      this.scrollScenery(dt);
      this.statusText.setText(`${Math.floor(this.speed / 18)} m/s`);
      this.snapshotClock += dt;
      if (this.snapshotClock > 0.12) { this.snapshotClock = 0; this.publish(); }
    }
    if (this.mode !== "paused") this.animateChicken(playing ? this.elapsed : _time / 1000, playing);
  }

  scrollScenery(dt) {
    this.clouds.forEach((cloud) => { cloud.x -= this.speed * dt * 0.025; if (cloud.x < -100) cloud.x += W + 200; });
    this.landscapes.forEach((landscape) => { landscape.x -= this.speed * dt * 0.07; if (landscape.x < -this.landscapeSpan) landscape.x += this.landscapeSpan * 3; });
    this.fencePosts.forEach((post) => { post.x -= this.speed * dt * 0.34; if (post.x < -90) post.x += 1170; });
    this.grasses.forEach((grass) => { grass.x -= this.speed * dt; if (grass.x < -25) grass.x += 1127; });
    this.trackMarks.forEach((mark) => { mark.x -= this.speed * dt; if (mark.x < -30) mark.x += 1100; });
  }

  animateChicken(time, playing) {
    if (this.mode === "gameover") return;
    const airborne = playing && this.player.y < GROUND - 4;
    const ducking = playing && this.duck && !airborne;
    const stride = time * (playing ? this.speed / 24 : 2);
    const bob = playing && !airborne && !ducking ? Math.abs(Math.sin(stride)) * 3 : Math.sin(time * 2.8) * 1.3;
    const parts = this.rigParts;
    this.chicken.setPosition(this.player.x, this.player.y - bob);
    this.chicken.setScale(ducking ? 1.16 : 1 + (this.landSquash || 0) * 0.1, ducking ? 0.44 : 1 - (this.landSquash || 0) * 0.12);
    parts.feet.forEach((foot, i) => {
      const phase = stride + i * Math.PI;
      foot.setPosition((i ? 12 : -12) + (airborne ? -7 : Math.sin(phase) * 12), -5 - (airborne ? 8 : Math.max(0, Math.cos(phase)) * 6));
      foot.rotation = airborne ? -0.45 : Math.sin(phase) * 0.35;
    });
    parts.wing.rotation = airborne ? -0.8 + Math.sin(time * 26) * 0.42 : -0.25 + Math.sin(stride) * 0.2;
    parts.tail.rotation = Math.sin(stride * 0.6) * 0.12;
    parts.head.rotation = airborne ? -0.08 : Math.sin(stride * 0.5) * 0.025;
    parts.scarf.rotation = Math.sin(time * 18) * 0.07;
    this.eye.scaleY = Math.sin(time * 1.3) > 0.995 ? 0.12 : 1;
    const elevation = Math.max(0, GROUND - this.player.y);
    this.shadow.setScale(Math.max(0.4, 1 - elevation / 270)).setAlpha(Math.max(0.08, 0.22 - elevation / 850));
  }

  ensureAudio() {
    if (this.muted) return;
    try {
      if (!this.audio) this.audio = new (window.AudioContext || window.webkitAudioContext)();
      if (this.audio.state === "suspended") this.audio.resume().catch(() => {});
    } catch { /* Audio is optional. */ }
  }

  tone(frequency, duration, type = "triangle", volume = 0.04) {
    if (this.muted || this.audio?.state !== "running") return;
    const oscillator = this.audio.createOscillator();
    const gain = this.audio.createGain();
    oscillator.type = type;
    oscillator.frequency.setValueAtTime(frequency, this.audio.currentTime);
    oscillator.frequency.exponentialRampToValueAtTime(frequency * 0.7, this.audio.currentTime + duration);
    gain.gain.setValueAtTime(volume, this.audio.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, this.audio.currentTime + duration);
    oscillator.connect(gain);
    gain.connect(this.audio.destination);
    oscillator.onended = () => { oscillator.disconnect(); gain.disconnect(); };
    oscillator.start();
    oscillator.stop(this.audio.currentTime + duration);
  }

  publish() {
    this.onSnapshot({ status: this.mode, score: this.score, distance: this.distance, pepples: this.pepples, combo: this.combo, best: Math.max(this.best, this.score) });
  }
}

export function mountJumpGame(parent, onSnapshot, onReady) {
  return new Phaser.Game({
    type: Phaser.AUTO, parent, width: W, height: H, backgroundColor: "#c5e9dc",
    render: { antialias: true, roundPixels: true },
    scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
    physics: { default: "arcade", arcade: { gravity: { x: 0, y: 1800 }, fps: 120, fixedStep: true, debug: false } },
    input: { keyboard: { capture: [] }, activePointers: 3 },
    scene: new JumpScene(onSnapshot, onReady),
  });
}
