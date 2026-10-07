// Recorrido del operador con el servidor simulado: ingresar → elegir punto →
// prestar (persona preinscrita → validar → bici → foto → confirmar) → devolver.
// Verifica que la interfaz llama a las funciones correctas con los datos correctos.
// Datos 100 % ficticios. Deja capturas en capturas/e2e-*.png.
import { expect, test } from '@playwright/test'
import { fileURLToPath } from 'node:url'

const FOTO = fileURLToPath(new URL('../../public/marca/logo_sttv.png', import.meta.url))
const AHORA = new Date().toISOString()

function jwtFalso() {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url')
  const exp = Math.floor(Date.now() / 1000) + 3600
  return `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64({ sub: 'u-op', role: 'authenticated', exp })}.firma`
}

const RESUMEN = {
  id: 'per-1', tipo_documento: 'CC', tipo_documento_nombre: 'Cédula de ciudadanía',
  documento_enmascarado: '****0001', nombres: 'Ana María', apellidos: 'Prueba Demo',
  telefono_enmascarado: '****0000', edad_estimada: 30, es_menor: false, estado: 'preinscrita',
  acudiente: null, politica_vigente: '0.2', autorizacion_vigente: true, autoriza_foto: true,
  autorizacion_presencial: false, sancion: null, prestamos_activos: 0,
}

async function simularServidor(page, llamadas) {
  const json = (route, cuerpo, status = 200) =>
    route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(cuerpo) })

  await page.route('**/auth/v1/token**', (r) => json(r, {
    access_token: jwtFalso(), token_type: 'bearer', expires_in: 3600,
    expires_at: Math.floor(Date.now() / 1000) + 3600, refresh_token: 'r',
    user: { id: 'u-op', aud: 'authenticated', role: 'authenticated', email: 'operador@prueba.invalid' },
  }))
  await page.route('**/rest/v1/rpc/**', async (r) => {
    const fn = new URL(r.request().url()).pathname.split('/').pop()
    const cuerpo = r.request().postDataJSON() ?? {}
    llamadas.push({ fn, cuerpo })
    const respuestas = {
      mi_perfil: { id: 'u-op', nombre: 'Operador Demo', rol: 'operador', debe_cambiar_clave: false },
      buscar_persona: RESUMEN,
      validar_persona: { ...RESUMEN, estado: 'validada' },
      prestamos_activos: [{ prestamo_id: 'pr-1', codigo: 'BPV-003', numero: 3, persona: 'Ana P.', es_menor: false,
        punto_salida: 'P01 · Plaza (demo)', salida_en: AHORA, vence_en: null, ahora_servidor: AHORA }],
      registrar_prestamo: { prestamo_id: cuerpo.p_id, estado: 'activo', codigo: 'BPV-003', salida_en: AHORA,
        vence_en: null, ahora_servidor: AHORA },
      registrar_devolucion: { prestamo_id: 'pr-1', estado: 'finalizado', codigo: 'BPV-003', persona: 'Ana P.',
        salida_en: AHORA, devuelto_en: AHORA, duracion_min: 42, excedio: null, ahora_servidor: AHORA },
    }
    return json(r, respuestas[fn] ?? null)
  })
  await page.route('**/rest/v1/puntos**', (r) => json(r, [
    { id: 'p1', codigo: 'P01', nombre: 'Plaza (demo)', tipo: 'fijo', estado: 'activo' }]))
  await page.route('**/rest/v1/tipos_documento**', (r) => json(r, [
    { codigo: 'CC', nombre: 'Cédula de ciudadanía', implica_menor: false },
    { codigo: 'TI', nombre: 'Tarjeta de identidad', implica_menor: true }]))
  await page.route('**/rest/v1/politicas_tratamiento**', (r) => json(r, {
    version: '0.2', texto_autorizacion: 'Autorizo el tratamiento de mis datos (demo).',
    texto_autorizacion_foto: 'Autorizo la foto de evidencia (demo).' }))
  await page.route('**/rest/v1/parametros**', (r) => json(r, { valor: true }))
  await page.route('**/rest/v1/bicicletas**', (r) => json(r, [1, 2, 3].map((n) => (
    { id: `b${n}`, numero: n, codigo: `BPV-00${n}` }))))
  await page.route('**/rest/v1/incidencias**', (r) => json(r, []))
  await page.route('**/storage/v1/object/evidencias/**', (r) => {
    llamadas.push({ fn: 'subir_foto', ruta: new URL(r.request().url()).pathname })
    return json(r, { Key: 'evidencias/x', Id: 'obj-1' })
  })
}

test('el operador presta y devuelve una bici', async ({ page }) => {
  const llamadas = []
  const errores = []
  page.on('pageerror', (e) => errores.push(e.message))
  await simularServidor(page, llamadas)

  // Ingresar
  await page.goto('#/operador')
  await expect(page.getByRole('heading', { name: 'Ingreso del personal' })).toBeVisible()
  await page.getByLabel('Correo').fill('operador@prueba.invalid')
  await page.getByLabel('Clave').fill('clave-de-prueba')
  await page.getByRole('button', { name: 'Ingresar' }).click()

  // Elegir punto de trabajo
  await page.getByRole('button', { name: /P01 · Plaza \(demo\)/ }).click()
  await expect(page.getByText('Turno del operador')).toBeVisible()
  await page.screenshot({ path: 'capturas/e2e-1-turno.png', fullPage: true })

  // Prestar · paso 1: buscar y validar
  await page.getByRole('link', { name: /Prestar/ }).click()
  await page.getByLabel('Número del documento').fill('00.100.001')
  await page.getByRole('button', { name: 'Buscar' }).click()
  await expect(page.getByRole('heading', { name: 'Ana María Prueba Demo' })).toBeVisible()
  const validar = page.getByRole('button', { name: 'Validar y continuar' })
  await expect(validar).toBeDisabled()                    // falta confirmar el documento
  await page.getByText('Vi el documento original').click()
  await page.screenshot({ path: 'capturas/e2e-2-persona.png', fullPage: true })
  await validar.click()

  // Paso 2: bici
  await page.getByRole('button', { name: '003' }).click()
  await expect(page.getByText('Código: BPV-003')).toBeVisible()
  await page.screenshot({ path: 'capturas/e2e-3-bici.png', fullPage: true })
  await page.getByRole('button', { name: 'Continuar' }).click()

  // Paso 3: foto
  await page.locator('input[type=file]').setInputFiles(FOTO)
  await expect(page.getByText(/Foto guardada/)).toBeVisible()
  await page.screenshot({ path: 'capturas/e2e-4-foto.png', fullPage: true })
  await page.getByRole('button', { name: 'Continuar' }).click()

  // Paso 4: confirmar
  await expect(page.getByRole('heading', { name: 'Confirmar préstamo' })).toBeVisible()
  await page.getByRole('button', { name: 'Prestar', exact: true }).click()
  await expect(page.getByText('Préstamo registrado')).toBeVisible()
  await expect(page.getByText('BPV-003')).toBeVisible()
  await page.screenshot({ path: 'capturas/e2e-5-prestado.png', fullPage: true })

  // Lo que la interfaz le pidió al servidor
  const buscar = llamadas.find((l) => l.fn === 'buscar_persona')
  expect(buscar.cuerpo).toEqual({ p_tipo: 'CC', p_numero: '00100001' })   // documento normalizado
  expect(llamadas.find((l) => l.fn === 'validar_persona').cuerpo.p_persona_id).toBe('per-1')
  const prestamo = llamadas.find((l) => l.fn === 'registrar_prestamo').cuerpo
  const foto = llamadas.find((l) => l.fn === 'subir_foto')
  expect(prestamo).toMatchObject({ p_persona_id: 'per-1', p_numero_bici: 3, p_punto_id: 'p1' })
  expect(prestamo.p_foto_ruta).toBe(`prestamos/${prestamo.p_id}/salida.webp`)
  expect(foto.ruta).toContain(`prestamos/${prestamo.p_id}/salida.webp`)

  // Devolver sin novedad
  await page.getByRole('link', { name: 'Volver al turno' }).click()
  await page.getByRole('link', { name: /Devolver/ }).click()
  await page.getByRole('button', { name: /BPV-003 · Ana P\./ }).click()
  await page.getByRole('button', { name: 'Sin novedad' }).click()
  await page.screenshot({ path: 'capturas/e2e-6-devolver.png', fullPage: true })
  await page.getByRole('button', { name: 'Registrar devolución' }).click()
  await expect(page.getByText('Devolución registrada')).toBeVisible()
  await expect(page.getByText('42 min')).toBeVisible()
  const devolucion = llamadas.find((l) => l.fn === 'registrar_devolucion').cuerpo
  expect(devolucion).toMatchObject({ p_numero_bici: 3, p_punto_id: 'p1', p_con_novedad: false, p_incidencia: null })

  expect(errores).toEqual([])
})

test('sin sesión, las rutas del operador llevan al ingreso', async ({ page }) => {
  await page.goto('#/operador/prestar')
  await expect(page.getByRole('heading', { name: 'Ingreso del personal' })).toBeVisible()
  expect(page.url()).toContain('ir=')
})

test('un menor sin autorización presencial exige que el acudiente autorice en el punto (D-21)', async ({ page }) => {
  const llamadas = []
  await simularServidor(page, llamadas)
  const menor = {
    ...RESUMEN, id: 'per-2', nombres: 'Luis', apellidos: 'Menor Demo', tipo_documento: 'TI', edad_estimada: 13,
    es_menor: true, estado: 'validada', autorizacion_presencial: false,
    acudiente: { nombres: 'Rosa', apellidos: 'Acudiente Demo', parentesco: 'madre', tipo_documento: 'CC',
      documento_enmascarado: '****0009', telefono_enmascarado: '****0009' },
  }
  await page.route('**/rest/v1/rpc/buscar_persona', (r) =>
    r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(menor) }))
  await page.route('**/rest/v1/rpc/registrar_autorizacion', async (r) => {
    llamadas.push({ fn: 'registrar_autorizacion', cuerpo: r.request().postDataJSON() })
    await r.fulfill({ status: 200, contentType: 'application/json',
      body: JSON.stringify({ ...menor, autorizacion_presencial: true }) })
  })

  await page.goto('#/ingresar?ir=/operador/prestar')
  await page.getByLabel('Correo').fill('operador@prueba.invalid')
  await page.getByLabel('Clave').fill('clave-de-prueba')
  await page.getByRole('button', { name: 'Ingresar' }).click()
  await page.getByRole('button', { name: /P01 · Plaza \(demo\)/ }).click()
  await page.getByRole('link', { name: /Prestar/ }).click()
  await page.getByLabel('Tipo de documento').selectOption('TI')
  await page.getByLabel('Número del documento').fill('00200001')
  await page.getByRole('button', { name: 'Buscar' }).click()

  await expect(page.getByText(/autoriza su acudiente, Rosa Acudiente Demo/)).toBeVisible()
  await page.getByText('Vi el documento original').click()
  const continuar = page.getByRole('button', { name: 'Continuar', exact: true })
  await expect(continuar).toBeDisabled()                      // faltan las casillas del acudiente
  await page.getByText('Autorizo el tratamiento de mis datos (demo).').click()
  await page.getByText('Autorizo la foto de evidencia (demo).').click()
  await expect(continuar).toBeDisabled()                      // falta la constancia de escuchar al menor
  await page.getByText(/escuchó la opinión del menor/).click()
  await page.screenshot({ path: 'capturas/e2e-7-menor.png', fullPage: true })
  await continuar.click()

  await expect(page.getByRole('heading', { name: '¿Qué bici se lleva?' })).toBeVisible()
  const aut = llamadas.find((l) => l.fn === 'registrar_autorizacion').cuerpo
  expect(aut.p_persona_id).toBe('per-2')
  expect(aut.p_autorizacion).toMatchObject({
    politica_version: '0.2', autoriza_tratamiento: true, autoriza_foto: true, menor_escuchado: true })
})
