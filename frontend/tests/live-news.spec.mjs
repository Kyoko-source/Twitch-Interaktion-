import { test, expect } from "@playwright/test";
import { join } from "node:path";
import { tmpdir } from "node:os";

const initial = { message: "", kind: "breaking", speed: 90, enabled: false, revision: 0, updated_at: null };

async function setup(page) {
  let state = { ...initial };
  const writes = [];
  await page.route("**/api/**", async (route) => {
    const request = route.request();
    const path = new URL(request.url()).pathname;
    if (path.endsWith("/live-news")) {
      if (request.method() !== "GET") {
        expect(request.headers()["x-admin-password"]).toBe("test-password");
        writes.push(request.postDataJSON());
        state = { ...state, ...request.postDataJSON(), revision: state.revision + 1, updated_at: new Date().toISOString() };
      }
      return route.fulfill({ json: state });
    }
    return route.fulfill({ json: path.endsWith("/admin/overview")
      ? { users: [], registration_requests: [], support_messages: [], wishes: [] }
      : path.endsWith("/auth/me") ? { user: null } : [] });
  });
  return { writes, setState: (next) => { state = { ...state, ...next }; } };
}

async function openAdmin(page) {
  await page.goto("/#admin");
  await page.getByLabel("Admin Passwort").fill("test-password");
  await page.getByRole("button", { name: "Dashboard laden" }).click();
  await page.getByRole("button", { name: "Live News", exact: true }).click();
  await expect(page.getByLabel("Nachricht", { exact: true })).toBeEnabled();
}

test("admin: isolated preview, publish, visibility, source URL and all message types", async ({ page }) => {
  const errors = [];
  page.on("pageerror", (error) => errors.push(error.message));
  const { writes } = await setup(page);
  await openAdmin(page);
  const frame = page.frameLocator("iframe[title='Live News Vorschau']");
  await expect(frame.locator("#ticker")).toBeHidden();
  await expect(page.getByRole("button", { name: "Live schalten", exact: true })).toBeDisabled();
  await page.getByLabel("Nachricht", { exact: true }).fill("EILMELDUNG: Kyoko hat den Boss besiegt!");
  await page.getByRole("button", { name: "Vorschau", exact: true }).click();
  await expect(frame.locator("#ticker")).toBeVisible();
  await expect(frame.locator("#news-label")).toHaveText("BREAKING NEWS");
  expect(writes).toEqual([]);
  await page.getByRole("button", { name: "Live schalten", exact: true }).click();
  await expect(page.getByRole("switch")).toBeChecked();
  expect(writes).toHaveLength(1);
  for (const [label, kind, tag] of [["Normale News", "normal", "NEWS"], ["Community News", "community", "COMMUNITY NEWS"]]) {
    await page.getByLabel(label, { exact: true }).check();
    await page.getByRole("button", { name: "Vorschau", exact: true }).click();
    await expect(frame.locator("#ticker")).toHaveAttribute("data-kind", kind);
    await expect(frame.locator("#news-label")).toHaveText(tag);
  }
  await page.getByLabel("Geschwindigkeit").fill("150");
  await page.getByRole("button", { name: "Live schalten", exact: true }).click();
  expect(writes.at(-1)).toMatchObject({ kind: "community", speed: 150, enabled: true });
  await page.getByRole("switch").uncheck();
  await expect(page.getByText("Ticker ausgeblendet.", { exact: true })).toBeVisible();
  expect(writes.at(-1)).toEqual({ enabled: false });
  const url = await page.getByLabel("Browserquellen-URL").inputValue();
  expect(url).toBe("http://127.0.0.1:4186/overlays/live-news.html");
  expect(url).not.toContain("password");
  await page.getByRole("button", { name: "URL kopieren", exact: true }).click();
  await expect(page.getByRole("button", { name: "Kopiert", exact: true })).toBeVisible();
  await expect(page.locator(".supportFab")).toBeHidden();
  await page.screenshot({ path: join(tmpdir(), "live-news-admin-desktop.png"), fullPage: true });
  expect(errors).toEqual([]);
});

test("OBS: transparent, live updates, actual movement, no restart on polling, network recovery and no HTML injection", async ({ page }) => {
  const { setState } = await setup(page);
  await page.setViewportSize({ width: 1920, height: 1080 });
  await page.goto("/overlays/live-news.html");
  await expect(page.locator("#ticker")).toBeHidden();
  expect(await page.locator("body").evaluate((node) => getComputedStyle(node).backgroundColor)).toBe("rgba(0, 0, 0, 0)");
  setState({ message: "<img src=x onerror=alert(1)> Community gewinnt!", enabled: true, revision: 1 });
  await expect(page.locator("#ticker")).toBeVisible();
  await expect(page.locator(".news-copy").first()).toHaveText("+++ <img src=x onerror=alert(1)> Community gewinnt! +++");
  expect(await page.locator("img").count()).toBe(0);
  const time = await page.locator("#news-track").evaluate((node) => node.getAnimations()[0].currentTime);
  await page.waitForTimeout(2300);
  const later = await page.locator("#news-track").evaluate((node) => node.getAnimations()[0].currentTime);
  expect(later - time).toBeGreaterThan(2000);
  const translation = await page.locator("#news-track").evaluate((node) => new DOMMatrixReadOnly(getComputedStyle(node).transform).m41);
  expect(translation).toBeLessThan(-150);
  expect(await page.locator("#news-track").evaluate((node) => {
    const width = node.parentElement.clientWidth;
    const unit = node.firstElementChild.getBoundingClientRect().width;
    return node.getBoundingClientRect().width - unit >= width;
  })).toBe(true);
  await page.route("**/api/live-news", (route) => route.abort());
  await page.waitForTimeout(1200);
  await expect(page.locator("#ticker")).toBeVisible();
  await page.unroute("**/api/live-news");
  setState({ message: "Community Abend um 20 Uhr", kind: "community", speed: 120, revision: 2 });
  await expect(page.locator("#ticker")).toHaveAttribute("data-kind", "community");
  await page.screenshot({ path: join(tmpdir(), "live-news-overlay.png"), omitBackground: true });
  const box = await page.locator("#ticker").boundingBox();
  expect(box.y + box.height).toBe(1080);
  expect(box.height).toBe(102);
  expect(await page.locator("#news-label").evaluate((node) => node.scrollWidth <= node.clientWidth)).toBe(true);
  setState({ enabled: false, revision: 3 });
  await expect(page.locator("#ticker")).toBeHidden();
});

test("mobile: controls and scaled preview fit; backend failure cannot report success", async ({ page }) => {
  await setup(page);
  await page.setViewportSize({ width: 390, height: 844 });
  await openAdmin(page);
  await page.getByLabel("Nachricht", { exact: true }).fill("Neue Community News");
  await page.getByRole("button", { name: "Vorschau", exact: true }).click();
  const frame = page.frameLocator("iframe[title='Live News Vorschau']");
  await expect(frame.locator("#ticker")).toBeVisible();
  await expect(page.locator(".supportFab")).toBeHidden();
  const screen = await page.locator(".liveNewsScreen").boundingBox();
  const preview = await page.locator(".liveNewsFrameViewport").boundingBox();
  expect(preview.width).toBeCloseTo(screen.width - 2, 0);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({ path: join(tmpdir(), "live-news-admin-mobile.png"), fullPage: true });
  await page.route("**/api/admin/live-news", (route) => route.fulfill({ status: 503, json: { detail: "Speichern fehlgeschlagen" } }));
  await page.getByRole("button", { name: "Live schalten", exact: true }).click();
  await expect(page.getByRole("alert")).toHaveText("Speichern fehlgeschlagen");
  await expect(page.getByRole("switch")).not.toBeChecked();
  await expect(page.getByRole("button", { name: "Live schalten", exact: true })).toBeEnabled();
});
