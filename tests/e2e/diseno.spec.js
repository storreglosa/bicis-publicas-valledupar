// Verificación de diseño (plan, verificación 3): las páginas públicas no se desbordan
// a lo ancho a 320, 390 y 1440 px. Datos simulados con nombres largos a propósito.
import { expect, test } from '@playwright/test'

const AHORA = new Date().toISOString()
const PUNTOS = [
  ['P01', 'Plaza Alfonso López — costado de la Casa de la Cultura (demo)', 'fijo', 10.477751, -73.244632, 12, true],
  ['P02', 'Parque Novalito (demo)', 'fijo', 10.48167, -73.248189, 0, true],
  ['P03', 'Universidad Popular del Cesar, sede Sabanas (demo)', 'fijo', 10.449123, -73.262523, 3, false],
  ['E01', 'Balneario Hurtado — ciclopaseo dominical (demo)', 'evento', 10.501328, -73.270795, 10, false],
].map(([codigo, nombre, tipo, latitud, longitud, bicis, abierto], i) => ({
  punto_id: `p${i}`, codigo, nombre, tipo, latitud, longitud, direccion: 'Carrera 4 con calle 15, Comuna 1 (demo)',
  horario_texto: 'Lunes a sábado, 6:00 a. m. – 6:00 p. m.', evento_nombre: tipo === 'evento' ? 'Ciclopaseo de demostración' : null,
  evento_inicia_en: tipo === 'evento' ? AHORA : null, evento_termina_en: tipo === 'evento' ? AHORA : null,
  abierto, bicis_disponibles: bicis, actualizado_en: AHORA,
}))

async function simular(page) {
  const json = (r, cuerpo) => r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(cuerpo) })
  const unaOLista = (r, obj) => json(r, (r.request().headers().accept ?? '').includes('vnd.pgrst.object') ? obj : [obj])
  await page.route('**/rest/v1/disponibilidad_puntos**', (r) => json(r, PUNTOS))
  await page.route('**/rest/v1/eventos**', (r) => json(r, [{ id: 'ev', nombre: 'Ciclopaseo de demostración por el río Guatapurí',
    descripcion: 'Recorrido familiar de 12 km.', lugar_texto: 'Balneario Hurtado, entrada principal', inicia_en: AHORA, termina_en: AHORA, estado: 'planeado' }]))
  await page.route('**/rest/v1/parametros**', (r) => {
    const una = (r.request().headers().accept ?? '').includes('vnd.pgrst.object')
    const filas = [
      { clave: 'reglas_uso.duracion_maxima_min', categoria: 'Reglas de uso', descripcion: 'Duración máxima de un préstamo', tipo: 'entero', unidad: 'minutos', valor: 120, orden: 10 },
      { clave: 'evidencia.foto_persona_obligatoria', categoria: 'Evidencia', descripcion: 'Foto', tipo: 'booleano', unidad: null, valor: true, orden: 10 },
    ]
    return json(r, una ? { valor: true } : filas)
  })
  await page.route('**/rest/v1/politicas_tratamiento**', (r) => unaOLista(r, { version: '0.3', vigente_desde: '2026-10-08', vigente: true,
    sha256: 'a'.repeat(64), texto_md: '# Política\n\nTexto de prueba con una palabra muy larga: anticonstitucionalidadmente.',
    texto_autorizacion: 'Autorizo (prueba).', texto_autorizacion_foto: 'Foto (prueba).' }))
  await page.route('**/rest/v1/tipos_documento**', (r) => json(r, [{ codigo: 'CC', nombre: 'Cédula de ciudadanía', implica_menor: false }]))
  await page.route('**/tile.openstreetmap.org/**', (r) => r.abort())
  await page.route('**/challenges.cloudflare.com/turnstile/**', (r) => r.fulfill({ contentType: 'text/javascript',
    body: 'window.turnstile = { render() { return "w" }, reset() {}, remove() {} }' }))
}

// Ruta → comienzo del título de la pestaña (lo fija el router): así se mide la página nueva, no la anterior.
const RUTAS = { '#/': 'Bicis Públicas', '#/mapa': 'Mapa de puntos', '#/reglas': 'Reglas de uso', '#/eventos': 'Eventos',
  '#/inscribirme': 'Inscribirme', '#/politica-de-datos': 'Política de tratamiento', '#/b/BPV-001': 'Bicicleta',
  '#/ingresar': 'Ingreso del personal' }

for (const ancho of [320, 390, 1440]) {
  test(`sin desborde horizontal a ${ancho} px`, async ({ page }) => {
    await page.setViewportSize({ width: ancho, height: 900 })
    await simular(page)
    const problemas = []
    for (const [ruta, titulo] of Object.entries(RUTAS)) {
      await page.goto('about:blank')                 // carga completa: cambiar solo el # no recarga la página
      await page.goto(ruta)
      await expect(page).toHaveTitle(new RegExp(`^${titulo}`))
      await page.locator('main h1').first().waitFor()
      await page.waitForTimeout(300)            // mapa y fuentes asentados
      const r = await page.evaluate(() => {
        const ancho = document.documentElement.clientWidth
        const culpables = [...document.querySelectorAll('body *')]
          .filter((el) => el.getBoundingClientRect().right > ancho + 1 && el.getClientRects().length)
          .filter((el) => !el.closest('.leaflet-container'))
          .slice(0, 3).map((el) => `${el.tagName.toLowerCase()}.${[...el.classList].join('.')}`)
        return { desborde: document.documentElement.scrollWidth - ancho, culpables }
      })
      if (r.desborde > 0) problemas.push(`${ruta}: ${r.desborde} px de más (${r.culpables.join(', ')})`)
    }
    if (ancho === 320) await page.screenshot({ path: 'capturas/diseno-320-ingresar.png' })
    expect(problemas).toEqual([])
  })
}
