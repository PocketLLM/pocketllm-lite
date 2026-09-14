import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/e2e",
  timeout: 30000,
  fullyParallel: false,
  retries: 1,
  use: { baseURL: "http://127.0.0.1:4173/app/", trace: "retain-on-failure" },
  webServer: {
    command: "npm run build && npm run preview -- --host 127.0.0.1 --port 4173",
    url: "http://127.0.0.1:4173/app/",
    reuseExistingServer: !process.env.CI,
    timeout: 120000
  },
  projects: [
    { name: "chromium-desktop", use: { ...devices["Desktop Chrome"] } },
    { name: "chromium-mobile", use: { ...devices["Pixel 7"] } },
    { name: "firefox-desktop", use: { ...devices["Desktop Firefox"] } },
    { name: "webkit-desktop", use: { ...devices["Desktop Safari"] } }
  ]
});
