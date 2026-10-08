// La política de seguridad de contenido (CSP, vite.config.js) está activa en el
// build y no bloquea nada legítimo: mapa, inscripción con Turnstile y página de una bici.
import { expect, test } from '@playwright/test'

test.use({ viewport: { width: 390, height: 844 } })

async function preparar(page) {
  await page.addInitScript(() => {
    window.__violaciones = []
    document.addEventListener('securitypolicyviolation', (e) => window.__violaciones.push(`${e.violatedDirective} ${e.blockedURI}`))
  })
  const json = (r, cuerpo) => r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(cuerpo) })
  const unaOLista = (r, obj) => json(r, (r.request().headers().accept ?? '').includes('vnd.pgrst.object') ? obj : [obj])
  await page.route('**/rest/v1/disponibilidad_puntos**', (r) => json(r, [{ punto_id: 'p1', codigo: 'P01', nombre: 'Plaza (demo)',
    tipo: 'fijo', latitud: 10.477751, longitud: -73.244632, abierto: true, visible: true, bicis_disponibles: 12, actualizado_en: new Date().toISOString() }]))
  await page.route('**/rest/v1/tipos_documento**', (r) => json(r, [{ codigo: 'CC', nombre: 'Cédula de ciudadanía', implica_menor: false }]))
  await page.route('**/rest/v1/politicas_tratamiento**', (r) => unaOLista(r, { version: '0.2', texto_autorizacion: 'Autorizo (prueba).', texto_autorizacion_foto: 'Foto (prueba).' }))
  await page.route('**/rest/v1/parametros**', (r) => unaOLista(r, { valor: true }))
  await page.route('**/tile.openstreetmap.org/**', (r) => r.fulfill({ status: 200, contentType: 'image/png',
    body: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=', 'base64') }))
  await page.route('**/challenges.cloudflare.com/turnstile/**', (r) => r.fulfill({ contentType: 'text/javascript',
    body: 'window.turnstile = { render(el, o) { el.textContent = "ok"; o.callback("t"); return "w" }, reset() {}, remove() {} }' }))
}

test('la CSP está en el build y bloquea scripts de otros orígenes', async ({ page }) => {
  await preparar(page)
  await page.goto('#/')
  const politica = await page.locator('meta[http-equiv="Content-Security-Policy"]').getAttribute('content')
  expect(politica).toContain("script-src 'self' https://challenges.cloudflare.com")
  expect(politica).toMatch(/connect-src 'self' https:\/\/[a-z0-9]+\.supabase\.co wss:\/\/[a-z0-9]+\.supabase\.co/)
  expect(politica).toContain("object-src 'none'")
  // Control positivo: un script de un dominio ajeno debe quedar bloqueado.
  await page.evaluate(() => { const s = document.createElement('script'); s.src = 'https://ajeno.example/x.js'; document.head.appendChild(s) })
  await expect.poll(() => page.evaluate(() => window.__violaciones.join('|'))).toContain('script-src')
})

test('mapa, inscripción y página de una bici funcionan sin violaciones de la CSP', async ({ page }) => {
  await preparar(page)
  await page.goto('#/mapa')
  await expect(page.locator('.leaflet-container')).toBeVisible()
  await page.goto('#/inscribirme')
  await expect(page.getByText('ok', { exact: true })).toBeVisible()          // widget de Turnstile cargado
  await page.goto('#/b/BPV-007')
  await page.waitForLoadState('networkidle')
  expect(await page.evaluate(() => window.__violaciones)).toEqual([])
})
