import { expect, test, type Page } from '@playwright/test'
import { readFileSync } from 'node:fs'

const run = Date.now()
const creds = {
  email: `feat-${run}@example.com`,
  password: `Clave-${run}-a`,
  name: 'Persona Funciones',
}

async function register(page: Page) {
  await page.goto('/register')
  await page.getByLabel('Nombre').fill(creds.name)
  await page.getByLabel('Correo').fill(creds.email)
  await page.getByLabel('Contraseña', { exact: true }).fill(creds.password)
  await page.getByRole('button', { name: 'Crear cuenta' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Resumen' })).toBeVisible()
}

async function login(page: Page, password = creds.password) {
  await page.goto('/login')
  await page.getByLabel('Correo').fill(creds.email)
  await page.getByLabel('Contraseña', { exact: true }).fill(password)
  await page.getByRole('button', { name: 'Entrar' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Resumen' })).toBeVisible()
}

async function open(page: Page, path: string, heading: string) {
  await page.goto(path)
  await expect(page.getByRole('heading', { level: 1, name: heading })).toBeVisible()
}

test.describe.configure({ mode: 'serial' })

test('metas: crear, aportar, retirar de más, lograr y eliminar', async ({ page }) => {
  await register(page)
  // usuario nuevo: la guía de primeros pasos aparece con los 3 pasos pendientes
  const steps = page.getByRole('list', { name: 'Primeros pasos' })
  await expect(steps.getByRole('link')).toHaveCount(3)
  await expect(steps.getByText('(pendiente)')).toHaveCount(3)
  await open(page, '/goals', 'Metas')
  await page.getByLabel('Nombre').fill('Viaje')
  await page.getByLabel('Monto objetivo').fill('1000')
  await page.getByLabel('Moneda').fill('cop')
  await page.getByRole('button', { name: 'Crear meta' }).click()
  await expect(page.getByRole('status').filter({ hasText: 'Meta creada' })).toBeVisible()
  const card = page.getByRole('listitem').filter({ hasText: 'Viaje' })
  await expect(card.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '0')

  await card.getByRole('button', { name: 'Aportar' }).click()
  await page.getByRole('dialog').getByLabel('Monto').fill('250')
  await page.getByRole('dialog').getByRole('button', { name: 'Aportar' }).click()
  await expect(card.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '25')

  // retirar más de lo ahorrado: el servidor lo rechaza y el diálogo lo explica
  await card.getByRole('button', { name: 'Retirar' }).click()
  await page.getByRole('dialog').getByLabel('Monto').fill('999')
  await page.getByRole('dialog').getByRole('button', { name: 'Retirar' }).click()
  await expect(page.getByRole('dialog').getByRole('alert')).toContainText('No puedes retirar más')
  await page.keyboard.press('Escape')

  await card.getByRole('button', { name: 'Aportar' }).click()
  await page.getByRole('dialog').getByLabel('Monto').fill('750')
  await page.getByRole('dialog').getByRole('button', { name: 'Aportar' }).click()
  await expect(card.getByText('Lograda')).toBeVisible()
  await expect(card.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '100')

  await card.getByRole('button', { name: 'Eliminar' }).click()
  await page.getByRole('alertdialog').getByRole('button', { name: 'Eliminar' }).click()
  await expect(page.getByText(/Aún no tienes metas/)).toBeVisible()
})

test('cuentas: renombrar, no eliminar con movimientos, eliminar vacía y exportar CSV', async ({
  page,
}) => {
  await login(page)
  await open(page, '/accounts', 'Cuentas')
  for (const name of ['Principal', 'Vacía']) {
    await page.getByLabel('Nombre').fill(name)
    await page.getByLabel('Moneda').fill('cop')
    await page.getByRole('button', { name: 'Crear cuenta' }).click()
    await expect(page.getByRole('listitem').filter({ hasText: name })).toBeVisible()
  }
  // renombrar
  await page.getByRole('button', { name: 'Renombrar Principal' }).click()
  await page.getByRole('dialog').getByLabel('Nombre').fill('Nómina')
  await page.getByRole('dialog').getByRole('button', { name: 'Guardar' }).click()
  await expect(page.getByRole('listitem').filter({ hasText: 'Nómina' })).toBeVisible()

  // un movimiento impide eliminar la cuenta
  await open(page, '/transactions', 'Movimientos')
  await page.getByRole('button', { name: 'Nueva', exact: true }).click()
  const form = page.locator('section', { hasText: 'Nueva transacción' })
  await form.getByLabel('Cuenta', { exact: true }).selectOption({ label: 'Nómina (COP)' })
  await form.getByLabel('Monto').fill('1234.5')
  await form.getByLabel('Descripción').fill('=SUMA(1+1)')
  await form.getByRole('button', { name: 'Guardar' }).click()
  await expect(form).toBeHidden()

  // exportar CSV: descarga real, con BOM y sin inyección de fórmulas
  const [download] = await Promise.all([
    page.waitForEvent('download'),
    page.getByRole('button', { name: 'Exportar CSV' }).click(),
  ])
  expect(download.suggestedFilename()).toBe('movimientos.csv')
  const text = readFileSync((await download.path())!, 'utf8')
  expect(text.startsWith('﻿')).toBe(true)
  expect(text).toContain('fecha,tipo,cuenta')
  expect(text).toContain("'=SUMA(1+1)")
  expect(text).toContain('1234.50')

  await open(page, '/accounts', 'Cuentas')
  await page.getByRole('button', { name: 'Eliminar Nómina' }).click()
  await page.getByRole('alertdialog').getByRole('button', { name: 'Eliminar' }).click()
  await expect(page.getByRole('alert')).toContainText('archívala')
  await page.getByRole('button', { name: 'Eliminar Vacía' }).click()
  await page.getByRole('alertdialog').getByRole('button', { name: 'Eliminar' }).click()
  await expect(page.getByRole('listitem').filter({ hasText: 'Vacía' })).toHaveCount(0)
})

test('perfil: cambiar nombre y contraseña, y entrar con la nueva', async ({ page }) => {
  await login(page)
  await open(page, '/profile', 'Perfil')
  await expect(page.getByLabel('Nombre')).toHaveValue(creds.name) // carga con recarga directa
  await page.getByLabel('Nombre').fill('Nombre Nuevo')
  await page.getByRole('button', { name: 'Guardar' }).click()
  await expect(page.getByRole('status').filter({ hasText: 'Perfil actualizado' })).toBeVisible()

  await page.getByLabel('Contraseña actual').fill('incorrecta-9')
  await page.getByLabel('Contraseña nueva').fill('NuevaClave-2026')
  await page.getByRole('button', { name: 'Cambiar contraseña' }).click()
  await expect(page.getByRole('alert')).toContainText('actual es incorrecta')
  await page.getByLabel('Contraseña actual').fill(creds.password)
  await page.getByRole('button', { name: 'Cambiar contraseña' }).click()
  await expect(page.getByRole('status').filter({ hasText: 'Contraseña cambiada' })).toBeVisible()
  // la sesión actual sigue activa (tokens nuevos): una recarga no la pierde
  await page.reload()
  await expect(page.getByRole('heading', { level: 1, name: 'Perfil' })).toBeVisible()

  await page.getByRole('button', { name: 'Cerrar sesión', exact: true }).click()
  await expect(page).toHaveURL(/\/login$/)
  await page.getByLabel('Correo').fill(creds.email)
  await page.getByLabel('Contraseña', { exact: true }).fill(creds.password)
  await page.getByRole('button', { name: 'Entrar' }).click()
  await expect(page.getByRole('alert')).toContainText('Credenciales incorrectas')
  await page.getByLabel('Contraseña', { exact: true }).fill('NuevaClave-2026')
  await page.getByRole('button', { name: 'Entrar' }).click()
  await expect(page.getByText('Nombre Nuevo')).toBeVisible()
})

test('login: tras demasiados intentos fallidos se bloquea con un mensaje claro', async ({
  page,
}) => {
  await page.goto('/login')
  for (let i = 0; i < 5; i++) {
    await page.getByLabel('Correo').fill(`bloqueo-${run}@example.com`)
    await page.getByLabel('Contraseña', { exact: true }).fill('incorrecta-1')
    await page.getByRole('button', { name: 'Entrar' }).click()
    await expect(page.getByRole('alert')).toContainText('Credenciales incorrectas')
  }
  await page.getByRole('button', { name: 'Entrar' }).click()
  await expect(page.getByRole('alert')).toContainText('Demasiados intentos fallidos')
})

test.describe('móvil', () => {
  test.use({ viewport: { width: 390, height: 844 } })

  test('"Más" da acceso a presupuestos, categorías y perfil', async ({ page }) => {
    await login(page, 'NuevaClave-2026')
    await expect(page.locator('.cr-bottom')).toBeVisible()
    await page.locator('.cr-bottom').getByRole('link', { name: 'Más' }).click()
    await expect(page.getByRole('heading', { level: 1, name: 'Más' })).toBeVisible()
    for (const [link, heading] of [
      ['Presupuestos', 'Presupuestos'],
      ['Categorías', 'Categorías'],
      ['Perfil y ajustes', 'Perfil'],
    ]) {
      await page.getByRole('link', { name: link }).click()
      await expect(page.getByRole('heading', { level: 1, name: heading })).toBeVisible()
      await page.locator('.cr-bottom').getByRole('link', { name: 'Más' }).click()
    }
  })
})

test('recurrentes: los vencidos se registran solos al abrir la app', async ({ page, request }) => {
  const run2 = Date.now()
  const c = { email: `rec-${run2}@example.com`, password: `Clave-${run2}-r` }
  await request.post('/api/v1/auth/register', { data: { ...c, full_name: 'Persona Recurrente' } })
  const tokens = await (await request.post('/api/v1/auth/login', { data: c })).json()
  const headers = { Authorization: `Bearer ${tokens.access_token}` }
  const post = async (path: string, data: unknown) =>
    (await request.post(`/api/v1${path}`, { data, headers })).json()
  const acc = await post('/accounts', {
    name: 'Principal',
    type: 'bank',
    currency: 'COP',
    initial_balance: '0',
  })
  const cat = await post('/categories', { name: 'Arriendo', kind: 'expense' })
  // primera fecha hace ~2 meses y medio → 3 ocurrencias vencidas
  const start = new Date()
  start.setMonth(start.getMonth() - 2)
  start.setDate(1)
  const iso = `${start.getFullYear()}-${String(start.getMonth() + 1).padStart(2, '0')}-01`
  await post('/recurring', {
    type: 'expense',
    account_id: acc.id,
    category_id: cat.id,
    amount: '800000',
    description: 'Arriendo',
    frequency: 'monthly',
    start_date: iso,
  })

  await page.addInitScript((t) => {
    localStorage.setItem('access_token', t.access_token)
    localStorage.setItem('refresh_token', t.refresh_token)
  }, tokens)
  await page.goto('/')
  await expect(
    page.getByRole('status').filter({ hasText: /Se registraron 3 movimientos recurrentes/ }),
  ).toBeVisible()
  await expect(page.getByText('Próximos recurrentes')).toBeVisible()

  await open(page, '/transactions', 'Movimientos')
  await expect(page.getByText('3 resultados')).toBeVisible()
  await open(page, '/accounts', 'Cuentas')
  await expect(page.getByRole('listitem').filter({ hasText: 'Principal' })).toContainText(
    /2\D?400\D?000/,
  )

  // volver a abrir la app no duplica (idempotente)
  await page.reload()
  await open(page, '/transactions', 'Movimientos')
  await expect(page.getByText('3 resultados')).toBeVisible()

  // gestionar: pausar y eliminar desde la pantalla
  await open(page, '/recurring', 'Recurrentes')
  await page.getByRole('button', { name: 'Pausar Arriendo' }).click()
  await expect(page.getByText(/pausado/).first()).toBeVisible()
  await page.getByRole('button', { name: 'Eliminar' }).click()
  await page.getByRole('alertdialog').getByRole('button', { name: 'Eliminar' }).click()
  await expect(page.getByText(/Aún no tienes movimientos recurrentes/)).toBeVisible()
})

test('resumen por moneda: el selector separa cuentas, la dona y la tasa de ahorro', async ({
  page,
  request,
}) => {
  const stamp = Date.now()
  const c = { email: `mon-${stamp}@example.com`, password: `Clave-${stamp}-m` }
  await request.post('/api/v1/auth/register', { data: { ...c, full_name: 'Persona Monedas' } })
  const tokens = await (await request.post('/api/v1/auth/login', { data: c })).json()
  const headers = { Authorization: `Bearer ${tokens.access_token}` }
  const post = async (path: string, data: unknown) =>
    (await request.post(`/api/v1${path}`, { data, headers })).json()
  const cop = await post('/accounts', {
    name: 'Pesos',
    type: 'bank',
    currency: 'COP',
    initial_balance: '1000000',
  })
  const usd = await post('/accounts', {
    name: 'Dólares',
    type: 'bank',
    currency: 'USD',
    initial_balance: '250',
  })
  const food = await post('/categories', { name: 'Comida', kind: 'expense' })
  const fun = await post('/categories', { name: 'Ocio', kind: 'expense' })
  const pay = await post('/categories', { name: 'Sueldo', kind: 'income' })
  const today = new Date().toISOString().slice(0, 10)
  await post('/transactions', {
    type: 'income',
    account_id: cop.id,
    category_id: pay.id,
    amount: '2000000',
    occurred_on: today,
  })
  await post('/transactions', {
    type: 'expense',
    account_id: cop.id,
    category_id: food.id,
    amount: '300000',
    occurred_on: today,
  })
  await post('/transactions', {
    type: 'expense',
    account_id: cop.id,
    category_id: fun.id,
    amount: '100000',
    occurred_on: today,
  })
  await post('/transactions', {
    type: 'income',
    account_id: usd.id,
    category_id: pay.id,
    amount: '40',
    occurred_on: today,
  })
  await page.addInitScript((t) => {
    localStorage.setItem('access_token', t.access_token)
    localStorage.setItem('refresh_token', t.refresh_token)
  }, tokens)

  await page.goto('/')
  // por defecto, la moneda de la primera cuenta: no se mezclan los 40 USD con los pesos
  const group = page.getByRole('group', { name: 'Moneda' })
  await expect(group).toBeVisible()
  await expect(group.getByRole('button', { name: 'COP' })).toHaveAttribute('aria-pressed', 'true')
  await expect(page.getByText('Ahorraste el 80 % de tus ingresos')).toBeVisible()
  await expect(
    page.getByRole('img', { name: /Distribución del gasto: Comida 75 %, Ocio 25 %/ }),
  ).toBeVisible()
  // sin guía de primeros pasos: ya hay cuentas, categorías y movimientos
  await expect(page.getByRole('list', { name: 'Primeros pasos' })).toHaveCount(0)

  await group.getByRole('button', { name: 'USD' }).click()
  await expect(group.getByRole('button', { name: 'USD' })).toHaveAttribute('aria-pressed', 'true')
  await expect(page.getByText('Sin gastos este mes.')).toBeVisible()
  await expect(page.getByText(/US\$\s*290/)).toBeVisible() // 250 + 40, solo cuentas en USD
})
