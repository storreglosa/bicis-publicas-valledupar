// Purga diaria de fotos de evidencia (diseño §7), sin APIs de Deno: se prueba con
// vitest en Node (tests/unit/funcion_purgar_fotos.test.js).
//
// La llama solo pg_cron (pg_net) con la cabecera x-clave-cron. Por lote:
//   1. fotos_por_purgar → rutas vencidas según retencion.fotos_dias.
//   2. marcar_fotos_eliminadas → devuelve solo las que marcó (si el administrador
//      conservó alguna entretanto, no vuelve y no se borra).
//   3. Borra esos archivos con la API de Storage (borrar la fila por SQL no borra el archivo).
// Después, huérfanas: archivos de préstamos marcados como eliminados (un borrado que
// falló) o subidos para un préstamo que nunca se registró. Todo queda en
// registrar_tarea y el tablero lo muestra; un error nunca se silencia.

const MAX_LOTES = 10

function json(cuerpo, status) {
  return new Response(JSON.stringify(cuerpo), { status, headers: { 'content-type': 'application/json; charset=utf-8' } })
}

// Comparación en tiempo constante (sobre los resúmenes, que tienen el mismo largo).
async function iguales(a, b) {
  const resumen = async (t) => new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(t)))
  const [x, y] = await Promise.all([resumen(a), resumen(b)])
  let diferencia = 0
  for (let i = 0; i < x.length; i++) diferencia |= x[i] ^ y[i]
  return diferencia === 0
}

const codigoDe = (error) => String(error?.message ?? error ?? 'desconocido').slice(0, 120)

export function crearManejador({ claveCron, rpc, borrarArchivos, lote = 500, ahora = () => new Date() }) {
  return async (req) => {
    if (req.method !== 'POST') return json({ error: 'metodo_no_permitido' }, 405)
    if (!claveCron || claveCron.length < 32 || !(await iguales(req.headers.get('x-clave-cron') ?? '', claveCron))) {
      return json({ error: 'no_autorizado' }, 401)
    }

    const inicio = ahora().toISOString()
    const detalle = { marcadas: 0, borradas: 0, huerfanas_borradas: 0, errores: [] }
    try {
      for (let i = 0; i < MAX_LOTES; i++) {
        const { data: vencidas, error: e1 } = await rpc('fotos_por_purgar', { p_limite: lote })
        if (e1) throw e1
        if (!vencidas?.length) break
        const { data: marcadas, error: e2 } = await rpc('marcar_fotos_eliminadas', { p_rutas: vencidas.map((f) => f.foto_ruta) })
        if (e2) throw e2
        detalle.marcadas += marcadas.length
        if (marcadas.length) {
          const { error: e3 } = await borrarArchivos(marcadas)
          if (e3) detalle.errores.push(`borrar: ${codigoDe(e3)}`)     // quedan como huérfanas: se reintentan
          else detalle.borradas += marcadas.length
        }
        if (vencidas.length < lote) break
      }

      const { data: huerfanas, error: e4 } = await rpc('fotos_huerfanas', { p_limite: lote })
      if (e4) throw e4
      if (huerfanas?.length) {
        const { error: e5 } = await borrarArchivos(huerfanas)
        if (e5) detalle.errores.push(`huerfanas: ${codigoDe(e5)}`)
        else detalle.huerfanas_borradas = huerfanas.length
      }
    } catch (e) {
      detalle.errores.push(codigoDe(e))
    }

    const resultado = detalle.errores.length ? 'error' : 'ok'
    const { error: e6 } = await rpc('registrar_tarea', {
      p_tarea: 'purgar_fotos', p_inicio: inicio, p_resultado: resultado, p_detalle: detalle,
    })
    if (e6) detalle.errores.push(`registrar_tarea: ${codigoDe(e6)}`)
    return json({ resultado, ...detalle }, resultado === 'ok' && !e6 ? 200 : 500)
  }
}
