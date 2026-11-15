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
