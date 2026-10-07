// Captura una vista esperando a que aparezca un selector (datos cargados).
//
//   node scripts/capturar.mjs <url> <salida.png> [selector] [ancho] [alto]
//
// Usa el Chromium en caché de Playwright (CHROMIUM_PATH lo cambia), así no hay que
// descargar navegadores. Falla si el selector no aparece en 30 s o si la página
// registra errores en consola: nada se silencia.
import { chromium } from '@playwright/test'
import { homedir } from 'node:os'

const [url, salida, selector = 'main', ancho = '390', alto = '900'] = process.argv.slice(2)
if (!url || !salida) {
  console.error('uso: node scripts/capturar.mjs <url> <salida.png> [selector] [ancho] [alto]')
  process.exit(2)
}

const navegador = await chromium.launch({
  executablePath: process.env.CHROMIUM_PATH ?? `${homedir()}/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome`,
})
const pagina = await navegador.newPage({ viewport: { width: Number(ancho), height: Number(alto) } })
const errores = []
pagina.on('console', (m) => m.type() === 'error' && errores.push(m.text()))
pagina.on('pageerror', (e) => errores.push(e.message))

try {
  await pagina.goto(url, { waitUntil: 'domcontentloaded' })
  await pagina.waitForSelector(selector, { timeout: 30_000 })
  // Espera breve a que terminen las teselas; el canal en vivo (WebSocket) puede no
  // dejar nunca la red en reposo, así que agotar este plazo no es un error.
  await pagina.waitForLoadState('networkidle', { timeout: 15_000 }).catch(() => {})
  await pagina.screenshot({ path: salida, fullPage: true })
  console.log(`captura: ${salida}`)
} finally {
  await navegador.close()
}
if (errores.length) {
  console.error('Errores en la consola de la página:\n' + errores.join('\n'))
  process.exit(1)
}
