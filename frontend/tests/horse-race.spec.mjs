import { test, expect } from "@playwright/test";

const SHOTS = process.env.DERBY_SHOTS;

// A scripted race like the server sends: `winner` crosses first, horse 1 leads early.
function script(winner, chosen) {
  let seed = 11;
  const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
  const shapes = [];
  for (let h = 0; h < 9; h++) {
    const speeds = [];
    let v = 1;
    for (let k = 0; k < 32; k++) { v = v * 0.8 + 0.2 + (rnd() - 0.5) * 0.2; speeds.push(Math.max(0.6, v * (h === 1 && k < 14 ? 1.15 : 1))); }
    const total = speeds.reduce((a, b) => a + b, 0);
    let run = 0;
    shapes.push([0, ...speeds.map((s) => (run += s) / total)]);
    shapes[h][32] = 1;
  }
  const others = [...Array(9).keys()].filter((h) => h !== winner);
  const order = [winner, ...others];
  const finish = Array(9).fill(0);
  order.forEach((h, i) => { finish[h] = 68 + i * 0.3 + (i ? 0.1 : 0); });
  const won = winner === chosen;
  return { winner, order, finish, shapes, laps: 5, horse: chosen, won, stake: 50, payout: won ? 100 : 0, place: order.indexOf(chosen) + 1 };
}

async function setup(page, { user = { username: "marello", role: "admin" }, credits = 120, winner = 2 } = {}) {
  const races = [];
  await page.route("**/api/**", async (route) => {
    const req = route.request(), path = new URL(req.url()).pathname;
    if (path.endsWith("/auth/me")) return route.fulfill({ json: { user } });
    if (path.endsWith("/api/horses")) return route.fulfill({ json: { stake: 50, payout: 100, laps: 5, horses: [], wallet: { chickens: 0, credits, gsc: 0 }, recent: [2, 5, 2] } });
    if (path.endsWith("/api/horses/race")) {
      const body = req.postDataJSON(); races.push(body);
      const race = script(winner, body.horse);
      credits = credits - 50 + race.payout;
      return route.fulfill({ json: { ...race, wallet: { chickens: 0, credits, gsc: 0 }, duplicate: false } });
    }
    return route.fulfill({ json: [] });
  });
  if (user) await page.addInitScript(() => localStorage.setItem("aviary_token", "token"));
  return races;
}

async function shot(page, name) { if (SHOTS) await page.locator(".hrStage").screenshot({ path: `${SHOTS}/${name}.png` }); }

test("pick a horse, bet 50 credits, watch the race and double the stake on a win", async ({ page }) => {
  await page.clock.install();
  const races = await setup(page, { winner: 2 });
  await page.goto("/#games/horse-race");
  await expect(page.getByTestId("derby-credits")).toHaveText("120");
  await expect(page.locator(".hrCard")).toHaveCount(9);
  await expect(page.locator(".hrStart")).toBeDisabled();
  await page.clock.runFor(1500);
  await shot(page, "01-lobby");
  await page.locator(".hrCard").nth(2).click();
  await expect(page.locator(".hrStart")).toContainText("STURMWIND");
  await page.locator(".hrStart").click();
  await expect(page.getByTestId("derby-credits")).toHaveText("70");
  expect(races[0].horse).toBe(2);
  expect(races[0].request_id).toMatch(/^[a-f0-9]{40}$/);
  await page.clock.runFor(1200);
  await expect(page.locator(".hrCountdown b")).toBeVisible();
  await shot(page, "02-countdown");
  await page.clock.runFor(9500);
  await expect(page.locator(".hrCall")).toBeVisible();
  await shot(page, "03-start");
  await page.clock.runFor(8000);
  await shot(page, "04-race");
  await expect(page.locator(".hrBoard li")).toHaveCount(9);
  await page.clock.runFor(14000);
  await shot(page, "05-race-mid");
  await page.clock.runFor(42000);
  await shot(page, "06-finish");
  await page.clock.runFor(8000);
  await expect(page.locator(".hrWinTitle")).toHaveText("SIEG!!!");
  await shot(page, "07-win");
  await page.clock.runFor(6000);
  await expect(page.locator(".hrCount")).toHaveText("100");
  await expect(page.getByTestId("derby-credits")).toHaveText("170");
  await shot(page, "08-win-final");
  await page.getByRole("button", { name: "Nächstes Rennen" }).click();
  await expect(page.locator(".hrCards")).toBeVisible();
});

test("a losing horse shows its place and the winner", async ({ page }) => {
  await page.clock.install();
  await setup(page, { winner: 5 });
  await page.goto("/#games/horse-race");
  await page.locator(".hrCard").nth(0).click();
  await page.locator(".hrStart").click();
  await page.clock.runFor(100000);
  await expect(page.locator(".hrPlace")).toContainText("PLATZ");
  await expect(page.locator(".hrLosePanel")).toContainText("Silberpfeil");
  await expect(page.getByTestId("derby-credits")).toHaveText("70");
  await shot(page, "09-lose");
});

test("too few credits leads to the shop, guests get a login button", async ({ page }) => {
  await setup(page, { credits: 30 });
  await page.goto("/#games/horse-race");
  await expect(page.locator("a.hrStart")).toHaveAttribute("href", "#shop");
});

test("guests can look but must log in to bet", async ({ page }) => {
  await setup(page, { user: null });
  await page.goto("/#games/horse-race");
  await expect(page.locator(".hrStart")).toContainText("Anmelden");
});

test.describe("phone", () => {
  test.use({ viewport: { width: 390, height: 844 } });
  test("the course and the picker fit a phone screen", async ({ page }) => {
    await page.clock.install();
    await setup(page, { winner: 4 });
    await page.goto("/#games/horse-race");
    await page.locator(".hrCard").nth(4).click();
    if (SHOTS) await page.screenshot({ path: `${SHOTS}/10-phone-lobby.png`, fullPage: false });
    const overflow = await page.evaluate(() => document.querySelector(".hrShell").scrollWidth - document.querySelector(".hrShell").clientWidth);
    expect(overflow).toBeLessThanOrEqual(1);
    await page.locator(".hrStart").click();
    await page.clock.runFor(30000);
    await shot(page, "11-phone-race");
    await page.clock.runFor(60000);
    await shot(page, "12-phone-win");
  });
});

test.describe("stream overlay", () => {
  test.use({ viewport: { width: 1920, height: 1080 } });

  test("stays transparent until a race comes in, plays it full screen with the bettor and hides again", async ({ page }) => {
    await page.clock.install();
    const t0 = Date.now() / 1000;
    let races = [];
    await page.route("**/api/**", (route) => {
      const path = new URL(route.request().url()).pathname;
      if (path.endsWith("/api/horses/live")) return route.fulfill({ json: { server_time: t0 + (Date.now() / 1000 - t0), countdown: 10, races } });
      return route.fulfill({ json: [] });
    });
    await page.goto("/stream/derby");
    await page.clock.runFor(3000);
    await expect(page.locator(".doShell")).not.toHaveClass(/ on/);
    await expect(page.locator(".appShell, nav")).toHaveCount(0);
    const bg = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    expect(bg).toBe("rgba(0, 0, 0, 0)");
    races = [{ id: 7, username: "marello", created: Date.now() / 1000, ...script(4, 4) }];
    await page.clock.runFor(2500);
    await expect(page.locator(".doShell")).toHaveClass(/ on/);
    await expect(page.locator(".doIntro")).toContainText("marello");
    await expect(page.locator(".doIntro")).toContainText("Feuerfunke");
    await page.clock.runFor(1500);
    await shot(page, "20-overlay-intro");
    await page.clock.runFor(30000);
    await expect(page.locator(".doMine")).toContainText("PLATZ");
    await shot(page, "21-overlay-race");
    await page.clock.runFor(55000);
    await expect(page.locator(".hrWinName")).toContainText("marello gewinnt");
    await page.clock.runFor(4000);
    await shot(page, "22-overlay-win");
    await page.clock.runFor(10000);
    await expect(page.locator(".doShell")).not.toHaveClass(/ on/);
  });

  test("joins a running race at the right moment", async ({ page }) => {
    await page.clock.install();
    const created = Date.now() / 1000 - 40;   // started 40 s ago: 30 s into the race
    await page.route("**/api/**", (route) => route.fulfill({ json: { server_time: Date.now() / 1000, countdown: 10, races: [{ id: 9, username: "luna", created, ...script(1, 6) }] } }));
    await page.goto("/stream/derby");
    await page.clock.runFor(2000);
    await expect(page.locator(".doShell")).toHaveClass(/ on/);
    await expect(page.locator(".doIntro")).toHaveCount(0);
    await expect(page.locator(".hrLap")).toContainText(/RUNDE [23]\/5/);
  });

  test("ignores races that finished before the overlay was opened", async ({ page }) => {
    await page.clock.install();
    await page.route("**/api/**", (route) => route.fulfill({ json: { server_time: Date.now() / 1000, countdown: 10, races: [{ id: 3, username: "old", created: Date.now() / 1000 - 300, ...script(1, 6) }] } }));
    await page.goto("/stream/derby");
    await page.clock.runFor(5000);
    await expect(page.locator(".doShell")).not.toHaveClass(/ on/);
  });
});
