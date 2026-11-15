import { test, expect } from "@playwright/test";

const SHOTS = process.env.LEVEL_SHOTS;
const levels = (level, xp) => ({
  level, xp, level_progress: 40, level_target: 100 + 40 * (level - 1), level_title: level >= 5 ? "Hofhenne" : "Junghenne", streak: 3,
  unlocks: level >= 5 ? ["derby-crown"] : [], recent: [{ source: "game", amount: 35, created: 1 }, { source: "daily", amount: 30, created: 1 }],
  leaderboard: [{ username: "Kyoko", xp, level, level_title: "Hofhenne" }, { username: "luna", xp: 200, level: 2, level_title: "Küken" }],
  titles: [{ level: 1, name: "Küken" }, { level: 3, name: "Junghenne" }, { level: 5, name: "Hofhenne" }, { level: 8, name: "Flinkes Huhn" }],
  unlock_list: [{ level: 5, id: "derby-crown", name: "Derby-Krone", text: "Dein Pferd trägt eine Krone." }, { level: 10, id: "jump-golden", name: "Goldenes Huhn", text: "Goldenes Huhn." }],
  rewards: { 5: { chickens: 70, credits: 12 }, 6: { chickens: 22, credits: 2 } },
});

test("header shows level and XP, a level-up celebrates with rewards, the profile lists unlocks", async ({ page }) => {
  const user = { username: "Kyoko", role: "member", chickens: 10, chickens_earned: 10, ...levels(4, 600) };
  let info = levels(4, 600);
  await page.route("**/api/**", (route) => {
    const path = new URL(route.request().url()).pathname;
    if (path.endsWith("/auth/me")) return route.fulfill({ json: { user } });
    if (path.endsWith("/api/levels")) return route.fulfill({ json: info });
    if (path.endsWith("/wallet/history")) return route.fulfill({ json: { wallet: user, summary: { earned: 10, adjustments: 0, spent: 0 }, transactions: [] } });
    return route.fulfill({ json: [] });
  });
  await page.addInitScript(() => localStorage.setItem("aviary_token", "token"));
  await page.goto("/#home");
  await expect(page.getByText("Level 4 · Junghenne")).toBeVisible();
  await expect(page.getByText("40 / 220 XP zum nächsten Level")).toBeVisible();

  info = levels(5, 690);
  await page.evaluate(() => window.dispatchEvent(new CustomEvent("aviary-wallet", { detail: { username: "Kyoko", wallet: { level: 5, xp: 690, level_title: "Hofhenne", level_progress: 30, level_target: 260, unlocks: ["derby-crown"] } } })));
  await expect(page.locator(".xpToast")).toContainText("+90 XP");
  const dialog = page.getByRole("dialog", { name: "Level 5 erreicht" });
  await expect(dialog).toBeVisible();
  await expect(dialog).toContainText("+70 Chickens");
  await expect(dialog).toContainText("+12 Credits");
  await expect(dialog).toContainText("Neuer Titel: Hofhenne");
  await expect(dialog).toContainText("Derby-Krone");
  if (SHOTS) { await page.waitForTimeout(900); await page.screenshot({ path: `${SHOTS}/levelup.png` }); }
  await dialog.getByRole("button", { name: "Weiter" }).click();
  await expect(dialog).toHaveCount(0);

  await page.goto("/#profile");
  await expect(page.locator(".levelPanel")).toContainText("Hofhenne");
  await expect(page.locator(".levelUnlock.open")).toContainText("Derby-Krone");
  await expect(page.locator(".levelUnlock:not(.open)")).toContainText("Goldenes Huhn");
  await expect(page.locator(".levelLog")).toContainText("Runde gespielt");
  if (SHOTS) await page.locator(".levelPanel").screenshot({ path: `${SHOTS}/profile.png` });
});

// Level tree 1-100 as the server builds it (xp.py: need(l) = 100 + 40 * (l - 1)).
function tree() {
  const titles = { 1: "Küken", 3: "Junghenne", 5: "Hofhenne", 8: "Flinkes Huhn", 12: "Federheld", 25: "Goldfeder" };
  const unlocks = { 5: ["derby-crown"], 10: ["jump-golden"], 25: ["derby-phoenix", "jump-rainbow"] };
  let xp = 0;
  return Array.from({ length: 100 }, (_, i) => {
    const level = i + 1;
    if (level > 1) xp += 100 + 40 * (level - 2);
    return { level, xp, rewards: level > 1 ? { chickens: 10 + 2 * level + (level % 5 ? 0 : 50), credits: 2 + (level % 5 ? 0 : 10) } : null, title: titles[level] || null, unlocks: unlocks[level] || [] };
  });
}

test("the level tree shows all 100 levels, what each brings and the Phönix skin at level 25", async ({ page }) => {
  const info = {
    ...levels(8, 4000), level_title: "Flinkes Huhn", tree: tree(),
    unlock_list: [
      { level: 5, id: "derby-crown", name: "Derby-Krone", text: "Dein Pferd trägt eine Krone." },
      { level: 10, id: "jump-golden", name: "Goldenes Huhn", text: "Goldenes Huhn." },
      { level: 25, id: "derby-phoenix", name: "Phönix-Hengst", text: "Skin fürs Chicken Derby.", skin: true },
      { level: 25, id: "jump-rainbow", name: "Regenbogenspur", text: "Regenbogen." },
    ],
  };
  const user = { username: "Kyoko", role: "member", chickens: 10, chickens_earned: 10, ...info };
  const errors = []; page.on("pageerror", (e) => errors.push(e.message));
  await page.route("**/api/**", (route) => {
    const path = new URL(route.request().url()).pathname;
    if (path.endsWith("/auth/me")) return route.fulfill({ json: { user } });
    if (path.endsWith("/api/levels")) return route.fulfill({ json: info });
    if (path.endsWith("/api/leaderboard")) return route.fulfill({ json: [{ username: "Kyoko", chickens_earned: 271, chickens: 3029, level: 8, level_title: "Flinkes Huhn", rank_name: "Flinkes Huhn" }, { username: "luna", chickens_earned: 146, chickens: 146, level: 3, level_title: "Junghenne", rank_name: "Junghenne" }] });
    if (path.endsWith("/wallet/history")) return route.fulfill({ json: { wallet: user, summary: { earned: 10, adjustments: 0, spent: 0 }, transactions: [] } });
    return route.fulfill({ json: [] });
  });
  await page.addInitScript(() => localStorage.setItem("aviary_token", "token"));
  await page.goto("/#profile");
  const nodes = page.locator(".ltNode");
  await expect(nodes).toHaveCount(100);
  await expect(page.locator(".ltNode.now")).toHaveText("8");
  await expect(page.locator(".ltNode.done")).toHaveCount(7);
  await expect(page.locator(".ltDetail")).toContainText("LV 9");
  await expect(page.locator(".ltShowcase")).toContainText("Phönix-Hengst");
  await page.locator(".ltShowcase").click();
  await expect(page.locator(".ltDetail")).toContainText("Titel: Goldfeder");
  await expect(page.locator(".ltDetail")).toContainText("+110 Chickens");
  await expect(page.locator(".ltDetail .ltUnlock.skin")).toContainText("Phönix-Hengst");
  await expect(page.locator(".ltDetail canvas.phoenixPreview")).toBeVisible();
  if (SHOTS) { await page.waitForTimeout(400); await page.locator(".levelTree").screenshot({ path: `${SHOTS}/tree.png` }); }
  await page.getByRole("button", { name: "Nur Highlights" }).click();
  expect(await nodes.count()).toBeLessThan(40);
  await page.setViewportSize({ width: 390, height: 844 });
  if (SHOTS) await page.locator(".levelTree").screenshot({ path: `${SHOTS}/tree-phone.png` });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);

  await page.setViewportSize({ width: 1400, height: 1000 });
  await page.goto("/#leaderboard");
  const row = page.locator(".leaderRow").first();
  await expect(row).toContainText("Lv 8");
  await expect(row).toContainText("Flinkes Huhn");
  await expect(page.locator(".leaderRow").nth(1)).toContainText("Lv 3");
  if (SHOTS) await page.locator(".leaderTable").screenshot({ path: `${SHOTS}/leaderboard.png` });
  expect(errors).toEqual([]);
});
