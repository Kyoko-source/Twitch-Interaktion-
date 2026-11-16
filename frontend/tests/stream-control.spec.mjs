import { test, expect } from "@playwright/test";
import { EFFECTS } from "../src/stream/effects.js";

const SHOTS = process.env.STREAM_SHOTS;
test.use({ launchOptions: { args: ["--autoplay-policy=no-user-gesture-required"] } });

function feed(page) {
  const state = { events: [], id: 0 };
  page.route("**/api/**", (route) => {
    const path = new URL(route.request().url()).pathname;
    if (path.endsWith("/api/stream-control")) return route.fulfill({ json: { server_time: Date.now() / 1000, last_id: state.id, events: state.events } });
    return route.fulfill({ json: [] });
  });
  return (effect, extra = {}) => { state.id += 1; state.events = [...state.events.slice(-10), { id: state.id, effect, duration: 4, video: null, created: Date.now() / 1000, ...extra }]; };
}

test.describe("overlay", () => {
  test.use({ viewport: { width: 1920, height: 1080 } });

  test("is transparent and ignores old events, then plays every one of the 50 effects without errors", async ({ page }) => {
    test.setTimeout(240000);
    const errors = [];
    page.on("pageerror", (e) => errors.push(e.message));
    const fire = feed(page);
    fire("gg");                                     // already there before the source loads
    await page.goto("/stream/control");
    await page.waitForTimeout(1800);
    await expect(page.locator(".scEffect")).toHaveCount(0);
    expect(await page.evaluate(() => getComputedStyle(document.body).backgroundColor)).toBe("rgba(0, 0, 0, 0)");
    const shots = new Set(["confetti-cannon", "noir-rain", "thunderstorm", "fireworks", "matrix", "glass-crack", "fire", "vhs", "chicken-run", "frost", "horror", "fail", "respect", "sunglasses", "disco", "underwater"]);
    for (const e of EFFECTS.filter((x) => x.id !== "ad")) {
      fire(e.id);
      await expect(page.locator(`.scEffect[data-effect="${e.id}"]`)).toHaveCount(1, { timeout: 4000 });
      await page.waitForTimeout(shots.has(e.id) ? 1700 : 500);
      if (SHOTS && shots.has(e.id)) await page.screenshot({ path: `${SHOTS}/${e.id}.png` });
      fire("stop");
      await expect(page.locator(".scEffect")).toHaveCount(0, { timeout: 4000 });
    }
    expect(errors).toEqual([]);
  });

  test("Werbung plays the chosen video full screen and hides when it ends", async ({ page }) => {
    const fire = feed(page);
    await page.goto("/stream/control");
    await page.waitForTimeout(1500);
    fire("ad", { video: "after-play" });
    const video = page.locator(".scAd video");
    await expect(video).toHaveAttribute("src", "/stream-media/after-play.mp4", { timeout: 4000 });
    await expect(page.locator(".scAdTag")).toContainText("WERBUNG");
    await page.waitForFunction(() => { const v = document.querySelector(".scAd video"); return v && v.currentTime > 0.5; }, null, { timeout: 15000 });
    if (SHOTS) await page.screenshot({ path: `${SHOTS}/ad.png` });
    await page.evaluate(() => { const v = document.querySelector(".scAd video"); v.currentTime = v.duration - 0.3; });
    await expect(page.locator(".scAd")).toHaveCount(0, { timeout: 6000 });
  });
});

test("admin tab fires effects, custom durations, ads and the stop button", async ({ page }) => {
  const posts = [];
  await page.route("**/api/**", (route) => {
    const req = route.request(), path = new URL(req.url()).pathname;
    if (path.endsWith("/api/admin/stream-control")) {
      expect(req.headers()["x-admin-password"]).toBe("test-password");
      posts.push(req.postDataJSON());
      return route.fulfill({ json: { event: { id: posts.length, ...req.postDataJSON() }, message: "Läuft im Stream." } });
    }
    if (path.endsWith("/api/stream-control")) return route.fulfill({ json: { server_time: Date.now() / 1000, last_id: 0, events: [] } });
    if (path.endsWith("/admin/overview")) return route.fulfill({ json: { users: [], registration_requests: [], support_messages: [], wishes: [] } });
    if (path.endsWith("/auth/me")) return route.fulfill({ json: { user: null } });
    return route.fulfill({ json: [] });
  });
  await page.goto("/#admin");
  await page.getByLabel("Admin Passwort").fill("test-password");
  await page.getByRole("button", { name: "Dashboard laden" }).click();
  await page.getByRole("button", { name: "Stream Control", exact: true }).click();
  await expect(page.locator(".scBtn")).toHaveCount(49);
  await expect(page.getByLabel("Stream-Control-URL")).toHaveValue(/\/stream\/control$/);
  await expect(page.locator(".scPreview iframe")).toHaveAttribute("src", "/stream/control?muted=1");
  await page.getByRole("button", { name: "Ton aus" }).click();
  await expect(page.locator(".scPreview iframe")).toHaveAttribute("src", "/stream/control");
  await page.getByRole("button", { name: "Ton an" }).click();
  await expect(page.locator(".scPreview iframe")).toHaveAttribute("src", "/stream/control?muted=1");
  await page.locator(".scBtn", { hasText: "Konfetti-Kanone" }).click();
  await expect.poll(() => posts.length).toBe(1);
  expect(posts[0]).toEqual({ effect: "confetti-cannon", duration: 8 });
  await expect(page.locator(".scBtn.live")).toContainText("läuft");
  await page.getByLabel("Eigene Dauer statt Standard").check();
  await page.locator(".scDuration input[type=range]").fill("25");
  await page.locator(".scBtn", { hasText: "Schwarz-Weiß + Regen" }).click();
  await expect.poll(() => posts.length).toBe(2);
  expect(posts[1]).toEqual({ effect: "noir-rain", duration: 25 });
  await page.locator(".scVideo", { hasText: "After Play" }).click();
  await page.getByRole("button", { name: "Werbung abspielen" }).click();
  await expect.poll(() => posts.length).toBe(3);
  expect(posts[2]).toMatchObject({ effect: "ad", video: "after-play" });
  await page.getByRole("button", { name: "ALLES STOPPEN" }).click();
  await expect.poll(() => posts.length).toBe(4);
  expect(posts[3].effect).toBe("stop");
  await expect(page.locator(".scBtn.live")).toHaveCount(0);
  if (SHOTS) await page.locator(".streamControl").screenshot({ path: `${SHOTS}/admin.png` });
});
