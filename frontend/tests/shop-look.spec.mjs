import { expect, test } from "@playwright/test";

const shots = process.env.WHEEL_SHOTS;
const items = [
  { id: 1, name: "kein Englisch für 5 Minuten", category: "Aufgaben", price: 300, sold: 1 },
  { id: 2, name: "Mit einer Hand spielen (10 min)", category: "Aufgaben", price: 450, sold: 0 },
  { id: 3, name: "Chat bestimmt nächstes Ziel/Aufgaben", category: "Aufgaben", price: 600, sold: 2 },
  { id: 4, name: "Wasser trinken (nochmal drehen)", category: "Bestrafungs Ideen", price: 150, sold: 5 },
  { id: 5, name: "nicht sprinten dürfen", category: "Bestrafungs Ideen", price: 300, sold: 2 },
  { id: 6, name: "Langsame DPI", category: "Bestrafungs Ideen", price: 300, sold: 0 },
  { id: 7, name: "3 Squats", category: "Bestrafungs Ideen", price: 450, sold: 3 },
  { id: "chat-style-neon", name: "Chat Animation: Neon Pulse", description: "Cooler Cyber-Look mit wandernder Neon-Kante.", category: "Chat Animation", style: "neon", price: 600, sold: 1 },
];
const wheel = { server_time: 0, spin: null, entries: [
  { key: "wasser trinken (nochmal drehen)", name: "Wasser trinken (nochmal drehen)", weight: 3, buyers: [{ username: "a", count: 3 }] },
  { key: "nicht sprinten dürfen", name: "nicht sprinten dürfen", weight: 2, buyers: [{ username: "b", count: 2 }] },
  { key: "3 squats", name: "3 Squats", weight: 1, buyers: [{ username: "c", count: 1 }] },
] };

test("shop shows the store hero, wheel spotlight and themed collectible cards", async ({ page }) => {
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  const user = { username: "magical_kyoko_", role: "member", chickens: 336, credits: 4, gsc: 10500000, level: 7 };
  await page.route("**/api/**", async (route) => {
    const path = new URL(route.request().url()).pathname;
    if (path.endsWith("/auth/me")) return route.fulfill({ json: { user } });
    if (path.endsWith("/shop")) return route.fulfill({ json: items });
    if (path.endsWith("/stream/wheel")) return route.fulfill({ json: wheel });
    if (path.endsWith("/chat/styles")) return route.fulfill({ json: { styles: [{ id: "default", owned: true }] } });
    return route.fulfill({ json: [] });
  });
  await page.addInitScript(() => localStorage.setItem("aviary_token", "x"));
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto("/#shop");
  await expect(page.locator(".shopRewardCard")).toHaveCount(8);
  await expect(page.locator(".shSpot")).toContainText("3 Bestrafungen warten");
  await expect(page.locator(".shopRewardCard", { hasText: "Wasser trinken" }).locator(".shWheelChip")).toHaveText(/50 % auf dem Rad/);
  await expect(page.locator(".shopRewardCard", { hasText: "Wasser trinken" }).locator(".shBadge.hot")).toBeVisible();
  await expect(page.locator(".shopRewardCard", { hasText: "Neon Pulse" }).locator(".chatStyle-neon")).toBeVisible();
  if (shots) await page.screenshot({ path: `${shots}/shop-top.png` });
  await page.locator(".shTabs").scrollIntoViewIfNeeded();
  await page.locator(".shopRewardCard").nth(3).hover({ position: { x: 60, y: 60 } });
  if (shots) await page.locator(".shGrid").screenshot({ path: `${shots}/shop-cards.png` });
  await page.getByRole("button", { name: "Bestrafungs Ideen", exact: true }).click();
  await expect(page.locator(".shopRewardCard")).toHaveCount(4);
  await page.setViewportSize({ width: 390, height: 844 });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.evaluate(() => window.scrollTo(0, 0));
  if (shots) await page.screenshot({ path: `${shots}/shop-mobile.png` });
  expect(errors).toEqual([]);
});
