import AxeBuilder from '@axe-core/playwright'
import { expect, test, type Page } from '@playwright/test'

// Funciones diferenciadoras: horas de vida, suscripciones fantasma y «disponible hoy».
// Fechas relativas a hoy y datos únicos por ejecución: nada fijo en el código.
const run = Date.now()
const creds = { email: `ins-${run}@example.com`, password: `Clave-${run}-i` }

const isoDay = (offsetDays: number, monthsBack = 0) => {
  const d = new Date()
  d.setMonth(d.getMonth() - monthsBack)
  d.setDate(d.getDate() + offsetDays)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

test.describe.configure({ mode: 'serial' })

async function seed(page: Page) {
  await page.request.post('/api/v1/auth/register', {
    data: { ...creds, full_name: 'Persona Insights' },
  })
  const tokens = await (await page.request.post('/api/v1/auth/login', { data: creds })).json()
  const headers = { Authorization: `Bearer ${tokens.access_token}` }
  const post = async (path: string, data: unknown) =>
    (await page.request.post(`/api/v1${path}`, { data, headers })).json()
  const account = await post('/accounts', {
    name: 'Principal',
    type: 'bank',
    currency: 'EUR',
    initial_balance: '0',
  })
  const fun = await post('/categories', { name: 'Ocio', kind: 'expense' })
  const pay = await post('/categories', { name: 'Nómina', kind: 'income' })
  const first = isoDay(0).slice(0, 8) + '01'
  await post('/transactions', {
    type: 'income',
    account_id: account.id,
    category_id: pay.id,
    amount: '2000',
    occurred_on: first,
    description: 'Nómina',
  })
  await post('/budgets', { category_id: fun.id, month: first, amount: '900' })
  for (let i = 3; i >= 0; i--) {
    await post('/transactions', {
      type: 'expense',
      account_id: account.id,
      category_id: fun.id,
      amount: i === 0 ? '12.99' : '10.99',
      occurred_on: isoDay(0, i).slice(0, 8) + '05',
      description: 'Plataforma de video',
    })
  }
  await page.addInitScript((t) => {
    localStorage.setItem('access_token', t.access_token)
    localStorage.setItem('refresh_token', t.refresh_token)
  }, tokens)
}

test('resumen: disponible hoy, valor de la hora y aviso de suscripciones', async ({ page }) => {
  await seed(page)
  await page.goto('/')
  const hoy = page.getByRole('region', { name: 'Disponible hoy' })
  await expect(hoy).toBeVisible()
  await expect(hoy).toContainText('Según tu presupuesto del mes')

  await expect(page.getByText('Hay 1 cobro recurrente que no registraste')).toBeVisible()
  await page.getByRole('link', { name: 'Revisar' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Suscripciones' })).toBeVisible()
  await expect(page.getByRole('list', { name: 'Cobros sin registrar' })).toContainText(
    'Plataforma de video',
  )
  await expect(page.getByRole('list', { name: 'Alertas' })).toContainText(/subió de/)

  // Configurar el valor de la hora y verlo reflejado en los gastos
  await page.goto('/')
  await page.getByRole('button', { name: 'Configurar' }).click()
  await page.getByLabel('Ingreso neto mensual').fill('2000')
  await expect(page.getByText(/Tu hora vale ≈/)).toBeVisible()
  await page.getByRole('button', { name: 'Guardar' }).click()
  await expect(
    page.getByRole('status').filter({ hasText: 'Valor de tu hora guardado' }),
  ).toBeVisible()
  await expect(page.getByText(/de trabajo se fueron en gastos este mes/)).toBeVisible()
  await page.goto('/transactions')
  await expect(page.getByText(/de trabajo/).first()).toBeVisible()
})

test('selector de moneda: menú de cristal con teclado', async ({ page }) => {
  await seed(page)
  await page.goto('/accounts')
  const moneda = page.getByLabel('Moneda')
  await moneda.focus()
  await page.keyboard.press('Enter')
  const menu = page.getByRole('listbox', { name: 'Moneda' })
  await expect(menu).toBeVisible()
  await page.keyboard.press('ArrowDown')
  await page.keyboard.press('ArrowDown')
  await page.keyboard.press('Enter')
  await expect(menu).toBeHidden()
  await expect(moneda).toHaveValue('EUR')

  await moneda.click() // con el ratón también se abre
  await expect(menu).toBeVisible()
  await page.keyboard.press('Escape')
  await expect(menu).toBeHidden()
})

test('login: mantener sesión decide dónde se guardan los tokens', async ({ page, request }) => {
  const c = { email: `rem-${run}@example.com`, password: `Clave-${run}-r` }
  await request.post('/api/v1/auth/register', { data: { ...c, full_name: 'Persona Sesión' } })
  const attempt = async (remember: boolean) => {
    await page.goto('/login')
    await page.evaluate(() => {
      localStorage.clear()
      sessionStorage.clear()
    })
    await page.getByLabel('Correo').fill(c.email)
    await page.getByLabel('Contraseña', { exact: true }).fill(c.password)
    const box = page.getByLabel('Mantener sesión iniciada')
    if ((await box.isChecked()) !== remember) await box.setChecked(remember, { force: true })
    await page.getByRole('button', { name: 'Entrar' }).click()
    await expect(page.getByRole('heading', { level: 1, name: 'Resumen' })).toBeVisible()
    return page.evaluate(() => ({
      local: !!localStorage.getItem('access_token'),
      session: !!sessionStorage.getItem('access_token'),
    }))
  }
  expect(await attempt(true)).toEqual({ local: true, session: false })
  await page.getByRole('button', { name: 'Salir' }).click()
  expect(await attempt(false)).toEqual({ local: false, session: true })
})

test('login: mostrar contraseña y accesibilidad', async ({ page }) => {
  await page.goto('/login')
  const password = page.getByLabel('Contraseña', { exact: true })
  await password.fill('secreto-de-prueba')
  await expect(password).toHaveAttribute('type', 'password')
  await page.getByRole('button', { name: 'Mostrar contraseña' }).click()
  await expect(password).toHaveAttribute('type', 'text')
  await page.getByRole('button', { name: 'Ocultar contraseña' }).click()
  await expect(password).toHaveAttribute('type', 'password')

  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
    .analyze()
  expect(results.violations.map((v) => `${v.id}: ${v.nodes.length}`)).toEqual([])
})
