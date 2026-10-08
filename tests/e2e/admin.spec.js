// Panel de administración con el servidor simulado (sin credenciales, datos ficticios).
// Capturas en capturas/e2e-admin-*.png.
import { expect, test } from '@playwright/test'
import { readFileSync } from 'node:fs'

const AHORA = new Date().toISOString()

function jwtFalso() {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url')
  return `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64({ sub: 'u-adm', role: 'authenticated', exp: Math.floor(Date.now() / 1000) + 3600 })}.firma`
}

const TABLERO = {
  ahora_servidor: AHORA,
  bicis: { total: 130, disponible: 118, prestada: 7, no_disponible: 5, averiada: 2, en_reparacion: 3, extraviada: 0, baja: 0 },
  prestamos_hoy: 23, prestamos_activos: 7, prestamos_vencidos: 1,
  por_hora_hoy: [{ hora: 7, prestamos: 4 }, { hora: 8, prestamos: 6 }, { hora: 12, prestamos: 3 }, { hora: 17, prestamos: 10 }],
  por_punto: [{ codigo: 'P01', nombre: 'Plaza (demo)', tipo: 'fijo', disponibles: 30, total: 35 },
    { codigo: 'P02', nombre: 'Novalito (demo)', tipo: 'fijo', disponibles: 12, total: 30 }],
  incidencias_abiertas: 2, preinscritas_sin_validar: 4, retencion_fotos_dias: null,
  storage_bytes: 120 * 1024 ** 2, bd_bytes: 30 * 1024 ** 2, ultimo_respaldo: null, ultima_purga: null,
}

const PARAMETROS = [
  { clave: 'reglas_uso.duracion_maxima_min', categoria: 'Reglas de uso', descripcion: 'Duración máxima de un préstamo', tipo: 'entero',
    unidad: 'minutos', minimo: 5, maximo: 1440, publico: true, orden: 10, valor: null, actualizado_en: null },
]

const PRESTAMOS = [{
  id: 'pr-1', estado: 'finalizado', bici_codigo: 'BPV-003', bici_numero: 3, persona_id: 'per-1', tipo_documento: 'CC',
  numero_documento: '00100001', nombres: 'Ana', apellidos: 'Prueba', sexo_genero: 'mujer', edad_estimada: 30, es_menor: false,
  punto_salida: 'P01', punto_devolucion: 'P02', salida_en: AHORA, devuelto_en: AHORA, duracion_min: 42, con_novedad: false,
  devolucion_forzada: false, foto_contenido: 'persona_y_bici', foto_estado: 'almacenada', foto_ruta: 'prestamos/pr-1/salida.webp',
  operador_salida: 'Operador Demo', operador_devolucion: 'Operador Demo', motivo_cierre: null,
}]

async function simular(page, { rol = 'administrador', llamadas = [] } = {}) {
  const json = (r, cuerpo, status = 200) => r.fulfill({ status, contentType: 'application/json', body: JSON.stringify(cuerpo) })
  await page.route('**/auth/v1/token**', (r) => json(r, {
    access_token: jwtFalso(), token_type: 'bearer', expires_in: 3600, expires_at: Math.floor(Date.now() / 1000) + 3600,
    refresh_token: 'r', user: { id: 'u-adm', aud: 'authenticated', role: 'authenticated', email: 'admin@prueba.invalid' },
  }))
  await page.route('**/rest/v1/rpc/**', (r) => {
    const fn = new URL(r.request().url()).pathname.split('/').pop()
    llamadas.push({ fn, cuerpo: r.request().postDataJSON() })
    const respuestas = {
      mi_perfil: { id: 'u-adm', nombre: 'Admin Demo', rol, debe_cambiar_clave: false },
      tablero_resumen: TABLERO, registrar_exportacion: null,
    }
    return json(r, respuestas[fn] ?? null)
  })
  await page.route('**/rest/v1/parametros**', (r) => {
    if (r.request().method() === 'PATCH') {
      llamadas.push({ fn: 'actualizar_parametro', cuerpo: r.request().postDataJSON(), url: r.request().url() })
      return r.fulfill({ status: 204, body: '' })
    }
    return json(r, PARAMETROS)
  })
  await page.route('**/rest/v1/v_prestamos_admin**', (r) => json(r, PRESTAMOS))
  await page.route('**/rest/v1/puntos**', (r) => json(r, [{ id: 'p1', codigo: 'P01', nombre: 'Plaza (demo)', tipo: 'fijo', estado: 'activo' }]))
}

async function ingresar(page, destino) {
  await page.goto(`#/ingresar?ir=${destino}`)
  await page.getByLabel('Correo').fill('admin@prueba.invalid')
  await page.getByLabel('Clave').fill('clave-de-prueba')
  await page.getByRole('button', { name: 'Ingresar' }).click()
}

test.use({ viewport: { width: 1280, height: 900 } })

test('tablero: indicadores, alertas y gráfico con vista de tabla', async ({ page }) => {
  const errores = []
  page.on('pageerror', (e) => errores.push(e.message))
  await simular(page)
  await ingresar(page, '/admin')
  await expect(page.getByRole('heading', { name: 'Tablero' })).toBeVisible()
  await expect(page.locator('.indicador__valor').first()).toHaveText('118')
  await expect(page.getByText('1 préstamo(s) superan la duración máxima')).toBeVisible()
  await expect(page.getByText(/retención de fotos no está configurada/)).toBeVisible()
  await expect(page.locator('.col__marca')).toHaveCount(17)          // 5 h a 21 h
  await page.screenshot({ path: 'capturas/e2e-admin-1-tablero.png', fullPage: true })
  await page.locator('.col').nth(12).focus()                          // 17 h, por teclado
  await expect(page.locator('.tooltip')).toContainText('10 préstamos')
  await page.getByRole('button', { name: 'Ver tabla' }).click()
  await expect(page.getByRole('cell', { name: '17 h' })).toBeVisible()
  expect(errores).toEqual([])
})

test('parámetros: activar una regla envía solo el valor', async ({ page }) => {
  const llamadas = []
  await simular(page, { llamadas })
  await ingresar(page, '/admin/parametros')
  await expect(page.getByText('Duración máxima de un préstamo')).toBeVisible()
  await expect(page.getByText('No aplica', { exact: true })).toBeVisible()
  await page.getByRole('button', { name: 'Cambiar' }).click()
  await page.getByText('Esta regla aplica').click()
  await page.getByLabel('Valor (minutos)').fill('60')
  await page.getByRole('button', { name: 'Guardar' }).click()
  await expect.poll(() => llamadas.find((l) => l.fn === 'actualizar_parametro')).toBeTruthy()
  const patch = llamadas.find((l) => l.fn === 'actualizar_parametro')
  expect(patch.cuerpo).toEqual({ valor: 60 })
  expect(decodeURIComponent(patch.url)).toContain('clave=eq.reglas_uso.duracion_maxima_min')
})

test('etiquetas QR: 24 códigos con el enlace a la página de cada bici', async ({ page }) => {
  await simular(page)
  await ingresar(page, '/admin/etiquetas')
  await page.getByRole('button', { name: 'Generar' }).click()
  await expect(page.locator('.etiqueta')).toHaveCount(24)
  await expect(page.locator('.etiqueta__codigo').first()).toHaveText('BPV-001')
  await expect(page.locator('.etiqueta__codigo').last()).toHaveText('BPV-024')
  await expect(page.locator('.etiqueta__qr svg').first()).toBeVisible()
  await page.screenshot({ path: 'capturas/e2e-admin-2-etiquetas.png', fullPage: true })
})

test('préstamos: el CSV por defecto va sin datos personales y queda en la bitácora', async ({ page }) => {
  const llamadas = []
  await simular(page, { llamadas })
  await ingresar(page, '/admin/prestamos')
  await expect(page.getByRole('cell', { name: 'BPV-003' })).toBeVisible()
  const [descarga] = await Promise.all([
    page.waitForEvent('download'),
    page.getByRole('button', { name: /Descargar 1 fila/ }).click(),
  ])
  const csv = readFileSync(await descarga.path(), 'utf8')
  expect(csv.charCodeAt(0)).toBe(0xfeff)                                     // utf-8-sig
  expect(csv).not.toContain('00100001')
  expect(csv).not.toContain('nombres')
  expect(csv).toContain('BPV-003')
  expect(descarga.suggestedFilename()).toMatch(/^\d{4}-\d{2}-\d{2}_bicis_prestamos\.csv$/)
  expect(llamadas.find((l) => l.fn === 'registrar_exportacion').cuerpo.p_con_datos_personales).toBe(false)
})

test('un operador no entra a la administración', async ({ page }) => {
  await simular(page, { rol: 'operador' })
  await page.route('**/rest/v1/puntos**', (r) => r.fulfill({ status: 200, contentType: 'application/json', body: '[]' }))
  await ingresar(page, '/admin')
  await expect(page.getByRole('heading', { name: 'Turno del operador' })).toBeVisible()
  await expect(page.getByRole('link', { name: 'Administración' })).toHaveCount(0)
})
