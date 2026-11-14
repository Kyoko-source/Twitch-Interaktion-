import { test, expect } from "@playwright/test";

const LINES = [[1, 1, 1, 1, 1], [0, 0, 0, 0, 0], [2, 2, 2, 2, 2], [0, 1, 2, 1, 0], [2, 1, 0, 1, 2], [0, 0, 1, 2, 2], [2, 2, 1, 0, 0], [1, 0, 0, 0, 1], [1, 2, 2, 2, 1], [0, 1, 1, 1, 0]];
const PAY = { cherry: [0.3, 1, 2.5], lemon: [0.5, 1.3, 3.5], grape: [0.7, 1.7, 5], bell: [1.3, 3.5, 10], bar: [1.7, 5, 17], seven: [3.5, 13, 50], wild: [4, 20, 200] };
const shots = process.env.SLOT_SHOTS;
const plain = [["lemon", "bell", "grape"], ["cherry", "bar", "lemon"], ["grape", "bell", "lemon"], ["seven", "cherry", "bar"], ["bar", "lemon", "cherry"]];
const eggs = [["egg", "bell", "grape"], ["cherry", "egg", "lemon"], ["grape", "bell", "egg"], ["seven", "cherry", "bar"], ["bar", "lemon", "cherry"]];
const sevens = [["cherry", "seven", "lemon"], ["bell", "seven", "bar"], ["cherry", "seven", "lemon"], ["bell", "seven", "bar"], ["grape", "seven", "lemon"]];

test("three golden eggs start the egg bonus, play every free spin and count the bonus total", async ({ page }) => {
  test.setTimeout(90_000);
  const errors = []; page.on("pageerror", (error) => errors.push(error.message));
  const freeWin = 50 * 3 * 10000;
  const spinBody = {
    grid: eggs, bet: 1, wins: [], scatter: { count: 3, mult: 1, free_spins: 3, cells: [[0, 0], [1, 1], [2, 2]] }, multiplier: 1, base_win: 10000,
    bonus: { awarded: 3, mult: 3, win: freeWin + 0, spins: [
      { grid: plain, wins: [], scatter: null, multiplier: 0, win: 0, extra_spins: 0 },
      { grid: sevens, wins: [{ line: 0, symbol: "seven", count: 5, mult: 50, win: freeWin, cells: [[0, 1], [1, 1], [2, 1], [3, 1], [4, 1]] }], scatter: null, multiplier: 150, win: freeWin, extra_spins: 0 },
      { grid: plain, wins: [], scatter: null, multiplier: 0, win: 0, extra_spins: 0 },
    ] },
    win: 10000 + freeWin, wallet: { chickens: 0, credits: 9, gsc: 10000 + freeWin }, today: { won: 10000 + freeWin },
  };
  await page.route("**/api/**", async (route) => {
    const path = new URL(route.request().url()).pathname;
    if (path.endsWith("/auth/me")) return route.fulfill({ json: { user: { username: "marello", role: "admin" } } });
    if (path.endsWith("/api/slots")) return route.fulfill({ json: { bets: [1, 2, 5, 10], gsc_per_credit: 10000, pay: PAY, scatter: { 3: 1, 4: 5, 5: 25 }, free_spins: { 3: 8, 4: 12, 5: 20 }, free_mult: 3, lines: LINES, rtp: 0.93, wallet: { chickens: 0, credits: 10, gsc: 0 }, today: { won: 0 } } });
    if (path.endsWith("/api/slots/spin")) return route.fulfill({ json: spinBody });
    return route.fulfill({ json: [] });
  });
  await page.addInitScript(() => localStorage.setItem("aviary_token", "token"));
  await page.setViewportSize({ width: 1400, height: 1000 });
  await page.goto("/#games/slots");
  await expect(page.getByTestId("slot-balance")).toHaveText("10");
  if (shots) await page.locator(".slShell").screenshot({ path: `${shots}/slot-idle.png` });
  await page.locator(".slSpin").click();
  await expect(page.locator(".slReel.moving")).toHaveCount(5);
  if (shots) { await page.waitForTimeout(250); await page.locator(".slShell").screenshot({ path: `${shots}/slot-spin.png` }); }
  await expect(page.locator(".slSplash")).toContainText("EIER-BONUS", { timeout: 12_000 });
  if (shots) { await page.waitForTimeout(700); await page.locator(".slShell").screenshot({ path: `${shots}/slot-bonus-splash.png` }); }
  await expect(page.locator(".slBonusBar")).toContainText("FREISPIEL 1 / 3", { timeout: 8000 });
  await expect(page.locator(".slBonusBar")).toContainText("FREISPIEL 2 / 3", { timeout: 15_000 });
  await expect(page.locator(".slWinBox.big")).toBeVisible({ timeout: 15_000 });
  if (shots) { await page.waitForTimeout(2500); await page.locator(".slShell").screenshot({ path: `${shots}/slot-bigwin.png` }); }
  await expect(page.locator(".slWinBox.bonusTotal")).toContainText("EIER-BONUS GESAMT", { timeout: 30_000 });
  await expect(page.getByTestId("slot-gsc")).toHaveText((10000 + freeWin).toLocaleString("de-DE"), { timeout: 20_000 });
  await expect(page.locator(".slSpin")).toHaveText("SPIN", { timeout: 10_000 });
  if (shots) await page.locator(".slShell").screenshot({ path: `${shots}/slot-after.png` });
  await page.setViewportSize({ width: 390, height: 844 });
  if (shots) await page.locator(".slShell").screenshot({ path: `${shots}/slot-phone.png` });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  expect(errors).toEqual([]);
});
