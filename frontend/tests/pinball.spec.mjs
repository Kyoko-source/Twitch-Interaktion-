import { test, expect } from "@playwright/test";

async function mockApi(page, { user = null } = {}) {
  const starts = [], scores = [];
  await page.route("**/api/**", async (route) => {
    const request = route.request(), path = new URL(request.url()).pathname;
    let json = [];
    if (path.endsWith("/auth/me")) json = { user };
    else if (path.endsWith("/game-runs")) { starts.push(request.postDataJSON()); json = { run_id: `pin-run-${starts.length}-abcdefghijklmnop` }; }
    else if (path.endsWith("/scores") && request.method() === "POST") { scores.push(request.postDataJSON()); json = { message: "Score gespeichert. +5 Chickens!", wallet: user }; }
    return route.fulfill({ json });
  });
  return { starts, scores };
}

async function openPinball(page) {
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto("/#games/chicken-flipper");
  await page.waitForFunction(() => document.querySelector(".pbStage")?.__pinball?.renderer?.composer, null, { timeout: 30000 });
  return errors;
}
const game = (page, fn, arg) => page.locator(".pbStage").evaluate((el, [src, a]) => new Function("s", "a", src)(el.__pinball, a), [fn, arg]);

test("table renders, Enter starts, the plunger launches the ball out of the shooter lane", async ({ page }) => {
  await mockApi(page);
  const errors = await openPinball(page);
  await expect(page.getByRole("button", { name: "Spiel starten" })).toBeVisible();
  await page.keyboard.press("Enter");
  await expect.poll(() => game(page, "return s.engine.status")).toBe("ready");
  await page.keyboard.down("Space");
  await page.waitForTimeout(1400);
  await page.keyboard.up("Space");
  await expect.poll(() => game(page, "return s.engine.status")).toBe("play");
  await expect.poll(() => game(page, "return s.engine.world.balls[0]?.y ?? 99")).toBeLessThan(16);
  const lit = await game(page, `s.renderer.composer.render(0); const r = s.renderer.renderer, gl = r.getContext(); const w = r.domElement.width, h = r.domElement.height, d = new Uint8Array(4 * 64);
    let bright = 0; for (let i = 0; i < 40; i++) { gl.readPixels(Math.floor(w * (0.2 + 0.015 * i)), Math.floor(h * 0.5), 8, 8, gl.RGBA, gl.UNSIGNED_BYTE, d); for (let k = 0; k < d.length; k += 4) if (d[k] + d[k + 1] + d[k + 2] > 60) bright++; } return bright;`);
  expect(lit).toBeGreaterThan(0);
  expect(errors).toEqual([]);
});

test("flipper keys raise the bats and a cradled ball is shot back up the table", async ({ page }) => {
  await mockApi(page);
  await openPinball(page);
  await page.keyboard.press("Enter");
  await game(page, "const e = s.engine; e.status = 'play'; const b = e.world.balls[0]; b.x = 1.5; b.y = 13.9; b.vx = 0.6; b.vy = 6;");
  await page.keyboard.down("KeyA");
  await page.waitForTimeout(1500);
  expect(await game(page, "return s.engine.table.flipL.angle")).toBeLessThan(0);
  await page.keyboard.up("KeyA");
  await page.waitForTimeout(280);
  await page.keyboard.down("KeyA");
  await expect.poll(() => game(page, "return s.engine.world.balls[0].y"), { timeout: 3000 }).toBeLessThan(13);
  await page.keyboard.up("KeyA");
  await page.keyboard.down("ArrowRight");
  await expect.poll(() => game(page, "return s.engine.table.flipR.angle")).toBeGreaterThan(Math.PI);
  await page.keyboard.up("ArrowRight");
});

test("three VIP locks start a three-ball multiball and the side panel follows", async ({ page }) => {
  await mockApi(page);
  await openPinball(page);
  await page.keyboard.press("Enter");
  await game(page, `const e = s.engine; e.status = 'play'; e.switchHit(); const b = e.world.balls[0];
    for (let n = 0; n < 3; n++) { for (const d of e.table.drops) d.enabled = true; for (const d of e.table.drops) e.dropHit(d); b.held = null; b.ignoreScoopUntil = 0; e.scoop(b); }`);
  await expect(page.locator(".pbLockRow")).toContainText("MULTIBALL!");
  await expect.poll(() => game(page, "return s.engine.world.balls.length"), { timeout: 8000 }).toBe(3);
});

test("game over submits the score once for a logged-in player", async ({ page }) => {
  const { starts, scores } = await mockApi(page, { user: { username: "magical_kyoko_", role: "admin", chickens: 10, chickens_earned: 10, level: 1 } });
  await openPinball(page);
  await page.getByRole("button", { name: "Spiel starten" }).click();
  await expect.poll(() => starts.length).toBe(1);
  expect(starts[0].game).toBe("chicken-flipper");
  await game(page, `const e = s.engine; e.score = 1234560; e.ball = 3; e.status = 'play'; e.ballSaveUntil = 0; e.ballSaveArmed = false; e.drain(e.world.balls[0]);`);
  await expect(page.getByRole("button", { name: "Nochmal spielen" })).toBeVisible({ timeout: 12000 });
  await expect.poll(() => scores.length).toBe(1);
  expect(scores[0]).toMatchObject({ game: "chicken-flipper", run_id: "pin-run-1-abcdefghijklmnop" });
  expect(scores[0].score).toBeGreaterThanOrEqual(1234560);
  await expect(page.locator(".pbMessage")).toContainText("Score gespeichert");
});

test("pause freezes the simulation and P resumes it", async ({ page }) => {
  await mockApi(page);
  await openPinball(page);
  await page.keyboard.press("Enter");
  await page.keyboard.press("KeyP");
  await expect(page.getByRole("button", { name: "Weiter" }).first()).toBeVisible();
  const t0 = await game(page, "return s.engine.time");
  await page.waitForTimeout(400);
  expect(await game(page, "return s.engine.time")).toBe(t0);
  await page.keyboard.press("KeyP");
  await expect.poll(() => game(page, "return s.engine.time")).toBeGreaterThan(t0);
});

test("phone: touch buttons and table halves work the flippers", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await mockApi(page);
  await openPinball(page);
  await page.getByRole("button", { name: "Spiel starten" }).click();
  const left = page.getByRole("button", { name: "Linker Flipper" });
  await expect(left).toBeVisible();
  const box = await left.boundingBox();
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await expect.poll(() => game(page, "return s.engine.table.flipL.pressed")).toBe(true);
  await page.mouse.up();
  await expect.poll(() => game(page, "return s.engine.table.flipL.pressed")).toBe(false);
  const stage = await page.locator(".pbStage").boundingBox();
  await page.locator(".pbStage").dispatchEvent("pointerdown", { pointerId: 7, pointerType: "touch", clientX: stage.x + stage.width * 0.8, clientY: stage.y + stage.height * 0.7 });
  await expect.poll(() => game(page, "return s.engine.table.flipR.pressed")).toBe(true);
  await page.locator(".pbStage").dispatchEvent("pointerup", { pointerId: 7, pointerType: "touch", clientX: stage.x + stage.width * 0.8, clientY: stage.y + stage.height * 0.7 });
  await expect.poll(() => game(page, "return s.engine.table.flipR.pressed")).toBe(false);
});

test("fullscreen mode fills the window and volume sliders change and remember the mix", async ({ page }) => {
  await mockApi(page);
  await openPinball(page);
  await page.keyboard.press("Enter");
  await page.getByRole("button", { name: "Vollbild" }).click();
  await expect(page.locator(".pbShell")).toHaveClass(/pbFull/);
  const box = await page.locator(".pbMachine").boundingBox();
  expect(box.height).toBeGreaterThan(900);
  await page.locator(".pbFsBar").getByRole("button", { name: "Lautstärke" }).click();
  await page.getByRole("slider", { name: "Lautstärke Effekte" }).fill("30");
  await page.getByRole("slider", { name: "Lautstärke Musik" }).fill("10");
  await expect.poll(() => game(page, "return [s.audio.sfxVolume, s.audio.musicVolume]")).toEqual([0.3, 0.1]);
  await page.getByRole("button", { name: "Effekte stumm" }).click();
  await expect.poll(() => game(page, "return s.audio.sfxOn")).toBe(false);
  await page.locator(".pbFsBar").getByRole("button", { name: "Vollbild beenden" }).click();
  await expect(page.locator(".pbShell")).not.toHaveClass(/pbFull/);
  await page.reload();
  await page.waitForFunction(() => document.querySelector(".pbStage")?.__pinball?.audio, null, { timeout: 30000 });
  expect(await game(page, "return [s.audio.sfxVolume, s.audio.musicVolume, s.audio.sfxOn]")).toEqual([0.3, 0.1, false]);
});
