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

const BICIS = Array.from({ length: 130 }, (_, i) => ({
  id: `b-${i + 1}`, numero: i + 1, codigo: `BPV-${String(i + 1).padStart(3, '0')}`, disponibilidad: 'disponible',
  condicion: 'operativa', punto_actual_id: 'p1', marca: null, modelo: null, color: null, talla: null, numero_serie: null,
  fecha_ingreso: null, nota_operativa: null, ultimo_movimiento_en: AHORA,
}))

const EVENTOS = [{
  id: 'ev-1', nombre: 'Ciclopaseo (demo)', descripcion: null, lugar_texto: 'Balneario (demo)',
  inicia_en: '2026-10-20T07:00:00-05:00', termina_en: '2026-10-20T12:00:00-05:00', estado: 'planeado', publicado: true,
}]

const PUNTOS = [
  { id: 'p1', codigo: 'P01', nombre: 'Plaza (demo)', tipo: 'fijo', estado: 'activo', evento_id: null, latitud: 10.477751,
    longitud: -73.244632, direccion: null, horario_texto: null, capacidad: null, notas_internas: null },
  { id: 'p9', codigo: 'E01', nombre: 'Balneario (demo)', tipo: 'evento', estado: 'activo', evento_id: 'ev-1', latitud: 10.49,
    longitud: -73.26, direccion: null, horario_texto: null, capacidad: null, notas_internas: null },
]

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
  await page.route('**/rest/v1/bicicletas**', (r) => json(r, BICIS))
  await page.route('**/rest/v1/incidencias**', (r) => json(r, []))
  await page.route('**/tile.openstreetmap.org/**', (r) => r.abort())
  // Altas y ediciones: se registran y se responde como PostgREST.
  for (const tabla of ['puntos', 'eventos']) {
    await page.route(`**/rest/v1/${tabla}**`, (r) => {
      const metodo = r.request().method()
      if (metodo === 'GET') return json(r, tabla === 'puntos' ? PUNTOS : EVENTOS)
      llamadas.push({ fn: `${metodo} ${tabla}`, cuerpo: r.request().postDataJSON(), url: r.request().url() })
      return metodo === 'POST' && tabla === 'eventos' ? json(r, { id: 'ev-nuevo' }, 201) : r.fulfill({ status: 204, body: '' })
    })
  }
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

// Las ventanas de edición se abren encima de la página, donde esté el usuario. Antes
// el panel de «Gestionar» quedaba ~7.400 px más abajo (tras 130 filas) y el de
// «Editar evento» arriba, fuera de la vista: los botones parecían no hacer nada.
test.describe('ventanas de edición (pantalla de portátil)', () => {
  test.use({ viewport: { width: 1366, height: 768 } })

  test('bicicletas: «Gestionar» abre la ficha a la vista; Esc la cierra y el foco vuelve', async ({ page }) => {
    await simular(page)
    await ingresar(page, '/admin/bicicletas')
    const boton = page.getByRole('row', { name: /BPV-001/ }).getByRole('button', { name: 'Gestionar' })
    await boton.click()
    const ficha = page.getByRole('dialog', { name: 'BPV-001' })
    await expect(ficha).toBeInViewport()
    await expect(ficha.getByRole('heading', { name: 'Condición física' })).toBeVisible()
    await page.screenshot({ path: 'capturas/e2e-admin-3-gestionar-bici.png' })
    await page.keyboard.press('Escape')
    await expect(ficha).toHaveCount(0)
    await expect(boton).toBeFocused()
  })

  test('eventos: el nuevo evento trae el mapa y crea el evento y luego su punto', async ({ page }) => {
    const llamadas = []
    await simular(page, { llamadas })
    await ingresar(page, '/admin/puntos')
    await page.getByRole('button', { name: 'Nuevo evento' }).click()
    const ventana = page.getByRole('dialog', { name: 'Nuevo evento' })
    await expect(ventana).toBeInViewport()
    await ventana.getByLabel('Nombre del evento').fill('Ciclopaseo nocturno (demo)')
    await ventana.getByLabel('Inicia (hora de Colombia)').fill('2026-10-25T18:00')
    await ventana.getByLabel('Termina').fill('2026-10-25T22:00')
    await ventana.getByText('Publicado (aparece').click()
    await expect(ventana.getByLabel('Código del punto (se imprime; no cambia)')).toHaveValue('E02')          // siguiente a E01
    await expect(ventana.getByText('Para guardar falta ubicar el punto de préstamo en el mapa.')).toBeVisible()
    await ventana.locator('.leaflet-container').click()                                  // centro del mapa
    await expect(ventana.getByLabel('Latitud')).not.toHaveValue('')
    await page.screenshot({ path: 'capturas/e2e-admin-4-nuevo-evento.png' })
    await ventana.getByRole('button', { name: 'Guardar evento' }).click()
    await expect(page.getByText('Evento «Ciclopaseo nocturno (demo)» guardado con su punto E02.')).toBeVisible()

    const escrituras = llamadas.filter((l) => l.fn.startsWith('POST'))
    expect(escrituras.map((l) => l.fn)).toEqual(['POST eventos', 'POST puntos'])
    expect(escrituras[0].cuerpo).toMatchObject({ nombre: 'Ciclopaseo nocturno (demo)', publicado: true,
      inicia_en: '2026-10-25T18:00:00-05:00', termina_en: '2026-10-25T22:00:00-05:00' })
    const punto = escrituras[1].cuerpo
    expect(punto).toMatchObject({ codigo: 'E02', tipo: 'evento', evento_id: 'ev-nuevo', estado: 'activo',
      nombre: 'Ciclopaseo nocturno (demo)' })
    expect(punto.latitud).toBeGreaterThan(10.3)
    expect(punto.latitud).toBeLessThan(10.6)
    expect(punto.longitud).toBeGreaterThan(-73.4)
    expect(punto.longitud).toBeLessThan(-73.1)
  })

  test('eventos: «Editar» desde la tabla de abajo abre el evento con sus puntos', async ({ page }) => {
    const llamadas = []
    await simular(page, { llamadas })
    const otros = ['P02', 'P03', 'P04', 'T01'].map((c, i) => ({ ...PUNTOS[0], id: `px${i}`, codigo: c }))
    await page.route('**/rest/v1/puntos**', (r) => (r.request().method() === 'GET'
      ? r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify([...PUNTOS, ...otros]) }) : r.fallback()))
    await ingresar(page, '/admin/puntos')
    await page.locator('table').nth(1).getByRole('button', { name: 'Editar' }).click()
    const ventana = page.getByRole('dialog', { name: 'Editar evento: Ciclopaseo (demo)' })
    await expect(ventana).toBeInViewport()
    await expect(ventana.getByLabel('Inicia (hora de Colombia)')).toHaveValue('2026-10-20T07:00')
    await expect(ventana.getByText('E01')).toBeVisible()
    await ventana.getByRole('button', { name: 'Agregar otro punto en el mapa' }).click()
    await expect(ventana.locator('.leaflet-container')).toBeVisible()
    await ventana.getByRole('button', { name: 'No agregar este punto' }).click()
    await ventana.getByLabel('Termina').fill('2026-10-20T13:00')
    await ventana.getByRole('button', { name: 'Guardar evento' }).click()
    await expect.poll(() => llamadas.find((l) => l.fn === 'PATCH eventos')).toBeTruthy()
    const patch = llamadas.find((l) => l.fn === 'PATCH eventos')
    expect(patch.cuerpo.termina_en).toBe('2026-10-20T13:00:00-05:00')
    expect(decodeURIComponent(patch.url)).toContain('id=eq.ev-1')
    expect(llamadas.some((l) => l.fn === 'POST puntos')).toBe(false)
  })
})

test('eliminar un evento nunca usado: avisa sus puntos, pide motivo y llama a eliminar_evento', async ({ page }) => {
  const llamadas = []
  await page.setViewportSize({ width: 1366, height: 768 })
  await simular(page, { llamadas })
  await ingresar(page, '/admin/puntos')
  await expect(page.locator('table').first().getByRole('row', { name: /P01/ }).getByRole('button', { name: 'Eliminar' })).toHaveCount(0)
  await page.locator('table').nth(1).getByRole('button', { name: 'Eliminar' }).click()
  const ventana = page.getByRole('dialog', { name: 'Eliminar el evento «Ciclopaseo (demo)»' })
  await expect(ventana).toBeInViewport()
  await expect(ventana.getByText('También se eliminan sus puntos: E01.')).toBeVisible()
  const boton = ventana.getByRole('button', { name: 'Eliminar definitivamente' })
  await expect(boton).toBeDisabled()
  await ventana.getByLabel('Motivo (queda en la auditoría)').fill('Evento de prueba creado por error')
  await boton.click()
  await expect.poll(() => llamadas.find((l) => l.fn === 'eliminar_evento')).toBeTruthy()
  expect(llamadas.find((l) => l.fn === 'eliminar_evento').cuerpo).toEqual({ p_evento_id: 'ev-1', p_motivo: 'Evento de prueba creado por error' })
  await expect(page.getByText('Se eliminó el evento «Ciclopaseo (demo)» y sus puntos (E01).')).toBeVisible()
})

test.describe('ventanas de préstamos y personas (pantalla de portátil)', () => {
  test.use({ viewport: { width: 1366, height: 768 } })

  test('préstamos: «Anular» abre la ventana a la vista y envía el motivo', async ({ page }) => {
    const llamadas = []
    await simular(page, { llamadas })
    const activos = Array.from({ length: 30 }, (_, i) => ({ ...PRESTAMOS[0], id: `pr-a${i}`, estado: 'activo', devuelto_en: null,
      duracion_min: null, bici_codigo: `BPV-${String(i + 10).padStart(3, '0')}`, bici_numero: i + 10 }))
    await page.route('**/rest/v1/v_prestamos_admin**', (r) => r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(activos) }))
    await ingresar(page, '/admin/prestamos')
    await page.getByRole('row', { name: /BPV-039/ }).getByRole('button', { name: 'Anular' }).click()
    const ventana = page.getByRole('dialog', { name: 'Anular préstamo · BPV-039' })
    await expect(ventana).toBeInViewport()
    await ventana.getByLabel('Motivo (queda en la auditoría)').fill('Registrado por error en la prueba')
    await ventana.getByRole('button', { name: 'Confirmar' }).click()
    await expect.poll(() => llamadas.find((l) => l.fn === 'anular_prestamo')).toBeTruthy()
    expect(llamadas.find((l) => l.fn === 'anular_prestamo').cuerpo.p_prestamo_id).toBe('pr-a29')
    await expect(ventana).toHaveCount(0)
  })

  test('préstamos: «Conservar» la foto pide motivo y llama a conservar_foto', async ({ page }) => {
    const llamadas = []
    await simular(page, { llamadas })
    await ingresar(page, '/admin/prestamos')
    await page.getByRole('row', { name: /BPV-003/ }).getByRole('button', { name: 'Conservar' }).click()
    const ventana = page.getByRole('dialog', { name: 'Conservar foto · BPV-003' })
    await expect(ventana).toBeInViewport()
    await ventana.getByLabel('Motivo (queda en la auditoría)').fill('Reclamo de la persona en trámite')
    await ventana.getByRole('button', { name: 'Confirmar' }).click()
    await expect.poll(() => llamadas.find((l) => l.fn === 'conservar_foto')).toBeTruthy()
    expect(llamadas.find((l) => l.fn === 'conservar_foto').cuerpo).toEqual({ p_prestamo_id: 'pr-1', p_motivo: 'Reclamo de la persona en trámite' })
  })

  test('personas: «Abrir» muestra la ficha a la vista', async ({ page }) => {
    await simular(page)
    const persona = { id: 'per-1', tipo_documento: 'CC', numero_documento: '00100001', nombres: 'Ana', apellidos: 'Prueba',
      estado: 'validada', origen: 'punto', creada_en: AHORA, telefono: '3001234567', correo: null, edad_declarada: 30,
      edad_declarada_en: '2026-10-07', sexo_genero: 'mujer', acudiente_id: null, acudiente_parentesco: null, validada_en: AHORA }
    await page.route('**/rest/v1/personas**', (r) => {
      const una = (r.request().headers().accept ?? '').includes('vnd.pgrst.object')
      return r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(una ? persona : Array(50).fill(persona)) })
    })
    for (const t of ['autorizaciones_datos', 'sanciones']) {
      await page.route(`**/rest/v1/${t}**`, (r) => r.fulfill({ status: 200, contentType: 'application/json', body: '[]' }))
    }
    await ingresar(page, '/admin/personas')
    await page.getByRole('button', { name: 'Abrir' }).first().click()
    const ficha = page.getByRole('dialog', { name: 'Ana Prueba' })
    await expect(ficha).toBeInViewport()
    await expect(ficha.getByText('CC 00100001')).toBeVisible()
  })
})

// Cada campo de una fila debe quedar dentro de la ventana y sin montarse sobre el
// vecino (antes, a 390 px, «Termina» se salía 76 px por la derecha y la etiqueta
// «Inicia (hora de Colombia)» pisaba la de «Termina»).
async function revisarFilas(ventana) {
  const problemas = await ventana.evaluate((d) => {
    const caja = d.getBoundingClientRect()
    const fuera = []
    for (const fila of d.querySelectorAll('.fila-campos')) {
      const hijos = [...fila.children].map((h) => ({ texto: h.textContent.trim().slice(0, 30), r: h.getBoundingClientRect() }))
      for (const h of hijos) {
        if (h.r.left < caja.left - 0.5 || h.r.right > caja.right + 0.5) fuera.push(`«${h.texto}» se sale de la ventana`)
        const control = fila.querySelector(':scope > * input, :scope > * select')
        if (control && control.scrollWidth > control.clientWidth + 1 && control.type !== 'date' && control.type !== 'datetime-local') {
          fuera.push(`«${h.texto}» recorta su contenido`)
        }
      }
      for (let a = 0; a < hijos.length; a++) {
        for (let b = a + 1; b < hijos.length; b++) {
          const [x, y] = [hijos[a].r, hijos[b].r]
          if (x.left < y.right - 0.5 && y.left < x.right - 0.5 && x.top < y.bottom - 0.5 && y.top < x.bottom - 0.5) {
            fuera.push(`«${hijos[a].texto}» se traslapa con «${hijos[b].texto}»`)
          }
        }
      }
    }
    return fuera
  })
  expect(problemas).toEqual([])
}

test.describe('formularios en el celular (390 px)', () => {
  test.use({ viewport: { width: 390, height: 844 } })

  test('nuevo evento: las fechas no se traslapan y se leen completas', async ({ page }) => {
    await simular(page)
    await ingresar(page, '/admin/puntos')
    await page.getByRole('button', { name: 'Nuevo evento' }).click()
    const ventana = page.getByRole('dialog', { name: 'Nuevo evento' })
    await expect(ventana).toBeVisible()
    await revisarFilas(ventana)
    const inicia = await ventana.getByLabel('Inicia (hora de Colombia)').boundingBox()
    expect(inicia.width).toBeGreaterThanOrEqual(14 * 16 - 1)             // no se encoge hasta recortar la fecha
    await page.screenshot({ path: 'capturas/e2e-admin-5-evento-movil.png' })
  })

  test('gestionar bici: los campos caben en la ventana', async ({ page }) => {
    await simular(page)
    await ingresar(page, '/admin/bicicletas')
    await page.getByRole('row', { name: /BPV-001/ }).getByRole('button', { name: 'Gestionar' }).click()
    const ventana = page.getByRole('dialog', { name: 'BPV-001' })
    await expect(ventana).toBeVisible()
    await revisarFilas(ventana)
  })
})

test('«Módulo operación» (ingreso del personal) está en la cabecera, también en el celular', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.route('**/rest/v1/**', (r) => r.fulfill({ status: 200, contentType: 'application/json', body: '[]' }))
  await page.goto('#/')
  const enlace = page.getByRole('banner').getByRole('link', { name: 'Módulo operación' })
  await expect(enlace).toBeInViewport()
  await page.screenshot({ path: 'capturas/e2e-cabecera-movil.png' })
  await enlace.click()
  await expect(page.getByLabel('Correo')).toBeVisible()
})
