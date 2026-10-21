import { defineConfig } from '@playwright/test'

const API_PORT = 8100
const WEB_PORT = 5180

export default defineConfig({
  testDir: './e2e',
  testMatch: '*.e2e.ts',
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? 'github' : 'list',
  use: { baseURL: `http://localhost:${WEB_PORT}`, trace: 'retain-on-failure' },
  webServer: [
    {
      // Backend real contra una BD SQLite desechable, migrada con Alembic
      command: `rm -f e2e.db && uv run alembic upgrade head && uv run uvicorn app.main:app --port ${API_PORT}`,
      cwd: '../backend',
      url: `http://localhost:${API_PORT}/health`,
      reuseExistingServer: false,
      timeout: 60_000,
      env: {
        DATABASE_URL: 'sqlite+aiosqlite:///./e2e.db',
        SECRET_KEY: 'e2e-only-secret-key-0123456789abcdefghijkl',
        CORS_ORIGINS: '[]',
      },
    },
    {
      command: `npm run dev -- --port ${WEB_PORT} --strictPort`,
      url: `http://localhost:${WEB_PORT}`,
      reuseExistingServer: false,
      env: { VITE_PROXY_TARGET: `http://localhost:${API_PORT}` },
    },
  ],
})
