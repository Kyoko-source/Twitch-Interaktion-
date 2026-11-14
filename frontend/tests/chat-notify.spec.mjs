import { test, expect } from "@playwright/test";

test("chat: unread private messages show a badge, a popup and open the right conversation", async ({ page }) => {
  const errors = []; page.on("pageerror", (error) => errors.push(error.message));
  const user = { username: "magical_kyoko_", role: "member", chickens: 10, chickens_earned: 10, level: 1, level_progress: 0, level_target: 100 };
  let unread = { total: 2, conversations: [{ username: "alice", count: 2, last_id: "m2", last_at: "2026-11-14T12:00:00", last_body: "Bist du heute im Stream?" }] };
  const opened = [];
  await page.route("**/api/**", (route) => {
    const path = new URL(route.request().url()).pathname;
    let json = [];
    if (path.endsWith("/auth/me")) json = { user };
    else if (path.endsWith("/chat/unread")) json = unread;
    else if (path.endsWith("/dashboard")) json = { stats: {}, leaderboard: [], active_members: [], news: [], events: [] };
    else if (path.endsWith("/api/users")) json = [user, { username: "alice", role: "member" }, { username: "bob", role: "member" }];
    else if (path.endsWith("/chat/styles")) json = { selected: "default", styles: [] };
    else if (path.endsWith("/chat/private/alice")) {
      opened.push("alice");
      unread = { total: 0, conversations: [] };
      json = [{ id: "m2", sender_username: "alice", recipient_username: user.username, body: "Bist du heute im Stream?", created_at: "2026-11-14T12:00:00" }];
    }
    return route.fulfill({ json });
  });
  await page.goto("/");
  const toast = page.locator(".chatToast");
  await expect(toast).toContainText("alice");
  await expect(toast).toContainText("Bist du heute im Stream?");
  await expect(page.locator(".chatBell .navBadge")).toHaveText("2");
  await expect(page).toHaveTitle(/^\(2\) /);
  if (process.env.SHOT) await page.screenshot({ path: process.env.SHOT });

  await toast.getByRole("button", { name: "Antworten" }).click();
  await expect(page.locator(".chatWindowHead strong")).toHaveText("alice");
  await expect(page.locator(".chatMessages")).toContainText("Bist du heute im Stream?");
  expect(opened.length).toBeGreaterThan(0);
  await expect(page.locator(".chatBell .navBadge")).toHaveCount(0);
  await expect(page).not.toHaveTitle(/^\(/);
  expect(errors).toEqual([]);
});
