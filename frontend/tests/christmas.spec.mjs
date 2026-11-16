import { test, expect } from "@playwright/test";

const SHOTS = process.env.XMAS_SHOTS;

function mock(page, user, calls) {
  return page.route("**/api/**", (route) => {
    const path = new URL(route.request().url()).pathname;
    const method = route.request().method();
    if (path.endsWith("/auth/me")) return route.fulfill({ json: { user: { ...user } } });
    if (path.endsWith("/auth/login")) return route.fulfill({ json: { token: "t2", user: { ...user } } });
    if (path.endsWith("/profile/christmas") && method === "PUT") {
      const { mode } = route.request().postDataJSON();
      calls.push(mode);
      user.christmas = mode;
      return route.fulfill({ json: { christmas: mode } });
    }
    if (path.endsWith("/dashboard")) return route.fulfill({ json: { stats: {}, leaderboard: [{ username: "kyoko", chickens_earned: 50 }], active_members: [], news: [{ id: 1, title: "Adventskalender ist da", body: "Jeden Tag ein Türchen." }], events: [] } });
    if (path.endsWith("/chat/unread")) return route.fulfill({ json: { total: 0, conversations: [] } });
    if (path.includes("/profile/") && path.endsWith("/card")) return route.fulfill({ status: 404, json: { detail: "nope" } });
    if (path.endsWith("/wallet/history")) return route.fulfill({ json: { wallet: user, summary: { earned: 0, adjustments: 0, spent: 0 }, transactions: [] } });
    if (path.endsWith("/api/levels")) return route.fulfill({ json: {} });
    return route.fulfill({ json: [] });
  });
}

test("asks on login until yes; yes decorates the site live; the profile switch turns it off and on", async ({ page }) => {
  const errors = []; page.on("pageerror", (e) => errors.push(e.message));
  const user = { username: "kyoko", role: "member", chickens: 120, chickens_earned: 500, level: 6, christmas: "ask" };
  const calls = [];
  await mock(page, user, calls);
  await page.addInitScript(() => { if (!localStorage.getItem("aviary_token")) localStorage.setItem("aviary_token", "token"); });

  await page.goto("/#home");
  const prompt = page.getByRole("dialog", { name: "Naa, schon in Weihnachtsstimmung?" });
  await expect(prompt).toBeVisible();
  if (SHOTS) { await page.waitForTimeout(600); await page.screenshot({ path: `${SHOTS}/xmas-prompt.png` }); }
  await prompt.getByRole("button", { name: "Nein, noch nicht" }).click();
  await expect(prompt).toHaveCount(0);
  expect(calls).toEqual(["declined"]);
  await expect(page.locator(".xmGarland")).toHaveCount(0);

  // Same visit: no second question. A new login asks again, with the other wording.
  await page.reload();
  await page.waitForTimeout(1500);
  await expect(page.locator(".xmPrompt")).toHaveCount(0);
  await page.goto("/#login");
  await page.locator("input").first().fill("kyoko");
  await page.locator("input[type=password]").fill("geheim123");
  await page.locator("form button[type=submit]").first().click();
  const again = page.getByRole("dialog", { name: "Wie sieht's aus, jetzt in Weihnachtsstimmung?" });
  await expect(again).toBeVisible();
  await again.getByRole("button", { name: /Ja, her damit/ }).click();
  expect(calls).toEqual(["declined", "on"]);

  // The site transforms step by step.
  await expect(page.locator(".xmGarland.xmIntro")).toBeVisible();
  await expect(page.locator(".xmFireplace")).toBeVisible();
  await expect(page.locator(".xmSnow")).toBeVisible();
  await expect(page.locator(".xmHat")).toBeVisible();
  await expect(page.locator(".xmMusicBtn")).toBeVisible();
  if (SHOTS) {
    for (const t of [700, 1500, 1800, 2500, 7000]) { await page.waitForTimeout(t); await page.screenshot({ path: `${SHOTS}/xmas-intro-${t}.png` }); }
  }

  // Music button mutes; it is remembered.
  await page.locator(".xmMusicBtn").click();
  await expect(page.locator(".xmMusicBtn")).toHaveClass(/muted/);
  expect(await page.evaluate(() => JSON.parse(localStorage.getItem("aviary_xmas_music")).muted)).toBe(true);

  // Reload with Christmas on: no question, decorations right away.
  await page.reload();
  await expect(page.locator(".xmGarland")).toBeVisible();
  await expect(page.locator(".xmGarland.xmIntro")).toHaveCount(0);
  await expect(page.locator(".xmPrompt")).toHaveCount(0);
  if (SHOTS) { await page.waitForTimeout(6000); await page.screenshot({ path: `${SHOTS}/xmas-home.png` }); }

  // Christmas colours replace the violet look; one click on the tree brings the normal design back.
  const accent = () => page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue("--neon-violet").trim());
  expect(await accent()).toBe("#e8424f");
  const tree = page.getByRole("button", { name: "Weihnachtsdesign ausschalten" });
  await tree.click();
  await expect(page.locator(".xmGarland")).toHaveCount(0);
  await expect.poll(accent).toBe("#b56cff");
  expect(calls.at(-1)).toBe("off");
  if (SHOTS) { await page.waitForTimeout(1500); await page.screenshot({ path: `${SHOTS}/xmas-off.png` }); }
  await page.getByRole("button", { name: "Weihnachtsdesign einschalten" }).click();
  await expect(page.locator(".xmGarland")).toBeVisible();
  await expect.poll(accent).toBe("#e8424f");
  if (SHOTS) { await page.waitForTimeout(500); await page.screenshot({ path: `${SHOTS}/xmas-reveal.png` }); }
  expect(calls.at(-1)).toBe("on");
  // The circle transition takes ~1.3 s; clicks wait for it.
  await expect.poll(() => page.evaluate(() => document.documentElement.classList.contains("xmReveal"))).toBe(false);

  // Profile: switch it off and back on.
  await page.goto("/#profile");
  const deco = page.getByRole("switch", { name: /Weihnachtsdeko/ });
  await expect(deco).toBeChecked();
  if (SHOTS) await page.locator(".xmSettings").screenshot({ path: `${SHOTS}/xmas-settings.png` });
  await deco.click({ force: true });
  await expect(page.locator(".xmGarland")).toHaveCount(0);
  await expect.poll(() => page.evaluate(() => document.documentElement.classList.contains("xmReveal"))).toBe(false);
  expect(calls.at(-1)).toBe("off");
  await page.reload();
  await page.waitForTimeout(1500);
  await expect(page.locator(".xmPrompt")).toHaveCount(0);
  await page.getByRole("switch", { name: /Weihnachtsdeko/ }).click({ force: true });
  await expect(page.locator(".xmGarland")).toBeVisible();
  expect(calls.at(-1)).toBe("on");
  expect(errors).toEqual([]);
});

test("phone: decorations fit and the question is readable", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  const user = { username: "kyoko", role: "member", chickens: 120, chickens_earned: 500, level: 6, christmas: "on" };
  await mock(page, user, []);
  await page.addInitScript(() => localStorage.setItem("aviary_token", "token"));
  await page.goto("/#home");
  await expect(page.locator(".xmGarland")).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  if (SHOTS) {
    await page.waitForTimeout(5000); await page.screenshot({ path: `${SHOTS}/xmas-phone.png` });
    await page.getByRole("button", { name: "Menü öffnen" }).click(); await page.waitForTimeout(800);
    await page.screenshot({ path: `${SHOTS}/xmas-phone-menu.png` });
  }
});
