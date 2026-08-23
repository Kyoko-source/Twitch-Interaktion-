const TABLE = {
  w: 760,
  h: 920,
  field: { left: 72, right: 688, top: 58, bottom: 872 },
  lane: { left: 626, right: 682, top: 122, bottom: 806 },
  drain: { x1: 312, x2: 448, y: 812 },
};

const INSERTS = [
  { id: "skill", x: 646, y: 244, text: "SKILL", mode: "blink", color: "#ffd27d" },
  { id: "lock", x: 522, y: 286, text: "LOCK", mode: "off", color: "#7bf4de" },
  { id: "jackpot", x: 386, y: 388, text: "JACKPOT", mode: "off", color: "#ff5ea8" },
  { id: "super", x: 386, y: 430, text: "SUPER", mode: "off", color: "#ffed91" },
  { id: "extra", x: 202, y: 410, text: "EXTRA", mode: "off", color: "#8c6cff" },
  { id: "bonus", x: 178, y: 704, text: "BONUS", mode: "on", color: "#ffd27d" },
  { id: "multi", x: 582, y: 704, text: "MULTI", mode: "off", color: "#7bf4de" },
  { id: "x2", x: 276, y: 674, text: "2X", mode: "on", color: "#ff5ea8" },
  { id: "x3", x: 484, y: 674, text: "3X", mode: "off", color: "#8c6cff" },
];

const LETTERS = ["P", "E", "P", "P", "L", "E"].map((letter, index) => ({
  id: `letter-${index}`,
  letter,
  x: 226 + index * 49,
  y: 114,
}));

export function createPepplePinball() {
  return {
    status: "ready",
    balls: [makeBall(654, 770, 0, 0, true)],
    ballsLeft: 3,
    lockedBalls: 0,
    plunger: 0,
    plungerDir: 1,
    score: 0,
    level: 1,
    streak: 0,
    combo: 0,
    mult: 1,
    bonus: 0,
    jackpot: 2500,
    superJackpot: false,
    multiball: false,
    ballSaveUntil: 9000,
    nudgeCooldown: 0,
    time: 0,
    lastSnapshot: 0,
    flash: 0,
    shake: 0,
    notice: "PEPPLE PINBALL",
    noticeT: 1200,
    letters: LETTERS.map((letter) => ({ ...letter, lit: false })),
    inserts: INSERTS.map((insert) => ({ ...insert, pulse: 0 })),
    bumpers: [
      { x: 252, y: 238, r: 37, label: "PEP", color: "#ffc77a", value: 820, pulse: 0 },
      { x: 384, y: 252, r: 40, label: "JACK", color: "#76f0d8", value: 1200, pulse: 0 },
      { x: 514, y: 238, r: 37, label: "PLE", color: "#ff62a8", value: 820, pulse: 0 },
    ],
    posts: [
      [120, 184], [168, 224], [594, 184], [552, 224], [142, 558], [618, 558],
      [224, 604], [536, 604], [156, 690], [604, 690], [294, 792], [466, 792],
    ].map(([x, y]) => ({ x, y, r: 11 })),
    rollovers: [
      { x: 198, y: 144, w: 38, h: 13, value: 500, lit: false },
      { x: 247, y: 140, w: 38, h: 13, value: 500, lit: false },
      { x: 296, y: 138, w: 38, h: 13, value: 500, lit: false },
      { x: 345, y: 138, w: 38, h: 13, value: 500, lit: false },
      { x: 394, y: 140, w: 38, h: 13, value: 500, lit: false },
      { x: 443, y: 144, w: 38, h: 13, value: 500, lit: false },
    ],
    standups: [
      { x: 126, y: 300, w: 18, h: 84, side: "left", label: "PEP", lit: false, value: 650 },
      { x: 604, y: 300, w: 18, h: 84, side: "right", label: "PLE", lit: false, value: 650 },
      { x: 176, y: 472, w: 72, h: 16, side: "top", label: "2X", lit: false, value: 800 },
      { x: 514, y: 472, w: 72, h: 16, side: "top", label: "3X", lit: false, value: 1000 },
    ],
    drops: [
      { x: 308, y: 512, w: 30, h: 18, label: "L", down: false },
      { x: 348, y: 512, w: 30, h: 18, label: "O", down: false },
      { x: 388, y: 512, w: 30, h: 18, label: "C", down: false },
      { x: 428, y: 512, w: 30, h: 18, label: "K", down: false },
    ],
    spinner: { x: 162, y: 356, r: 20, angle: 0, spin: 0 },
    scoop: { x: 514, y: 410, r: 25, cooldown: 0 },
    lockHole: { x: 568, y: 520, r: 26, cooldown: 0 },
    rampGate: 0,
    events: [],
  };
}

export function makePeppleAudio(enabledRef) {
  const ref = { current: null };
  function ctx() {
    if (!enabledRef.current) return null;
    const AudioCtx = window.AudioContext || window.webkitAudioContext;
    if (!AudioCtx) return null;
    if (!ref.current) ref.current = new AudioCtx();
    if (ref.current.state === "suspended") ref.current.resume();
    return ref.current;
  }
  function tone(freq, dur = 0.05, type = "triangle", vol = 0.025) {
    const ac = ctx();
    if (!ac) return;
    const now = ac.currentTime;
    const osc = ac.createOscillator();
    const gain = ac.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, now);
    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(vol, now + 0.006);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + dur);
    osc.connect(gain).connect(ac.destination);
    osc.start(now);
    osc.stop(now + dur + 0.02);
  }
  return (kind) => {
    if (kind === "flip") tone(132, 0.035, "square", 0.028);
    else if (kind === "bumper") [560, 840].forEach((f, i) => setTimeout(() => tone(f, 0.05, "triangle", 0.032), i * 28));
    else if (kind === "sling") tone(420, 0.04, "sawtooth", 0.024);
    else if (kind === "target") tone(720, 0.045, "triangle", 0.025);
    else if (kind === "ramp") [440, 660, 990].forEach((f, i) => setTimeout(() => tone(f, 0.045, "triangle", 0.025), i * 34));
    else if (kind === "lock") [260, 520, 1040].forEach((f, i) => setTimeout(() => tone(f, 0.08, "square", 0.035), i * 50));
    else if (kind === "jackpot") [520, 780, 1040, 1560].forEach((f, i) => setTimeout(() => tone(f, 0.08, "square", 0.04), i * 45));
    else if (kind === "drain") [220, 146, 98].forEach((f, i) => setTimeout(() => tone(f, 0.11, "sawtooth", 0.032), i * 52));
    else if (kind === "launch") [190, 380, 760].forEach((f, i) => setTimeout(() => tone(f, 0.05, "triangle", 0.03), i * 36));
  };
}

export function stepPepplePinball(state, keys, dt, sound) {
  const fixed = 1000 / 120;
  let remaining = Math.min(dt, 38);
  while (remaining > 0) {
    const step = Math.min(fixed, remaining);
    integrate(state, keys, step, sound);
    remaining -= step;
  }
}

function integrate(state, keys, dt, sound) {
  const s = dt / 16.67;
  state.time += dt;
  state.flash = Math.max(0, state.flash - dt);
  state.shake = Math.max(0, state.shake - dt);
  state.noticeT = Math.max(0, state.noticeT - dt);
  state.scoop.cooldown = Math.max(0, state.scoop.cooldown - dt);
  state.lockHole.cooldown = Math.max(0, state.lockHole.cooldown - dt);
  state.spinner.angle += state.spinner.spin * s;
  state.spinner.spin *= 0.975;
  state.rampGate = Math.max(0, state.rampGate - dt);
  state.nudgeCooldown = Math.max(0, state.nudgeCooldown - dt);
  if (state.nudgeCooldown <= 0 && (keys.nudgeL || keys.nudgeR)) {
    const dir = keys.nudgeL ? -1 : 1;
    state.balls.forEach((ball) => {
      if (!ball.locked && !ball.dead) ball.vx += dir * 1.8;
    });
    state.shake = 180;
    state.nudgeCooldown = 420;
  }
  if (state.status === "ready") {
    const ball = state.balls[0] || makeBall();
    state.balls[0] = ball;
    ball.x = 654;
    ball.y = 770 - state.plunger * 92;
    ball.vx = 0;
    ball.vy = 0;
    ball.launchBall = true;
    if (keys.launch) {
      state.plunger += 0.018 * state.plungerDir * s;
      if (state.plunger >= 1) { state.plunger = 1; state.plungerDir = -1; }
      if (state.plunger <= 0.08) { state.plunger = 0.08; state.plungerDir = 1; }
    }
    return;
  }
  state.balls.forEach((ball) => {
    if (ball.dead || ball.locked) return;
    applyBallMotion(ball, s);
    collideStatic(ball, state, sound);
    collideFlippers(ball, state, keys, sound);
    collideTableToys(ball, state, sound);
    releaseStuckBall(ball);
    if (isDrain(ball)) {
      if (state.time < state.ballSaveUntil) {
        ball.x = 380;
        ball.y = 690;
        ball.vx = (Math.random() - 0.5) * 3.2;
        ball.vy = -12.4;
        state.notice = "BALL SAVE";
        state.noticeT = 900;
        state.flash = 240;
        return;
      }
      ball.dead = true;
    }
  });
  state.balls = state.balls.filter((ball) => !ball.dead && !ball.locked);
  if (!state.balls.length) nextBall(state, sound);
  updateModes(state, sound);
}

export function launchPeppleBall(state, sound) {
  if (state.status !== "ready") return;
  const ball = state.balls[0] || makeBall();
  const power = Math.max(0.18, state.plunger);
  ball.launchBall = false;
  ball.vy = -13.5 - power * 20;
  ball.vx = -0.45 - power * 1.3;
  state.status = "play";
  state.plunger = 0;
  state.notice = power > 0.78 ? "SKILLSHOT READY" : "SOFT PLUNGE";
  state.noticeT = 820;
  sound("launch");
}

export function getPeppleSnapshot(state) {
  return {
    score: state.score,
    level: state.level,
    balls: state.ballsLeft,
    streak: state.streak,
    mult: state.mult,
    jackpot: state.jackpot,
    locked: state.lockedBalls,
    bonus: state.bonus,
  };
}

function makeBall(x = 654, y = 770, vx = 0, vy = 0, launchBall = true) {
  return { x, y, z: 0, vx, vy, r: 10.8, spin: Math.random() * 6, launchBall, lastHit: "", stuckT: 0 };
}

function applyBallMotion(ball, s) {
  ball.vy += 0.22 * s;
  ball.vx *= 0.997;
  ball.vy *= 0.997;
  const speed = Math.hypot(ball.vx, ball.vy);
  const steps = Math.max(1, Math.ceil(speed / 8));
  for (let i = 0; i < steps; i += 1) {
    ball.x += (ball.vx * s) / steps;
    ball.y += (ball.vy * s) / steps;
  }
  ball.spin += ball.vx * 0.035;
}

function collideStatic(ball, state, sound) {
  const f = TABLE.field;
  const lane = TABLE.lane;
  if (ball.x > lane.left && ball.y > lane.top && ball.y < lane.bottom) {
    if (ball.x < lane.left + ball.r) reflect(ball, lane.left + ball.r, ball.y, 1, 0, 0.68);
    if (ball.x > lane.right - ball.r) reflect(ball, lane.right - ball.r, ball.y, -1, 0, 0.68);
  } else {
    if (ball.x < f.left + ball.r) reflect(ball, f.left + ball.r, ball.y, 1, 0, 0.72);
    if (ball.x > f.right - ball.r) reflect(ball, f.right - ball.r, ball.y, -1, 0, 0.72);
  }
  releaseShooterExit(ball);
  if (ball.y < f.top + ball.r) {
    reflect(ball, ball.x, f.top + ball.r, 0, 1, 0.74);
    ball.vx -= 3.8;
  }
  line(ball, 94, 736, 248, 648, 0.8, "guide");
  line(ball, 666, 736, 512, 648, 0.8, "guide");
  line(ball, 136, 206, 220, 118, 0.86, "orbit");
  line(ball, 540, 118, 626, 206, 0.86, "orbit");
  line(ball, 132, 612, 254, 552, 0.86, "inlane");
  line(ball, 626, 612, 504, 552, 0.86, "inlane");
  line(ball, 104, 670, 170, 792, 0.42, "outlane");
  line(ball, 656, 670, 590, 792, 0.42, "outlane");
  state.posts.forEach((post) => collideCircle(ball, post, 0.92));
  if (ball.y > 670 && ball.y < 810 && ball.x < 130) { ball.vx += 0.09; ball.vy += 0.18; }
  if (ball.y > 670 && ball.y < 810 && ball.x > 630) { ball.vx -= 0.09; ball.vy += 0.18; }
  if (ball.y > 748 && ball.x > TABLE.drain.x1 && ball.x < TABLE.drain.x2) ball.vy += 0.42;
  state.rollovers.forEach((roll, i) => {
    if (rectHit(ball, roll) && !roll.lit) {
      roll.lit = true;
      state.letters[i].lit = true;
      score(state, roll.value, "ROLLOVER");
      sound("target");
    }
  });
}

function releaseShooterExit(ball) {
  const lane = TABLE.lane;
  const nearShooterExit = ball.x > lane.left - 34 && ball.x < lane.right + ball.r && ball.y > TABLE.field.top + ball.r && ball.y < lane.top + 82;
  if (!nearShooterExit) return;
  const speed = Math.hypot(ball.vx, ball.vy);
  if (ball.x > lane.left - 8 || speed < 5 || ball.vy < 1.6) {
    ball.x = lane.left - 42;
    ball.y = lane.top + 62;
    ball.vx = -Math.max(4.8, Math.abs(ball.vx) + 1.2);
    ball.vy = Math.max(5.8, Math.abs(ball.vy) * 0.35 + 4.8);
    ball.lastHit = "shooter-exit";
    ball.stuckT = 0;
  }
}

function releaseStuckBall(ball) {
  const lane = TABLE.lane;
  const pinchedAtShooterExit = ball.x > lane.left - 42 && ball.x < lane.right + 10 && ball.y > 86 && ball.y < 204;
  const slow = Math.hypot(ball.vx, ball.vy) < 2.2;
  ball.stuckT = pinchedAtShooterExit && slow ? (ball.stuckT || 0) + 1 : 0;
  if (ball.stuckT < 18) return;
  ball.x = lane.left - 46;
  ball.y = lane.top + 70;
  ball.vx = -6.2;
  ball.vy = 6.4;
  ball.stuckT = 0;
  ball.lastHit = "unstuck";
}

function collideTableToys(ball, state, sound) {
  state.bumpers.forEach((bumper) => {
    if (collideCircle(ball, bumper, 1.2)) {
      const dx = ball.x - bumper.x;
      const dy = ball.y - bumper.y;
      const dist = Math.hypot(dx, dy) || 1;
      const speed = Math.max(10.5, Math.hypot(ball.vx, ball.vy) + 4.4);
      ball.vx = (dx / dist) * speed;
      ball.vy = (dy / dist) * speed - 2.4;
      bumper.pulse = 260;
      state.flash = 140;
      score(state, bumper.value, bumper.label);
      sound("bumper");
    }
    bumper.pulse = Math.max(0, bumper.pulse - 16);
  });
  state.standups.forEach((target) => {
    if (rectHit(ball, target)) {
      target.lit = true;
      ball.vx += target.side === "left" ? 3.2 : target.side === "right" ? -3.2 : 0;
      ball.vy = -Math.abs(ball.vy) - 2;
      score(state, target.value, target.label);
      sound("target");
    }
  });
  state.drops.forEach((drop) => {
    if (!drop.down && rectHit(ball, drop)) {
      drop.down = true;
      ball.vy = -Math.abs(ball.vy) - 2.8;
      score(state, 900, `DROP ${drop.label}`);
      sound("target");
    }
  });
  if (state.drops.every((drop) => drop.down)) {
    state.inserts.find((insert) => insert.id === "lock").mode = "blink";
  }
  if (collideCircle(ball, state.spinner, 0.85)) {
    state.spinner.spin += 0.6 + Math.abs(ball.vx) * 0.08;
    score(state, 360, "SPINNER");
    sound("target");
  }
  if (state.scoop.cooldown <= 0 && distance(ball, state.scoop) < ball.r + state.scoop.r) {
    state.scoop.cooldown = 1400;
    ball.x = 500;
    ball.y = 370;
    ball.vx = -7.5;
    ball.vy = -8.4;
    score(state, state.superJackpot ? state.jackpot * 2 : 1600, state.superJackpot ? "SUPER JACKPOT" : "SCOOP");
    state.superJackpot = false;
    sound("jackpot");
  }
  if (state.lockHole.cooldown <= 0 && distance(ball, state.lockHole) < ball.r + state.lockHole.r) {
    state.lockHole.cooldown = 1200;
    if (state.drops.every((drop) => drop.down) && state.lockedBalls < 2 && !state.multiball) {
      ball.locked = true;
      state.lockedBalls += 1;
      state.bonus += 2500;
      state.drops.forEach((drop) => { drop.down = false; });
      state.notice = `BALL ${state.lockedBalls} LOCKED`;
      state.noticeT = 1200;
      score(state, 2500, "BALL LOCKED");
      state.balls.push(makeBall(654, 770, 0, 0, true));
      state.status = "ready";
      sound("lock");
    } else if (state.lockedBalls >= 2 && !state.multiball) {
      startMultiball(state, sound);
      ball.vx = -8;
      ball.vy = -7.5;
    } else {
      ball.vx = -7.2;
      ball.vy = -8.2;
      score(state, 1200, "KICKOUT");
      sound("lock");
    }
  }
  rampShot(ball, state, sound);
}

function rampShot(ball, state, sound) {
  const enteringLeftRamp = ball.x > 170 && ball.x < 286 && ball.y > 590 && ball.y < 650 && ball.vy < -3;
  const enteringRightOrbit = ball.x > 494 && ball.x < 620 && ball.y > 585 && ball.y < 650 && ball.vy < -3;
  if (enteringLeftRamp && state.rampGate <= 0) {
    state.rampGate = 850;
    ball.x = 486;
    ball.y = 176;
    ball.vx = 5.6;
    ball.vy = 4.4;
    score(state, 1800, "JACKPOT RAMP");
    state.inserts.find((insert) => insert.id === "jackpot").mode = "blink";
    sound("ramp");
  } else if (enteringRightOrbit && state.rampGate <= 0) {
    state.rampGate = 650;
    ball.x = 154;
    ball.y = 184;
    ball.vx = -3.5;
    ball.vy = 6.2;
    score(state, 1400, "RIGHT ORBIT");
    sound("ramp");
  }
}

function collideFlippers(ball, state, keys, sound) {
  flippers(keys).forEach((flipper) => {
    if (ball.y > flipper.pivot.y + 28) return;
    if (line(ball, flipper.a.x, flipper.a.y, flipper.b.x, flipper.b.y, flipper.on ? 1.05 : 0.74, "flipper")) {
      const contact = projection(ball, flipper.a, flipper.b);
      if (flipper.on) {
        const center = flipper.side === "left" ? 5.8 : -5.8;
        ball.vx += center + center * contact * 0.42;
        ball.vy = Math.min(ball.vy, -13.2 - contact * 8.6);
        ball.y -= 4;
        state.combo += 1;
        score(state, 180 + contact * 140, "FLIP");
        sound("flip");
      }
    }
  });
}

function flippers(keys) {
  return [
    flipper(198, 790, "left", keys.left),
    flipper(562, 790, "right", keys.right),
  ];
}

function flipper(x, y, side, on) {
  const rest = side === "left" ? -0.16 : Math.PI + 0.16;
  const active = side === "left" ? -0.72 : Math.PI + 0.72;
  const angle = on ? active : rest;
  const len = 132;
  return {
    side,
    on,
    pivot: { x, y },
    a: { x, y },
    b: { x: x + Math.cos(angle) * len, y: y + Math.sin(angle) * len },
  };
}

function updateModes(state, sound) {
  if (state.letters.every((letter) => letter.lit)) {
    state.letters.forEach((letter) => { letter.lit = false; });
    state.bonus += 5000;
    state.mult = Math.min(6, state.mult + 1);
    score(state, 5000, "SPELL PEPPLE");
    state.inserts.find((insert) => insert.id === "bonus").mode = "blink";
  }
  if (state.streak >= 8) state.inserts.find((insert) => insert.id === "jackpot").mode = "on";
  if (state.streak >= 16) state.inserts.find((insert) => insert.id === "super").mode = "blink";
  if (state.multiball && state.balls.length < 2) state.superJackpot = true;
  if (state.streak >= 22 && state.ballsLeft < 4) {
    state.ballsLeft += 1;
    state.notice = "EXTRA BALL";
    state.noticeT = 1300;
    state.inserts.find((insert) => insert.id === "extra").mode = "blink";
    sound("jackpot");
  }
}

function startMultiball(state, sound) {
  state.multiball = true;
  state.lockedBalls = 0;
  state.status = "play";
  state.balls.push(makeBall(524, 420, -7.8, -7.2, false), makeBall(206, 328, 6.4, -5.2, false));
  state.notice = "MULTIBALL";
  state.noticeT = 1600;
  state.flash = 720;
  state.shake = 340;
  state.jackpot += 10000;
  state.inserts.find((insert) => insert.id === "multi").mode = "blink";
  state.inserts.find((insert) => insert.id === "jackpot").mode = "blink";
  sound("jackpot");
}

function nextBall(state, sound) {
  state.ballsLeft -= 1;
  state.score += Math.round(state.bonus * state.mult);
  state.bonus = 0;
  state.streak = 0;
  state.combo = 0;
  state.mult = 1;
  state.multiball = false;
  state.superJackpot = false;
  if (state.ballsLeft <= 0) {
    state.status = "gameover";
    state.notice = "GAME OVER";
    state.noticeT = 3000;
    sound("drain");
    return;
  }
  state.status = "ready";
  state.plunger = 0;
  state.plungerDir = 1;
  state.balls = [makeBall()];
  state.ballSaveUntil = state.time + 7000;
  state.notice = `${state.ballsLeft} BALLS LEFT`;
  state.noticeT = 1100;
  sound("drain");
}

function score(state, points, label) {
  const gained = Math.round(points * state.mult);
  state.score += gained;
  state.streak += 1;
  state.combo = Math.max(state.combo, 1);
  state.level = Math.max(state.level, Math.floor(state.score / 14000) + 1);
  state.jackpot += Math.round(gained * 0.18);
  state.notice = label;
  state.noticeT = 720;
}

function isDrain(ball) {
  if (ball.y > 878) return true;
  if (ball.y > TABLE.drain.y && ball.x > TABLE.drain.x1 && ball.x < TABLE.drain.x2) return true;
  if (ball.y > 788 && ball.x < 126) return true;
  if (ball.y > 788 && ball.x > 634) return true;
  return false;
}

function rectHit(ball, rect) {
  const cx = Math.max(rect.x, Math.min(ball.x, rect.x + rect.w));
  const cy = Math.max(rect.y, Math.min(ball.y, rect.y + rect.h));
  return Math.hypot(ball.x - cx, ball.y - cy) < ball.r + 3;
}

function collideCircle(ball, circle, bounce = 0.9) {
  const dx = ball.x - circle.x;
  const dy = ball.y - circle.y;
  const dist = Math.hypot(dx, dy) || 1;
  if (dist > ball.r + circle.r) return false;
  const nx = dx / dist;
  const ny = dy / dist;
  ball.x = circle.x + nx * (ball.r + circle.r + 0.5);
  ball.y = circle.y + ny * (ball.r + circle.r + 0.5);
  const dot = ball.vx * nx + ball.vy * ny;
  if (dot < 0) {
    ball.vx = (ball.vx - 2 * dot * nx) * bounce;
    ball.vy = (ball.vy - 2 * dot * ny) * bounce;
  }
  return true;
}

function line(ball, x1, y1, x2, y2, bounce = 0.86) {
  const a = { x: x1, y: y1 };
  const b = { x: x2, y: y2 };
  const t = projection(ball, a, b);
  const px = x1 + (x2 - x1) * t;
  const py = y1 + (y2 - y1) * t;
  const nx0 = ball.x - px;
  const ny0 = ball.y - py;
  const dist = Math.hypot(nx0, ny0) || 1;
  if (dist > ball.r + 4) return false;
  const nx = nx0 / dist;
  const ny = ny0 / dist;
  ball.x = px + nx * (ball.r + 4.2);
  ball.y = py + ny * (ball.r + 4.2);
  const dot = ball.vx * nx + ball.vy * ny;
  if (dot < 0) {
    ball.vx = (ball.vx - 2 * dot * nx) * bounce;
    ball.vy = (ball.vy - 2 * dot * ny) * bounce;
  }
  return true;
}

function reflect(ball, x, y, nx, ny, bounce) {
  ball.x = x;
  ball.y = y;
  const dot = ball.vx * nx + ball.vy * ny;
  if (dot < 0) {
    ball.vx = (ball.vx - 2 * dot * nx) * bounce;
    ball.vy = (ball.vy - 2 * dot * ny) * bounce;
  }
}

function projection(ball, a, b) {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const len2 = dx * dx + dy * dy || 1;
  return Math.max(0, Math.min(1, ((ball.x - a.x) * dx + (ball.y - a.y) * dy) / len2));
}

function distance(a, b) {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

export function renderPepplePinball(ctx, canvas, state, keys, status) {
  const t = state.time;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.save();
  if (state.shake > 0) ctx.translate((Math.random() - 0.5) * 4, (Math.random() - 0.5) * 4);
  drawCabinet(ctx);
  drawPlayfield(ctx);
  drawArtwork(ctx, state, t);
  drawMetalGuides(ctx);
  drawRamps(ctx, t);
  drawTargets(ctx, state, t);
  drawBumpers(ctx, state);
  drawPosts(ctx, state);
  drawSlings(ctx);
  drawDrain(ctx);
  flippers(keys).forEach((f) => drawFlipper(ctx, f));
  drawShooterLane(ctx, state);
  drawBalls(ctx, state);
  drawGlass(ctx);
  drawDmd(ctx, state, status, t);
  ctx.restore();
}

function drawCabinet(ctx) {
  const wood = ctx.createLinearGradient(0, 0, 0, TABLE.h);
  wood.addColorStop(0, "#622c1f");
  wood.addColorStop(0.34, "#2b1412");
  wood.addColorStop(1, "#090405");
  ctx.fillStyle = wood;
  round(ctx, 18, 10, 724, 900, 48);
  ctx.shadowColor = "rgba(0,0,0,.8)";
  ctx.shadowBlur = 28;
  ctx.fill();
  ctx.shadowBlur = 0;
}

function drawPlayfield(ctx) {
  const field = ctx.createLinearGradient(0, 58, 0, 872);
  field.addColorStop(0, "#141725");
  field.addColorStop(0.26, "#221322");
  field.addColorStop(0.58, "#101521");
  field.addColorStop(1, "#060406");
  ctx.fillStyle = field;
  round(ctx, 56, 34, 648, 858, 42);
  ctx.fill();
  ctx.save();
  ctx.strokeStyle = "rgba(244,220,174,.86)";
  ctx.lineWidth = 8;
  ctx.shadowColor = "#ffd99f";
  ctx.shadowBlur = 18;
  round(ctx, 64, 42, 632, 842, 38);
  ctx.stroke();
  ctx.strokeStyle = "rgba(255,255,255,.18)";
  ctx.lineWidth = 2;
  round(ctx, 82, 62, 596, 800, 28);
  ctx.stroke();
  ctx.restore();
  ctx.save();
  const sideShade = ctx.createLinearGradient(56, 0, 704, 0);
  sideShade.addColorStop(0, "rgba(0,0,0,.42)");
  sideShade.addColorStop(0.12, "rgba(255,220,166,.06)");
  sideShade.addColorStop(0.5, "rgba(255,255,255,0)");
  sideShade.addColorStop(0.88, "rgba(255,220,166,.06)");
  sideShade.addColorStop(1, "rgba(0,0,0,.42)");
  ctx.fillStyle = sideShade;
  round(ctx, 64, 42, 632, 842, 38);
  ctx.fill();
  ctx.restore();
  ctx.save();
  ctx.globalAlpha = 0.16;
  ctx.strokeStyle = "#ffe2aa";
  ctx.lineWidth = 1;
  for (let i = 0; i < 22; i += 1) {
    ctx.beginPath();
    ctx.moveTo(102 + i * 27, 70);
    ctx.lineTo(32 + i * 24, 872);
    ctx.stroke();
  }
  ctx.restore();
}

function drawArtwork(ctx, state, t) {
  ctx.save();
  ctx.textAlign = "center";
  ctx.font = "950 42px Inter, Arial";
  ctx.fillStyle = "rgba(255,244,228,.92)";
  ctx.shadowColor = "#ff5ea8";
  ctx.shadowBlur = 22;
  ctx.fillText("PEPPLE", 382, 330);
  ctx.font = "900 15px Inter, Arial";
  ctx.fillStyle = "rgba(255,210,125,.9)";
  ctx.fillText("COMPLETE PEP  *  HIT JACK  *  COMPLETE PLE", 382, 356);
  state.letters.forEach((letter, i) => {
    const lit = letter.lit || pulse(t, 900 + i * 40) > 0.65;
    insert(ctx, letter.x, letter.y, 30, letter.letter, lit ? "#ff5ea8" : "#372034", lit ? "on" : "off");
  });
  state.inserts.forEach((ins) => {
    const lit = ins.mode === "on" || (ins.mode === "blink" && pulse(t, 700) > 0.38);
    insert(ctx, ins.x, ins.y, ins.text.length > 3 ? 64 : 42, ins.text, ins.color, lit ? "on" : "off");
  });
  ctx.restore();
}

function drawMetalGuides(ctx) {
  ctx.save();
  ctx.lineCap = "round";
  ctx.strokeStyle = "rgba(225,222,208,.78)";
  ctx.lineWidth = 5;
  arc(ctx, 382, 294, 278, Math.PI * 1.06, Math.PI * 1.9);
  arc(ctx, 382, 302, 246, Math.PI * 1.08, Math.PI * 1.86);
  ctx.strokeStyle = "rgba(255,255,255,.36)";
  ctx.lineWidth = 2;
  arc(ctx, 382, 294, 286, Math.PI * 1.06, Math.PI * 1.9);
  ctx.restore();
}

function drawRamps(ctx, t) {
  ctx.save();
  ctx.lineCap = "round";
  ctx.shadowColor = "rgba(125,244,222,.38)";
  ctx.shadowBlur = 12;
  ctx.strokeStyle = "rgba(118,221,207,.18)";
  ctx.lineWidth = 20;
  ctx.beginPath();
  ctx.moveTo(206, 620);
  ctx.bezierCurveTo(212, 478, 328, 418, 504, 378);
  ctx.bezierCurveTo(586, 358, 626, 272, 610, 176);
  ctx.stroke();
  ctx.shadowBlur = 0;
  ctx.strokeStyle = "rgba(235,255,250,.78)";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(190, 610);
  ctx.bezierCurveTo(218, 480, 342, 422, 506, 386);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(224, 632);
  ctx.bezierCurveTo(238, 506, 356, 444, 530, 402);
  ctx.stroke();
  ctx.strokeStyle = "rgba(0,0,0,.28)";
  ctx.lineWidth = 12;
  ctx.beginPath();
  ctx.moveTo(218, 644);
  ctx.bezierCurveTo(238, 536, 356, 472, 538, 432);
  ctx.stroke();
  ctx.shadowBlur = 0;
  ctx.fillStyle = "rgba(255,210,125,.75)";
  [260, 410, 552].forEach((x, i) => {
    ctx.fillRect(x, 528 - i * 58 + Math.sin((t + i * 200) / 500) * 1, 8, 48);
  });
  ctx.restore();
}

function drawTargets(ctx, state, t) {
  state.rollovers.forEach((roll) => {
    ctx.fillStyle = roll.lit ? "#fff1b6" : "rgba(255,210,125,.38)";
    ctx.shadowColor = "#ffd27d";
    ctx.shadowBlur = roll.lit ? 18 : 5;
    round(ctx, roll.x, roll.y, roll.w, roll.h, 6);
    ctx.fill();
  });
  state.standups.forEach((target) => {
    ctx.save();
    ctx.shadowColor = target.label === "PLE" ? "#ff5ea8" : "#7bf4de";
    ctx.shadowBlur = target.lit ? 26 : 12;
    ctx.fillStyle = target.lit ? "#fff4d6" : (target.label === "PLE" ? "#ff5ea8" : "#7bf4de");
    round(ctx, target.x, target.y, target.w, target.h, 6);
    ctx.fill();
    ctx.restore();
  });
  state.drops.forEach((drop) => {
    ctx.save();
    ctx.globalAlpha = drop.down ? 0.28 : 1;
    ctx.fillStyle = drop.down ? "#2b1b20" : "#ffd27d";
    ctx.shadowColor = "#ffd27d";
    ctx.shadowBlur = drop.down ? 0 : 16;
    round(ctx, drop.x, drop.y, drop.w, drop.h, 5);
    ctx.fill();
    ctx.fillStyle = "#241014";
    ctx.font = "900 13px Inter, Arial";
    ctx.textAlign = "center";
    ctx.fillText(drop.label, drop.x + drop.w / 2, drop.y + 14);
    ctx.restore();
  });
  ctx.save();
  ctx.translate(state.spinner.x, state.spinner.y);
  ctx.rotate(state.spinner.angle);
  ctx.strokeStyle = "#f5d49b";
  ctx.lineWidth = 4;
  ctx.beginPath();
  ctx.moveTo(-22, 0);
  ctx.lineTo(22, 0);
  ctx.stroke();
  ctx.fillStyle = "#7bf4de";
  ctx.beginPath();
  ctx.arc(0, 0, 5, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
  hole(ctx, state.scoop.x, state.scoop.y, state.scoop.r, "SCOOP");
  hole(ctx, state.lockHole.x, state.lockHole.y, state.lockHole.r, "LOCK");
}

function drawBumpers(ctx, state) {
  state.bumpers.forEach((b) => {
    const scale = 1 + b.pulse / 720;
    ctx.save();
    ctx.translate(b.x, b.y);
    ctx.shadowColor = b.color;
    ctx.shadowBlur = 22 + b.pulse / 5;
    const grad = ctx.createRadialGradient(-10, -14, 4, 0, 0, b.r * scale);
    grad.addColorStop(0, "#fff8e8");
    grad.addColorStop(0.38, b.color);
    grad.addColorStop(1, "#321724");
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.arc(0, 0, b.r * scale, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "rgba(255,255,255,.86)";
    ctx.lineWidth = 4;
    ctx.stroke();
    ctx.fillStyle = "#13080d";
    ctx.font = "950 13px Inter, Arial";
    ctx.textAlign = "center";
    ctx.fillText(b.label, 0, 5);
    ctx.restore();
  });
}

function drawPosts(ctx, state) {
  state.posts.forEach((post) => {
    ctx.save();
    ctx.shadowColor = "#ffd27d";
    ctx.shadowBlur = 10;
    ctx.fillStyle = "#f4d59e";
    ctx.beginPath();
    ctx.arc(post.x, post.y, post.r, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "#ff5ea8";
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.arc(post.x, post.y, post.r + 5, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  });
}

function drawSlings(ctx) {
  ctx.save();
  ctx.shadowColor = "#ffd27d";
  ctx.shadowBlur = 18;
  ctx.fillStyle = "rgba(255,94,168,.28)";
  ctx.beginPath(); ctx.moveTo(126, 632); ctx.lineTo(254, 552); ctx.lineTo(206, 524); ctx.closePath(); ctx.fill();
  ctx.beginPath(); ctx.moveTo(634, 632); ctx.lineTo(506, 552); ctx.lineTo(554, 524); ctx.closePath(); ctx.fill();
  ctx.strokeStyle = "#f6d092";
  ctx.lineWidth = 8;
  ctx.beginPath(); ctx.moveTo(132, 612); ctx.lineTo(254, 552); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(628, 612); ctx.lineTo(506, 552); ctx.stroke();
  ctx.restore();
}

function drawDrain(ctx) {
  ctx.save();
  const apron = ctx.createLinearGradient(0, 730, 0, 890);
  apron.addColorStop(0, "rgba(255,94,168,.03)");
  apron.addColorStop(0.5, "rgba(0,0,0,.34)");
  apron.addColorStop(1, "rgba(0,0,0,.82)");
  ctx.fillStyle = apron;
  ctx.beginPath();
  ctx.moveTo(84, 854);
  ctx.lineTo(168, 704);
  ctx.lineTo(306, 778);
  ctx.quadraticCurveTo(380, 826, 454, 778);
  ctx.lineTo(592, 704);
  ctx.lineTo(676, 854);
  ctx.closePath();
  ctx.fill();
  ctx.shadowColor = "#000";
  ctx.shadowBlur = 32;
  ctx.fillStyle = "rgba(0,0,0,.92)";
  ctx.beginPath();
  ctx.ellipse(380, 828, 78, 34, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = "rgba(245,210,154,.46)";
  ctx.lineWidth = 4;
  ctx.beginPath();
  ctx.arc(380, 804, 72, 0.14, Math.PI - 0.14);
  ctx.stroke();
  ctx.strokeStyle = "rgba(255,94,168,.28)";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(306, 778);
  ctx.quadraticCurveTo(380, 826, 454, 778);
  ctx.stroke();
  ctx.restore();
}

function drawFlipper(ctx, f) {
  const angle = Math.atan2(f.b.y - f.a.y, f.b.x - f.a.x);
  ctx.save();
  ctx.translate(f.a.x, f.a.y);
  ctx.rotate(angle);
  ctx.lineCap = "round";
  ctx.shadowColor = f.on ? "#ffd27d" : "#ff5ea8";
  ctx.shadowBlur = f.on ? 24 : 10;
  ctx.strokeStyle = "rgba(0,0,0,.72)";
  ctx.lineWidth = 34;
  ctx.beginPath();
  ctx.moveTo(0, 0);
  ctx.lineTo(126, 0);
  ctx.stroke();
  const grad = ctx.createLinearGradient(0, -14, 126, 14);
  grad.addColorStop(0, "#ffe6b1");
  grad.addColorStop(0.42, "#ff704c");
  grad.addColorStop(0.78, "#ff4e9c");
  grad.addColorStop(1, "#7bf4de");
  ctx.strokeStyle = grad;
  ctx.lineWidth = 28;
  ctx.beginPath();
  ctx.moveTo(0, 0);
  ctx.lineTo(124, 0);
  ctx.stroke();
  ctx.strokeStyle = "rgba(255,255,255,.7)";
  ctx.lineWidth = 5;
  ctx.beginPath();
  ctx.moveTo(18, -7);
  ctx.lineTo(94, -6);
  ctx.stroke();
  ctx.restore();
  ctx.save();
  ctx.shadowColor = "#ffd27d";
  ctx.shadowBlur = 18;
  ctx.fillStyle = "#f6d49b";
  ctx.beginPath();
  ctx.arc(f.pivot.x, f.pivot.y, 18, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#391b23";
  ctx.beginPath();
  ctx.arc(f.pivot.x, f.pivot.y, 7, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

function drawShooterLane(ctx, state) {
  const lane = TABLE.lane;
  ctx.save();
  ctx.fillStyle = "rgba(1,4,8,.86)";
  round(ctx, lane.left, lane.top, lane.right - lane.left, lane.bottom - lane.top, 22);
  ctx.fill();
  ctx.strokeStyle = "rgba(230,222,198,.76)";
  ctx.lineWidth = 4;
  round(ctx, lane.left + 4, lane.top + 6, lane.right - lane.left - 8, lane.bottom - lane.top - 12, 18);
  ctx.stroke();
  for (let i = 0; i < 10; i += 1) {
    ctx.strokeStyle = "rgba(255,210,125,.72)";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(642, 744 - i * 20);
    ctx.lineTo(668, 736 - i * 20);
    ctx.stroke();
  }
  ctx.fillStyle = "#2e180f";
  round(ctx, 646, 704 + state.plunger * 80, 24, 124 - state.plunger * 78, 12);
  ctx.fill();
  ctx.fillStyle = "#f1bf75";
  round(ctx, 638, 688 + state.plunger * 90, 40, 28, 10);
  ctx.fill();
  ctx.font = "950 12px Inter, Arial";
  ctx.fillStyle = "#fff7e7";
  ctx.textAlign = "center";
  ctx.fillText("SPACE", 654, 842);
  ctx.restore();
}

function drawBalls(ctx, state) {
  state.balls.forEach((ball) => {
    if (ball.locked) return;
    ctx.save();
    ctx.shadowColor = "rgba(255,255,255,.8)";
    ctx.shadowBlur = 15;
    const g = ctx.createRadialGradient(ball.x - 4, ball.y - 6, 2, ball.x, ball.y, ball.r + 7);
    g.addColorStop(0, "#ffffff");
    g.addColorStop(0.25, "#dbeaff");
    g.addColorStop(0.62, "#6f7c8d");
    g.addColorStop(1, "#18202a");
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(ball.x, ball.y, ball.r, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  });
}

function drawGlass(ctx) {
  const g = ctx.createLinearGradient(70, 40, 690, 890);
  g.addColorStop(0, "rgba(255,255,255,.10)");
  g.addColorStop(0.22, "rgba(255,255,255,.02)");
  g.addColorStop(0.54, "rgba(255,255,255,.055)");
  g.addColorStop(0.64, "rgba(255,255,255,.02)");
  g.addColorStop(1, "rgba(255,255,255,.06)");
  ctx.fillStyle = g;
  ctx.fillRect(56, 34, 648, 858);
  if (ctx.globalAlpha !== undefined) {
    ctx.fillStyle = "rgba(255,244,228,.08)";
  }
}

function drawDmd(ctx, state, status, t) {
  ctx.save();
  ctx.fillStyle = "rgba(0,0,0,.78)";
  round(ctx, 110, 70, 540, 60, 5);
  ctx.fill();
  ctx.strokeStyle = "rgba(255,210,125,.26)";
  ctx.stroke();
  ctx.fillStyle = "#ffe9c6";
  ctx.font = "950 21px Inter, Arial";
  ctx.textAlign = "left";
  ctx.fillText(`SCORE ${state.score.toLocaleString("de-DE")}`, 132, 107);
  ctx.textAlign = "right";
  ctx.font = "900 13px Inter, Arial";
  ctx.fillStyle = pulse(t, 800) > 0.5 && state.noticeT > 0 ? "#7bf4de" : "#ffd27d";
  ctx.fillText(`${state.notice || status.toUpperCase()}  BALL ${state.ballsLeft}  x${state.mult}`, 632, 105);
  if (state.flash > 0) {
    ctx.fillStyle = `rgba(255,244,226,${Math.min(0.18, state.flash / 2600)})`;
    ctx.fillRect(56, 34, 648, 858);
  }
  ctx.restore();
}

function insert(ctx, x, y, w, text, color, mode) {
  ctx.save();
  ctx.globalAlpha = mode === "off" ? 0.46 : 1;
  ctx.shadowColor = color;
  ctx.shadowBlur = mode === "off" ? 2 : 18;
  ctx.fillStyle = mode === "off" ? "rgba(22,14,20,.92)" : color;
  round(ctx, x - w / 2, y - 14, w, 28, 14);
  ctx.fill();
  ctx.strokeStyle = "rgba(255,255,255,.32)";
  ctx.stroke();
  ctx.fillStyle = mode === "off" ? "rgba(255,255,255,.44)" : "#12080d";
  ctx.font = "950 10px Inter, Arial";
  ctx.textAlign = "center";
  ctx.fillText(text, x, y + 4);
  ctx.restore();
}

function hole(ctx, x, y, r, label) {
  ctx.save();
  ctx.shadowColor = "#000";
  ctx.shadowBlur = 18;
  ctx.fillStyle = "#020203";
  ctx.beginPath();
  ctx.ellipse(x, y, r + 6, r + 2, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = "rgba(255,210,125,.6)";
  ctx.lineWidth = 3;
  ctx.stroke();
  ctx.fillStyle = "#ffd27d";
  ctx.font = "950 10px Inter, Arial";
  ctx.textAlign = "center";
  ctx.fillText(label, x, y + r + 18);
  ctx.restore();
}

function arc(ctx, x, y, r, a1, a2) {
  ctx.beginPath();
  ctx.arc(x, y, r, a1, a2);
  ctx.stroke();
}

function round(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

function pulse(t, period) {
  return (Math.sin((t / period) * Math.PI * 2) + 1) / 2;
}
