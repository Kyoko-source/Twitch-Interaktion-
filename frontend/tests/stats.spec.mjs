import { expect, test } from "@playwright/test";

const shots = process.env.WHEEL_SHOTS;

function mockStats(days) {
  const today = new Date();
  const hourly = days === 1;
  const keys = hourly
    ? Array.from({ length: 24 }, (_, h) => `${today.toISOString().slice(0, 10)}T${String(h).padStart(2, "0")}`)
    : Array.from({ length: days }, (_, i) => new Date(today.getTime() - (days - 1 - i) * 86400000).toISOString().slice(0, 10));
  const wave = (i, base, amp) => Math.max(0, Math.round(base + amp * Math.sin(i / 2.3) + (i % 7 === 5 ? amp : 0)));
  const daily = keys.map((day, i) => { const members = wave(i, 9, 4), guests = wave(i + 3, 5, 3); return { day, members, guests, visitors: members + guests, views: (members + guests) * 6, minutes: (members + guests) * 11 }; });
  return {
    days, keys, hourly, now: Date.now() / 1000, tracking_since: Date.now() / 1000 - 86400 * 40,
    kpis: { visitors: [61, 48], views: [940, 1010], members: [23, 20], minutes_per_visitor: [14.2, 11.8], active_members: [19, 17], rounds: [412, 380], purchases: [37, 22], spent: [8450, 5200] },
    online: [{ user: "alice", path: "games/chicken-jump", device: "Desktop" }, { user: "bob", path: "shop", device: "Smartphone" }, { user: "Gast", path: "home", device: "Desktop" }],
    traffic: {
      daily,
      heat: Array.from({ length: 7 }, (_, d) => Array.from({ length: 24 }, (_, h) => (h > 15 && h < 24 ? Math.round(10 + 8 * Math.sin(h + d)) + (d > 4 ? 12 : 0) : h < 2 ? 4 : 0))),
      pages: [["home", 320, 60, 210], ["games/chicken-jump", 210, 31, 640], ["shop", 150, 28, 120], ["chat", 120, 19, 380], ["games/horse-race", 80, 14, 160], ["u", 40, 12, 20]].map(([path, views, visitors, minutes]) => ({ path, views, visitors, minutes })),
      devices: [["Desktop", 41], ["Smartphone", 17], ["Tablet", 3]],
      browsers: [["Chrome", 30], ["Edge", 14], ["Safari", 10], ["Firefox", 5], ["OBS / Streamlabs", 2]],
      referrers: [["twitch.tv", 34], ["discord.com", 12], ["google.com", 3]],
    },
    activity: {
      active_daily: daily.map((d) => d.members + 3), rounds_daily: daily.map((d) => d.members * 3), casino_daily: daily.map((d) => d.guests * 2),
      purchases_daily: daily.map((d, i) => i % 3), earned_daily: daily.map((d) => d.members * 20), spent_daily: daily.map((d, i) => (i % 4) * 150),
      rounds: 412, purchases: 37, spent: 8450, earned: 9100,
      games: [["Chicken Jump", 160], ["Chicken Derby", 90], ["Chicken Snake", 70], ["Chicken Jackpot", 52], ["Chicken Defense", 40]],
      players: [["alice", 88], ["bob", 61], ["carla", 40], ["dino", 22]], items: [["10 Squats", 9], ["Credits", 8], ["Chat Animation: Neon Pulse", 3]],
    },
  };
}

test("admin opens on the Statistik dashboard with grouped navigation", async ({ page }) => {
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  let lastDays = null;
  await page.route("**/api/**", async (route) => {
    const url = new URL(route.request().url());
    if (url.pathname === "/api/admin/overview") return route.fulfill({ json: { users: [{ username: "alice" }], registration_requests: [{ id: 1, username: "neu", status: "pending" }], support_messages: [] } });
    if (url.pathname === "/api/admin/stats") { lastDays = Number(url.searchParams.get("days")); return route.fulfill({ json: mockStats(lastDays) }); }
    return route.fulfill({ json: [] });
  });
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto("/#admin");
  await page.getByLabel("Admin Passwort").fill("x");
  await page.getByRole("button", { name: "Dashboard laden" }).click();
  await expect(page.getByRole("heading", { name: "Statistik" })).toBeVisible();
  await expect(page.locator(".adminNavBadge")).toHaveText("1");
  await expect(page.locator(".stKpi").first()).toContainText("61");
  await expect(page.locator(".stKpi").first()).toContainText("+27 %");
  await expect(page.getByText("3 gerade online").or(page.locator(".stLive"))).toBeVisible();
  const chart = page.locator(".stChart svg").first();
  const box = await chart.boundingBox();
  await chart.hover({ position: { x: box.width * 0.6, y: box.height / 2 } });
  await expect(page.locator(".stTip").first()).toBeVisible();
  if (shots) await page.screenshot({ path: `${shots}/stats.png`, fullPage: true });
  await page.getByRole("button", { name: "Heute" }).click();
  await expect.poll(() => lastDays).toBe(1);
  await expect(page.getByRole("heading", { name: "Traffic nach Stunde" })).toBeVisible();
  await page.setViewportSize({ width: 420, height: 900 });
  if (shots) await page.screenshot({ path: `${shots}/stats-mobile.png`, fullPage: false });
  expect(errors).toEqual([]);
});
