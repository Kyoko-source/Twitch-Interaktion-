import { test, expect } from "@playwright/test";
import { tmpdir } from "node:os";
import { join } from "node:path";

test("failed graphics show retry instead of an endless loader; retry loads a playable scene", async ({ page }) => {
  await page.route("**/api/**", route => route.fulfill({ json: route.request().url().includes("auth/me") ? { user: null } : [] }));
  await page.route("**/assets/chicken-jump-ai-v1.png", route => route.abort());
  await page.goto("/#games/chicken-jump");
  await expect(page.getByRole("button", { name: "Erneut laden", exact: true })).toBeEnabled({ timeout: 18000 });
  await page.unroute("**/assets/chicken-jump-ai-v1.png");
  await page.getByRole("button", { name: "Erneut laden", exact: true }).click();
  await expect(page.getByRole("button", { name: "Loslaufen", exact: true })).toBeEnabled();
  await page.getByRole("button", { name: "Loslaufen", exact: true }).click();
  await expect(page.locator(".jumpPrimary")).toBeHidden();
});

async function openRunner(page) {
  await page.route("**/api/**", (route) => route.fulfill({ json: route.request().url().includes("auth/me") ? { user: null } : [] }));
  await page.goto("/#games");
  await page.getByRole("button", { name: "Chicken Jump", exact: true }).click();
  await expect(page.getByRole("button", { name: "Loslaufen" })).toBeEnabled();
  await page.locator(".jumpRunnerStage").scrollIntoViewIfNeeded();
}

test("runner: real jump, collision, restart, duck, pause and playable obstacle sequence", async ({ page }) => {
  const errors = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await openRunner(page);
  await expect(page.locator(".jumpRunnerCanvas canvas")).toBeVisible();
  await page.getByRole("button", { name: "Loslaufen" }).click();
  await expect(page.locator(".supportFab")).toBeHidden();
  await page.keyboard.down("Space");
  await page.waitForTimeout(180);
  const airborne = await page.locator(".jumpRunnerCanvas canvas").evaluate((canvas) => canvas.__jumpScene.player.y);
  expect(airborne).toBeLessThan(400);
  await page.keyboard.up("Space");
  await page.waitForTimeout(700);
  expect(await page.locator(".jumpRunnerCanvas canvas").evaluate((canvas) => canvas.__jumpScene.player.y)).toBeCloseTo(444, 0);

  await page.keyboard.press("Escape");
  await expect(page.getByRole("heading", { name: "Pause", exact: true })).toBeVisible();
  const pausedX = await page.locator(".jumpRunnerCanvas canvas").evaluate((canvas) => canvas.__jumpScene.distance);
  await page.waitForTimeout(200);
  expect(await page.locator(".jumpRunnerCanvas canvas").evaluate((canvas) => canvas.__jumpScene.distance)).toBe(pausedX);
  await page.getByRole("button", { name: "Weiterlaufen" }).click();
  await expect(page.getByText("RUN BEENDET", { exact: true })).toBeVisible({ timeout: 10000 });
  await page.getByRole("button", { name: "Nochmal laufen" }).click();
  await page.keyboard.down("ArrowDown");
  await page.waitForTimeout(80);
  expect(await page.locator(".jumpRunnerCanvas canvas").evaluate((canvas) => canvas.__jumpScene.player.body.height)).toBe(28);
  await page.keyboard.up("ArrowDown");

  // Observe upcoming hazards; use only the actual input controls to clear them.
  let cleared = 0;
  let birds = 0;
  let jumping = false;
  let ducking = false;
  const deadline = Date.now() + 28000;
  while (Date.now() < deadline) {
    const state = await page.locator(".jumpRunnerCanvas canvas").evaluate((canvas) => {
      const s = canvas.__jumpScene;
      const next = s.obstacles.getChildren().filter((o) => !o.scored && o.x > 80).sort((a, b) => a.x - b.x)[0];
      return { mode: s.mode, speed: s.speed, next: next ? { x: next.x, kind: next.kind } : null, passed: s.pattern - s.obstacles.getChildren().filter((o) => !o.scored).length };
    });
    expect(state.mode, JSON.stringify(state)).toBe("play");
    cleared = Math.max(cleared, state.passed);
    if (state.next?.kind === "fence" && state.next.x < 164 + state.speed * 0.29 && !jumping) {
      await page.keyboard.down("Space"); jumping = true;
    }
    if (jumping && (!state.next || state.next.x < 130)) { await page.keyboard.up("Space"); jumping = false; }
    if (state.next?.kind === "bird" && state.next.x < 370 && !ducking) {
      await page.keyboard.down("ArrowDown"); ducking = true; birds += 1;
    }
    if (ducking && (!state.next || state.next.kind !== "bird" || state.next.x < 95)) { await page.keyboard.up("ArrowDown"); ducking = false; }
    if (cleared >= 7 && birds >= 1) break;
    await page.waitForTimeout(20);
  }
  expect(cleared).toBeGreaterThanOrEqual(7);
  expect(birds).toBeGreaterThanOrEqual(1);
  const score = await page.locator(".jumpRunnerCanvas canvas").evaluate((canvas) => canvas.__jumpScene.score);
  expect(score).toBeGreaterThan(350);
  await page.screenshot({ path: join(tmpdir(), "chicken-jump-desktop.png") });
  expect(errors).toEqual([]);
});

test("mobile: stage fits and touch buttons drive jump and duck", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await openRunner(page);
  await page.getByRole("button", { name: "Loslaufen" }).click();
  const stage = await page.locator(".jumpRunnerStage").boundingBox();
  expect(stage.width).toBeLessThanOrEqual(390);
  const touch = await page.context().newCDPSession(page);
  const press = async (name) => {
    const button = page.getByRole("button", { name, exact: true });
    await button.scrollIntoViewIfNeeded();
    const box = await button.boundingBox();
    await touch.send("Input.dispatchTouchEvent", { type: "touchStart", touchPoints: [{ x: box.x + box.width / 2, y: box.y + box.height / 2, id: 0 }] });
  };
  const release = () => touch.send("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
  await press("Springen");
  await page.waitForTimeout(180);
  expect(await page.locator(".jumpRunnerCanvas canvas").evaluate((canvas) => canvas.__jumpScene.player.y)).toBeLessThan(400);
  await release();
  await page.waitForTimeout(750);
  await press("Ducken");
  await page.waitForTimeout(80);
  expect(await page.locator(".jumpRunnerCanvas canvas").evaluate((canvas) => canvas.__jumpScene.player.body.height)).toBe(28);
  await release();
  await page.screenshot({ path: join(tmpdir(), "chicken-jump-mobile.png") });
});
