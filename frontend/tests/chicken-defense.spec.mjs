import { test, expect } from "@playwright/test";

const shots = process.env.CD_SHOTS;

async function setup(page, user = { username: "Kyoko", role: "member", chickens: 100, chickens_earned: 100, level: 1 }) {
  const starts = [], saves = [];
  await page.route("**/api/**", async (route) => {
    const req = route.request(), path = new URL(req.url()).pathname;
    let json = [];
    if (path.endsWith("/auth/me")) json = { user };
    else if (path.endsWith("/game-runs")) { starts.push(req.postDataJSON()); json = { run_id: `defense-run-${starts.length}-abcdefghijk` }; }
    else if (path.endsWith("/scores") && req.method() === "POST") { saves.push(req.postDataJSON()); json = { message: "Score gespeichert. +7 Chickens!", wallet: { ...user, chickens: 107 } }; }
    return route.fulfill({ json });
  });
  return { starts, saves };
}
const game = (page, src) => page.locator(".cdCanvas").evaluate((c, s) => new Function("g", s)(c.__defense), src);

test("build towers, play a wave, upgrade to a branch, lose and save the score", async ({ page }) => {
  test.setTimeout(90_000);
  const errors = []; page.on("pageerror", (e) => errors.push(e.message));
  const { starts, saves } = await setup(page);
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto("/#games/chicken-defense");
  await expect(page.getByRole("button", { name: "Spiel starten" })).toBeVisible();
  if (shots) await page.locator(".cdShell").screenshot({ path: `${shots}/cd-start.png` });
  await page.getByRole("button", { name: "Spiel starten" }).click();
  await expect.poll(() => starts.length).toBe(1);
  await expect(page.getByTestId("cd-korn")).toHaveText("220");

  // Build a Gatling chicken with the keyboard + a click on a free tile.
  await page.keyboard.press("1");
  const clickTile = async (c, r) => {
    const box = await page.locator(".cdCanvas").boundingBox();
    await page.mouse.click(box.x + ((c + 0.5) / 22) * box.width, box.y + ((r + 0.5) / 13) * box.height);
  };
  await clickTile(5, 4);
  await expect(page.getByTestId("cd-korn")).toHaveText("160");
  await clickTile(3, 4);
  await expect(page.getByTestId("cd-korn")).toHaveText("100");

  await page.getByRole("button", { name: /Erste Welle starten/ }).click();
  await expect(page.getByTestId("cd-wave")).toHaveText("1");
  await page.getByRole("button", { name: "3×" }).click();
  await expect(page.getByRole("button", { name: /Welle 2 starten/ })).toBeVisible({ timeout: 30_000 });
  await expect(page.getByTestId("cd-eggs")).toHaveText("20");

  // Rich enough to try all branches: select the tower and specialise it.
  await game(page, "g.engine.korn = 99999; g.engine.wave = 12;");
  await page.keyboard.press("Escape");
  await clickTile(5, 4);
  await page.getByRole("button", { name: /Level 2/ }).click();
  await page.getByRole("button", { name: /Level 3/ }).click();
  await expect(page.locator(".cdBranches button")).toHaveCount(3);
  if (shots) { await page.waitForTimeout(600); await page.locator(".cdShell").screenshot({ path: `${shots}/cd-branches.png` }); }
  await page.locator(".cdBranches button", { hasText: "Dauerfeuer" }).click();
  await expect(page.locator(".cdPanelHead")).toContainText("Dauerfeuer");
  if (shots) { await page.waitForTimeout(600); await page.locator(".cdShell").screenshot({ path: `${shots}/cd-modal.png` }); }
  await page.keyboard.press("Escape");
  await expect(page.locator(".cdModal")).toHaveCount(0);
  // A busy board for the screenshot.
  await game(page, `const e = g.engine; e.wave = 20; const plan = [["archer",7,5,"volley"],["samurai",11,6,"guard"],["beekeeper",16,8,null],["disco",12,2,"mirrorBall"],["viking",16,5,null],["volcano",2,7,"ash"],["cosmos",7,11,null],["ghost",10,12,"lantern"],["vampire",18,4,"batSwarm"],["paintball",15,12,"marked"],["portal",13,8,null],["bubble",6,3,"foam"],["chef",2,5,null],["lumberjack",11,8,null],["necro",16,3,"cursed"],["magnet",7,7,null]];
    for (const [k, c, r, b] of plan) { const t = e.build(k, c, r); if (t) { e.upgrade(t.id); e.upgrade(t.id); if (b) e.upgrade(t.id, b); } }
    e.startWave(); const kinds = ["runner","spider","fox","raccoon","knight","pilot","robohawk","slime","chicks","bomber","healer","shadow","ice","boar","toxic","mech","hydra"];
    kinds.forEach((k, i) => e.spawn(k, i % 2 ? "a" : "b", 2 + i * 1.6));
    e.spawn("golem", "a", 24); e.spawn("dragon", "b", 10);`);
  await page.waitForTimeout(2500);
  if (shots) await page.locator(".cdShell").screenshot({ path: `${shots}/cd-battle.png` });

  await game(page, "g.engine.eggs = 1; g.engine.towers.forEach((t) => { t.disabledUntil = 1e9; }); g.engine.spawn('lava', 'a', 40);");
  await expect(page.getByText("Das Nest ist leer!")).toBeVisible({ timeout: 30_000 });
  if (shots) { await page.waitForTimeout(1500); await page.locator(".cdShell").screenshot({ path: `${shots}/cd-over.png` }); }
  await page.getByRole("button", { name: "Score speichern" }).click();
  await expect(page.locator(".cdMsg")).toContainText("+7 Chickens");
  expect(saves[0].run_id).toBe("defense-run-1-abcdefghijk");
  expect(saves[0].level).toBeGreaterThanOrEqual(12);
  expect(errors).toEqual([]);
});

test("phone layout fits and the tower bar scrolls", async ({ page }) => {
  await setup(page, null);
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/#games/chicken-defense");
  await page.getByRole("button", { name: "Spiel starten" }).click();
  await expect(page.locator(".cdCard2")).toHaveCount(30);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  if (shots) await page.locator(".cdShell").screenshot({ path: `${shots}/cd-phone.png` });
});

test("upgrade menu keeps the game running, auto starts waves, flyers stay on the path, fullscreen fits", async ({ page }) => {
  test.setTimeout(90_000);
  const errors = []; page.on("pageerror", (e) => errors.push(e.message));
  await setup(page);
  await page.setViewportSize({ width: 1920, height: 1080 });
  await page.goto("/#games/chicken-defense");
  await page.getByRole("button", { name: "Spiel starten" }).click();
  if (shots) await page.locator(".cdStage").screenshot({ path: `${shots}/cd-map.png` });
  await page.keyboard.press("1");
  const clickTile = async (c, r) => {
    await page.locator(".cdCanvas").scrollIntoViewIfNeeded();
    const box = await page.locator(".cdCanvas").boundingBox();
    await page.mouse.click(box.x + ((c + 0.5) / 22) * box.width, box.y + ((r + 0.5) / 13) * box.height);
  };
  await clickTile(5, 4);
  await page.getByRole("button", { name: /Erste Welle starten/ }).click();
  await page.keyboard.press("Escape");
  await clickTile(5, 4);
  await expect(page.locator(".cdModal")).toBeVisible();
  const t0 = await game(page, "return g.engine.time;");
  await page.waitForTimeout(800);
  expect(await game(page, "return g.engine.time;")).toBeGreaterThan(t0 + 0.3);
  await expect(page.getByRole("heading", { name: "Pause" })).toHaveCount(0);
  await page.keyboard.press("Escape");

  // flyers follow the path: every flyer sits on a path tile
  const offPath = await game(page, `const e = g.engine; for (let i = 0; i < 6; i++) e.spawn(i % 2 ? "pilot" : "robohawk", "a", 1 + i * 3);
    return e.enemies.filter((x) => x.flying).map((x) => { const pts = ${JSON.stringify([[-1, 2], [4, 2], [4, 9], [9, 9], [9, 4], [14, 4], [14, 10], [19, 10], [19, 6], [20, 6]])};
      let best = 99; for (let i = 1; i < pts.length; i++) { const [x1, y1] = pts[i - 1], [x2, y2] = pts[i]; const len = Math.hypot(x2 - x1, y2 - y1) || 1;
        const t = Math.max(0, Math.min(1, ((x.x - x1) * (x2 - x1) + (x.y - y1) * (y2 - y1)) / (len * len))); best = Math.min(best, Math.hypot(x.x - (x1 + (x2 - x1) * t), x.y - (y1 + (y2 - y1) * t))); }
      return best; }).filter((d) => d > 0.05).length;`);
  expect(offPath).toBe(0);

  // Auto: once the field is clear the next wave starts by itself after about three seconds
  await game(page, "g.engine.enemies.forEach((x) => { x.hp = 0; }); g.engine.queue = []; g.engine.korn = 5000;");
  await page.getByRole("button", { name: /Auto/ }).click();
  await expect(page.locator(".cdWaveBtn")).toContainText(/Welle 2 in [123]/, { timeout: 8000 });
  await expect(page.getByTestId("cd-wave")).toHaveText("2", { timeout: 6000 });

  // fullscreen layout: field, tabs and the whole chicken bar fit on one 1080p screen
  await page.locator(".cdShell").evaluate((el) => { el.classList.add("isFull"); el.style.position = "fixed"; el.style.inset = "0"; el.style.zIndex = "999"; });
  await page.waitForTimeout(300);
  const shop = await page.locator(".cdShop").boundingBox();
  expect(shop.y + shop.height).toBeLessThanOrEqual(1080);
  const stage = await page.locator(".cdStage").boundingBox();
  expect(stage.height).toBeGreaterThan(500);
  if (shots) await page.screenshot({ path: `${shots}/cd-full.png` });
  expect(errors).toEqual([]);
});

test("mouse wheel over the chicken bar scrolls it sideways", async ({ page }) => {
  await setup(page);
  await page.setViewportSize({ width: 1280, height: 900 });
  await page.goto("/#games/chicken-defense");
  const bar = page.locator(".cdShop");
  await bar.scrollIntoViewIfNeeded();
  const start = await bar.evaluate((el) => el.scrollLeft);
  const box = await bar.boundingBox();
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  const pageY = await page.evaluate(() => window.scrollY);
  await page.mouse.wheel(0, 400);
  await expect.poll(() => bar.evaluate((el) => el.scrollLeft)).toBeGreaterThan(start + 200);
  expect(await page.evaluate(() => window.scrollY)).toBe(pageY);
});
