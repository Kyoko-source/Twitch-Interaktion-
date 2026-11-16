import { test, expect } from "@playwright/test";

const me = { username: "kyoko", role: "member", chickens: 10, chickens_earned: 500, level: 6, level_title: "Hofhenne" };
const badge = (id, earned) => ({ id, name: `Badge ${id}`, text: "Text", icon: "flame", tier: "gold", earned, value: earned ? 3 : 1, goal: 3, progress: earned ? 1 : 0.33 });
const card = (user, extra = {}) => ({
  user, rank: 2, members: 9, online: false, chat_style: "default",
  level: { level: user.level || 1, xp: 900, level_progress: 40, level_target: 300, level_title: user.level_title || "Küken", streak: 2, unlocks: [], xp_rank: 3 },
  derby: { races: 10, won: 4, net: 100, best_payout: 100, streak: 2, horses: [0, 0, 6, 0, 4, 0, 0, 0, 0], favorite: { id: 2, name: "Sturmwind", bets: 6, wins: 3 } },
  slots: { spins: 0, wagered: 0, won: 0, best_win: 0, best_mult: 0, bonuses: 0, best_wheel: 0 },
  games: [{ game: "chicken-jump", name: "Chicken Jump", plays: 5, best: 1200, place: 1 }],
  shop: [], unlocks: [], next_unlock: { name: "Goldenes Huhn", level: 10 },
  activity: { start: "2026-05-20", days: { "2026-11-15": 120 }, recent: [], active_days: 1, first_seen: null },
  badges: [badge("hot-streak", true), badge("record", true), badge("shopper", false)],
  prefs: { theme: "neon", showcase: ["record"] },
  themes: [{ id: "neon", name: "Neon", level: 1, unlocked: true }, { id: "sunset", name: "Sonnenuntergang", level: 1, unlocked: true }, { id: "gold", name: "Goldfeder", level: 25, unlocked: false }],
  ...extra,
});

test("public profile: stats, badges, share link; own profile saves bio, look and showcase", async ({ page, context }) => {
  const errors = []; page.on("pageerror", (e) => errors.push(e.message));
  await context.grantPermissions(["clipboard-read", "clipboard-write"]);
  let saved = null, look = null;
  await page.route("**/api/**", (route) => {
    const path = new URL(route.request().url()).pathname;
    const method = route.request().method();
    if (path.endsWith("/auth/me")) return route.fulfill({ json: { user: me } });
    if (path.endsWith("/profile/luna/card")) return route.fulfill({ json: card({ username: "luna", role: "vip", level: 4, level_title: "Junghenne", bio: "Hallo!", chickens_earned: 900 }) });
    if (path.endsWith("/profile/kyoko/card")) return route.fulfill({ json: card({ ...me, bio: saved?.bio || "" }, { prefs: look || { theme: "neon", showcase: ["record"] } }) });
    if (path.endsWith("/profile/ghost/card")) return route.fulfill({ status: 404, json: { detail: "Profil nicht gefunden" } });
    if (path.endsWith("/api/profile/look") && method === "PATCH") { look = route.request().postDataJSON(); return route.fulfill({ json: { prefs: look } }); }
    if (path.endsWith("/api/profile") && method === "PATCH") { saved = route.request().postDataJSON(); return route.fulfill({ json: { user: { ...me, ...saved } } }); }
    if (path.endsWith("/api/leaderboard")) return route.fulfill({ json: [{ ...me, level: 6 }, { username: "luna", level: 4, chickens_earned: 900 }] });
    if (path.endsWith("/api/levels")) return route.fulfill({ json: {} });
    if (path.endsWith("/wallet/history")) return route.fulfill({ json: { wallet: me, summary: { earned: 0, adjustments: 0, spent: 0 }, transactions: [] } });
    return route.fulfill({ json: [] });
  });
  await page.addInitScript(() => localStorage.setItem("aviary_token", "token"));

  // Names in the leaderboard open the public profile.
  await page.goto("/#leaderboard");
  await page.locator(".leaderRow a.profileLink", { hasText: "luna" }).click();
  await expect(page).toHaveURL(/#u\/luna$/);
  const view = page.getByTestId("profile-view");
  await expect(view.locator("h1")).toHaveText("luna");
  await expect(view).toContainText("Junghenne");
  await expect(view).toContainText("#2 von 9");
  await expect(view).toContainText("#3 Sturmwind");
  await expect(view).toContainText("Chicken Jump");
  await expect(view.locator(".pfShowcase .pfMedal")).toHaveCount(1);
  await expect(view.locator(".pfBadge.earned")).toHaveCount(2);
  await expect(view.getByRole("button", { name: "Nachricht" })).toBeVisible();
  await expect(view.getByRole("button", { name: "Bearbeiten" })).toHaveCount(0);
  await view.getByTestId("profile-share").click();
  await expect(view.getByTestId("profile-share")).toContainText("Kopiert");
  expect(await page.evaluate(() => navigator.clipboard.readText())).toMatch(/\/#u\/luna$/);

  await page.goto("/#u/ghost");
  await expect(page.getByText("Profil nicht gefunden").first()).toBeVisible();

  // Own profile: edit bio, pick a look and the showcase.
  await page.goto("/#profile");
  await expect(view.locator("h1")).toHaveText("kyoko");
  await view.getByRole("button", { name: "Bearbeiten" }).click();
  await page.getByLabel("Über mich").fill("Ich liebe das Derby");
  await expect(page.getByRole("button", { name: /Goldfeder/ })).toBeDisabled();
  await page.getByRole("button", { name: "Sonnenuntergang" }).click();
  await page.locator(".pfPick button").first().click();
  await page.getByRole("button", { name: "Speichern" }).click();
  await expect(view.locator(".pfBio")).toHaveText("Ich liebe das Derby");
  expect(saved.bio).toBe("Ich liebe das Derby");
  expect(look).toEqual({ theme: "sunset", showcase: ["record", "hot-streak"] });
  await expect(view).toHaveClass(/pfTheme-sunset/);
  await expect(page.getByText("Nur für dich sichtbar")).toBeVisible();
  expect(errors).toEqual([]);
});

test("chat groups messages, links @names to profiles and switches to the list on phones", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  const errors = []; page.on("pageerror", (e) => errors.push(e.message));
  const luna = { username: "luna", role: "member", level: 4 };
  const msgs = [
    { id: 1, sender_username: "luna", sender: luna, body: "Hi!", created_at: "2026-11-16T18:00:00", chat_style: "default" },
    { id: 2, sender_username: "luna", sender: luna, body: "Frag mal @kyoko", created_at: "2026-11-16T18:01:00", chat_style: "default" },
    { id: 3, sender_username: "kyoko", sender: me, body: "Bin da", created_at: "2026-11-16T18:02:00", chat_style: "neon" },
  ];
  await page.route("**/api/**", (route) => {
    const path = new URL(route.request().url()).pathname;
    let json = [];
    if (path.endsWith("/auth/me")) json = { user: me };
    else if (path.endsWith("/chat/unread")) json = { total: 0, conversations: [] };
    else if (path.endsWith("/api/users")) json = [me, luna];
    else if (path.endsWith("/chat/styles")) json = { selected: "neon", styles: [{ id: "default", name: "Standard", owned: true }, { id: "neon", name: "Neon", owned: true }] };
    else if (path.endsWith("/chat/global")) json = msgs;
    return route.fulfill({ json });
  });
  await page.addInitScript(() => localStorage.setItem("aviary_token", "token"));
  await page.goto("/#chat");
  await expect(page.locator(".cGroup")).toHaveCount(2);
  await expect(page.locator(".cGroup").first().locator(".cBubble")).toHaveCount(2);
  await expect(page.locator(".cGroup.mine .chatStyle-neon")).toContainText("Bin da");
  await expect(page.locator("a.cMention")).toHaveAttribute("href", "#u/kyoko");
  await expect(page.locator(".cSide")).toBeHidden();
  await page.getByRole("button", { name: "Zur Übersicht" }).click();
  await expect(page.locator(".cSide")).toBeVisible();
  await page.locator(".cConvList .cConv", { hasText: "luna" }).click();
  await expect(page.locator(".cHead strong")).toContainText("luna");
  await expect(page.locator(".cSide")).toBeHidden();
  expect(errors).toEqual([]);
});
