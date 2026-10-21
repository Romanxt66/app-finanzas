import react from '@vitejs/plugin-react'
import { defineConfig, loadEnv } from 'vite'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const target = env.VITE_PROXY_TARGET
  return {
    plugins: [react()],
    server: target ? { proxy: { '/api': { target, changeOrigin: true } } } : undefined,
    test: {
      environment: 'jsdom',
      setupFiles: ['./src/test-setup.ts'],
      globals: true,
      exclude: ['e2e/**', 'node_modules/**'],
    },
  }
})
