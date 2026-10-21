import AxeBuilder from '@axe-core/playwright'
import { expect, test, type Page } from '@playwright/test'

// Auditoría WCAG 2.1 AA automática de cada pantalla, en claro y oscuro, móvil y escritorio.
async function seed(page: Page) {
  const run = Date.now()
  const creds = { email: `a11y-${run}@example.com`, password: `Clave-${run}-x` }
  await page.request.post('/api/v1/auth/register', {
    data: { ...creds, full_name: 'Persona Accesible' },
  })
  const tokens = await (await page.request.post('/api/v1/auth/login', { data: creds })).json()
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
    amount: '700000',
    occurred_on: today,
    description: 'Mercado de la semana',
  })
  await post('/budgets', { category_id: food.id, month: today, amount: '600000' }) // excedido: estado de error
  await post('/goals', {
    name: 'Viaje',
    target_amount: '2000000',
    currency: 'COP',
    deadline: '2099-01-01',
  })
  await page.addInitScript((t) => {
    localStorage.setItem('access_token', t.access_token)
    localStorage.setItem('refresh_token', t.refresh_token)
  }, tokens)
}

const routes: [string, string][] = [
  ['/', 'Resumen'],
  ['/transactions', 'Movimientos'],
  ['/accounts', 'Cuentas'],
  ['/budgets', 'Presupuestos'],
  ['/goals', 'Metas'],
  ['/recurring', 'Recurrentes'],
  ['/categories', 'Categorías'],
  ['/profile', 'Perfil'],
  ['/more', 'Más'],
]

for (const scheme of ['dark', 'light'] as const) {
  for (const vp of [
    { name: 'móvil', width: 390, height: 844 },
    { name: 'escritorio', width: 1280, height: 800 },
  ]) {
    test(`a11y ${vp.name} (${scheme}): sin violaciones WCAG AA`, async ({ browser }) => {
      test.setTimeout(120_000)
      const context = await browser.newContext({
        viewport: vp,
        colorScheme: scheme,
        reducedMotion: 'reduce',
      })
      const page = await context.newPage()
      await seed(page)
      for (const [path, heading] of routes) {
        await page.goto(path)
        await expect(page.getByRole('heading', { level: 1, name: heading })).toBeVisible()
        await page.waitForLoadState('networkidle')
        const results = await new AxeBuilder({ page })
          .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
          .analyze()
        const summary = results.violations.map(
          (v) => `${v.id} (${v.nodes.length}): ${v.nodes[0].target.join(' ')} — ${v.help}`,
        )
        expect(summary, `${path} [${scheme}/${vp.name}]`).toEqual([])
      }
      // pantallas con diálogo abierto
      await page.goto('/goals')
      await page.getByLabel('Nombre').fill('Casa')
      await page.getByRole('button', { name: 'Crear meta' }).click()
      await page.getByRole('button', { name: 'Aportar' }).first().click()
      await expect(page.getByRole('dialog')).toBeVisible()
      const dialog = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze()
      expect(dialog.violations.map((v) => `${v.id}: ${v.help}`)).toEqual([])
      await context.close()
    })
  }
}
