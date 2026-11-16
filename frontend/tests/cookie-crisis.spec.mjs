import { test, expect } from "@playwright/test";

const SHOTS = process.env.COOKIE_SHOTS;
const user = { username: "kyoko", role: "member", chickens: 10, chickens_earned: 10, level: 3 };
const save = JSON.stringify({ v: 1, t: 600, dough: 1_000_000 - 4321, carry: 0, ball: 0, rollProgress: 0, sheet: 0, tray: 0, queue: 0, belt: [], exit: 0, falling: [], talers: 4281, earned: 4321, baked: 4321, spent: 40, levels: { eimer: 1 }, acc: {}, pushT: 0, clicks: 0, finished: null });

test.setTimeout(180_000);

test("the launch page shows progress and opens the Godot game in its own window", async ({ page }) => {
  const errors = []; page.on("pageerror", (e) => errors.push(e.message));
  await page.route("**/api/**", (route) => {
    const path = new URL(route.request().url()).pathname;
    if (path.endsWith("/auth/me")) return route.fulfill({ json: { user } });
    if (path.endsWith("/cookie/save") && route.request().method() === "GET") return route.fulfill({ json: { save } });
    if (path.endsWith("/cookie/save")) return route.fulfill({ json: { saved: 1 } });
    return route.fulfill({ json: [] });
  });
  await page.addInitScript(() => localStorage.setItem("aviary_token", "token"));
  await page.goto("/#games/cookie-crisis");
  const launch = page.getByTestId("cookie-game");
  await expect(launch).toContainText("Santa's Cookie Crisis");
  await expect(page.getByTestId("cookie-progress")).toContainText("4.321");
  await expect(page.getByTestId("cookie-play")).toContainText("Weiterbacken");
  if (SHOTS) await launch.screenshot({ path: `${SHOTS}/cookie-launch.png` });
  await page.getByTestId("cookie-play").click();
  const frame = page.frameLocator('[data-testid="cookie-frame"]');
  await expect(frame.locator("canvas")).toBeVisible({ timeout: 60_000 });
  await page.waitForTimeout(20_000); // the engine loads, the world is built
  if (SHOTS) await page.screenshot({ path: `${SHOTS}/cookie-godot-window.png` });
  await page.getByRole("button", { name: "Zurück zur Webseite" }).click();
  await expect(page.locator(".ccWindow")).toHaveCount(0);
  expect(errors).toEqual([]);
});
