import { test, expect } from "@playwright/test";
import { play } from "../src/cookie/bot.mjs";
import { serialize } from "../src/cookie/sim.js";

const SHOTS = process.env.COOKIE_SHOTS;
const user = { username: "kyoko", role: "member", chickens: 10, chickens_earned: 10, level: 3 };

async function mock(page, store) {
  await page.route("**/api/**", (route) => {
    const path = new URL(route.request().url()).pathname;
    const method = route.request().method();
    if (path.endsWith("/auth/me")) return route.fulfill({ json: { user } });
    if (path.endsWith("/cookie/save") && method === "GET") return route.fulfill({ json: { save: store.save || null } });
    if (path.endsWith("/cookie/save") && method === "PUT") { store.puts = (store.puts || 0) + 1; store.save = route.request().postDataJSON().data; return route.fulfill({ json: { saved: Date.now() / 1000 } }); }
    if (path.endsWith("/cookie/finale")) { store.finale = true; return route.fulfill({ json: { title: "Oberster Keksmeister des Nordpols" } }); }
    return route.fulfill({ json: [] });
  });
  await page.addInitScript(() => localStorage.setItem("aviary_token", "token"));
}

test("the first cookie is made by hand: dough, rolling, cutting, belt, oven, chute, one taler", async ({ page }) => {
  const errors = []; page.on("pageerror", (e) => errors.push(e.message));
  const store = {};
  await mock(page, store);
  await page.goto("/#games/cookie-crisis");
  await expect(page.getByTestId("cookie-game")).toBeVisible();
  await expect(page.getByTestId("cookie-baked")).toHaveText("0");
  await page.getByTestId("cookie-portion").click();
  for (let i = 0; i < 3; i++) await page.getByTestId("cookie-roll").click();
  for (let i = 0; i < 4; i++) await page.getByTestId("cookie-cut").click();
  if (SHOTS) await page.locator(".ccStage").screenshot({ path: `${SHOTS}/cookie-start.png` });
  await page.getByTestId("cookie-load").click();
  await expect(page.getByTestId("cookie-talers")).toHaveText("0");
  // four cookies ride through the oven (~17 s at the start) and drop into the chute
  await expect(page.getByTestId("cookie-talers")).toHaveText("4", { timeout: 30_000 });
  await expect(page.getByTestId("cookie-baked")).toHaveText("4");
  if (SHOTS) await page.screenshot({ path: `${SHOTS}/cookie-first.png`, fullPage: true });
  // keyboard: space does the next sensible step
  await page.locator(".ccCanvas").focus();
  await page.keyboard.press("Space");
  // look around by dragging, walk with WASD
  const box = await page.locator(".ccCanvas").boundingBox();
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down(); await page.mouse.move(box.x + box.width / 2 + 120, box.y + box.height / 2 - 40, { steps: 6 }); await page.mouse.up();
  await page.keyboard.down("s"); await page.waitForTimeout(300); await page.keyboard.up("s");
  if (SHOTS) await page.locator(".ccStage").screenshot({ path: `${SHOTS}/cookie-look.png` });
  expect(errors).toEqual([]);
});

for (const [name, stopAt] of [["werkstatt", 4000], ["automatik", 60_000], ["industrie", 200_000], ["magie", 700_000]]) {
  test(`a saved game in phase "${name}" loads with its machines and keeps producing`, async ({ page }) => {
    const errors = []; page.on("pageerror", (e) => errors.push(e.message));
    const { state } = play({ clicksPerSecond: 2.5, stopAt });
    const store = { save: serialize(state) };
    await mock(page, store);
    await page.goto("/#games/cookie-crisis");
    const baked = page.getByTestId("cookie-baked");
    await expect(baked).not.toHaveText("0");
    const before = Number((await baked.textContent()).replace(/\./g, ""));
    expect(before).toBeGreaterThanOrEqual(stopAt);
    await page.waitForTimeout(stopAt > 10_000 ? 2500 : 4000);
    if (stopAt > 10_000) await expect.poll(async () => Number((await baked.textContent()).replace(/\./g, ""))).toBeGreaterThan(before);
    await expect(page.locator(".ccUp.rec")).toBeVisible();
    if (SHOTS) await page.screenshot({ path: `${SHOTS}/cookie-${name}.png`, fullPage: true });
    expect(errors).toEqual([]);
  });
}

test("buying an upgrade spends talers and the game saves to the account", async ({ page }) => {
  const { state } = play({ clicksPerSecond: 2.5, stopAt: 300 });
  state.talers = 5000; state.earned = state.baked; state.spent = 0;
  state.talers = state.earned; // talers must match the cookies baked
  const store = { save: serialize(state) };
  await mock(page, store);
  await page.goto("/#games/cookie-crisis");
  const rec = page.locator(".ccUp.rec button");
  await expect(rec).toBeEnabled({ timeout: 15_000 });
  const before = Number((await page.getByTestId("cookie-talers").textContent()).replace(/\./g, ""));
  await rec.click();
  await expect.poll(async () => Number((await page.getByTestId("cookie-talers").textContent()).replace(/\./g, ""))).toBeLessThan(before + 20);
  await page.evaluate(() => document.dispatchEvent(new Event("visibilitychange")));
  await page.goto("/#home");
  await expect.poll(() => store.puts || 0).toBeGreaterThan(0);
  expect(JSON.parse(store.save).spent).toBeGreaterThan(0);
});

test("the millionth cookie starts the finale with Santa's message and the title", async ({ page }) => {
  const { state } = play({ clicksPerSecond: 2.5, stopAt: 999_000 });
  const store = { save: serialize(state) };
  await mock(page, store);
  await page.goto("/#games/cookie-crisis");
  const dialog = page.getByRole("dialog", { name: /Weihnachten gerettet/ });
  await expect(dialog).toBeVisible({ timeout: 60_000 });
  await expect(dialog).toContainText("Oberster Keksmeister des Nordpols");
  await expect(page.getByTestId("cookie-baked")).toHaveText("1.000.000");
  expect(store.finale).toBe(true);
  if (SHOTS) { await page.waitForTimeout(1500); await page.screenshot({ path: `${SHOTS}/cookie-finale.png` }); }
});

test("phone layout: no sideways scrolling, buttons reachable", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await mock(page, {});
  await page.goto("/#games/cookie-crisis");
  await expect(page.getByTestId("cookie-game")).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  await page.getByTestId("cookie-portion").click();
  await expect(page.locator(".ccHud")).toBeVisible();
  await expect(page.locator(".ccShop")).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  if (SHOTS) { await page.locator(".ccGame").scrollIntoViewIfNeeded(); await page.screenshot({ path: `${SHOTS}/cookie-phone.png`, fullPage: true }); }
});
