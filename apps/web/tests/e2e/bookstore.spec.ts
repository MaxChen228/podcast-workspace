import { test, expect } from "@playwright/test";

test.describe("bookstore flow", () => {
  test("loads shell", async ({ page }) => {
    await page.goto("/");
    await expect(page.getByRole("heading", { name: "Storytelling Web" })).toBeVisible();
  });
});
