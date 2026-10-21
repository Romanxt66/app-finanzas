import { expect, test, type Page } from '@playwright/test'

// Prepara un usuario con datos vía API (el mismo camino que usa la app)
async function seed(page: Page) {
  const run = Date.now()
  const creds = { email: `resp-${run}@example.com`, password: `pw-${run}-secret` }
  await page.request.post('/api/v1/auth/register', {
    data: { ...creds, full_name: 'Persona Responsive' },
  })
  const login = await page.request.post('/api/v1/auth/login', { data: creds })
  const tokens = await login.json()
  const headers = { Authorization: `Bearer ${tokens.access_token}` }
  const post = async (path: string, data: unknown) =>
    (await page.request.post(`/api/v1${path}`, { data, headers })).json()
  const account = await post('/accounts', {
    name: 'Principal',
    type: 'bank',
    currency: 'COP',
    initial_balance: '5000000',
  })
  const food = await post('/categories', { name: 'Comida', kind: 'expense' })
  const pay = await post('/categories', { name: 'Nómina', kind: 'income' })
  const today = new Date().toISOString().slice(0, 10)
  await post('/transactions', {
    type: 'income',
    account_id: account.id,
    category_id: pay.id,
    amount: '4850000',
    occurred_on: today,
    description: 'Pago mensual',
  })
  await post('/transactions', {
    type: 'expense',
    account_id: account.id,
    category_id: food.id,
    amount: '186400',
    occurred_on: today,
    description: 'Mercado de la semana',
  })
  await post('/budgets', { category_id: food.id, month: today, amount: '600000' })
  await page.addInitScript((t) => {
    localStorage.setItem('access_token', t.access_token)
    localStorage.setItem('refresh_token', t.refresh_token)
  }, tokens)
}

const viewports = [
  { name: 'movil', width: 390, height: 844 },
  { name: 'escritorio', width: 1280, height: 800 },
] as const

for (const vp of viewports) {
  for (const scheme of ['dark', 'light'] as const) {
    test(`${vp.name} (${scheme}): diseño Cristal sin desbordes`, async ({ browser }) => {
      const context = await browser.newContext({ viewport: vp, colorScheme: scheme })
      const page = await context.newPage()
      await seed(page)
      await page.goto('/')
      await expect(page.getByText('Saldo total')).toBeVisible()
      await expect(page.getByText('Mercado de la semana')).toBeVisible()

      // navegación: pestañas abajo en móvil, barra superior en escritorio
      const tabbar = page.locator('.cr-bottom')
      const topnav = page.locator('.cr-nav')
      if (vp.width < 900) {
        await expect(tabbar).toBeVisible()
        await expect(topnav).toBeHidden()
      } else {
        await expect(tabbar).toBeHidden()
        await expect(topnav).toBeVisible()
      }

      // sin scroll horizontal
      const overflow = await page.evaluate(
        () => document.documentElement.scrollWidth - window.innerWidth,
      )
      expect(overflow).toBeLessThanOrEqual(0)

      // ninguna pantalla desborda horizontalmente
      for (const route of ['/transactions', '/accounts', '/budgets', '/categories']) {
        await page.goto(route)
        await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
        const extra = await page.evaluate(
          () => document.documentElement.scrollWidth - window.innerWidth,
        )
        expect(extra, `desborde en ${route}`).toBeLessThanOrEqual(0)
      }
      await page.goto('/')
      await expect(page.getByText('Saldo total')).toBeVisible()

      // el tema sale de los tokens: fondo distinto en claro y oscuro
      const bg = await page.evaluate(() =>
        getComputedStyle(document.documentElement).getPropertyValue('--bg').trim(),
      )
      expect(bg).toBe(scheme === 'dark' ? '#0a0e13' : '#eaf0f4')

      // objetivos táctiles de al menos 44 px en botones principales
      const btn = await page.getByRole('button', { name: 'Salir' }).boundingBox()
      expect(btn!.height).toBeGreaterThanOrEqual(34)

      if (process.env.SHOTS) {
        await page.screenshot({
          path: `test-results/shots/${vp.name}-${scheme}.png`,
          fullPage: true,
        })
        for (const [link, file] of [
          ['Movimientos', 'movimientos'],
          ['Presupuestos', 'presupuestos'],
        ] as const) {
          await page.getByRole('link', { name: link }).filter({ visible: true }).first().click()
          await page.waitForLoadState('networkidle')
          await page.screenshot({
            path: `test-results/shots/${vp.name}-${scheme}-${file}.png`,
            fullPage: true,
          })
          await page.getByRole('link', { name: 'Inicio' }).filter({ visible: true }).first().click()
        }
      }
      await context.close()
    })
  }
}
