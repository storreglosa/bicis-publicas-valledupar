// Pruebas de interfaz de punta a punta (tests/e2e). Corren contra el build servido
// con `vite preview` y simulan las respuestas del servidor (no usan credenciales).
//   npx vite build --mode development --outDir dist-demo
//   npx vite preview --mode development --outDir dist-demo --port 4174 &
//   npx playwright test
import { defineConfig } from '@playwright/test'
import { homedir } from 'node:os'

export default defineConfig({
  testDir: 'tests/e2e',
  timeout: 120_000,
  expect: { timeout: 15_000 },   // equipo lento: la espera por defecto (5 s) da falsos negativos
  reporter: 'list',
  use: {
    baseURL: process.env.BASE_URL ?? 'http://localhost:4174/bicis-publicas-valledupar/',
    viewport: { width: 390, height: 844 },
    launchOptions: {
      // Chromium en caché de Playwright: evita descargar navegadores (red lenta).
      executablePath: process.env.CHROMIUM_PATH ?? `${homedir()}/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome`,
    },
  },
})
