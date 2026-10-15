import { test, expect } from "@playwright/test";
import { join } from "node:path";
import { tmpdir } from "node:os";

const shopItems = [
  { id: 4, name: "3 Squats", category: "Bestrafungs Ideen", price: 450 },
  { id: 1, name: "Wasser trinken", category: "Bestrafungs Ideen", price: 150 },
  { id: "chat-style", name: "Chat Animation", category: "Chat Animation", style: "sparkle", price: 300 },
];

async function setup(page) {
  const user = { username: "magical_kyoko_", role: "moderator", chickens: 650, chickens_earned: 650, level: 3, level_progress: 150, level_target: 250 };
  const purchases = [], starts = [], scores = [];
  await page.route("**/api/**", async (route) => {
    const request = route.request(), path = new URL(request.url()).pathname;
    let json = [];
    if (path.endsWith("/auth/me")) json = { user };
    else if (path.endsWith("/shop")) json = shopItems;
    else if (path.endsWith("/chat/styles")) json = { styles: [{ id: "default", owned: true }], selected: "default" };
    else if (path.endsWith("/shop/purchase")) {
      const body = request.postDataJSON(); purchases.push(body);
      const item = shopItems.find((item) => String(item.id) === body.item_id);
      user.chickens -= item.price;
      json = { message: "Gekauft! Deine Bestrafung erscheint im Stream.", wallet: { ...user }, stream_alert: true };
    } else if (path.endsWith("/game-runs")) {
      const body = request.postDataJSON(); starts.push(body);
      json = { run_id: `test-run-${starts.length}-abcdefghijklmnop` };
    } else if (path.endsWith("/scores") && request.method() === "POST") {
      scores.push(request.postDataJSON()); user.chickens += 3; user.chickens_earned += 3;
      json = { message: "Score gespeichert. +3 Chickens!", chickens_awarded: 3, wallet: { ...user } };
    } else if (path.endsWith("/admin/overview")) json = { users: [user], registration_requests: [], support_messages: [], wishes: [] };
    else if (path.endsWith("/admin/purchase-alerts")) json = { settings: { duration_seconds: 10 }, purchases: [] };
    else if (path.endsWith("/dashboard")) json = { stats: {}, leaderboard: [user], active_members: [], news: [], events: [] };
    return route.fulfill({ json });
  });
  return { user, purchases, starts, scores };
}

test("shop: one currency, category filters, successful debit updates header and disables unaffordable repeat", async ({ page }) => {
  const errors = []; page.on("pageerror", (error) => errors.push(error.message));
  const { purchases } = await setup(page);
  await page.goto("/#shop");
  await expect(page.locator(".shopRewardCard")).toHaveCount(3);
  await expect(page.locator(".communityBalances")).toHaveText("650Chickens");
  await page.getByRole("button", { name: "Bestrafungs Ideen", exact: true }).click();
  await expect(page.locator(".shopRewardCard")).toHaveCount(2);
  await page.getByRole("button", { name: "Für 450 Chickens kaufen", exact: true }).click();
  await expect(page.getByRole("status")).toContainText("erscheint im Stream");
  await expect(page.locator(".communityBalances")).toHaveText("200Chickens");
  await expect(page.getByRole("button", { name: "Noch 250 Chickens" })).toBeDisabled();
  expect(purchases).toHaveLength(1);
  expect(purchases[0].request_id).toMatch(/^[a-f0-9]{40}$/);
  await page.screenshot({ path: join(tmpdir(), "aviary-shop-desktop.png"), fullPage: true });
  await page.setViewportSize({ width: 390, height: 844 });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({ path: join(tmpdir(), "aviary-shop-mobile.png"), fullPage: true });
  expect(errors).toEqual([]);
});

test("games: Jump and Snake register real rounds, submit bound scores and credit the visible wallet once", async ({ page }) => {
  const { starts, scores } = await setup(page);
  await page.goto("/#games/chicken-jump");
  await page.getByRole("button", { name: "Loslaufen", exact: true }).click();
  await expect.poll(() => starts.length).toBe(1);
  await expect(page.getByText("RUN BEENDET", { exact: true })).toBeVisible({ timeout: 15000 });
  await page.getByRole("button", { name: "Score & Chickens einreichen" }).click();
  await expect(page.getByText("Score gespeichert. +3 Chickens!", { exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: "Runde gewertet" })).toBeDisabled();
  expect(scores[0]).toMatchObject({ game: "chicken-jump", run_id: "test-run-1-abcdefghijklmnop" });
  await expect(page.locator(".communityBalances")).toHaveText("653Chickens");
  await page.getByRole("button", { name: "Chicken Snake", exact: true }).click();
  await page.getByRole("button", { name: "Spiel starten", exact: true }).click();
  await expect.poll(() => starts.length).toBe(2);
  await expect(page.locator(".gameHud .stat").first().locator("strong")).toHaveText("10");
  await page.getByRole("button", { name: "Runde abschließen", exact: true }).click();
  await expect(page.getByRole("button", { name: "Score speichern", exact: true })).toBeVisible({ timeout: 15000 });
  await page.getByRole("button", { name: "Score speichern", exact: true }).click();
  await expect(page.locator(".communityBalances")).toHaveText("656Chickens");
  expect(scores[1]).toMatchObject({ game: "chicken-snake", run_id: "test-run-2-abcdefghijklmnop" });
  await page.getByRole("button", { name: "PEPPLE Pinball", exact: true }).click();
  await page.getByRole("button", { name: "Spiel starten", exact: true }).click();
  await expect.poll(() => starts.length).toBe(3);
  expect(starts[2].game).toBe("chicken-flipper");
  await page.getByRole("button", { name: "Pepple Survivor", exact: true }).click();
  await page.getByRole("button", { name: "Start", exact: true }).first().click();
  await expect.poll(() => starts.length).toBe(4);
  expect(starts[3].game).toBe("braincell-survivor");
});

test("OBS: transparent center box, ordered purchases, literal text, expiry during network failure and no stale replay", async ({ page }) => {
  await page.setViewportSize({ width: 1536, height: 1024 });
  let events;
  let offline = false;
  await page.route("**/api/purchase-alerts", (route) => {
    const start = Date.now() / 1000;
    events ||= [
      { id: 1, username: "alice", item_name: "3 Squats", price: 450, starts: start, ends: start + 3 },
      { id: 2, username: "bob", item_name: "<img src=x onerror=alert(1)>", price: 150, starts: start + 3.2, ends: start + 5.2 },
    ];
    return offline ? route.abort() : route.fulfill({ json: { server_time: start, events } });
  });
  await page.goto("/overlays/shop-alert.html");
  await expect(page.locator("#shop-alert")).toBeVisible();
  await expect(page.locator("#buyer-name")).toHaveText("alice");
  await page.locator("#shop-alert").evaluate((node) => Promise.all(node.getAnimations().map((animation) => animation.finished)));
  const box = await page.locator("#shop-alert").boundingBox();
  expect(box.x + box.width / 2).toBeCloseTo(768, 0);
  expect(box.y + box.height / 2).toBeCloseTo(512, 0);
  expect(await page.locator("body").evaluate((node) => getComputedStyle(node).backgroundColor)).toBe("rgba(0, 0, 0, 0)");
  await expect(page.locator("#buyer-name")).toHaveText("bob", { timeout: 7000 });
  await expect(page.locator("#reward-name")).toHaveText("<img src=x onerror=alert(1)>");
  await expect(page.locator("#reward-name img")).toHaveCount(0);
  offline = true;
  await expect(page.locator("#shop-alert")).toBeHidden({ timeout: 4000 });
  offline = false;
  await page.reload();
  await expect(page.locator("#shop-alert")).toBeHidden();
  events = [];
});

test("admin: OBS source address, isolated preview, native-size design and duration validation", async ({ page }) => {
  await setup(page);
  const publicReads = [];
  page.on("request", (request) => { if (request.url().endsWith("/api/purchase-alerts")) publicReads.push(request.url()); });
  await page.goto("/#admin");
  await page.getByLabel("Admin Passwort").fill("test-password");
  await page.getByRole("button", { name: "Dashboard laden" }).click();
  await page.getByRole("button", { name: "Shop-Alerts", exact: true }).click();
  await expect(page.getByLabel("Shop-Alert-URL")).toHaveValue("http://127.0.0.1:4186/overlays/shop-alert.html");
  await page.getByRole("button", { name: "Vorschau abspielen" }).click();
  await expect(page.frameLocator("iframe[title='Shop-Alert Vorschau']").locator("#reward-name")).toHaveText("3 Squats");
  expect(publicReads).toEqual([]);
  await page.getByLabel("Anzeigedauer in Sekunden").fill("0");
  await expect(page.getByRole("button", { name: "Anzeigedauer speichern" })).toBeDisabled();
  await page.setViewportSize({ width: 390, height: 844 });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.goto("/overlays/shop-alert.html?preview=1");
  await page.setViewportSize({ width: 1536, height: 1024 });
  await page.evaluate(() => window.postMessage({ type: "aviary-shop-preview", duration: 20 }, location.origin));
  await expect(page.locator("#shop-alert")).toBeVisible();
  await page.locator("#shop-alert").evaluate((node) => node.getAnimations().forEach((animation) => animation.finish()));
  await page.screenshot({ path: join(tmpdir(), "aviary-shop-alert.png"), omitBackground: true });
});
