// Modo «Presentar» (src/vistas/publico/Presentacion.vue): arranca, avanza con el
// teclado, pausa, termina y sale; los clips no chocan con la CSP.
import { expect, test } from '@playwright/test'
import { ESCENAS } from '../../src/presentacion/guion.js'

test.use({ viewport: { width: 1366, height: 768 } })

test('la presentación avanza con el teclado, pausa, termina y sale', async ({ page }) => {
  await page.addInitScript(() => {
    window.__violaciones = []
    document.addEventListener('securitypolicyviolation', (e) => window.__violaciones.push(`${e.violatedDirective} ${e.blockedURI}`))
  })
  await page.route('**/rest/v1/**', (r) => r.fulfill({ status: 200, contentType: 'application/json', body: '[]' }))
  await page.goto('#/')
  await page.getByRole('link', { name: '▶ Presentar' }).click()
  await page.getByRole('button', { name: 'Comenzar la presentación' }).click()

  const region = page.getByRole('region', { name: 'Presentación de Bicis Públicas Valledupar' })
  await expect(region.getByText(ESCENAS[0].frases[0][1])).toBeVisible()
  await page.keyboard.press('ArrowRight')
  await expect(region.getByRole('heading', { name: 'El ciudadano' })).toBeVisible()
  await expect(region.locator('video')).toHaveAttribute('src', /ciudadano\.webm$/)

  await page.keyboard.press(' ')
  await expect(region.getByRole('button', { name: 'Continuar' })).toBeVisible()
  await page.keyboard.press(' ')
  await expect(region.getByRole('button', { name: 'Pausar' })).toBeVisible()

  for (let i = 2; i < ESCENAS.length; i++) await page.keyboard.press('ArrowRight')
  await expect(region.getByRole('heading', { name: ESCENAS.at(-1).titulo })).toBeVisible()
  await page.keyboard.press('ArrowRight')
  await expect(region.getByRole('heading', { name: 'Gracias' })).toBeVisible()

  expect(await page.evaluate(() => window.__violaciones)).toEqual([])
  await page.keyboard.press('Escape')
  await expect(region).toHaveCount(0)
  await expect(page).toHaveURL(/#\/$/)
})
