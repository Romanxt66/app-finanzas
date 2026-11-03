// Revisión visual de la app compilada, servida como en producción (nginx + backend real).
// Recorre las pantallas en escritorio y móvil, guarda una captura de cada una y falla si la app
// registra errores: de página, de consola o los que ella misma reporta a /api/v1/client-errors
// (se leen del log del backend, API_LOG).
//
// Uso:
//   APP_URL=http://localhost:8090 API_URL=http://localhost:8101 API_LOG=/tmp/api.log \
//   ALVEA_EMAIL=ci@example.com ALVEA_PASSWORD=... OUT=capturas node tool/visual_check.mjs [/ruta,/otra]
import { mkdirSync, readFileSync } from 'node:fs'
import { createRequire } from 'node:module'

// require respeta NODE_PATH: sirve un Playwright instalado aparte (p. ej. en la CI)
const { chromium } = createRequire(import.meta.url)('playwright')

const { APP_URL = 'http://localhost:8090', API_URL = 'http://localhost:8101', API_LOG, ALVEA_EMAIL, ALVEA_PASSWORD, OUT = 'capturas' } = process.env
if (!ALVEA_EMAIL || !ALVEA_PASSWORD) throw new Error('Define ALVEA_EMAIL y ALVEA_PASSWORD (usuario de prueba)')
const routes = (
  process.argv[2] ||
  '/,/transactions,/accounts,/budgets,/goals,/recurring,/categories,/subscriptions,/import,/waiting,/profile,/more'
).split(',')
mkdirSync(OUT, { recursive: true })

const login = await fetch(`${API_URL}/api/v1/auth/login`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email: ALVEA_EMAIL, password: ALVEA_PASSWORD }),
})
if (!login.ok) throw new Error(`No se pudo entrar: ${login.status} ${await login.text()}`)
const tokens = await login.json()

const browser = await chromium.launch()
const errors = []
// Un solo arranque del motor (sin GPU tarda): la vista móvil se obtiene cambiando el tamaño de la
// ventana en la misma página, como al girar o estrechar el navegador (la app es adaptable)
// Idioma explícito: sin él, Chromium sin interfaz usa la configuración regional «C», que la app no admite
const ctx = await browser.newContext({ viewport: { width: 1366, height: 860 }, colorScheme: 'dark', locale: 'es-CO' })
const page = await ctx.newPage()
let current = `escritorio ${routes[0]}`
page.on('pageerror', (e) => errors.push(`[${current}] error de página: ${e.message}`))
page.on('console', (m) => {
  if (m.type() === 'error') errors.push(`[${current}] consola: ${m.text().slice(0, 300)}`)
})
// La app guarda la sesión en shared_preferences (localStorage con prefijo «flutter.»)
await page.addInitScript((t) => {
  localStorage.setItem('flutter.access_token', JSON.stringify(t.access_token))
  localStorage.setItem('flutter.refresh_token', JSON.stringify(t.refresh_token))
}, tokens)
await page.goto(APP_URL + routes[0])
// Se espera a que Flutter pinte (el lienzo vive dentro del shadow DOM de flt-glass-pane)
await page.waitForFunction(() => document.querySelector('flutter-view flt-glass-pane')?.shadowRoot?.querySelector('canvas'), null, {
  timeout: 120_000,
})

// Navegación dentro de la app (como el botón «atrás» del navegador): sin recargar el motor
const go = (path) =>
  page.evaluate((p) => {
    history.pushState(null, '', p)
    dispatchEvent(new PopStateEvent('popstate', { state: null }))
  }, path)

// Espera a que terminen las peticiones y a que pasen las animaciones de entrada
async function settle(ms) {
  await page.waitForLoadState('networkidle', { timeout: 30_000 }).catch(() => {})
  await page.waitForTimeout(ms)
}

// Sin GPU, un fotograma puede tardar: margen amplio y un reintento antes de darlo por fallido
async function capture(path) {
  try {
    await page.screenshot({ path, timeout: 60_000 })
  } catch {
    await page.waitForTimeout(5000)
    await page.screenshot({ path, timeout: 90_000 })
  }
}

for (const [tag, viewport] of [
  ['escritorio', { width: 1366, height: 860 }],
  ['movil', { width: 390, height: 844 }],
]) {
  await page.setViewportSize(viewport)
  for (const [i, route] of routes.entries()) {
    current = `${tag} ${route}`
    if (tag !== 'escritorio' || i > 0) await go(route)
    await settle(i === 0 ? 6000 : 3000)
    const path = new URL(page.url()).pathname
    if (path !== route) errors.push(`[${current}] la app terminó en ${path}`)
    const slug = route === '/' ? '_inicio' : route.replace(/\//g, '_')
    await capture(`${OUT}/${tag}${slug}.png`)
    console.log('captura', `${tag}${slug}.png`)
  }
}
await browser.close()

if (API_LOG) {
  // Dar tiempo a que lleguen los últimos reportes
  await new Promise((r) => setTimeout(r, 1500))
  for (const line of readFileSync(API_LOG, 'utf8').split('\n')) {
    if (line.includes('client error')) errors.push(`reportado por la app: ${line.slice(0, 400)}`)
  }
}
if (errors.length) {
  console.error(`\n${errors.length} errores:\n${errors.join('\n')}`)
  process.exit(1)
}
console.log('\nsin errores')
