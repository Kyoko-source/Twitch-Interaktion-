import { expect, test } from "@playwright/test";

const shots = process.env.WHEEL_SHOTS;

test("demo wheel spins, lands on the winner and shows the result card", async ({ page }) => {
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.setViewportSize({ width: 1920, height: 1080 });
  await page.goto("/stream/wheel?demo=1&muted=1");
  await expect(page.locator(".wsTitle")).toBeVisible({ timeout: 4000 });
  await page.waitForTimeout(1600);
  if (shots) await page.screenshot({ path: `${shots}/wheel-intro.png` });
  await page.waitForTimeout(4000);
  if (shots) await page.screenshot({ path: `${shots}/wheel-spin.png` });
  await page.waitForTimeout(6000);
  if (shots) await page.screenshot({ path: `${shots}/wheel-crawl.png` });
  await expect(page.locator(".wsWinner")).toBeVisible({ timeout: 6000 });
  await page.waitForTimeout(1500);
  if (shots) await page.screenshot({ path: `${shots}/wheel-result.png` });
  // The name under the pointer at the stop is the announced winner.
  const winner = await page.locator(".wsWinner").textContent();
  expect(winner?.length).toBeGreaterThan(2);
  expect(errors).toEqual([]);
});

test("admin tab lists buyers, spins and resolves", async ({ page }) => {
  const now = () => Date.now() / 1000;
  const entries = [
    { key: "10 squats", name: "10 Squats", weight: 2, buyers: [{ purchase_id: "p1", username: "alice", price: 100, created: now() - 500 }, { purchase_id: "p2", username: "bob", price: 100, created: now() - 400 }] },
    { key: "kein englisch", name: "Kein Englisch", weight: 1, buyers: [{ purchase_id: "p3", username: "carla", price: 100, created: now() - 300 }] },
  ];
  let spin = null;
  await page.route("**/api/**", async (route) => {
    const url = route.request().url();
    if (url.includes("/api/admin/overview")) return route.fulfill({ json: { users: [], registration_requests: [], support_messages: [] } });
    if (url.endsWith("/api/admin/wheel")) return route.fulfill({ json: { server_time: now(), entries, total: 3, history: spin ? [spin] : [] } });
    if (url.endsWith("/api/admin/wheel/spin")) {
      spin = { id: 1, created: now(), entries: entries.map((e) => ({ key: e.key, name: e.name, weight: e.weight, buyers: e.buyers.map((b) => ({ username: b.username, count: 1 })) })), winner: "10 squats", start_angle: 0, final_angle: 7 * Math.PI * 2 + 5.0, status: "open", intro: 0.3, spin: 0.6, reveal: 9 };
      return route.fulfill({ json: { spin, server_time: now() } });
    }
    if (url.includes("/resolve")) { spin = { ...spin, status: "done" }; return route.fulfill({ json: { message: "Erledigt und vom Rad genommen (2×)." } }); }
    return route.fulfill({ json: [] });
  });
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto("/#admin");
  await page.getByLabel("Admin Passwort").fill("x");
  await page.getByRole("button", { name: "Dashboard laden" }).click();
  await page.getByRole("button", { name: "Glücksrad", exact: true }).click();
  await expect(page.getByText("Auf dem Rad · 2 Bestrafungen · 3 Lose")).toBeVisible();
  await expect(page.locator(".wheelBuyer", { hasText: "alice" })).toBeVisible();
  await expect(page.locator(".wheelChance").first()).toHaveText("67 %");
  if (shots) await page.screenshot({ path: `${shots}/wheel-admin.png`, fullPage: true });
  await page.getByRole("button", { name: "🎡 DREHEN!" }).click();
  await expect(page.getByRole("button", { name: "Erledigt – vom Rad nehmen" })).toBeVisible({ timeout: 6000 });
  if (shots) await page.screenshot({ path: `${shots}/wheel-admin-result.png` });
  await page.getByRole("button", { name: "Erledigt – vom Rad nehmen" }).click();
  await expect(page.getByText("Erledigt und vom Rad genommen (2×).")).toBeVisible();
});
