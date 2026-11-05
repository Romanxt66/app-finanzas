import { expect, type Page } from '@playwright/test'

/** Las altas se pliegan tras un botón cuando ya hay datos: si está plegada, la abre. */
export async function reveal(page: Page, title: string) {
  await page.waitForLoadState('networkidle')
  const button = page.getByRole('button', { name: title, exact: true })
  const card = page.getByRole('heading', { name: title, exact: true })
  await expect(button.or(card).first()).toBeVisible()
  if (await button.isVisible()) await button.click()
  await expect(card).toBeVisible()
}
