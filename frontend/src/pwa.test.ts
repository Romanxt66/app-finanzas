import { existsSync, readFileSync, statSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const publicDir = resolve(dirname(fileURLToPath(import.meta.url)), '../public')
const manifest = JSON.parse(readFileSync(resolve(publicDir, 'manifest.webmanifest'), 'utf8'))

describe('PWA / app instalable', () => {
  it('el manifest cumple lo mínimo para instalarse (Android/Chrome)', () => {
    expect(manifest.name).toBeTruthy()
    expect(manifest.short_name.length).toBeLessThanOrEqual(12)
    expect(manifest.display).toBe('standalone')
    expect(manifest.start_url).toBe('/')
    expect(manifest.lang).toBe('es')
    const sizes = manifest.icons.map((i: { sizes: string }) => i.sizes)
    expect(sizes).toEqual(expect.arrayContaining(['192x192', '512x512']))
  })

  it('cada icono declarado existe y es un archivo no vacío', () => {
    for (const icon of manifest.icons) {
      const file = resolve(publicDir, icon.src.replace(/^\//, ''))
      expect(existsSync(file), icon.src).toBe(true)
      expect(statSync(file).size).toBeGreaterThan(500)
    }
  })

  it('los colores del manifest coinciden con el fondo oscuro del diseño', () => {
    const tokens = JSON.parse(readFileSync(resolve(publicDir, '../../design/tokens.json'), 'utf8'))
    const bg = tokens.color.tokens.find((t: { name: string }) => t.name === 'bg').value.dark
    expect(manifest.background_color).toBe(bg)
    expect(manifest.theme_color).toBe(bg)
  })

  it('el service worker nunca cachea /api', () => {
    const sw = readFileSync(resolve(publicDir, 'sw.js'), 'utf8')
    expect(sw).toContain("startsWith('/api/')")
    expect(sw).toContain("request.method !== 'GET'")
  })
})
