import { test, expect } from "@playwright/test";
import { tmpdir } from "node:os";
import { join } from "node:path";

async function setup(page) {
  const user = { username: "magical_kyoko_", role: "moderator", chickens: 1118, chickens_earned: 18, level: 1 };
  const actions = [], bookings = [], roles = [];
  let revoked = false;
  await page.addInitScript(() => localStorage.setItem("aviary_token", "test-session"));
  await page.route("**/api/**", async route => {
    const req = route.request(), path = new URL(req.url()).pathname;
    let json = [];
    if (path.endsWith("/auth/me")) json = { user };
    else if (path.endsWith("/presence") && revoked) return route.fulfill({ status: 401, json: { detail: { code: "session_revoked", message: "Deine Sitzung wurde beendet." } } });
    else if (path.endsWith("/presence")) json = { status: "online", role: user.role };
    else if (path.endsWith("/admin/overview")) json = { users: [user], registration_requests: [], support_messages: [], wishes: [] };
    else if (path.endsWith("/admin/role")) { const body = req.postDataJSON(); roles.push(body); user.role = body.role; json = { message: "Gespeichert" }; }
    else if (path.endsWith("/action")) {
      const body = req.postDataJSON(); actions.push(body);
      if (body.action === "ban") { user.banned = true; user.ban_reason = body.reason; }
      if (body.action === "unban") { user.banned = false; user.ban_reason = ""; }
      json = { message: "Aktion gespeichert." };
    } else if (path.endsWith("/admin/points")) {
      const body = req.postDataJSON(); bookings.push(body); user.chickens += body.chickens_delta;
      json = { message: "Gebucht.", wallet: { ...user } };
    } else if (path.endsWith("/wallet/history")) json = { wallet: user, summary: { earned: 18, adjustments: 1400, spent: 300 }, transactions: [
      { id: "game-1", label: "PEPPLE Pinball", created: 1792059590, amount: 18, score: 557750 },
      { id: "purchase-1", label: "kein Englisch für 5 Minuten", created: 1792059623, amount: -300 },
      { id: "admin-1", label: "Admin-Gutschrift", created: 1792058530, amount: 700 },
      { id: "admin-2", label: "Admin-Gutschrift", created: 1792058534, amount: 700 },
    ] };
    else if (path.endsWith("/dashboard")) json = { stats: {}, leaderboard: [], active_members: [], news: [], events: [] };
    await route.fulfill({ json });
  });
  return { actions, bookings, roles, revoke: () => { revoked = true; } };
}

test("admin: remove role, kick, ban with reason, unban and double-click-safe Chicken booking", async ({ page }) => {
  const errors = []; page.on("pageerror", e => errors.push(e.message));
  const { actions, bookings, roles } = await setup(page);
  await page.goto("/#admin");
  await page.getByLabel("Admin Passwort").fill("isolated-test");
  await page.getByRole("button", { name: "Dashboard laden" }).click();
  await page.getByRole("button", { name: "Mitglieder & Rollen", exact: true }).click();
  await page.getByRole("button", { name: "Rolle entfernen" }).click();
  await expect(page.locator(".adminMemberIdentity")).toContainText("Mitglied");
  expect(roles).toEqual([{ username: "magical_kyoko_", role: "member" }]);
  for (const [button, action] of [["Kicken", "kick"], ["Bannen", "ban"], ["Entbannen", "unban"]]) {
    await page.getByRole("button", { name: button, exact: true }).click();
    await expect(page.getByRole("dialog")).toBeVisible();
    if (action === "ban") await page.getByLabel("Grund (optional)").fill("Spam im Chat");
    await page.getByRole("button", { name: "Aktion bestätigen" }).evaluate(b => { b.click(); b.click(); });
    await expect(page.getByRole("dialog")).toHaveCount(0);
    await expect(page.getByRole("button", { name: action === "ban" ? "Entbannen" : "Bannen", exact: true })).toBeVisible();
  }
  expect(actions.map(a => a.action)).toEqual(["kick", "ban", "unban"]);
  expect(actions[1].reason).toBe("Spam im Chat");
  expect(new Set(actions.map(a => a.request_id)).size).toBe(3);
  await page.setViewportSize({ width: 390, height: 844 });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.locator(".adminMembers").screenshot({ path: join(tmpdir(), "aviary-members-mobile.png") });
  await page.getByRole("button", { name: "Chickens", exact: true }).click();
  await page.getByRole("combobox", { name: "Mitglied", exact: true }).selectOption("magical_kyoko_");
  await page.getByLabel("Chickens Delta").fill("5");
  await page.getByRole("button", { name: "Chickens buchen", exact: true }).evaluate(b => { b.click(); b.click(); });
  await expect(page.getByRole("status")).toContainText("1123");
  expect(bookings).toHaveLength(1); expect(bookings[0].request_id).toMatch(/^[a-f0-9]{40}$/);
  expect(errors).toEqual([]);
});

test("profile: earned Chickens differ from available wallet and the ledger explains 1118", async ({ page }) => {
  await setup(page); await page.goto("/#profile");
  await expect(page.locator(".walletEquation")).toHaveText("18 erspielt+1.400 Admin-Buchungen−300 Einkäufe= 1.118 verfügbar");
  await expect(page.locator(".walletTransactions li")).toHaveCount(4);
  await expect(page.locator(".walletTransactions")).toContainText("557.750 Punkte");
  await page.locator(".walletHistory").screenshot({ path: join(tmpdir(), "aviary-wallet-history.png") });
});

test("revoked session: presence logs out, clears token and shows human-readable reason", async ({ page }) => {
  const state = await setup(page); await page.goto("/#profile");
  await expect(page.locator(".walletHistory")).toBeVisible(); state.revoke();
  await page.evaluate(() => document.dispatchEvent(new Event("visibilitychange")));
  await expect(page.getByText("Deine Sitzung wurde beendet.", { exact: true })).toBeVisible({ timeout: 18000 });
  expect(await page.evaluate(() => localStorage.getItem("aviary_token"))).toBeNull();
  await expect(page.locator("main").getByRole("button", { name: "Anmelden", exact: true })).toBeVisible();
});
