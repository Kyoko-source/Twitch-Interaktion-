import { test, expect } from "@playwright/test";
import { join } from "node:path";
import { tmpdir } from "node:os";

async function setup(page, { guest = false, assetFailure = false } = {}) {
  const user = { username: "Kyoko", role: "member", chickens: 100, chickens_earned: 100, level: 1 };
  const starts = [], saves = [], rows = [{ username: "Aviary", score: 9000 }];
  await page.route("**/api/**", async route => {
    const request = route.request(), path = new URL(request.url()).pathname;
    let json = [];
    if (path.endsWith("/auth/me")) json = { user: guest ? null : user };
    else if (path.endsWith("/game-runs")) { starts.push(request.postDataJSON()); json = { run_id: `survivor-round-${starts.length}` }; }
    else if (path.endsWith("/scores") && request.method() === "POST") {
      const score = request.postDataJSON(); saves.push(score); rows.push({ ...score, username: user.username });
      user.chickens += 4; json = { message: "Score gespeichert. +4 Chickens!", wallet: { ...user } };
    } else if (path.endsWith("/scores/braincell-survivor")) json = rows;
    else if (path.endsWith("/dashboard")) json = { stats: {}, leaderboard: [], active_members: [], news: [], events: [] };
    await route.fulfill({ json });
  });
  await page.goto("/#games/braincell-survivor");
  if (!assetFailure) await expect(page.getByRole("button", { name: "Spiel starten", exact: true })).toBeEnabled({ timeout: 20000 });
  return { starts, saves };
}
const game = (page, callback, value) => page.locator(".survivorCanvas").evaluate((canvas, args) => {
  return (new Function("game", "value", `return (${args.callback})(game, value)`))(canvas.__survivorGame, args.value);
}, { callback: callback.toString(), value });

test("desktop: real WASD, pause, save exact final state once and visible personal highscore", async ({ page }) => {
  const errors = []; page.on("pageerror", e => errors.push(e.message));
  await page.setViewportSize({ width: 1536, height: 1024 });
  const { starts, saves } = await setup(page);
  await page.locator(".survivorV2").screenshot({ path: join(tmpdir(), "aviary-survivor-menu.png") });
  await page.getByRole("button", { name: "Spiel starten", exact: true }).click();
  await expect.poll(() => starts.length).toBe(1);
  const x = await game(page, g => g.state.player.x);
  await page.keyboard.down("d");
  await expect.poll(() => game(page, g => g.state.player.x)).toBeGreaterThan(x + 50);
  await page.keyboard.up("d");
  await page.keyboard.press("p");
  await expect(page.locator(".survivorV2")).toHaveAttribute("data-status", "paused");
  const time = await game(page, g => g.state.seconds);
  await page.waitForTimeout(250);
  expect(await game(page, g => g.state.seconds)).toBe(time);
  await page.locator(".survivorScreenPanel").getByRole("button", { name: "Fortsetzen" }).click();
  await page.getByRole("button", { name: "Vollbild öffnen", exact: true }).click();
  await expect.poll(() => page.evaluate(() => document.fullscreenElement?.classList.contains("survivorBattleGrid"))).toBe(true);
  await page.locator(".survivorFullExit").click();
  await expect.poll(() => page.evaluate(() => Boolean(document.fullscreenElement))).toBe(false);
  await game(page, g => { g.state.score = 1234; g.state.kills = 17; });
  await page.getByRole("button", { name: "Run beenden" }).click();
  await expect(page.locator(".survivorFinalScore")).toContainText("1.234");
  await page.getByRole("button", { name: "Score & Chickens einreichen" }).evaluate(b => { b.click(); b.click(); });
  await expect(page.getByRole("button", { name: "Runde gewertet" })).toBeDisabled();
  expect(saves).toHaveLength(1);
  expect(saves[0]).toMatchObject({ game: "braincell-survivor", run_id: "survivor-round-1", score: 1234, kills: 17, build: "bolt:1" });
  await expect(page.locator(".communityBalances")).toHaveText("104Chickens");
  await expect(page.locator(".gameScores")).toContainText("Kyoko1.234");
  expect(errors).toEqual([]);
});

test("upgrades freeze combat; rail, comets, all evolved weapons and boss run without errors", async ({ page }) => {
  const errors = []; page.on("pageerror", e => errors.push(e.message));
  await setup(page, { guest: true });
  await page.getByRole("button", { name: "Spiel starten", exact: true }).click();
  await game(page, g => g.gainXp(g.state.nextXp));
  await expect(page.locator(".survivorUpgradeCard")).toHaveCount(3);
  await expect(page.locator(".survivorV2")).toHaveAttribute("data-status", "levelup");
  const seconds = await game(page, g => g.state.seconds);
  await page.waitForTimeout(150);
  expect(await game(page, g => g.state.seconds)).toBe(seconds);
  await page.locator(".survivorV2").screenshot({ path: join(tmpdir(), "aviary-survivor-upgrades.png") });
  await page.locator(".survivorUpgradeCard").first().click();
  await expect(page.locator(".survivorV2")).toHaveAttribute("data-status", "play");
  await game(page, g => {
    g.state.obstacles = []; g.state.player.invuln = 60000;
    for (const weapon of Object.keys(g.state.weapons)) g.state.weapons[weapon] = 8;
    g.state.seconds = 179.99;
  });
  await expect.poll(() => game(page, g => g.state.bossActive)).toBe(true);
  await expect(page.locator(".survivorBossPanel")).toContainText("Boss aktiv");
  await page.keyboard.down("d");
  await expect.poll(() => game(page, g => g.state.enemies.some(e => e.boss && e.hp < e.maxHp))).toBe(true);
  await page.locator(".survivorV2").screenshot({ path: join(tmpdir(), "aviary-survivor-combat.png") });
  await page.waitForTimeout(1800);
  await page.keyboard.up("d");
  expect(await game(page, g => [g.state.player.x, g.state.player.y, g.state.player.hp, ...g.state.shots.flatMap(s => [s.x, s.y])].every(Number.isFinite))).toBe(true);
  expect(await game(page, g => g.state.shots.length)).toBeLessThanOrEqual(88);
  await page.evaluate(() => window.dispatchEvent(new Event("blur")));
  await expect(page.locator(".survivorV2")).toHaveAttribute("data-status", "paused");
  expect(errors).toEqual([]);
});

test("mobile: real captured touch movement, first subsequent button tap, stacked upgrade cards", async ({ browser }) => {
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
  const page = await context.newPage();
  const errors = []; page.on("pageerror", e => errors.push(e.message));
  const { starts, saves } = await setup(page, { guest: true });
  await page.getByRole("button", { name: "Spiel starten", exact: true }).tap();
  await page.getByRole("group", { name: "Bewegungsstick" }).scrollIntoViewIfNeeded();
  const box = await page.getByRole("group", { name: "Bewegungsstick" }).boundingBox();
  const x = await game(page, g => g.state.player.x);
  const cdp = await context.newCDPSession(page);
  const touch = [{ x: box.x + box.width / 2 + 32, y: box.y + box.height / 2 }];
  await cdp.send("Input.dispatchTouchEvent", { type: "touchStart", touchPoints: touch });
  await expect.poll(() => game(page, g => g.state.player.x)).toBeGreaterThan(x + 25);
  await cdp.send("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
  await page.getByRole("button", { name: "Run beenden" }).tap();
  await expect(page.locator(".survivorV2")).toHaveAttribute("data-status", "gameover");
  await page.getByRole("button", { name: "Nochmal spielen" }).tap();
  await game(page, g => g.gainXp(g.state.nextXp));
  await expect(page.locator(".survivorUpgradeCard")).toHaveCount(3);
  const last = await page.locator(".survivorUpgradeCard").last().boundingBox();
  const stage = await page.locator(".survivorStage").boundingBox();
  expect(last.y + last.height).toBeLessThan(stage.y + stage.height);
  await page.locator(".survivorV2").screenshot({ path: join(tmpdir(), "aviary-survivor-mobile.png") });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.locator(".survivorUpgradeCard").last().tap();
  await expect(page.locator(".survivorV2")).toHaveAttribute("data-status", "play");
  expect(starts).toHaveLength(0); expect(saves).toHaveLength(0); expect(errors).toEqual([]);
  await context.close();
});

test("asset errors can retry, audio options persist and zero volume is respected", async ({ page }) => {
  await page.route("**/assets/survivor/nebula.png", route => route.abort());
  await setup(page, { assetFailure: true });
  await expect(page.getByRole("button", { name: "Erneut laden", exact: true })).toBeEnabled();
  await page.unroute("**/assets/survivor/nebula.png");
  await page.getByRole("button", { name: "Erneut laden", exact: true }).click();
  await expect(page.getByRole("button", { name: "Spiel starten", exact: true })).toBeEnabled();
  await page.getByRole("button", { name: "Optionen", exact: true }).click();
  await page.getByLabel("Lautstärke").fill("0");
  await page.getByLabel("Sound", { exact: true }).uncheck();
  await page.getByRole("button", { name: "Zurück zum Spiel" }).click();
  await expect(page.getByRole("button", { name: "Sound einschalten" })).toHaveAttribute("aria-pressed", "false");
  expect(await page.evaluate(() => JSON.parse(localStorage.getItem("pepple-survivor-settings-v1")))).toMatchObject({ audioOn: false, volume: 0 });
});
