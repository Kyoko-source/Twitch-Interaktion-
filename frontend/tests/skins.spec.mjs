import { expect, test } from "@playwright/test";

const shots = process.env.WHEEL_SHOTS;
const STYLES = ["sparkle", "cotton", "neon", "royal", "sakura", "ocean", "frost", "fire", "matrix", "glitch", "galaxy", "rainbow", "gold", "unicorn"];
const NAMES = { sakura: "Kirschblüte", ocean: "Tiefsee", frost: "Eiskristall", fire: "Feuerzauber", matrix: "Matrix", glitch: "Glitch", galaxy: "Galaxie", rainbow: "Regenbogen", gold: "Goldrausch", unicorn: "Einhorn", sparkle: "Sternenfunkeln", cotton: "Zuckerwatte", neon: "Neon Pulse", royal: "Royal Glow" };
const items = [
  ...STYLES.map((s, i) => ({ id: `chat-style-${s}`, name: `Chat Animation: ${NAMES[s]}`, description: "Vorschau", category: "Chat Animation", style: s, price: 300 + i * 150, sold: 0 })),
  { id: "derby-skin-zebra", name: "Derby-Skin: Zebra-Blitz", description: "Gestreift mit Blitzen.", category: "Derby Skins", skin: "zebra", price: 3000, sold: 0 },
  { id: "derby-skin-ghost", name: "Derby-Skin: Geisterross", description: "Halb durchsichtig.", category: "Derby Skins", skin: "ghost", price: 6000, sold: 0 },
  { id: "derby-skin-unicorn", name: "Derby-Skin: Regenbogen-Einhorn", description: "Schneeweißes Einhorn mit Regenbogenmähne.", category: "Derby Skins", skin: "unicorn", price: 10000, sold: 0 },
];
const catalog = [
  { id: "phoenix", name: "Phönix-Hengst", level: 25, text: "Feuer" }, { id: "zebra", name: "Zebra-Blitz", price: 3000, text: "" },
  { id: "ghost", name: "Geisterross", price: 6000, text: "" }, { id: "unicorn", name: "Regenbogen-Einhorn", price: 10000, text: "" },
];

test("shop lists 14 chat looks and three Derby skins; the unicorn costs 10.000 and can be worn in the Derby", async ({ page }) => {
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  const user = { username: "magical_kyoko_", role: "member", chickens: 12000, credits: 120, gsc: 0, level: 8, unlocks: [] };
  let owned = [], active = null;
  const skins = () => ({ owned, active, catalog: catalog.map((s) => ({ ...s, owned: owned.includes(s.id) })) });
  await page.route("**/api/**", async (route) => {
    const req = route.request(), path = new URL(req.url()).pathname;
    if (path.endsWith("/auth/me")) return route.fulfill({ json: { user } });
    if (path.endsWith("/shop")) return route.fulfill({ json: items });
    if (path.endsWith("/chat/styles")) return route.fulfill({ json: { styles: [{ id: "default", owned: true }] } });
    if (path.endsWith("/api/horses/skin")) { active = req.postDataJSON().skin === "none" ? null : req.postDataJSON().skin; return route.fulfill({ json: { skins: skins() } }); }
    if (path.endsWith("/api/horses")) return route.fulfill({ json: { stake: 50, payout: 100, laps: 5, horses: [], wallet: { chickens: user.chickens, credits: 120, gsc: 0 }, recent: [], stats: { races: 0, won: 0, wins: Array(9).fill(0), chance: 1 / 9 }, skins: skins() } });
    if (path.endsWith("/shop/purchase")) {
      const item = items.find((i) => i.id === req.postDataJSON().item_id);
      user.chickens -= item.price; owned = [...owned, item.skin]; active = item.skin;
      return route.fulfill({ json: { message: "Gekauft! Regenbogen-Einhorn läuft ab jetzt im Chicken Derby für dich.", wallet: { ...user }, duplicate: false } });
    }
    return route.fulfill({ json: [] });
  });
  await page.addInitScript(() => localStorage.setItem("aviary_token", "x"));
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto("/#shop");
  await page.getByRole("button", { name: "Chat Animation", exact: true }).click();
  await expect(page.locator(".shopRewardCard")).toHaveCount(14);
  for (const s of STYLES) await expect(page.locator(`.shopRewardCard .chatStyle-${s}`)).toBeVisible();
  if (shots) { await page.waitForTimeout(600); await page.locator(".shGrid").screenshot({ path: `${shots}/skins-chat.png` }); }

  await page.getByRole("button", { name: "Derby Skins", exact: true }).click();
  await expect(page.locator(".shopRewardCard")).toHaveCount(3);
  const unicorn = page.locator(".shopRewardCard", { hasText: "Regenbogen-Einhorn" });
  await expect(unicorn.locator(".shHorse")).toBeVisible();
  await expect(unicorn.locator(".shPrice")).toContainText("10.000");
  if (shots) { await page.waitForTimeout(500); await page.locator(".shGrid").screenshot({ path: `${shots}/skins-derby.png` }); }
  await unicorn.getByRole("button", { name: "Für 10.000 Chickens kaufen" }).click();
  await expect(unicorn.locator(".shBadge.owned")).toBeVisible();
  await expect(unicorn.getByRole("button", { name: "Bereits freigeschaltet" })).toBeDisabled();

  await page.goto("/#games/horse-race");
  await expect(page.locator(".hrSkins button.on")).toHaveText("Regenbogen-Einhorn");
  await expect(page.locator(".hrSkins a.locked", { hasText: "Geisterross" })).toBeVisible();
  await page.locator(".hrCard").nth(1).click();
  await page.waitForTimeout(400);
  if (shots) await page.locator(".hrPicker").screenshot({ path: `${shots}/skins-derby-picker.png` });
  await page.locator(".hrSkins").getByRole("button", { name: "Ohne" }).click();
  await expect(page.locator(".hrSkins button.on")).toHaveText("Ohne");
  expect(errors).toEqual([]);
});
