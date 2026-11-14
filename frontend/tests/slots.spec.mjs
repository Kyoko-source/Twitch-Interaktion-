import { test, expect } from "@playwright/test";

const LINES = [[1, 1, 1, 1, 1], [0, 0, 0, 0, 0], [2, 2, 2, 2, 2], [0, 1, 2, 1, 0], [2, 1, 0, 1, 2], [0, 0, 1, 2, 2], [2, 2, 1, 0, 0], [1, 0, 0, 0, 1], [1, 2, 2, 2, 1], [0, 1, 1, 1, 0]];
const PAY = { cherry: [0.5, 1.5, 4], lemon: [0.75, 2, 5], grape: [1, 2.5, 7.5], bell: [2, 5, 15], bar: [2.5, 7.5, 25], seven: [5, 20, 75], wild: [6, 30, 300] };

async function setup(page, { user = { username: "marello", role: "admin" }, balance = 20 } = {}) {
  const spins = [];
  await page.route("**/api/**", async (route) => {
    const req = route.request(), path = new URL(req.url()).pathname;
    if (path.endsWith("/auth/me")) return route.fulfill({ json: { user } });
    if (path.endsWith("/api/slots")) return route.fulfill({ json: { bets: [1, 2, 5, 10], gsc_per_credit: 10000, pay: PAY, scatter: { 3: 2, 4: 10, 5: 50 }, lines: LINES, rtp: 0.93, wallet: { chickens: 0, credits: balance, gsc: 0 }, today: { won: 0 } } });
    if (path.endsWith("/api/slots/spin")) {
      const body = req.postDataJSON(); spins.push(body);
      const win = body.bet * 10000 * 2;
      balance -= body.bet;
      return route.fulfill({ json: { grid: [["lemon", "bell", "grape"], ["cherry", "bell", "egg"], ["grape", "bell", "lemon"], ["seven", "cherry", "bar"], ["bar", "lemon", "cherry"]], bet: body.bet, wins: [{ line: 0, symbol: "bell", count: 3, mult: 2, cells: [[0, 1], [1, 1], [2, 1]] }], scatter: null, multiplier: 2, win, wallet: { chickens: 0, credits: balance, gsc: win }, today: { won: win } } });
    }
    return route.fulfill({ json: [] });
  });
  if (user) await page.addInitScript(() => localStorage.setItem("aviary_token", "token"));
  return spins;
}

test("a spin sends the chosen bet with a request id, lands the reels and pays the win", async ({ page }) => {
  const spins = await setup(page);
  await page.goto("/#games/slots");
  await expect(page.getByTestId("slot-balance")).toHaveText("20");
  await page.getByRole("button", { name: "Einsatz erhöhen" }).click();
  await page.locator(".slSpin").click();
  await expect(page.locator(".slReel.moving")).toHaveCount(5);
  await expect(page.locator(".slReel.moving")).toHaveCount(0, { timeout: 6000 });
  expect(spins[0].bet).toBe(2);
  expect(spins[0].request_id).toMatch(/^[a-f0-9]{40}$/);
  await expect(page.getByTestId("slot-balance")).toHaveText("18");
  await expect(page.getByTestId("slot-gsc")).toHaveText("40.000");
  await expect(page.locator(".slCell.hit")).toHaveCount(3);
  await expect(page.locator(".slWinBox")).toContainText("Glocke");
});

test("guests see the machine and a login button instead of spin", async ({ page }) => {
  await setup(page, { user: null });
  await page.goto("/#games/slots");
  await expect(page.getByRole("button", { name: /Anmelden & spielen/ })).toBeVisible();
  await expect(page.locator(".slReel")).toHaveCount(5);
});

test("paytable lists every symbol", async ({ page }) => {
  await setup(page);
  await page.goto("/#games/slots");
  await page.getByRole("button", { name: "Gewinntabelle" }).click();
  await expect(page.locator(".slPayGrid > div")).toHaveCount(8);
});

test("without credits the spin button turns into a shop link", async ({ page }) => {
  await setup(page, { balance: 0 });
  await page.goto("/#games/slots");
  await expect(page.getByRole("link", { name: "Credits kaufen" })).toHaveAttribute("href", "#shop");
});
