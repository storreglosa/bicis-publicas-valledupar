// Graba los clips del modo «Presentar» (src/vistas/publico/Presentacion.vue) sobre el
// build de la demo servido en local:
//   npx vite build --mode development --outDir dist-demo
//   npx vite preview --mode development --outDir dist-demo --port 4174
//   node scripts/grabar_presentacion.mjs
// Deja en public/presentacion/: ciudadano.webm, operador.webm, admin.webm, bici.png y
// clips.json (segundo del video donde empieza lo que se muestra; antes está el ingreso).
// Ciudadano: páginas públicas reales de la demo (dev). Operador y Secretaría: servidor
// simulado con datos ficticios (documentos 00…), para que el clip sea siempre igual.
import { chromium } from '@playwright/test'
import { mkdirSync, renameSync, rmSync, writeFileSync } from 'node:fs'
import { homedir, tmpdir } from 'node:os'
import { join } from 'node:path'

const BASE = process.env.BASE_URL ?? 'http://localhost:4174/bicis-publicas-valledupar/'
const DESTINO = new URL('../public/presentacion/', import.meta.url).pathname
const TEMPORAL = join(tmpdir(), `clips-${process.pid}`)
const AHORA = new Date().toISOString()
mkdirSync(DESTINO, { recursive: true })
mkdirSync(TEMPORAL, { recursive: true })

const navegador = await chromium.launch({ executablePath: `${homedir()}/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome` })
const espera = (ms) => new Promise((r) => setTimeout(r, ms))
const inicios = {}

// Círculo que marca cada toque (en el video no se ve el puntero).
const TOQUES = () => {
  addEventListener('pointerdown', (e) => {
    const c = document.createElement('div')
    c.style.cssText = `position:fixed;left:${e.clientX - 22}px;top:${e.clientY - 22}px;width:44px;height:44px;border-radius:50%;` +
      'background:rgba(180,70,10,.35);border:3px solid #b4460a;pointer-events:none;z-index:99999;transition:transform .6s,opacity .6s'
    document.body.appendChild(c)
    requestAnimationFrame(() => { c.style.transform = 'scale(1.6)'; c.style.opacity = '0' })
    setTimeout(() => c.remove(), 700)
  }, true)
}

async function clip(nombre, ancho, alto, guion) {
  const contexto = await navegador.newContext({ viewport: { width: ancho, height: alto },
    recordVideo: { dir: TEMPORAL, size: { width: ancho, height: alto } } })
  const comienzo = Date.now()
  const pagina = await contexto.newPage()
  await pagina.addInitScript(TOQUES)
  await guion(pagina, () => { inicios[nombre] = Math.max(0, (Date.now() - comienzo) / 1000 - 0.3) })
  const video = pagina.video()
  await contexto.close()
  renameSync(await video.path(), join(DESTINO, `${nombre}.webm`))
  console.log(`clip ${nombre}: listo (empieza en ${inicios[nombre]?.toFixed(1)} s)`)
}

// --- Servidor simulado (datos ficticios) -------------------------------------
function jwtFalso(sub) {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url')
  return `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64({ sub, role: 'authenticated', exp: Math.floor(Date.now() / 1000) + 3600 })}.firma`
}
const json = (r, cuerpo, status = 200) => r.fulfill({ status, contentType: 'application/json', body: JSON.stringify(cuerpo) })

async function simularSesion(pagina, rol) {
  const sub = rol === 'administrador' ? 'u-adm' : 'u-op'
  await pagina.route('**/auth/v1/token**', (r) => json(r, {
    access_token: jwtFalso(sub), token_type: 'bearer', expires_in: 3600, expires_at: Math.floor(Date.now() / 1000) + 3600,
    refresh_token: 'r', user: { id: sub, aud: 'authenticated', role: 'authenticated', email: 'demo@prueba.invalid' },
  }))
}

const PERSONA = {
  id: 'per-1', tipo_documento: 'CC', tipo_documento_nombre: 'Cédula de ciudadanía', documento_enmascarado: '****0001',
  nombres: 'Laura Marcela', apellidos: 'Gómez Ruiz', telefono_enmascarado: '****0000', edad_estimada: 27, es_menor: false,
  estado: 'preinscrita', acudiente: null, politica_vigente: '1.0', autorizacion_vigente: true, autoriza_foto: true,
  autorizacion_presencial: false, sancion: null, prestamos_activos: 0,
}

async function simularOperador(pagina) {
  await simularSesion(pagina, 'operador')
  await pagina.route('**/rest/v1/rpc/**', (r) => {
    const fn = new URL(r.request().url()).pathname.split('/').pop()
    const cuerpo = r.request().postDataJSON() ?? {}
    const respuestas = {
      mi_perfil: { id: 'u-op', nombre: 'Operador de turno', rol: 'operador', debe_cambiar_clave: false },
      buscar_persona: PERSONA,
      validar_persona: { ...PERSONA, estado: 'validada' },
      prestamos_activos: [],
      registrar_prestamo: { prestamo_id: cuerpo.p_id, estado: 'activo', codigo: 'BPV-015', salida_en: AHORA, vence_en: null, ahora_servidor: AHORA },
    }
    return json(r, respuestas[fn] ?? null)
  })
  await pagina.route('**/rest/v1/puntos**', (r) => json(r, [
    { id: 'p1', codigo: 'P01', nombre: 'Plaza Alfonso López', tipo: 'fijo', estado: 'activo' },
    { id: 'p2', codigo: 'P02', nombre: 'Parque Novalito', tipo: 'fijo', estado: 'activo' }]))
  await pagina.route('**/rest/v1/tipos_documento**', (r) => json(r, [
    { codigo: 'CC', nombre: 'Cédula de ciudadanía', implica_menor: false },
    { codigo: 'TI', nombre: 'Tarjeta de identidad', implica_menor: true }]))
  await pagina.route('**/rest/v1/politicas_tratamiento**', (r) => json(r, { version: '1.0',
    texto_autorizacion: 'Autorizo el tratamiento de mis datos personales.', texto_autorizacion_foto: 'Autorizo la foto de evidencia.' }))
  await pagina.route('**/rest/v1/parametros**', (r) => json(r, { valor: true }))
  await pagina.route('**/rest/v1/bicicletas**', (r) => json(r, [7, 12, 15, 21, 28, 34].map((n) => (
    { id: `b${n}`, numero: n, codigo: `BPV-${String(n).padStart(3, '0')}` }))))
  await pagina.route('**/rest/v1/incidencias**', (r) => json(r, []))
  await pagina.route('**/storage/v1/object/evidencias/**', (r) => json(r, { Key: 'evidencias/x', Id: 'obj-1' }))
}

const HORAS = [[6, 3], [7, 9], [8, 12], [9, 6], [10, 4], [11, 5], [12, 8], [13, 7], [14, 4], [15, 5], [16, 9], [17, 14], [18, 11]]
const TABLERO = {
  ahora_servidor: AHORA,
  bicis: { total: 130, disponible: 112, prestada: 13, no_disponible: 5, averiada: 2, en_reparacion: 3, extraviada: 0, baja: 0 },
  prestamos_hoy: 97, prestamos_activos: 13, prestamos_vencidos: 0,
  por_hora_hoy: HORAS.map(([hora, prestamos]) => ({ hora, prestamos })),
  por_punto: [
    { codigo: 'P01', nombre: 'Plaza Alfonso López', tipo: 'fijo', disponibles: 31, total: 35 },
    { codigo: 'P02', nombre: 'Parque Novalito', tipo: 'fijo', disponibles: 24, total: 30 },
    { codigo: 'P03', nombre: 'Universidad Popular del Cesar', tipo: 'fijo', disponibles: 27, total: 30 },
    { codigo: 'E01', nombre: 'Balneario Hurtado (evento)', tipo: 'evento', disponibles: 8, total: 10 }],
  incidencias_abiertas: 1, preinscritas_sin_validar: 6, retencion_fotos_dias: 7,
  storage_bytes: 46 * 1024 ** 2, bd_bytes: 18 * 1024 ** 2, ultimo_respaldo: AHORA, ultima_purga: { fin: AHORA, resultado: 'ok' },
}
const NOMBRES = [['Laura Marcela', 'Gómez'], ['Andrés', 'Mejía'], ['Valentina', 'Rojas'], ['Carlos', 'Daza'],
  ['Sofía', 'Arias'], ['Juan David', 'Quintero'], ['Mariana', 'Pérez'], ['Luis', 'Fuentes'], ['Daniela', 'Ospino']]
const PRESTAMOS = NOMBRES.map(([nombres, apellidos], i) => ({
  id: `pr-${i}`, estado: i < 3 ? 'activo' : 'finalizado', bici_codigo: `BPV-${String(7 + i * 9).padStart(3, '0')}`, bici_numero: 7 + i * 9,
  persona_id: `per-${i}`, tipo_documento: 'CC', numero_documento: `0010000${i}`, nombres, apellidos, sexo_genero: i % 2 ? 'hombre' : 'mujer',
  edad_estimada: 20 + i * 4, es_menor: false, punto_salida: ['P01', 'P02', 'P03'][i % 3], punto_devolucion: i < 3 ? null : ['P02', 'P01', 'P03'][i % 3],
  salida_en: new Date(Date.now() - (i + 1) * 47 * 60000).toISOString(), devuelto_en: i < 3 ? null : new Date(Date.now() - i * 20 * 60000).toISOString(),
  duracion_min: i < 3 ? null : 25 + i * 6, con_novedad: i === 5, devolucion_forzada: false, foto_contenido: 'persona_y_bici',
  foto_estado: 'almacenada', foto_ruta: `prestamos/pr-${i}/salida.webp`, foto_retener: false,
  operador_salida: 'Operador de turno', operador_devolucion: i < 3 ? null : 'Operador de turno', motivo_cierre: null,
}))
const PUNTOS_ADMIN = [
  ['p1', 'P01', 'Plaza Alfonso López', 10.477751, -73.244632], ['p2', 'P02', 'Parque Novalito', 10.48167, -73.248189],
  ['p3', 'P03', 'Universidad Popular del Cesar', 10.449123, -73.262523]].map(([id, codigo, nombre, latitud, longitud]) => (
  { id, codigo, nombre, tipo: 'fijo', estado: 'activo', evento_id: null, latitud, longitud, direccion: null, horario_texto: null, capacidad: null, notas_internas: null }))
const BICIS = Array.from({ length: 130 }, (_, i) => ({
  id: `b-${i + 1}`, numero: i + 1, codigo: `BPV-${String(i + 1).padStart(3, '0')}`,
  disponibilidad: i % 11 === 3 ? 'prestada' : i % 29 === 5 ? 'no_disponible' : 'disponible',
  condicion: i % 29 === 5 ? 'en_reparacion' : 'operativa', punto_actual_id: i % 11 === 3 ? null : ['p1', 'p2', 'p3'][i % 3],
  marca: 'GW', modelo: 'Urbana', color: 'Naranja', talla: 'M', numero_serie: null, fecha_ingreso: '2026-10-07', nota_operativa: null,
  ultimo_movimiento_en: new Date(Date.now() - (i % 17) * 3600000).toISOString(),
}))

async function simularAdmin(pagina) {
  await simularSesion(pagina, 'administrador')
  await pagina.route('**/rest/v1/rpc/**', (r) => {
    const fn = new URL(r.request().url()).pathname.split('/').pop()
    const respuestas = { mi_perfil: { id: 'u-adm', nombre: 'Administración', rol: 'administrador', debe_cambiar_clave: false }, tablero_resumen: TABLERO }
    return json(r, respuestas[fn] ?? null)
  })
  await pagina.route('**/rest/v1/v_prestamos_admin**', (r) => json(r, PRESTAMOS))
  await pagina.route('**/rest/v1/puntos**', (r) => json(r, PUNTOS_ADMIN))
  await pagina.route('**/rest/v1/bicicletas**', (r) => json(r, BICIS))
  await pagina.route('**/rest/v1/eventos**', (r) => json(r, []))
  await pagina.route('**/rest/v1/incidencias**', (r) => json(r, []))
}

// Foto de evidencia ilustrada (no es una foto real de nadie).
async function fotoIlustrada() {
  const p = await navegador.newPage({ viewport: { width: 640, height: 480 } })
  await p.setContent(`<body style="margin:0"><svg width="640" height="480" viewBox="0 0 640 480" xmlns="http://www.w3.org/2000/svg">
    <rect width="640" height="480" fill="#f3e3cf"/><rect y="330" width="640" height="150" fill="#d9c2a3"/>
    <g fill="none" stroke="#2b2622" stroke-width="10" stroke-linecap="round">
      <circle cx="230" cy="350" r="62"/><circle cx="420" cy="350" r="62"/>
      <path d="M230 350 L300 260 L380 260 L420 350 M300 260 L330 350 L380 260 M290 240 L320 240 M380 260 L372 228 L400 222"/></g>
    <circle cx="470" cy="150" r="34" fill="#b4460a"/><path d="M470 184 L470 290 M470 210 L410 252 M470 210 L520 250 M470 290 L440 360 M470 290 L500 360"
      stroke="#b4460a" stroke-width="18" stroke-linecap="round" fill="none"/>
    <text x="24" y="460" font-family="sans-serif" font-size="22" fill="#5b4a3c">Foto de evidencia (ilustración de demostración)</text></svg></body>`)
  const ruta = join(TEMPORAL, 'foto.png')
  await p.screenshot({ path: ruta })
  await p.close()
  return ruta
}

const lento = (loc, texto) => loc.pressSequentially(texto, { delay: 140 })

// --- 1. Ciudadano (páginas reales de la demo) --------------------------------
await clip('ciudadano', 390, 844, async (p, marcar) => {
  await p.goto(BASE + '#/')
  await p.locator('main h1').first().waitFor()
  marcar()
  await espera(3500)
  await p.mouse.wheel(0, 520); await espera(2500)
  await p.getByRole('banner').getByRole('link', { name: 'Mapa' }).click()
  await p.locator('.leaflet-container').waitFor(); await espera(6500)
  await p.getByRole('banner').getByRole('link', { name: 'Eventos' }).click(); await espera(3500)
  await p.getByRole('banner').getByRole('link', { name: 'Reglas' }).click(); await espera(2500)
  await p.mouse.wheel(0, 600); await espera(2000)
  await p.getByRole('banner').getByRole('link', { name: 'Inscribirme' }).click(); await espera(3500)
})

// Página de la bici (para la escena del QR)
{
  const p = await navegador.newPage({ viewport: { width: 390, height: 844 } })
  await p.goto(BASE + '#/b/BPV-015')
  await p.locator('main h1').first().waitFor(); await espera(800)
  await p.screenshot({ path: join(DESTINO, 'bici.png') })
  await p.close()
}

// --- 2. Operador (simulado) --------------------------------------------------
const FOTO = await fotoIlustrada()
await clip('operador', 390, 844, async (p, marcar) => {
  await simularOperador(p)
  await p.goto(BASE + '#/operador')
  await p.getByLabel('Correo').fill('operador@prueba.invalid')
  await p.getByLabel('Clave').fill('clave-de-prueba')
  await p.getByRole('button', { name: 'Ingresar' }).click()
  await p.getByRole('button', { name: /P01 · Plaza Alfonso López/ }).click()
  await p.getByText('Turno del operador').waitFor()
  marcar()
  await espera(2500)
  await p.getByRole('link', { name: /Prestar/ }).click(); await espera(1200)
  await lento(p.getByLabel('Número del documento'), '00100001'); await espera(500)
  await p.getByRole('button', { name: 'Buscar' }).click(); await espera(2200)
  await p.getByText('Vi el documento original').click(); await espera(900)
  await p.getByRole('button', { name: 'Validar y continuar' }).click(); await espera(1800)
  await p.getByRole('button', { name: '015' }).click(); await espera(1500)
  await p.getByRole('button', { name: 'Continuar' }).click(); await espera(1500)
  await p.locator('input[type=file]').setInputFiles(FOTO)
  await p.getByText(/Foto guardada/).waitFor(); await espera(2500)
  await p.getByRole('button', { name: 'Continuar' }).click(); await espera(2500)
  await p.getByRole('button', { name: 'Prestar', exact: true }).click()
  await p.getByText('Préstamo registrado').waitFor(); await espera(5000)
})

// --- 3. Secretaría (simulado) ------------------------------------------------
await clip('admin', 1280, 800, async (p, marcar) => {
  await simularAdmin(p)
  await p.goto(BASE + '#/ingresar?ir=/admin')
  await p.getByLabel('Correo').fill('admin@prueba.invalid')
  await p.getByLabel('Clave').fill('clave-de-prueba')
  await p.getByRole('button', { name: 'Ingresar' }).click()
  await p.getByRole('heading', { name: 'Tablero' }).waitFor(); await espera(600)
  marcar()
  await espera(3000)
  await p.locator('.col').nth(12).hover(); await espera(2200)
  await p.mouse.wheel(0, 420); await espera(2500)
  await p.getByRole('navigation', { name: 'Administración' }).getByRole('link', { name: 'Préstamos' }).click(); await espera(4500)
  await p.getByRole('navigation', { name: 'Administración' }).getByRole('link', { name: 'Bicicletas' }).click(); await espera(3000)
  await p.getByRole('row', { name: /BPV-015/ }).getByRole('button', { name: 'Gestionar' }).click(); await espera(3500)
  await p.keyboard.press('Escape'); await espera(800)
  await p.getByRole('navigation', { name: 'Administración' }).getByRole('link', { name: 'Etiquetas QR' }).click(); await espera(1200)
  await p.getByRole('button', { name: 'Generar' }).click(); await espera(5000)
})

writeFileSync(join(DESTINO, 'clips.json'), JSON.stringify(inicios, null, 2) + '\n')
await navegador.close()
rmSync(TEMPORAL, { recursive: true, force: true })
console.log('listo:', DESTINO)
