export const SPECIAL_WEAPONS = [
  { id: "rail", name: "Railgun", kind: "weapon", icon: "rail", desc: "Durchschlägt ganze Gegnerreihen.", color: "#69e7f8" },
  { id: "comet", name: "Kometensalve", kind: "weapon", icon: "comet", desc: "Zielsuchende Raketen mit Flächenschaden.", color: "#ffad74" },
];

export const WEAPON_ART = { feather: 0, bolt: 0, laser: 1, egg: 2, thunder: 3, gravity: 4, rail: 5, comet: 6, drone: 7, frost: 8, nova: 9, aura: 9, might: 9, orbit: 10, shield: 10, regen: 2, magnet: 4, boots: 11, speed: 11, cooldown: 3 };
export const evolutionTier = (level) => level >= 8 ? 2 : level >= 4 ? 1 : 0;
export const evolutionMultiplier = (level) => [1, 1.22, 1.5][evolutionTier(level)];

export function distanceToSegment(point, start, end) {
  const dx = end.x - start.x, dy = end.y - start.y, length = dx * dx + dy * dy;
  const amount = length ? Math.max(0, Math.min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / length)) : 0;
  return Math.hypot(point.x - (start.x + dx * amount), point.y - (start.y + dy * amount));
}

export function updateSpecialWeapons(state, dt, helpers) {
  const { visible, damageMult, cooldownMult, burst, ring, sound } = helpers;
  state.timers.rail = (state.timers.rail ?? 500) - dt;
  state.timers.comet = (state.timers.comet ?? 700) - dt;
  const targets = state.enemies.filter((enemy) => enemy.hp > 0);
  if (state.weapons.rail && state.timers.rail <= 0 && targets.length) {
    const level = state.weapons.rail;
    const target = visible(targets, state.player.x, state.player.y).sort((a, b) => Math.hypot(a.x - state.player.x, a.y - state.player.y) - Math.hypot(b.x - state.player.x, b.y - state.player.y))[0];
    if (target) {
      const angle = Math.atan2(target.y - state.player.y, target.x - state.player.x);
      const end = { x: state.player.x + Math.cos(angle) * 1100, y: state.player.y + Math.sin(angle) * 1100 };
      const damage = (65 + level * 20) * damageMult * evolutionMultiplier(level);
      const width = 8 + level * 1.2;
      // Obstacles still block each hit, even when the visual beam extends further.
      visible(targets, state.player.x, state.player.y).forEach((enemy) => {
        if (distanceToSegment(enemy, state.player, end) < enemy.radius + width) {
          enemy.hp -= damage; burst(enemy.x, enemy.y, "#69e7f8", 7);
        }
      });
      state.beams.push({ x1: state.player.x, y1: state.player.y, x2: end.x, y2: end.y, life: 350, ttl: 350, color: "#69e7f8", width, type: "rail" });
      ring(state.player.x, state.player.y, 48, 250, "#69e7f8"); sound("rail");
      state.timers.rail = Math.max(680, (3000 - level * 190) * cooldownMult);
    }
  }
  if (state.weapons.comet && state.timers.comet <= 0 && targets.length) {
    const level = state.weapons.comet, tier = evolutionTier(level);
    const pool = visible(targets, state.player.x, state.player.y);
    const count = Math.min(pool.length, 1 + Math.floor(level / 3) + tier);
    for (let index = 0; index < count; index++) {
      const target = pool[index], angle = Math.atan2(target.y - state.player.y, target.x - state.player.x) + (index - (count - 1) / 2) * 0.3;
      state.shots.push({ type: "comet", x: state.player.x, y: state.player.y, vx: Math.cos(angle) * 6, vy: Math.sin(angle) * 6,
        target, life: 2000, damage: (35 + level * 12) * damageMult * evolutionMultiplier(level), blastRadius: 65 + level * 9, pierce: 0 });
    }
    if (count) { sound("comet"); state.timers.comet = Math.max(850, (2600 - level * 130) * cooldownMult); }
  }
}

export function steerComet(shot, enemies, dt) {
  if (!shot.target || shot.target.hp <= 0 || !enemies.includes(shot.target)) {
    shot.target = enemies.filter((enemy) => enemy.hp > 0).sort((a, b) => Math.hypot(a.x - shot.x, a.y - shot.y) - Math.hypot(b.x - shot.x, b.y - shot.y))[0];
  }
  if (!shot.target) return;
  const dx = shot.target.x - shot.x, dy = shot.target.y - shot.y, distance = Math.max(1, Math.hypot(dx, dy));
  const amount = Math.min(1, dt / 90);
  shot.vx += (dx / distance * 8.5 - shot.vx) * amount;
  shot.vy += (dy / distance * 8.5 - shot.vy) * amount;
}

export function explodeComet(shot, state, helpers) {
  if (shot.exploded) return;
  shot.exploded = true; shot.life = 0;
  state.enemies.forEach((enemy) => {
    if (Math.hypot(enemy.x - shot.x, enemy.y - shot.y) <= shot.blastRadius + enemy.radius) enemy.hp -= shot.damage;
  });
  helpers.burst(shot.x, shot.y, "#ffad74", 28);
  helpers.ring(shot.x, shot.y, shot.blastRadius, 550, "#ffad74");
  helpers.sound("explosion");
}
