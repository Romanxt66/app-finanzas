import { defineConfig } from '@playwright/test'

// Prueba de humo contra un despliegue real: E2E_BASE_URL=https://alvea.softlane.click npm run e2e:prod
// Crea un usuario desechable (e2e-prod-<fecha>@example.com) en la BD del despliegue.
const baseURL = process.env.E2E_BASE_URL
if (!baseURL) throw new Error('Define E2E_BASE_URL (p. ej. https://alvea.softlane.click)')

export default defineConfig({
  testDir: './e2e-prod',
  testMatch: '*.prod.ts',
  workers: 1,
  reporter: 'list',
  use: { baseURL, trace: 'retain-on-failure' },
})
