// Preinscripción pública (hito 1e) en el celular, con el servidor y Turnstile
// simulados (datos ficticios). Capturas en capturas/e2e-inscripcion-*.png.
import { expect, test } from '@playwright/test'

const POLITICA = { version: '0.2', texto_autorizacion: 'Autorizo el tratamiento de mis datos (prueba).',
  texto_autorizacion_foto: 'Autorizo la foto de evidencia (prueba).' }

async function simular(page, respuesta = { status: 200, cuerpo: { resultado: 'inscrito' } }) {
  const envios = []
  const json = (r, cuerpo, status = 200) => r.fulfill({ status, contentType: 'application/json', body: JSON.stringify(cuerpo) })
  const unaOLista = (r, obj) => json(r, (r.request().headers().accept ?? '').includes('vnd.pgrst.object') ? obj : [obj])
  await page.route('**/rest/v1/tipos_documento**', (r) => json(r, [
    { codigo: 'CC', nombre: 'Cédula de ciudadanía', implica_menor: false },
    { codigo: 'TI', nombre: 'Tarjeta de identidad', implica_menor: true },
  ]))
  await page.route('**/rest/v1/politicas_tratamiento**', (r) => unaOLista(r, POLITICA))
  await page.route('**/rest/v1/parametros**', (r) => unaOLista(r, { valor: true }))
  // Turnstile simulado: entrega un token al instante.
  await page.route('**/challenges.cloudflare.com/turnstile/**', (r) => r.fulfill({
    contentType: 'text/javascript',
    body: `let opciones; window.turnstile = {
      render(el, o) { opciones = o; el.textContent = 'Verificación simulada'; setTimeout(() => o.callback('token-de-prueba'), 50); return 'w1' },
      reset() { setTimeout(() => opciones.callback('token-de-prueba-2'), 50) }, remove() {} }`,
  }))
  await page.route('**/functions/v1/preinscribir', (r) => {
    if (r.request().method() === 'OPTIONS') return r.fulfill({ status: 204 })
    envios.push(r.request().postDataJSON())
    return json(r, respuesta.cuerpo, respuesta.status)
  })
  return envios
}

async function llenarAdulto(page) {
  await page.getByLabel('Número de documento').fill('00100001')
  await page.getByLabel('Nombres').fill('Ana')
  await page.getByLabel('Apellidos').fill('Prueba')
  await page.getByLabel('Celular').fill('300 123-4567')
  await page.getByLabel('Edad').fill('30')
  await page.getByLabel('Sexo / género').selectOption('mujer')
}

test.use({ viewport: { width: 390, height: 844 } })

test('preinscripción: casillas sin marcar, envía datos y autorización, y confirma', async ({ page }) => {
  const errores = []
  page.on('pageerror', (e) => errores.push(e.message))
  const envios = await simular(page)
  await page.goto('#/inscribirme')
  await expect(page.getByRole('heading', { name: 'Inscribirme' })).toBeVisible()
  for (const casilla of await page.getByRole('checkbox').all()) await expect(casilla).not.toBeChecked()

  await llenarAdulto(page)
  const boton = page.getByRole('button', { name: 'Inscribirme' })
  await expect(page.getByText('Para enviar falta la autorización de tratamiento de datos.')).toBeVisible()
  await expect(boton).toBeDisabled()
  await page.getByText(POLITICA.texto_autorizacion).click()
  await page.getByText(POLITICA.texto_autorizacion_foto).click()
  await expect(boton).toBeEnabled()
  await page.screenshot({ path: 'capturas/e2e-inscripcion-1-formulario.png', fullPage: true })
  await boton.click()

  await expect(page.getByText('Listo: quedaste preinscrito.')).toBeVisible()
  expect(envios).toHaveLength(1)
  const { persona, turnstile } = envios[0]
  expect(turnstile).toBe('token-de-prueba')
  expect(persona).toMatchObject({
    tipo_documento: 'CC', numero_documento: '00100001', nombres: 'Ana', apellidos: 'Prueba', edad: '30', sexo_genero: 'mujer',
    correo: null, autorizacion: { politica_version: '0.2', autoriza_tratamiento: true, autoriza_foto: true, menor_escuchado: null },
  })
  expect(persona.id_operacion).toMatch(/^[0-9a-f-]{36}$/)
  expect(persona.acudiente).toBeUndefined()
  await page.screenshot({ path: 'capturas/e2e-inscripcion-2-listo.png' })
  expect(errores).toEqual([])
})

test('preinscripción de un menor: pide acudiente y su declaración', async ({ page }) => {
  const envios = await simular(page)
  await page.goto('#/inscribirme')
  await llenarAdulto(page)
  await page.getByLabel('Tipo de documento').first().selectOption('TI')   // aparece el bloque del acudiente
  await page.getByLabel('Edad').fill('14')
  await expect(page.getByRole('group', { name: 'Acudiente' })).toBeVisible()
  const acu = page.getByRole('group', { name: 'Acudiente' })
  await acu.getByLabel('Parentesco').selectOption('madre')
  await acu.getByLabel('Número').fill('00900001')
  await acu.getByLabel('Nombres').fill('Madre')
  await acu.getByLabel('Apellidos').fill('Prueba')
  await acu.getByLabel('Celular').fill('3000000009')
  await page.getByText(POLITICA.texto_autorizacion).click()
  await page.getByText(POLITICA.texto_autorizacion_foto).click()
  await expect(page.getByText(/falta la declaración del acudiente/)).toBeVisible()
  await page.getByText(/escuché la opinión del menor/).click()
  await page.getByRole('button', { name: 'Inscribirme' }).click()
  await expect(page.getByText('Listo: quedaste preinscrito.')).toBeVisible()
  await expect(page.getByText(/Ve con tu acudiente/)).toBeVisible()
  expect(envios[0].persona.acudiente).toMatchObject({ tipo_documento: 'CC', numero_documento: '00900001', parentesco: 'madre' })
  expect(envios[0].persona.autorizacion.menor_escuchado).toBe(true)
})

test('documento ya inscrito: mensaje amable, sin datos', async ({ page }) => {
  await simular(page, { status: 200, cuerpo: { resultado: 'ya_inscrito' } })
  await page.goto('#/inscribirme')
  await llenarAdulto(page)
  await page.getByText(POLITICA.texto_autorizacion).click()
  await page.getByText(POLITICA.texto_autorizacion_foto).click()
  await page.getByRole('button', { name: 'Inscribirme' }).click()
  await expect(page.getByText('Ese documento ya está inscrito.')).toBeVisible()
})

test('demasiados intentos: se traduce el código y el formulario sigue ahí', async ({ page }) => {
  const envios = await simular(page, { status: 429, cuerpo: { error: 'demasiados_intentos' } })
  await page.goto('#/inscribirme')
  await llenarAdulto(page)
  await page.getByText(POLITICA.texto_autorizacion).click()
  await page.getByText(POLITICA.texto_autorizacion_foto).click()
  await page.getByRole('button', { name: 'Inscribirme' }).click()
  await expect(page.getByRole('alert')).toContainText('demasiados intentos de inscripción')
  await expect(page.getByLabel('Nombres')).toHaveValue('Ana')
  // Reintento con el mismo formulario: mismo id_operacion (no duplica si el primero sí llegó).
  await expect(page.getByRole('button', { name: 'Inscribirme' })).toBeEnabled()
  await page.getByRole('button', { name: 'Inscribirme' }).click()
  await expect.poll(() => envios.length).toBe(2)
  expect(envios[1].persona.id_operacion).toBe(envios[0].persona.id_operacion)
})
