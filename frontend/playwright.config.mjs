import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  timeout: 60000,
  fullyParallel: false,
  workers: 1,
  use: { baseURL: "http://127.0.0.1:4186", headless: true, channel: "msedge", viewport: { width: 1440, height: 1000 } },
  webServer: { command: "npm run preview -- --host 127.0.0.1 --port 4186 --strictPort", url: "http://127.0.0.1:4186", reuseExistingServer: true },
});
