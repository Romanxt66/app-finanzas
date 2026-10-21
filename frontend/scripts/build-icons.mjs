// Genera los PNG de la app instalable (PWA / Android) desde design/icon.svg usando Chromium de Playwright.
// Uso: node scripts/build-icons.mjs
import { chromium } from '@playwright/test'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const svg = readFileSync(resolve('../design/icon.svg'), 'utf8')
const browser = await chromium.launch()
for (const size of [192, 512]) {
  const page = await browser.newPage({ viewport: { width: size, height: size } })
  await page.setContent(`<style>html,body{margin:0}svg{display:block;width:${size}px;height:${size}px}</style>${svg}`)
  await page.screenshot({ path: resolve(`public/icons/icon-${size}.png`), omitBackground: false })
  await page.close()
}
await browser.close()
console.log('iconos generados en public/icons')
