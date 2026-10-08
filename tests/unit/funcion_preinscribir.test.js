// Edge Function preinscribir (supabase/functions/preinscribir/nucleo.js) con
// Request/Response reales de Node; Turnstile y la base, simulados.
import { describe, expect, it, vi } from 'vitest'
import { crearHuellaIp, crearManejador, crearVerificadorTurnstile, ipDe, LIMITE_BYTES } from '../../supabase/functions/preinscribir/nucleo.js'

const ORIGEN = 'https://storreglosa.github.io'
const PERSONA = { id_operacion: '0b9f6a52-4e1e-4b8e-9c55-2f1f6f0e1a11', tipo_documento: 'CC', numero_documento: '00100001' }

function preparar(cambios = {}) {
  const llamadas = { turnstile: [], rpc: [] }
  const manejador = crearManejador({
    origenesPermitidos: [ORIGEN, 'http://localhost:5173'],
    configuracionCompleta: true,
    verificarTurnstile: async (...a) => { llamadas.turnstile.push(a); return true },
    huellaIp: async (ip) => `huella-de-${ip}`,
    preinscribir: async (persona, huella) => { llamadas.rpc.push({ persona, huella }); return { data: { resultado: 'inscrito' }, error: null } },
    registrar: vi.fn(),
    ...cambios,
  })
  return { manejador, llamadas }
}

const pedir = (cuerpo, { origen = ORIGEN, metodo = 'POST', encabezados = {} } = {}) => new Request('https://x.supabase.co/functions/v1/preinscribir', {
  method: metodo,
  headers: { origin: origen, 'content-type': 'application/json', 'cf-connecting-ip': '203.0.113.7', ...encabezados },
  body: metodo === 'POST' ? (typeof cuerpo === 'string' ? cuerpo : JSON.stringify(cuerpo)) : undefined,
})

describe('preinscribir', () => {
  it('inscribe: verifica Turnstile con la IP y pasa solo la huella a la base', async () => {
    const { manejador, llamadas } = preparar()
    const r = await manejador(pedir({ persona: PERSONA, turnstile: 'tok' }))
    expect(r.status).toBe(200)
    expect(await r.json()).toEqual({ resultado: 'inscrito' })
    expect(r.headers.get('access-control-allow-origin')).toBe(ORIGEN)
    expect(llamadas.turnstile).toEqual([['tok', '203.0.113.7', PERSONA.id_operacion]])
    expect(llamadas.rpc).toEqual([{ persona: PERSONA, huella: 'huella-de-203.0.113.7' }])
  })

  it('«ya inscrito» sale igual, sin ningún dato de la persona', async () => {
    const { manejador } = preparar({ preinscribir: async () => ({ data: { resultado: 'ya_inscrito', persona_id: 'x' }, error: null }) })
    const r = await manejador(pedir({ persona: PERSONA, turnstile: 'tok' }))
    expect(await r.json()).toEqual({ resultado: 'ya_inscrito' })
  })

  it('preflight: responde solo a orígenes permitidos', async () => {
    const { manejador } = preparar()
    expect((await manejador(pedir(null, { metodo: 'OPTIONS' }))).status).toBe(204)
    const ajeno = await manejador(pedir(null, { metodo: 'OPTIONS', origen: 'https://otro.example' }))
    expect(ajeno.status).toBe(403)
    expect(ajeno.headers.get('access-control-allow-origin')).toBeNull()
  })

  it('rechaza otro origen sin tocar Turnstile ni la base', async () => {
    const { manejador, llamadas } = preparar()
    const r = await manejador(pedir({ persona: PERSONA, turnstile: 'tok' }, { origen: 'https://otro.example' }))
    expect(r.status).toBe(403)
    expect(llamadas.turnstile).toEqual([])
    expect(llamadas.rpc).toEqual([])
  })

  it('rechaza cuerpos grandes, JSON roto y formas inválidas', async () => {
    const { manejador, llamadas } = preparar()
    expect((await manejador(pedir({ persona: PERSONA, turnstile: 'x'.repeat(LIMITE_BYTES) }))).status).toBe(413)
    expect(await (await manejador(pedir('{roto'))).json()).toEqual({ error: 'datos_invalidos' })
    expect((await manejador(pedir({ persona: PERSONA }))).status).toBe(400)
    expect((await manejador(pedir({ persona: [1], turnstile: 'tok' }))).status).toBe(400)
    expect(llamadas.rpc).toEqual([])
  })

  it('token de Turnstile inválido: no llega a la base', async () => {
    const { manejador, llamadas } = preparar({ verificarTurnstile: async () => false })
    const r = await manejador(pedir({ persona: PERSONA, turnstile: 'tok' }))
    expect(r.status).toBe(403)
    expect(await r.json()).toEqual({ error: 'verificacion_fallida' })
    expect(llamadas.rpc).toEqual([])
  })

  it('sin IP o sin secretos no atiende (no se comparte un cupo entre todos)', async () => {
    const { manejador } = preparar()
    const sinIp = new Request('https://x/f', { method: 'POST', headers: { origin: ORIGEN }, body: JSON.stringify({ persona: PERSONA, turnstile: 't' }) })
    expect((await manejador(sinIp)).status).toBe(500)
    const { manejador: m2 } = preparar({ configuracionCompleta: false })
    expect((await m2(pedir({ persona: PERSONA, turnstile: 'tok' }))).status).toBe(500)
  })

  it('pasa los códigos de negocio y oculta los errores internos', async () => {
    const limite = preparar({ preinscribir: async () => ({ data: null, error: { message: 'demasiados_intentos', code: 'P0001' } }) })
    const r1 = await limite.manejador(pedir({ persona: PERSONA, turnstile: 'tok' }))
    expect(r1.status).toBe(429)
    expect(await r1.json()).toEqual({ error: 'demasiados_intentos' })

    const interno = preparar({ preinscribir: async () => ({ data: null, error: { message: 'permission denied for function preinscribir', code: '42501' } }) })
    const r2 = await interno.manejador(pedir({ persona: PERSONA, turnstile: 'tok' }))
    expect(r2.status).toBe(500)
    expect(await r2.json()).toEqual({ error: 'error_interno' })
  })

  it('la IP sale de cf-connecting-ip antes que de x-forwarded-for (que el visitante puede falsificar)', () => {
    const h = (o) => new Request('https://x/f', { headers: o })
    expect(ipDe(h({ 'cf-connecting-ip': '203.0.113.7', 'x-forwarded-for': '1.2.3.4, 203.0.113.7' }))).toBe('203.0.113.7')
    expect(ipDe(h({ 'x-forwarded-for': ' 198.51.100.2 , 10.0.0.1' }))).toBe('198.51.100.2')
    expect(ipDe(h({}))).toBe('')
  })
})

describe('huella de la IP', () => {
  it('es HMAC hexadecimal de 64, cambia con la sal y con el día de Colombia', async () => {
    const dia = (iso) => () => new Date(iso)
    const a = await crearHuellaIp('s'.repeat(32), dia('2026-10-08T03:00:00Z'))('203.0.113.7')   // 7 oct. en Colombia
    const b = await crearHuellaIp('s'.repeat(32), dia('2026-10-08T04:59:00Z'))('203.0.113.7')   // sigue 7 oct.
    const c = await crearHuellaIp('s'.repeat(32), dia('2026-10-08T05:01:00Z'))('203.0.113.7')   // ya 8 oct.
    const d = await crearHuellaIp('t'.repeat(32), dia('2026-10-08T03:00:00Z'))('203.0.113.7')
    expect(a).toMatch(/^[0-9a-f]{64}$/)
    expect(a).toBe(b)
    expect(a).not.toBe(c)
    expect(a).not.toBe(d)
    expect(a).not.toContain('203')
  })
})

describe('verificación de Turnstile', () => {
  it('manda secreto, token, IP y clave de idempotencia; acepta solo success === true', async () => {
    const fetchFn = vi.fn(async () => new Response(JSON.stringify({ success: true })))
    expect(await crearVerificadorTurnstile('secreto', fetchFn)('tok', '203.0.113.7', 'op-1')).toBe(true)
    const [url, opciones] = fetchFn.mock.calls[0]
    expect(url).toBe('https://challenges.cloudflare.com/turnstile/v0/siteverify')
    expect(JSON.parse(opciones.body)).toEqual({ secret: 'secreto', response: 'tok', remoteip: '203.0.113.7', idempotency_key: 'op-1' })
    const no = vi.fn(async () => new Response(JSON.stringify({ success: false, 'error-codes': ['invalid-input-response'] })))
    expect(await crearVerificadorTurnstile('secreto', no)('tok', 'ip')).toBe(false)
    const caido = vi.fn(async () => new Response('', { status: 502 }))
    expect(await crearVerificadorTurnstile('secreto', caido)('tok', 'ip')).toBe(false)
  })
})
