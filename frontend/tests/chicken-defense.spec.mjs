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
  await page.locator(".cdBranches button", { hasText: "Dauerfeuer" }).click();
  await expect(page.locator(".cdPanelHead")).toContainText("Dauerfeuer");
  // A busy board for the screenshot.
  await game(page, `const e = g.engine; const spots = [[7,5],[11,6],[16,8],[12,2],[16,5],[2,7],[7,11],[10,12],[18,4],[15,12]];
    ["frost","mortar","sniper","wizard","golden","tesla","rocket","medic","dark","gatling"].forEach((k, i) => { const t = e.build(k, spots[i][0], spots[i][1]); if (t) { e.upgrade(t.id); e.upgrade(t.id); e.upgrade(t.id, Object.keys(e.constructor && t ? {} : {})[0]); } });
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
  await expect(page.locator(".cdTower")).toHaveCount(10);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  if (shots) await page.locator(".cdShell").screenshot({ path: `${shots}/cd-phone.png` });
});
