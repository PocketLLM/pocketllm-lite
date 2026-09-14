import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

async function dismissSetup(page: import("@playwright/test").Page) {
  const skip = page.getByRole("button", { name: /skip setup/i });
  await skip.waitFor({ state: "visible" });
  await skip.click();
  await expect(page.getByRole("heading", { name: /what.s on your mind/i })).toBeVisible();
}

test("app shell has no serious or critical axe violations", async ({ page }) => {
  await page.goto("/");
  await dismissSetup(page);
  const report = await new AxeBuilder({ page }).analyze();
  const severe = report.violations.filter((violation) => violation.impact === "serious" || violation.impact === "critical");
  expect(severe, severe.map((item) => `${item.id}: ${item.help}`).join("\n")).toEqual([]);
});

test("production preview is cross-origin isolated where supported", async ({ page, browserName }) => {
  test.skip(browserName !== "chromium", "Isolation assertion is release-gated on Chromium; other browsers remain capability-gated.");
  await page.goto("/");
  await expect.poll(() => page.evaluate(() => crossOriginIsolated)).toBe(true);
});

test("installed PWA shell survives an offline reload", async ({ page, context, browserName }) => {
  test.skip(browserName !== "chromium", "Offline PWA smoke runs once on Chromium.");
  await page.goto("/");
  await dismissSetup(page);
  await page.evaluate(async () => {
    if (!("serviceWorker" in navigator)) throw new Error("Service workers unavailable");
    await navigator.serviceWorker.ready;
  });
  await page.reload();
  await expect(page.getByRole("heading", { name: /what.s on your mind/i })).toBeVisible();
  await expect.poll(() => page.evaluate(() => Boolean(navigator.serviceWorker.controller))).toBe(true);
  await context.setOffline(true);
  await page.reload();
  await expect(page.getByRole("heading", { name: /what.s on your mind/i })).toBeVisible();
  await context.setOffline(false);
});
