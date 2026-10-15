import { test, expect } from "@playwright/test";
import { join } from "node:path";
import { tmpdir } from "node:os";

async function setup(page, { guest = false, failSave = false } = {}) {
  const user = { username: "Kyoko", role: "member", chickens: 100, chickens_earned: 100, level: 1 };
  const starts = [], saves = [];
  let failures = failSave ? 1 : 0;
  await page.route("**/api/**", async (route) => {
    const request = route.request(), path = new URL(request.url()).pathname;
    let json = [];
    if (path.endsWith("/auth/me")) json = { user: guest ? null : user };
    else if (path.endsWith("/game-runs")) { starts.push(request.postDataJSON()); json = { run_id: `snake-registered-round-${starts.length}` }; }
    else if (path.endsWith("/scores") && request.method() === "POST") {
      saves.push(request.postDataJSON());
      if (failures-- > 0) return route.fulfill({ status: 503, json: { detail: "Kurz offline. Bitte erneut speichern." } });
      user.chickens += 3;
      json = { message: "Score gespeichert. +3 Chickens!", wallet: { ...user }, is_highscore: false };
    } else if (path.endsWith("/scores/chicken-snake")) json = [{ username: "Kyoko", score: 4500 }, { username: "Aviary", score: 1200 }];
    else if (path.endsWith("/dashboard")) json = { stats: {}, leaderboard: [], active_members: [], news: [], events: [] };
    await route.fulfill({ json });
  });
  await page.goto("/#games/chicken-snake");
  await expect(page.locator(".snakeGame")).toHaveAttribute("data-status", "ready");
  return { starts, saves };
}

const read = (page, property) => page.locator(".snakeCanvas").evaluate((canvas, key) => canvas.__snakeGame.engine[key], property);

test("garden art, real movement, growing snake, pause, auto-pause and clean desktop rendering", async ({ page }) => {
  const errors = []; page.on("pageerror", (error) => errors.push(error.message));
  await page.setViewportSize({ width: 1536, height: 1024 });
  const { starts } = await setup(page);
  await expect(page.locator(".snakeHud")).toContainText("4.500");
  expect(await page.locator(".snakeCanvas").evaluate((canvas) => {
    const game = canvas.__snakeGame, probe = document.createElement("canvas");
    probe.width = 2; probe.height = 2;
    const ctx = probe.getContext("2d"); ctx.drawImage(game.sprites, 0, 0);
    return { transparent: ctx.getImageData(0, 0, 1, 1).data[3] === 0, spritesLoaded: game.sprites.complete };
  })).toEqual({ transparent: true, spritesLoaded: true });
  await page.locator(".snakeGame").screenshot({ path: join(tmpdir(), "aviary-snake-desktop-ready.png") });
  await page.getByRole("button", { name: "Spiel starten", exact: true }).click();
  await expect.poll(() => starts.length).toBe(1);
  await page.keyboard.press("p");
  await expect(page.locator(".snakeGame")).toHaveAttribute("data-status", "paused");
  const before = await read(page, "snake");
  await page.waitForTimeout(400);
  expect(await read(page, "snake")).toEqual(before);
  await page.getByRole("button", { name: "Weiterspielen", exact: true }).click();
  await expect(page.getByTestId("snake-score")).toHaveText("10");
  expect((await read(page, "snake")).length).toBe(6);
  expect(starts).toEqual([{ game: "chicken-snake" }]);
  await page.locator(".snakeGame").screenshot({ path: join(tmpdir(), "aviary-snake-desktop-playing.png") });
  await page.evaluate(() => window.dispatchEvent(new Event("blur")));
  await expect(page.locator(".snakeGame")).toHaveAttribute("data-status", "paused");
  await page.getByRole("button", { name: "Sound ausschalten" }).click();
  await expect(page.getByRole("button", { name: "Sound einschalten" })).toHaveAttribute("aria-pressed", "false");
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  expect(errors).toEqual([]);
});

test("real self collision ends play; failed saving is retryable and successful double click credits only once", async ({ page }) => {
  const { starts, saves } = await setup(page, { failSave: true });
  await page.getByRole("button", { name: "Spiel starten", exact: true }).click();
  await expect(page.getByTestId("snake-score")).toHaveText("10");
  await page.evaluate(() => {
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowUp" }));
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowLeft" }));
  });
  await expect.poll(() => read(page, "direction"), { intervals: [10] }).toEqual({ x: -1, y: 0 });
  await page.keyboard.press("ArrowDown");
  await expect(page.getByText("Deine Spur war schneller.", { exact: true })).toBeVisible();
  expect(await read(page, "reason")).toBe("collision");
  await page.getByRole("button", { name: "Score speichern", exact: true }).click();
  await expect(page.getByRole("status")).toHaveText("Kurz offline. Bitte erneut speichern.");
  await page.getByRole("button", { name: "Score speichern", exact: true }).evaluate((button) => { button.click(); button.click(); });
  await expect(page.getByRole("button", { name: "Runde gewertet", exact: true })).toBeDisabled();
  await expect(page.locator(".communityBalances")).toHaveText("103Chickens");
  expect(saves).toHaveLength(2); // Failed request plus exactly one retry.
  expect(saves[1]).toEqual({ game: "chicken-snake", run_id: "snake-registered-round-1", score: 10, level: 1 });
  expect(starts).toHaveLength(1);
  await page.locator(".snakeGame").screenshot({ path: join(tmpdir(), "aviary-snake-desktop-result.png") });
  await page.getByRole("button", { name: "Nochmal spielen", exact: true }).click();
  await expect(page.getByTestId("snake-score")).toHaveText("0");
  await expect.poll(() => starts.length).toBe(2);
});

test("mobile touch pad and swipes steer the real game; guest results do not register or submit rewards", async ({ browser }) => {
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
  const page = await context.newPage();
  const errors = []; page.on("pageerror", (error) => errors.push(error.message));
  const { starts, saves } = await setup(page, { guest: true });
  const startY = (await read(page, "snake"))[0].y;
  await page.locator(".snakeGame").screenshot({ path: join(tmpdir(), "aviary-snake-mobile-ready.png") });
  await page.getByRole("button", { name: "Spiel starten", exact: true }).tap();
  await page.getByRole("button", { name: "Nach oben", exact: true }).tap();
  await expect.poll(async () => (await read(page, "snake"))[0].y).toBeLessThan(startY);
  const before = (await read(page, "snake"))[0];
  const box = await page.locator(".snakeCanvas").boundingBox();
  const cdp = await context.newCDPSession(page);
  await cdp.send("Input.dispatchTouchEvent", { type: "touchStart", touchPoints: [{ x: box.x + box.width / 2, y: box.y + box.height / 2 }] });
  await cdp.send("Input.dispatchTouchEvent", { type: "touchMove", touchPoints: [{ x: box.x + box.width / 2 - 55, y: box.y + box.height / 2 }] });
  await cdp.send("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
  await expect.poll(async () => (await read(page, "snake"))[0].x).toBeLessThan(before.x);
  await page.locator(".snakeGame").screenshot({ path: join(tmpdir(), "aviary-snake-mobile-playing.png") });
  await page.getByRole("button", { name: "Runde abschließen", exact: true }).tap();
  await expect(page.getByText("Gut geschlängelt!", { exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: "Score speichern", exact: true })).toHaveCount(0);
  expect(starts).toEqual([]); expect(saves).toEqual([]);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  const resultBox = await page.locator(".snakeOverlayContent").boundingBox();
  expect(resultBox.x).toBeGreaterThanOrEqual(0);
  expect(resultBox.x + resultBox.width).toBeLessThanOrEqual(390);
  expect((await page.locator(".snakeStage").boundingBox()).width).toBeLessThan(390);
  await page.locator(".snakeGame").screenshot({ path: join(tmpdir(), "aviary-snake-mobile-result.png") });
  expect(errors).toEqual([]);
  await context.close();
});

test("missing art has a working retry; mobile fallback fullscreen can be exited and results fit", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  let missing = true;
  await page.route("**/assets/snake/jade-sprites.png", (route) => missing ? route.abort() : route.continue());
  await page.route("**/api/**", (route) => route.fulfill({ json: new URL(route.request().url()).pathname.endsWith("/auth/me") ? { user: null } : [] }));
  await page.goto("/#games/chicken-snake");
  await expect(page.getByRole("button", { name: "Erneut laden", exact: true })).toBeVisible();
  const retryBox = await page.getByRole("button", { name: "Erneut laden", exact: true }).boundingBox();
  const errorBox = await page.locator(".snakeStage").boundingBox();
  expect(retryBox.y + retryBox.height).toBeLessThanOrEqual(errorBox.y + errorBox.height);
  missing = false;
  await page.getByRole("button", { name: "Erneut laden", exact: true }).click();
  await expect(page.locator(".snakeGame")).toHaveAttribute("data-status", "ready");
  await page.locator(".snakeGame").evaluate((element) => { element.requestFullscreen = undefined; });
  await page.getByRole("button", { name: "Vollbild öffnen" }).click();
  await expect(page.locator(".snakeGame")).toHaveClass(/isExpanded/);
  await page.getByRole("button", { name: "Spiel starten", exact: true }).click();
  await expect(page.getByTestId("snake-score")).toHaveText("10");
  await page.getByRole("button", { name: "Runde abschließen", exact: true }).click();
  const result = await page.locator(".snakeOverlayContent").boundingBox();
  expect(result.x).toBeGreaterThanOrEqual(0); expect(result.x + result.width).toBeLessThanOrEqual(390);
  await page.keyboard.press("Escape");
  await expect(page.locator(".snakeGame")).not.toHaveClass(/isExpanded/);
  expect(await page.evaluate(() => document.body.style.overflow)).toBe("");
});

test("fullscreen is usable and reduced-motion retains gameplay while disabling decorative motion", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await setup(page);
  expect(await page.locator(".snakeCanvas").evaluate((canvas) => canvas.__snakeGame.reducedMotion)).toBe(true);
  await page.getByRole("button", { name: "Vollbild öffnen" }).click();
  await expect(page.getByRole("button", { name: "Vollbild schließen" })).toBeVisible();
  await page.getByRole("button", { name: "Spiel starten", exact: true }).click();
  await expect(page.getByTestId("snake-score")).toHaveText("10");
  const size = await page.locator(".snakeStage").boundingBox();
  expect(size.width).toBeGreaterThan(1200); expect(size.height).toBeGreaterThan(700);
  await page.screenshot({ path: join(tmpdir(), "aviary-snake-fullscreen.png") });
  await page.getByRole("button", { name: "Vollbild schließen" }).click();
  await expect(page.getByRole("button", { name: "Vollbild öffnen" })).toBeVisible();
});
