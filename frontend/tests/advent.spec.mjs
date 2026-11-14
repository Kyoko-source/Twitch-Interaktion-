import { test, expect } from "@playwright/test";

const ITEMS = {
  1: { id: "punish-virus", kind: "punishment", title: "VIRUS", text: "Countdown von genau 6 Monaten!" },
  5: { id: "task-only-up", kind: "task", title: "Only Up", text: "Spiele 60 Minuten Only Up." },
};

function calendar(opened, { admin, virusOff = null }) {
  const now = new Date("2026-12-05T20:00:00Z");
  const doors = Array.from({ length: 24 }, (_, i) => {
    const day = i + 1, at = new Date(Date.UTC(2026, 10, 30, 23) + i * 86400000);
    const d = { day, unlocks_at: at.toISOString(), unlocked: now >= at, opened: opened.includes(day) };
    if (d.opened) Object.assign(d, { opened_at: at.toISOString(), opened_by: "marello", item: ITEMS[day] });
    return d;
  });
  return { year: 2026, now: now.toISOString(), starts_at: doors[0].unlocks_at, doors, can_open: admin, virus: { started_at: doors[0].unlocks_at, deadline: "2027-05-31T23:00:00+00:00", months: 6, off: virusOff } };
}

async function setup(page, admin) {
  const opened = [1];
  const calls = { open: [], off: [] };
  let off = null;
  await page.route("**/api/**", async (route) => {
    const req = route.request(), path = new URL(req.url()).pathname;
    if (path.endsWith("/auth/me")) return route.fulfill({ json: { user: admin ? { username: "marello", role: "admin" } : null } });
    if (path.endsWith("/advent")) return route.fulfill({ json: calendar(opened, { admin, virusOff: off }) });
    const m = path.match(/advent\/(\d+)\/open/);
    if (m) { calls.open.push(Number(m[1])); opened.push(Number(m[1])); return route.fulfill({ json: calendar(opened, { admin, virusOff: off }) }); }
    if (path.endsWith("/virus/off")) {
      calls.off.push(req.postDataJSON());
      if (req.postDataJSON().password !== "richtig") return route.fulfill({ status: 403, json: { detail: "Falsches Passwort. Der Countdown läuft weiter." } });
      off = { at: "2026-12-05T20:00:00+00:00", by: "Passwort" };
      return route.fulfill({ json: calendar(opened, { admin, virusOff: off }) });
    }
    return route.fulfill({ json: [] });
  });
  if (admin) await page.addInitScript(() => localStorage.setItem("aviary_token", "token"));
  return calls;
}

test("admins open a ready door with a confirmation and get the big reveal", async ({ page }) => {
  const calls = await setup(page, true);
  await page.goto("/#advent");
  await expect(page.getByRole("heading", { name: /Adventskalender/ })).toBeVisible();
  await expect(page.locator(".advVirus")).toContainText("VIRUS AKTIV");
  await expect(page.getByRole("button", { name: "Türchen 9 – ab 9. Dezember" })).toBeDisabled();
  await page.getByRole("button", { name: "Türchen 5 öffnen" }).click();
  await page.getByRole("button", { name: "Aufmachen!" }).click();
  await expect(page.locator(".advReveal")).toContainText("AUFGABE!");
  await expect(page.locator(".advReveal")).toContainText("Only Up");
  expect(calls.open).toEqual([5]);
});

test("viewers cannot open doors but can switch the virus off only with the right password", async ({ page }) => {
  const calls = await setup(page, false);
  await page.goto("/#advent");
  await expect(page.getByRole("button", { name: "Türchen 5 öffnen" })).toBeDisabled();
  await page.getByRole("button", { name: /Türchen 1: BESTRAFUNG/ }).click();
  await expect(page.locator(".advReveal")).toContainText("VIRUS");
  await page.getByRole("button", { name: "Schließen" }).click();
  const field = page.getByLabel("Passwort zum Deaktivieren");
  await field.fill("falsch");
  await page.getByRole("button", { name: "Deaktivieren" }).click();
  await expect(page.locator(".advVirusForm [role=alert]")).toContainText("Falsches Passwort");
  await field.fill("richtig");
  await page.getByRole("button", { name: "Deaktivieren" }).click();
  await expect(page.locator(".advVirus")).toContainText("VIRUS DEAKTIVIERT");
  expect(calls.off.map((c) => c.password)).toEqual(["falsch", "richtig"]);
});
