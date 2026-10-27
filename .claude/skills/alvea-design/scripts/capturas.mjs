// Capturas de Alvea 2 con Playwright (escritorio y móvil, arriba y desplazado).
//
// Uso:
//   APP_URL=http://localhost:8090 API_URL=http://localhost:8101 \
//   ALVEA_EMAIL=demo@example.com ALVEA_PASSWORD=... OUT=/tmp/capturas \
//   node capturas.mjs /,/accounts:600,/transactions
//
// Cada ruta admite «:píxeles» para desplazar antes de la captura. Las credenciales son de un
// usuario de prueba local: no uses una cuenta real.
import { createRequire } from 'node:module'

// require respeta NODE_PATH, así sirve tanto un Playwright global como uno del proyecto
// (p. ej. NODE_PATH=frontend/node_modules)
const { chromium } = createRequire(import.meta.url)('playwright')

const { APP_URL = 'http://localhost:8090', API_URL = 'http://localhost:8101', ALVEA_EMAIL, ALVEA_PASSWORD, OUT = '.' } = process.env
const routes = (process.argv[2] || '/').split(',')
if (!ALVEA_EMAIL || !ALVEA_PASSWORD) throw new Error('Define ALVEA_EMAIL y ALVEA_PASSWORD (usuario de prueba)')

const res = await fetch(`${API_URL}/api/v1/auth/login`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email: ALVEA_EMAIL, password: ALVEA_PASSWORD }),
})
const tokens = await res.json()
const browser = await chromium.launch()
const errors = []
for (const [tag, viewport] of [['escritorio', { width: 1366, height: 860 }], ['movil', { width: 390, height: 844 }]]) {
  for (const item of routes) {
    const [route, scroll] = item.split(':')
    // Idioma explícito: sin él, Chromium sin interfaz usa la configuración regional «C», que la app no admite
    const ctx = await browser.newContext({ viewport, colorScheme: 'dark', locale: 'es-CO' })
    const page = await ctx.newPage()
    page.on('pageerror', (e) => errors.push(`${route}: ${e.message}`))
    // La app guarda la sesión en shared_preferences (localStorage con prefijo «flutter.»)
    await page.addInitScript((t) => {
      localStorage.setItem('flutter.access_token', JSON.stringify(t.access_token))
      localStorage.setItem('flutter.refresh_token', JSON.stringify(t.refresh_token))
    }, tokens)
    await page.goto(APP_URL + route)
    await page.waitForTimeout(8000) // CanvasKit tarda en arrancar
    if (scroll) {
      await page.mouse.move(viewport.width / 2, viewport.height / 2)
      await page.mouse.wheel(0, Number(scroll))
      await page.waitForTimeout(3000)
    }
    const slug = route === '/' ? '_inicio' : route.replace(/\//g, '_')
    const name = `${OUT}/${tag}${slug}${scroll ? '-' + scroll : ''}.png`
    await page.screenshot({ path: name })
    console.log('ok', name)
    await ctx.close()
  }
}
await browser.close()
console.log(errors.length ? errors.join('\n') : 'sin errores de página')
