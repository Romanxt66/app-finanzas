import { expect, test, type Page } from '@playwright/test'

// Datos generados por ejecución: nada fijo en el código ni en la BD
const run = Date.now()
const creds = { email: `e2e-${run}@example.com`, password: `pw-${run}-secret`, name: 'Persona E2E' }

async function signUp(page: Page) {
  await page.goto('/register')
  await page.getByLabel('Nombre').fill(creds.name)
  await page.getByLabel('Correo').fill(creds.email)
  await page.getByLabel('Contraseña', { exact: true }).fill(creds.password)
  await page.getByRole('button', { name: 'Crear cuenta' }).click()
  await expect(page.getByText(creds.name)).toBeVisible()
}

/** Navega por el menú y espera al título de la página (evita escribir en la vista anterior). */
async function goTo(page: Page, name: string, heading = name) {
  await page.getByRole('link', { name }).click()
  await expect(page.getByRole('heading', { level: 1, name: heading })).toBeVisible()
}

test.describe.configure({ mode: 'serial' })

test('rutas protegidas redirigen a login', async ({ page }) => {
  await page.goto('/accounts')
  await expect(page).toHaveURL(/\/login$/)
})

test('registro: cada contraseña inválida explica el motivo', async ({ page }) => {
  await page.goto('/register')
  await page.getByLabel('Nombre').fill('Persona')
  await page.getByLabel('Correo').fill(`debil-${run}@example.com`)
  const cases: [string, RegExp][] = [
    ['corta1', /al menos 8 caracteres/],
    ['soloLetrasAqui', /al menos un número/],
    ['1234567890', /al menos una letra/],
  ]
  for (const [password, reason] of cases) {
    await page.getByLabel('Contraseña', { exact: true }).fill(password)
    await page.getByRole('button', { name: 'Crear cuenta' }).click()
    await expect(page.getByText(reason).first()).toBeVisible()
  }
  await expect(page).toHaveURL(/\/register$/)
})

test('si el servidor no responde, la app lo dice (no "Error inesperado")', async ({ page }) => {
  await page.route('**/api/v1/auth/login', (route) => route.abort('connectionrefused'))
  await page.goto('/login')
  await page.getByLabel('Correo').fill('a@example.com')
  await page.getByLabel('Contraseña', { exact: true }).fill('clave-segura-1')
  await page.getByRole('button', { name: 'Entrar' }).click()
  await expect(page.getByRole('alert')).toContainText('No se pudo conectar con el servidor')
})

test('login con credenciales incorrectas muestra error', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('Correo').fill('nadie@example.com')
  await page.getByLabel('Contraseña', { exact: true }).fill('incorrecta1')
  await page.getByRole('button', { name: 'Entrar' }).click()
  await expect(page.getByRole('alert')).toHaveText('Credenciales incorrectas')
})

test('flujo completo: registro, cuentas, categorías, transacciones, presupuesto y resumen', async ({
  page,
}) => {
  await signUp(page)
  await expect(page).toHaveURL('/')

  // Cuentas
  await goTo(page, 'Cuentas')
  await page.getByLabel('Nombre').fill('Cuenta principal')
  await page.getByLabel('Moneda').selectOption('EUR')
  await page.getByLabel('Saldo inicial').fill('1000')
  await page.getByRole('button', { name: 'Crear cuenta' }).click()
  await expect(page.getByRole('status').filter({ hasText: 'Cuenta creada' })).toBeVisible()
  await expect(page.getByRole('listitem').filter({ hasText: 'Cuenta principal' })).toContainText(
    /1\D?000\D00/,
  )
  await page.getByLabel('Nombre').fill('Ahorro')
  await page.getByLabel('Tipo').selectOption('savings')
  await page.getByLabel('Moneda').selectOption('EUR')
  await page.getByRole('button', { name: 'Crear cuenta' }).click()
  await expect(page.getByRole('listitem').filter({ hasText: 'Ahorro' })).toBeVisible()

  // Categorías
  await goTo(page, 'Categorías')
  await page.getByLabel('Nombre').fill('Supermercado')
  await page.getByRole('button', { name: 'Añadir' }).click()
  await expect(page.getByRole('listitem').filter({ hasText: 'Supermercado' })).toBeVisible()
  await page.getByLabel('Nombre').fill('Nómina')
  await page.getByLabel('Tipo').selectOption('income')
  await page.getByRole('button', { name: 'Añadir' }).click()
  await expect(page.getByRole('listitem').filter({ hasText: 'Nómina' })).toBeVisible()

  // Transacciones: gasto, ingreso y transferencia
  await goTo(page, 'Movimientos')
  const addTx = async (fill: (form: ReturnType<Page['locator']>) => Promise<void>) => {
    await page.getByRole('button', { name: 'Nueva', exact: true }).click()
    const form = page.locator('section', { hasText: 'Nueva transacción' })
    await fill(form)
    await form.getByRole('button', { name: 'Guardar' }).click()
    await expect(form).toBeHidden()
  }
  await addTx(async (f) => {
    await f.getByLabel('Cuenta', { exact: true }).selectOption({ label: 'Cuenta principal (EUR)' })
    await f.getByLabel('Categoría').selectOption({ label: 'Supermercado' })
    await f.getByLabel('Monto').fill('200.50')
    await f.getByLabel('Descripción').fill('Compra semanal')
  })
  await addTx(async (f) => {
    await f.getByLabel('Tipo').selectOption('income')
    await f.getByLabel('Cuenta', { exact: true }).selectOption({ label: 'Cuenta principal (EUR)' })
    await f.getByLabel('Categoría').selectOption({ label: 'Nómina' })
    await f.getByLabel('Monto').fill('500')
  })
  await addTx(async (f) => {
    await f.getByLabel('Tipo').selectOption('transfer')
    await f.getByLabel('Cuenta origen').selectOption({ label: 'Cuenta principal (EUR)' })
    await f.getByLabel('Cuenta destino').selectOption({ label: 'Ahorro (EUR)' })
    await f.getByLabel('Monto').fill('100')
  })
  await expect(page.getByText('3 resultados')).toBeVisible()

  // Filtros
  await page.getByLabel('Buscar').fill('semanal')
  await expect(page.getByText('1 resultados')).toBeVisible()
  await page.getByLabel('Buscar').fill('')

  // Saldos: 1000 − 200.50 + 500 − 100 = 1199.50 ; ahorro = 100
  await goTo(page, 'Cuentas')
  const main = page.getByRole('listitem').filter({ hasText: 'Cuenta principal' })
  await expect(main).toContainText(/1[.,\s]?199[.,]50/)
  await expect(page.getByRole('listitem').filter({ hasText: 'Ahorro' })).toContainText(/100[.,]00/)

  // Presupuesto del mes actual
  await goTo(page, 'Presupuestos')
  await page.getByLabel('Categoría de gasto').selectOption({ label: 'Supermercado' })
  await page.getByLabel('Monto').fill('150')
  await page.getByRole('button', { name: 'Añadir' }).click()
  await expect(page.getByText(/Excedido en/)).toBeVisible()
  await expect(page.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '100')

  // Resumen
  await goTo(page, 'Inicio', 'Resumen')
  await expect(page.getByText('Saldo total')).toBeVisible()
  if (process.env.SHOTS)
    await page.screenshot({
      path: `test-results/shots/dashboard-${page.viewportSize()?.width}.png`,
      fullPage: true,
    })
  await expect(page.getByText('Supermercado')).toBeVisible()
  await expect(page.getByText(/Compra semanal/)).toBeVisible()

  // No se puede borrar una categoría en uso
  await goTo(page, 'Categorías')
  await page
    .getByRole('listitem')
    .filter({ hasText: 'Supermercado' })
    .getByRole('button', { name: 'Eliminar' })
    .click()
  await page.getByRole('alertdialog').getByRole('button', { name: 'Eliminar' }).click()
  await expect(page.getByRole('alert')).toContainText('transacciones asociadas')
})

test('la sesión persiste al recargar y se cierra con Salir', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('Correo').fill(creds.email)
  await page.getByLabel('Contraseña', { exact: true }).fill(creds.password)
  await page.getByRole('button', { name: 'Entrar' }).click()
  await expect(page.getByText(creds.name)).toBeVisible()
  await page.reload()
  await expect(page.getByText(creds.name)).toBeVisible()
  await page.getByRole('button', { name: 'Salir' }).click()
  await expect(page).toHaveURL(/\/login$/)
})
