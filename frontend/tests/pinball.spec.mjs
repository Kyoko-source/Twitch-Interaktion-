import { test, expect } from "@playwright/test";
import { tmpdir } from "node:os";
import { join } from "node:path";

test("five real target contacts arm the jackpot and grant exactly one extra multiball", async ({
  page,
}) => {
  await openPinball(page);
  await page.keyboard.press("Space");
  for (let index = 0; index < 5; index++) {
    await page.locator(".pinballMount").evaluate((el, index) => {
      const g = el.__pinballGame,
        target = g.targets[index],
        p = target.body.translation(),
        ball = g.balls[0];
      ball.body.setTranslation(
        {
          x: p.x + (index < 2 ? 0.5 : 0),
          y: 0.15,
          z: p.z + (index < 2 ? 0 : 0.5),
        },
        true,
      );
      ball.body.setLinvel(
        { x: index < 2 ? -4 : 0, y: 0, z: index < 2 ? 0 : -4 },
        true,
      );
    }, index);
    await expect
      .poll(() =>
        page
          .locator(".pinballMount")
          .evaluate(
            (el, index) => Boolean(el.__pinballGame.bank & (1 << index)),
            index,
          ),
      )
      .toBe(true);
  }
  await expect(page.locator(".pinballBigCombo")).toContainText("JACKPOT LIT");
  await page.locator(".pinballMount").evaluate((el) => {
    const g = el.__pinballGame,
      target = g.bumpers[1],
      ball = g.balls[0];
    ball.body.setTranslation(
      { x: target.x, y: 0.15, z: target.z + 0.68 },
      true,
    );
    ball.body.setLinvel({ x: 0, y: 0, z: -4 }, true);
  });
  await expect.poll(async () => (await state(page)).liveBalls.length).toBe(2);
  expect(
    await page
      .locator(".pinballMount")
      .evaluate((el) => el.__pinballGame.score),
  ).toBeGreaterThan(25000);
  const lives = await page.locator(".pinballMount").evaluate((el) => {
    const g = el.__pinballGame;
    g.saveUntil = 0;
    g.balls[1].body.setBodyType(2, true);
    g.balls[0].body.setTranslation({ x: 0, y: 0.15, z: 2.75 }, true);
    g.balls[0].body.setLinvel({ x: 0, y: 0, z: 3 }, true);
    return g.ball;
  });
  await expect.poll(async () => (await state(page)).liveBalls.length).toBe(1);
  expect(
    await page.locator(".pinballMount").evaluate((el) => el.__pinballGame.ball),
  ).toBe(lives);
});

test("high speed and a 100 ms frame stall do not send the ball through rails", async ({
  page,
}) => {
  await openPinball(page);
  await page.keyboard.press("Space");
  await page.keyboard.press("F3");
  for (const direction of [-1, 1]) {
    await page.locator(".pinballMount").evaluate((el, direction) => {
      const ball = el.__pinballGame.balls[0];
      ball.body.setTranslation({ x: 0, y: 0.15, z: 0.7 }, true);
      ball.body.setLinvel({ x: direction * 35, y: 0, z: 0 }, true);
      const end = performance.now() + 100;
      while (performance.now() < end) {}
    }, direction);
    await page.waitForTimeout(300);
    const ball = (await state(page)).liveBalls[0];
    expect(Math.abs(ball.position.x)).toBeLessThan(2.4);
    expect(
      Math.hypot(ball.velocity.x, ball.velocity.y, ball.velocity.z),
    ).toBeLessThanOrEqual(16.01);
  }
  expect(
    await page
      .locator(".pinballMount")
      .evaluate(
        (el) => el.__pinballGame.debugMesh.geometry.attributes.position.count,
      ),
  ).toBeGreaterThan(100);
});

test("one minute of real physics with flipper input stays bounded and keeps scoring", async ({
  page,
}) => {
  await openPinball(page);
  const result = await page.locator(".pinballMount").evaluate((el) => {
    const g = el.__pinballGame,
      start = g.time;
    g.paused = true;
    let outside = false,
      peakSpeed = 0;
    for (let i = 0; i < 7200 && g.status !== "gameover"; i++) {
      if (g.status === "ready") {
        g.paused = false;
        g.plunger = 0.65;
        g.launch();
        g.paused = true;
      }
      const ball = g.balls.find((b) => !b.ready && !b.falling);
      const p = ball?.body.translation(),
        v = ball?.body.linvel();
      g.keys.left = Boolean(
        p && p.x < 0.2 && p.z > 2.45 && (v.z > 0 || p.z > 2.9),
      );
      g.keys.right = Boolean(
        p && p.x > -0.2 && p.z > 2.45 && (v.z > 0 || p.z > 2.9),
      );
      g.step();
      if (i % 4 === 0) g.visuals(1 / 30);
      for (const b of g.balls) {
        const p = b.body.translation(),
          v = b.body.linvel();
        if (!b.falling && (Math.abs(p.x) > 2.45 || p.z < -4.5)) outside = true;
        peakSpeed = Math.max(peakSpeed, Math.hypot(v.x, v.y, v.z));
      }
    }
    return {
      elapsed: g.time - start,
      hits: g.hits,
      score: g.score,
      outside,
      peakSpeed,
      balls: g.ball,
    };
  });
  expect(result.outside, JSON.stringify(result)).toBe(false);
  expect(result.peakSpeed).toBeLessThanOrEqual(16.01);
  expect(result.elapsed).toBeGreaterThan(15);
  // The harder table intentionally yields fewer automatic hits; it must still
  // sustain real contacts and score without breaking containment or physics.
  expect(result.hits).toBeGreaterThan(4);
  expect(result.score).toBeGreaterThan(3000);
});

async function openPinball(page) {
  await page.route("**/api/**", (route) =>
    route.fulfill({
      json: route.request().url().includes("auth/me") ? { user: null } : [],
    }),
  );
  await page.goto("/#games");
  await page
    .getByRole("button", { name: "PEPPLE Pinball", exact: true })
    .click();
  await expect(
    page.getByRole("button", { name: "Spiel starten", exact: true }),
  ).toBeEnabled({ timeout: 20000 });
  await page
    .getByRole("button", { name: "Spiel starten", exact: true })
    .click();
  await expect(page.locator(".neonPinball")).toHaveAttribute(
    "data-status",
    "ready",
  );
}
const state = (page) =>
  page
    .locator(".pinballMount")
    .evaluate((el) => el.__pinballGame.getPhysicsDiagnostics());

test("short and full plunger shots physically exit the lane, pause and mute preserve the game", async ({
  page,
}) => {
  const errors = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await openPinball(page);
  for (const hold of [80, 1500]) {
    if (hold > 100)
      await page
        .getByRole("button", { name: "Neu starten", exact: true })
        .click();
    await page.keyboard.down("Space");
    await page.waitForTimeout(hold);
    await page.keyboard.up("Space");
    await expect
      .poll(async () => (await state(page)).liveBalls.some((b) => b.entered), {
        timeout: 8000,
      })
      .toBe(true);
    expect((await state(page)).liveBalls.every((b) => b.ccd)).toBe(true);
    await expect(page.locator(".neonPinball")).toHaveAttribute(
      "data-status",
      "play",
    );
  }
  const gameId = await page.locator(".pinballMount").evaluate((el) => {
    window.pinballIdentity = el.__pinballGame;
    return el.__pinballGame.score;
  });
  await page
    .getByRole("button", { name: "Sound ausschalten", exact: true })
    .click();
  expect(
    await page
      .locator(".pinballMount")
      .evaluate((el) => window.pinballIdentity === el.__pinballGame),
  ).toBe(true);
  expect(
    await page
      .locator(".pinballMount")
      .evaluate((el) => el.__pinballGame.score),
  ).toBeGreaterThanOrEqual(gameId);
  await page.keyboard.press("Escape");
  await expect(page.locator(".neonPinball")).toHaveAttribute(
    "data-status",
    "paused",
  );

  const position = await state(page);
  await page.waitForTimeout(250);
  expect(await state(page)).toEqual(position);
  await page.getByRole("button", { name: "Weiter", exact: true }).click();
  await page.screenshot({ path: join(tmpdir(), "pinball-desktop.png") });
  expect(errors).toEqual([]);
});

test("real bumper contacts produce points, combos and effects; idle contact cannot farm points", async ({
  page,
}) => {
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await openPinball(page);
  await page.keyboard.press("Space");
  for (let i = 0; i < 3; i++) {
    // A fixture places an incoming ball outside a bumper. Rapier must make the contact.
    await page.locator(".pinballMount").evaluate((el, index) => {
      const g = el.__pinballGame,
        b = g.balls[0],
        target = g.bumpers[index];
      b.body.setTranslation({ x: target.x, y: 0.15, z: target.z + 0.68 }, true);
      b.body.setLinvel({ x: 0, y: 0, z: -4 }, true);
    }, i);
    await expect
      .poll(async () => (await state(page)).hits)
      .toBeGreaterThanOrEqual(i + 1);
  }
  await expect(page.locator(".pinballBigCombo")).toContainText("COMBO");
  await expect(page.locator(".pinballFloat").first()).toBeVisible();
  const diagnostics = await state(page);
  expect(diagnostics.hits).toBeGreaterThanOrEqual(3);
  await page.screenshot({ path: join(tmpdir(), "pinball-combo.png") });
  await page.locator(".pinballMount").evaluate((el) => {
    const g = el.__pinballGame,
      b = g.balls[0];
    b.body.setTranslation({ x: 0, y: 0.15, z: 1.0 }, true);
    b.body.setLinvel({ x: 0, y: 0, z: 0 }, true);
    b.body.setBodyType(2, true);
  });
  const hits = (await state(page)).hits;
  await page.waitForTimeout(700);
  expect((await state(page)).hits).toBe(hits);
  expect(errors).toEqual([]);
});

test("flippers strike upwards, central drain is physically open, three drains end a round", async ({
  page,
}) => {
  await openPinball(page);
  await page.keyboard.press("Space");
  await page.locator(".pinballMount").evaluate((el) => {
    const g = el.__pinballGame,
      b = g.balls[0];
    b.body.setTranslation({ x: -0.55, y: 0.15, z: 2.8 }, true);
    b.body.setLinvel({ x: 0, y: 0, z: 3 }, true);
  });
  await page.keyboard.down("a");
  await page.waitForTimeout(150);
  expect((await state(page)).liveBalls[0].velocity.z).toBeLessThan(-3);
  await page.keyboard.up("a");
  for (let remaining = 2; remaining >= 0; remaining--) {
    if (remaining < 2) {
      await expect(page.locator(".neonPinball")).toHaveAttribute(
        "data-status",
        "ready",
        { timeout: 4000 },
      );
      await page.keyboard.press("Space");
    }
    await page.locator(".pinballMount").evaluate((el) => {
      const g = el.__pinballGame,
        b = g.balls[0];
      g.saveUntil = 0;
      b.body.setTranslation({ x: 0, y: 0.15, z: 2.75 }, true);
      b.body.setLinvel({ x: 0, y: 0, z: 2.8 }, true);
      window.drainPath = [];
      const step = g.step.bind(g);
      g.step = () => {
        step();
        if (g.balls.includes(b))
          window.drainPath.push({
            ...b.body.translation(),
            falling: b.falling,
          });
      };
    });
    await expect
      .poll(async () =>
        page.locator(".pinballMount").evaluate((el) => el.__pinballGame.ball),
      )
      .toBe(remaining);
    const path = await page.evaluate(() => window.drainPath);
    expect(path.some((p) => p.z > 3.65)).toBe(true);
    expect(path.some((p) => p.falling && p.y < 0.12)).toBe(true);
  }
  await expect(page.locator(".neonPinball")).toHaveAttribute(
    "data-status",
    "gameover",
  );
  await page.getByRole("button", { name: "Neue Runde", exact: true }).click();
  expect((await state(page)).liveBalls).toHaveLength(1);
});

test("mobile touch: charge/release and both flippers, framed nonblank 3D scene", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await openPinball(page);
  const stage = page.locator(".pinballStage");
  await stage.scrollIntoViewIfNeeded();
  const box = await stage.boundingBox();
  expect(box.width).toBeLessThan(390);
  const cdp = await page.context().newCDPSession(page);
  async function press(name) {
    const button = page.getByRole("button", { name, exact: true });
    await button.scrollIntoViewIfNeeded();
    const b = await button.boundingBox();
    await cdp.send("Input.dispatchTouchEvent", {
      type: "touchStart",
      touchPoints: [{ x: b.x + b.width / 2, y: b.y + b.height / 2, id: 0 }],
    });
  }
  async function release() {
    await cdp.send("Input.dispatchTouchEvent", {
      type: "touchEnd",
      touchPoints: [],
    });
  }
  await press("Plunger");
  await page.waitForTimeout(500);
  expect(
    await page
      .locator(".pinballMount")
      .evaluate((el) => el.__pinballGame.plunger),
  ).toBeGreaterThan(0.1);
  await release();
  await expect
    .poll(async () => (await state(page)).liveBalls.some((b) => b.entered), {
      timeout: 8000,
    })
    .toBe(true);
  await press("Linker Flipper");
  await page.waitForTimeout(120);
  expect(
    await page
      .locator(".pinballMount")
      .evaluate((el) => el.__pinballGame.keys.left),
  ).toBe(true);
  await release();
  await press("Rechter Flipper");
  await page.waitForTimeout(120);
  expect(
    await page
      .locator(".pinballMount")
      .evaluate((el) => el.__pinballGame.keys.right),
  ).toBe(true);
  await release();
  const pixels = await page.locator(".pinballMount").evaluate((el) => {
    const g = el.__pinballGame,
      gl = g.renderer.getContext(),
      w = g.renderer.domElement.width,
      h = g.renderer.domElement.height,
      data = new Uint8Array(w * h * 4);
    gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, data);
    let bright = 0;
    for (let i = 0; i < data.length; i += 4)
      if (data[i] + data[i + 1] + data[i + 2] > 150) bright++;
    return bright / (w * h);
  });
  expect(pixels).toBeGreaterThan(0.035);
  await stage.scrollIntoViewIfNeeded();
  await page.screenshot({ path: join(tmpdir(), "pinball-mobile.png") });
});
