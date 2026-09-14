import { expect, test } from "@playwright/test";

test("first-run setup can be skipped", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("dialog", { name: /your ai workspace/i })).toBeVisible();
  await page.getByRole("button", { name: /skip setup/i }).click();
  await expect(page.getByRole("heading", { name: /what.s on your mind/i })).toBeVisible();
});

test("major workspaces are reachable", async ({ page }) => {
  await page.goto("/");
  const skip = page.getByRole("button", { name: /skip setup/i });
  await skip.waitFor({ state: "visible" });
  await skip.click();
  if (page.viewportSize()!.width < 700) await page.getByRole("button", { name: /open navigation/i }).click();
  await page.getByRole("link", { name: "Knowledge" }).click();
  await expect(page.getByRole("heading", { name: "Knowledge" })).toBeVisible();
  if (page.viewportSize()!.width < 700) await page.getByRole("button", { name: /open navigation/i }).click();
  await page.getByRole("link", { name: "Models" }).click();
  await expect(page.getByRole("heading", { name: "Models", exact: true })).toBeVisible();
});
