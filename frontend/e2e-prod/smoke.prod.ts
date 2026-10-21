import { expect, test } from '@playwright/test'

const run = Date.now()
const creds = {
  email: `e2e-prod-${run}@example.com`,
  password: `pw-${run}-smoke`,
  name: 'Humo Prod',
}

test('HTTPS, cabeceras de seguridad y SPA', async ({ page, request, baseURL }) => {
  expect(baseURL).toMatch(/^https:/)
  const res = await request.get('/')
  expect(res.status()).toBe(200)
  const h = res.headers()
  expect(h['x-content-type-options']).toBe('nosniff')
  expect(h['x-frame-options']).toBe('DENY')
  expect(h['content-security-policy']).toContain("default-src 'self'")
  // una ruta del frontend sin archivo sirve la SPA (no 404)
  expect((await request.get('/accounts')).status()).toBe(200)
  // la API responde por el mismo origen y con el formato de errores propio
  const api = await request.get('/api/v1/auth/me')
  expect(api.status()).toBe(401)
  expect((await api.json()).error.code).toBe('unauthorized')
  // la consola no debe tener errores (CSP bloqueando fuentes/estilos, etc.)
  const problems: string[] = []
  page.on('console', (m) => m.type() === 'error' && problems.push(m.text()))
  page.on('pageerror', (e) => problems.push(e.message))
  await page.goto('/login')
  await expect(page.getByRole('heading', { name: 'Iniciar sesión' })).toBeVisible()
  expect(problems).toEqual([])
})

test('registro, cuenta, movimiento y cierre de sesión contra la BD real', async ({ page }) => {
  await page.goto('/register')
  await page.getByLabel('Nombre').fill(creds.name)
  await page.getByLabel('Correo').fill(creds.email)
  await page.getByLabel('Contraseña', { exact: true }).fill(creds.password)
  await page.getByRole('button', { name: 'Crear cuenta' }).click()
  await expect(page.getByText(creds.name)).toBeVisible()

  await page.getByRole('link', { name: 'Cuentas' }).filter({ visible: true }).first().click()
  await page.getByLabel('Nombre').fill('Cuenta humo')
  await page.getByLabel('Moneda').fill('cop')
  await page.getByLabel('Saldo inicial').fill('1000')
  await page.getByRole('button', { name: 'Crear cuenta' }).click()
  await expect(page.getByRole('listitem').filter({ hasText: 'Cuenta humo' })).toBeVisible()

  await page.reload() // los datos vienen de Postgres, no del estado del navegador
  await expect(page.getByRole('listitem').filter({ hasText: 'Cuenta humo' })).toContainText(
    /1\D?000/,
  )

  await page.getByRole('button', { name: 'Salir' }).click()
  await expect(page).toHaveURL(/\/login$/)
})
