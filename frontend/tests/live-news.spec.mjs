import { test, expect } from "@playwright/test";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { readFileSync } from "node:fs";

// OBS allows browser-source autoplay. Exercise actual media playback, not a mocked play().
test.use({ launchOptions: { args: ["--autoplay-policy=no-user-gesture-required"] } });

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
  expect(await page.locator("#news-track").evaluate((node) => new DOMMatrixReadOnly(getComputedStyle(node).transform).m41))
    .toBeLessThan(1665);
  expect(await page.locator(".news-copy").count()).toBe(1);
  await page.route("**/api/live-news", (route) => route.abort());
  await page.waitForTimeout(1200);
  await expect(page.locator("#ticker")).toBeVisible();
  await page.unroute("**/api/live-news");
  setState({ message: "Community Abend um 20 Uhr", kind: "community", speed: 120, revision: 2 });
  await expect(page.locator("#ticker")).toHaveAttribute("data-kind", "community");
  await page.screenshot({ path: join(tmpdir(), "live-news-overlay.png"), omitBackground: true });
  const box = await page.locator("#ticker").boundingBox();
  expect(box.y + box.height).toBe(1080);
  expect(box.height).toBe(52);
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

test("admin: duration/count settings, exact cycle measurement, sound audition and mute are published", async ({ page }) => {
  const { writes } = await setup(page);
  await page.addInitScript(() => {
    window.__newsAudio = [];
    const NativeAudio = window.Audio;
    window.Audio = class extends NativeAudio {
      constructor(src) { super(src); window.__newsAudio.push(this); }
    };
  });
  await openAdmin(page);
  await page.getByLabel("Nachricht", { exact: true }).fill("Community trifft sich um 20 Uhr!");
  await page.getByLabel("Anzahl Durchlaeufe", { exact: true }).fill("21");
  await expect(page.getByRole("button", { name: "Live schalten", exact: true })).toBeDisabled();
  await page.getByRole("button", { name: "Zeitdauer", exact: true }).click();
  await page.getByLabel("Dauer in Sekunden", { exact: true }).fill("4");
  await page.getByRole("button", { name: "Durchlaeufe", exact: true }).click();
  await page.getByLabel("Anzahl Durchlaeufe", { exact: true }).fill("2");
  await page.getByRole("button", { name: "Live schalten", exact: true }).click();
  await expect(page.getByText("Nachricht ist live.", { exact: true })).toBeVisible();
  expect(writes.at(-1)).toMatchObject({ playback_mode: "loops", repeat_count: 2, duration_seconds: 30, sound_enabled: true, volume: 70 });
  const overlay = page.frames().find((frame) => frame.url().includes("preview=1"));
  const actualCycle = await overlay.evaluate(() => {
    const track = document.getElementById("news-track");
    const windowWidth = track.parentElement.clientWidth;
    return (windowWidth + track.firstElementChild.getBoundingClientRect().width) / 90;
  });
  expect(writes.at(-1).cycle_seconds).toBeCloseTo(actualCycle, 1);
  await page.getByRole("button", { name: "Zeitdauer", exact: true }).click();
  await page.getByLabel("Dauer in Sekunden", { exact: true }).fill("4");
  await expect(page.getByRole("button", { name: "Live schalten", exact: true })).toBeDisabled();
  await page.getByLabel("Dauer in Sekunden", { exact: true }).fill("15");
  await page.getByLabel("Lautstaerke").fill("40");
  for (const [label, kind] of [["Breaking News", "breaking"], ["Normale News", "normal"], ["Community News", "community"]]) {
    await page.getByLabel(label, { exact: true }).check();
    await page.getByRole("button", { name: "Sound testen", exact: true }).click();
    await expect(page.getByRole("button", { name: "Sound stoppen", exact: true })).toBeVisible();
    expect(await page.evaluate(() => ({ src: window.__newsAudio.at(-1).src.split("/").at(-1), volume: window.__newsAudio.at(-1).volume })))
      .toEqual({ src: `${kind}.wav`, volume: .4 });
    await page.getByRole("button", { name: "Sound stoppen", exact: true }).click();
    expect(await page.evaluate(() => window.__newsAudio.at(-1).paused)).toBe(true);
  }
  await page.getByLabel("Sound beim Start", { exact: true }).uncheck();
  await expect(page.getByRole("button", { name: "Sound testen", exact: true })).toBeDisabled();
  await page.getByRole("button", { name: "Live schalten", exact: true }).click();
  await expect(page.getByText("Nachricht ist live.", { exact: true })).toBeVisible();
  expect(writes.at(-1)).toMatchObject({ playback_mode: "duration", duration_seconds: 15, sound_enabled: false, volume: 40 });
  await page.screenshot({ path: join(tmpdir(), "live-news-playback-controls.png"), fullPage: true });
});

test("admin: expiration updates live status without overwriting draft; identical preview restarts after finishing", async ({ page }) => {
  const { setState } = await setup(page);
  await openAdmin(page);
  await page.getByLabel("Nachricht", { exact: true }).fill("Gesendete Nachricht");
  await page.getByRole("button", { name: "Live schalten", exact: true }).click();
  await expect(page.getByRole("switch")).toBeChecked();
  await page.getByLabel("Nachricht", { exact: true }).fill("Ungespeicherter Entwurf");
  setState({ enabled: false });
  await expect(page.getByRole("switch")).not.toBeChecked({ timeout: 6000 });
  await expect(page.getByLabel("Nachricht", { exact: true })).toHaveValue("Ungespeicherter Entwurf");
  await page.getByRole("button", { name: "Vorschau", exact: true }).click();
  const frame = page.frameLocator("iframe[title='Live News Vorschau']");
  await expect(frame.locator("#ticker")).toBeVisible();
  await frame.locator("#news-track").evaluate((node) => node.getAnimations()[0].finish());
  await expect(frame.locator("#ticker")).toBeHidden();
  await page.getByRole("button", { name: "Vorschau", exact: true }).click();
  await expect(frame.locator("#ticker")).toBeVisible();
});

test("OBS: exact finite loops stop, identical polling cannot restart, identical republish can", async ({ page }) => {
  const { setState } = await setup(page);
  const start = Date.now();
  setState({ message: "Zweimal", enabled: true, repeat_count: 2, cycle_seconds: 1, sound_enabled: false,
    updated_at: new Date(start).toISOString(), ends_at: new Date(start + 2000).toISOString(), revision: 1 });
  await page.goto("/overlays/live-news.html");
  await expect(page.locator("#ticker")).toBeVisible();
  expect(await page.locator("#news-track").evaluate((node) => getComputedStyle(node).animationIterationCount)).toBe("2");
  await expect(page.locator("#ticker")).toBeHidden({ timeout: 3500 });
  await page.waitForTimeout(1100);
  await expect(page.locator("#ticker")).toBeHidden();
  await page.reload();
  await expect(page.locator("#ticker")).toBeHidden();
  setState({ updated_at: new Date().toISOString(), ends_at: new Date(Date.now() + 2000).toISOString(), revision: 2 });
  await expect(page.locator("#ticker")).toBeVisible();
  await expect(page.locator("#ticker")).toBeHidden({ timeout: 3500 });
});

test("OBS: duration stops during network failure and expired publications stay hidden on reload", async ({ page }) => {
  const { setState } = await setup(page);
  const start = Date.now();
  setState({ message: "Nur fuenf Sekunden", enabled: true, playback_mode: "duration", duration_seconds: 5,
    cycle_seconds: 1, sound_enabled: false, updated_at: new Date(start).toISOString(), ends_at: new Date(start + 5000).toISOString() });
  await page.goto("/overlays/live-news.html");
  await expect(page.locator("#ticker")).toBeVisible();
  expect(await page.locator("#news-track").evaluate((node) => getComputedStyle(node).animationIterationCount)).toBe("infinite");
  await page.route("**/api/live-news", (route) => route.abort());
  await expect(page.locator("#ticker")).toBeHidden({ timeout: 6500 });
  await page.unroute("**/api/live-news");
  await page.reload();
  await expect(page.locator("#ticker")).toBeHidden();
});

test("OBS: actual type-specific audio plays once, stops on hide, respects mute and skips stale reloads", async ({ page }) => {
  const { setState } = await setup(page);
  await page.addInitScript(() => {
    window.__newsAudio = [];
    const NativeAudio = window.Audio;
    window.Audio = class extends NativeAudio {
      constructor(src) { super(src); window.__newsAudio.push(this); }
    };
  });
  await page.goto("/overlays/live-news.html");
  let revision = 0;
  for (const kind of ["breaking", "normal", "community", "community"]) {
    revision++;
    setState({ message: "Test", kind, enabled: true, playback_mode: "duration", duration_seconds: 15,
      sound_enabled: true, volume: 45, revision, updated_at: new Date().toISOString(), ends_at: new Date(Date.now() + 15000).toISOString() });
    await expect.poll(() => page.evaluate(() => window.__newsAudio.length)).toBe(revision);
    await expect(page.locator("#ticker")).toHaveAttribute("data-sound-state", "playing");
    await expect.poll(() => page.evaluate(() => window.__newsAudio.at(-1)?.currentTime ?? 0)).toBeGreaterThan(.05);
    const playback = await page.evaluate(() => {
      const current = window.__newsAudio.at(-1);
      return { count: window.__newsAudio.length, src: current.src.split("/").at(-1), volume: current.volume,
        paused: current.paused, duration: current.duration, previousStopped: window.__newsAudio.slice(0, -1).every((audio) => audio.paused) };
    });
    expect(playback).toMatchObject({ count: revision, src: `${kind}.wav`, volume: .45, paused: false, previousStopped: true });
    expect(playback.duration).toBeGreaterThan(2);
    await page.waitForTimeout(1100);
    expect(await page.evaluate(() => window.__newsAudio.length)).toBe(revision);
  }
  setState({ enabled: false });
  await expect(page.locator("#ticker")).toBeHidden();
  expect(await page.evaluate(() => window.__newsAudio.every((audio) => audio.paused))).toBe(true);
  setState({ enabled: true, revision: ++revision, updated_at: new Date().toISOString(), ends_at: new Date(Date.now() + 15000).toISOString() });
  await expect.poll(() => page.evaluate(() => window.__newsAudio.length)).toBe(revision);
  await expect(page.locator("#ticker")).toHaveAttribute("data-sound-state", "playing");
  await page.reload();
  await expect(page.locator("#ticker")).toHaveAttribute("data-sound-state", "already-played");
  expect(await page.evaluate(() => window.__newsAudio.length)).toBe(0);
  setState({ sound_enabled: false, revision: ++revision, updated_at: new Date().toISOString() });
  await expect(page.locator("#ticker")).toHaveAttribute("data-sound-state", "disabled");
  expect(await page.evaluate(() => window.__newsAudio.length)).toBe(0);
  setState({ sound_enabled: true, volume: 0, revision: ++revision, updated_at: new Date().toISOString() });
  await expect(page.locator("#ticker")).toHaveAttribute("data-sound-state", "disabled");
  expect(await page.evaluate(() => window.__newsAudio.length)).toBe(0);
  setState({ sound_enabled: true, volume: 45, revision: ++revision, updated_at: new Date(Date.now() - 8000).toISOString() });
  await expect(page.locator("#ticker")).toHaveAttribute("data-sound-state", "stale");
  expect(await page.evaluate(() => window.__newsAudio.length)).toBe(0);
  setState({ enabled: false });
  await expect(page.locator("#ticker")).toBeHidden();
});

test("compact overlay: consistent stream height at full HD, 720p, default OBS and mobile widths", async ({ page }) => {
  const { setState } = await setup(page);
  const start = Date.now() - 12000;
  setState({ message: "Community News: Schoen, dass ihr dabei seid!", enabled: true, kind: "breaking",
    sound_enabled: false, cycle_seconds: 30, repeat_count: 3,
    updated_at: new Date(start).toISOString(), ends_at: new Date(start + 90000).toISOString() });
  await page.setViewportSize({ width: 1920, height: 1080 });
  await page.goto("/overlays/live-news.html");
  await expect(page.locator("#ticker")).toBeVisible();
  for (const kind of ["breaking", "normal", "community"]) {
    setState({ kind });
    await expect(page.locator("#ticker")).toHaveAttribute("data-kind", kind);
    const sizes = await page.evaluate(() => {
      const label = document.getElementById("news-label").getBoundingClientRect();
      const bar = document.querySelector(".news-bar").getBoundingClientRect();
      const text = document.querySelector(".news-copy").getBoundingClientRect();
      return { labelFits: label.top >= bar.top && label.bottom <= bar.bottom,
        textFits: text.height <= bar.height, height: document.getElementById("ticker").getBoundingClientRect().height };
    });
    expect(sizes).toEqual({ labelFits: true, textFits: true, height: 52 });
  }
  await page.screenshot({ path: join(tmpdir(), "live-news-compact-1080p.png"), omitBackground: true });
  for (const [width, height] of [[1280, 720], [800, 600], [390, 844]]) {
    await page.setViewportSize({ width, height });
    await expect.poll(async () => Math.round((await page.locator("#ticker").boundingBox()).width)).toBe(width);
    const box = await page.locator("#ticker").boundingBox();
    expect(box.x).toBeCloseTo(0, 3);
    expect(box.y + box.height).toBeCloseTo(height, 3);
    expect(box.height).toBeCloseTo(52 * width / 1920, 2);
    expect(box.height * 1920 / width).toBeCloseTo(52, 2);
    expect(await page.locator(".news-copy").evaluate((node) => getComputedStyle(node).fontSize)).toBe("22px");
    if (width === 800) await page.screenshot({ path: join(tmpdir(), "live-news-compact-obs-default.png"), omitBackground: true });
  }
});

test("generated audio assets: valid non-silent PCM without clipping", () => {
  const fingerprints = new Set();
  for (const kind of ["breaking", "normal", "community"]) {
    const wav = readFileSync(new URL(`../public/overlays/sounds/${kind}.wav`, import.meta.url));
    expect(wav.toString("ascii", 0, 4)).toBe("RIFF");
    expect(wav.readUInt32LE(24)).toBe(44100);
    expect(wav.readUInt16LE(34)).toBe(16);
    let sum = 0, peak = 0;
    for (let offset = 44; offset < wav.length; offset += 2) {
      const value = wav.readInt16LE(offset) / 32768;
      sum += value * value; peak = Math.max(peak, Math.abs(value));
    }
    expect(Math.sqrt(sum / ((wav.length - 44) / 2))).toBeGreaterThan(.03);
    expect(peak).toBeLessThan(.9);
    fingerprints.add(wav.length);
  }
  expect(fingerprints.size).toBe(3);
});
