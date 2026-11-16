import { expect, test } from "@playwright/test";

const shots = process.env.WHEEL_SHOTS;

test("Derby volume panel: both sliders are full width, numbers stay on their row and dragging changes them", async ({ page }) => {
  await page.route("**/api/**", async (route) => {
    const path = new URL(route.request().url()).pathname;
    if (path.endsWith("/auth/me")) return route.fulfill({ json: { user: { username: "kyoko", role: "member", unlocks: [] } } });
    if (path.endsWith("/api/horses")) return route.fulfill({ json: { stake: 50, payout: 100, laps: 5, horses: [], wallet: { chickens: 0, credits: 100, gsc: 0 }, recent: [], stats: { races: 0, won: 0, wins: Array(9).fill(0), chance: 1 / 9 } } });
    return route.fulfill({ json: [] });
  });
  await page.addInitScript(() => localStorage.setItem("aviary_token", "x"));
  await page.goto("/#games/horse-race");
  await page.getByRole("button", { name: "Lautstärke" }).click();
  const panel = page.locator(".hrVolume");
  const sliders = panel.locator('input[type="range"]');
  await expect(sliders).toHaveCount(2);
  for (const i of [0, 1]) {
    const row = await panel.locator("label").nth(i).boundingBox();
    const slider = await sliders.nth(i).boundingBox();
    const value = await panel.locator("label b").nth(i).boundingBox();
    expect(slider.width).toBeGreaterThan(110);
    expect(Math.abs((value.y + value.height / 2) - (slider.y + slider.height / 2))).toBeLessThan(8);   // same row
    expect(row.height).toBeLessThan(40);
  }
  await sliders.nth(0).fill("0.3");
  await expect(panel.locator("label b").nth(0)).toHaveText("30");
  if (shots) await panel.screenshot({ path: `${shots}/derby-volume.png` });
});
