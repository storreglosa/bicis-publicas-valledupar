// Lógica de la preinscripción pública (diseño §4), sin APIs de Deno: se prueba
// con vitest en Node (tests/unit/funcion_preinscribir.test.js). index.ts solo
// conecta esto con el entorno de Supabase.
//
// Orden: origen permitido → tamaño → forma del cuerpo → Turnstile → huella de la
// IP → RPC preinscribir (que aplica el límite de intentos). Responde solo
// {resultado: 'inscrito' | 'ya_inscrito'} o {error: '<código>'}: nunca datos.

export const LIMITE_BYTES = 4096
const SITEVERIFY = 'https://challenges.cloudflare.com/turnstile/v0/siteverify'
const CODIGO_NEGOCIO = /^[a-z_]{3,60}$/

function json(cuerpo, status, encabezados = {}) {
  return new Response(JSON.stringify(cuerpo), {
    status, headers: { 'content-type': 'application/json; charset=utf-8', ...encabezados },
  })
}

export function encabezadosCors(origen) {
  return {
    'access-control-allow-origin': origen,
    'access-control-allow-methods': 'POST, OPTIONS',
    'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
    'access-control-max-age': '86400',
    vary: 'Origin',
  }
}

// IP del visitante. cf-connecting-ip la fija Cloudflare (el visitante no puede
// falsificarla); el primer valor de x-forwarded-for sí lo puede escribir él, por eso
// queda de último recurso. Sin IP, todos compartirían un mismo cupo: se rechaza.
export function ipDe(req) {
  const h = req.headers
  return (h.get('cf-connecting-ip') ?? h.get('x-real-ip') ?? h.get('x-forwarded-for')?.split(',')[0] ?? '').trim()
}

// HMAC-SHA256(sal secreta, fecha de Colombia | IP) en hexadecimal. La base solo ve
// esto; sin la sal no se puede recuperar la IP probando las 2^32 direcciones.
export function crearHuellaIp(sal, ahora = () => new Date()) {
  return async (ip) => {
    const fecha = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Bogota' }).format(ahora())
    const clave = await crypto.subtle.importKey('raw', new TextEncoder().encode(sal), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
    const firma = await crypto.subtle.sign('HMAC', clave, new TextEncoder().encode(`${fecha}|${ip}`))
    return [...new Uint8Array(firma)].map((b) => b.toString(16).padStart(2, '0')).join('')
  }
}

// Verificación del token en Cloudflare (válido 300 s y de un solo uso). La clave de
// idempotencia evita que un reintento de red gaste el token dos veces.
export function crearVerificadorTurnstile(secreto, fetchFn = fetch) {
  return async (token, ip, idempotencia) => {
    const cuerpo = { secret: secreto, response: token, remoteip: ip }
    if (idempotencia) cuerpo.idempotency_key = idempotencia
    const r = await fetchFn(SITEVERIFY, {
      method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(cuerpo),
    })
    if (!r.ok) return false
    const datos = await r.json()
    return datos.success === true
  }
}

export function crearManejador({ origenesPermitidos, configuracionCompleta, verificarTurnstile, huellaIp,
  preinscribir, registrar = console.error }) {
  return async (req) => {
    const origen = req.headers.get('origin') ?? ''
    const permitido = origenesPermitidos.includes(origen)
    const cors = permitido ? encabezadosCors(origen) : { vary: 'Origin' }

    if (req.method === 'OPTIONS') return new Response(null, { status: permitido ? 204 : 403, headers: cors })
    if (!permitido) return json({ error: 'origen_no_permitido' }, 403, cors)
    if (req.method !== 'POST') return json({ error: 'metodo_no_permitido' }, 405, cors)
    if (!configuracionCompleta) {
      registrar('preinscribir: faltan secretos de la función')
      return json({ error: 'error_interno' }, 500, cors)
    }

    const texto = await req.text()
    if (new TextEncoder().encode(texto).length > LIMITE_BYTES) return json({ error: 'solicitud_demasiado_grande' }, 413, cors)
    let cuerpo
    try { cuerpo = JSON.parse(texto) } catch { return json({ error: 'datos_invalidos' }, 400, cors) }
    const persona = cuerpo?.persona
    const token = cuerpo?.turnstile
    if (typeof token !== 'string' || !token || token.length > 2048 || !persona || typeof persona !== 'object' || Array.isArray(persona)) {
      return json({ error: 'datos_invalidos' }, 400, cors)
    }

    const ip = ipDe(req)
    if (!ip) {
      registrar('preinscribir: la petición llegó sin IP del visitante')
      return json({ error: 'error_interno' }, 500, cors)
    }
    let tokenValido
    try {
      tokenValido = await verificarTurnstile(token, ip, typeof persona.id_operacion === 'string' ? persona.id_operacion : undefined)
    } catch {
      registrar('preinscribir: no se pudo consultar Turnstile')
      return json({ error: 'verificacion_no_disponible' }, 503, cors)
    }
    if (!tokenValido) return json({ error: 'verificacion_fallida' }, 403, cors)

    const { data, error } = await preinscribir(persona, await huellaIp(ip))
    if (error) {
      // Los errores de negocio llegan como un código ('demasiados_intentos',
      // 'documento_invalido'…): se devuelven tal cual para que la página los traduzca.
      const codigo = String(error.message ?? '')
      if (CODIGO_NEGOCIO.test(codigo)) return json({ error: codigo }, codigo === 'demasiados_intentos' ? 429 : 400, cors)
      registrar(`preinscribir: error de la base ${error.code ?? ''}`)   // nunca el detalle ni los datos
      return json({ error: 'error_interno' }, 500, cors)
    }
    return json({ resultado: data?.resultado === 'ya_inscrito' ? 'ya_inscrito' : 'inscrito' }, 200, cors)
  }
}
