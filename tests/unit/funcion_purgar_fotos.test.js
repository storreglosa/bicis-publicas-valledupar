// Edge Function purgar-fotos (supabase/functions/purgar-fotos/nucleo.js) con
// Request/Response reales de Node; la base y Storage, simulados.
import { describe, expect, it } from 'vitest'
import { crearManejador } from '../../supabase/functions/purgar-fotos/nucleo.js'

const CLAVE = 'c'.repeat(64)
const pedir = (clave = CLAVE, metodo = 'POST') => new Request('https://x.supabase.co/functions/v1/purgar-fotos', {
  method: metodo, headers: clave ? { 'x-clave-cron': clave } : {},
})

function simular({ vencidas = [], conservadas = [], huerfanas = [], falla = {} } = {}) {
  const log = { rpc: [], borradas: [], tarea: null }
  let entregadas = false
  const rpc = async (fn, args) => {
    log.rpc.push(fn)
    if (falla[fn]) return { data: null, error: { message: falla[fn] } }
    if (fn === 'fotos_por_purgar') {
      const r = entregadas ? [] : vencidas.map((foto_ruta) => ({ prestamo_id: foto_ruta, foto_ruta }))
      entregadas = true
      return { data: r, error: null }
    }
    if (fn === 'marcar_fotos_eliminadas') return { data: args.p_rutas.filter((r) => !conservadas.includes(r)), error: null }
    if (fn === 'fotos_huerfanas') return { data: huerfanas, error: null }
    if (fn === 'registrar_tarea') { log.tarea = args; return { data: null, error: null } }
    throw new Error(fn)
  }
  const borrarArchivos = async (rutas) => {
    if (falla.storage) return { data: null, error: { message: falla.storage } }
    log.borradas.push(...rutas)
    return { data: rutas, error: null }
  }
  return { log, manejador: crearManejador({ claveCron: CLAVE, rpc, borrarArchivos, ahora: () => new Date('2026-10-09T08:00:00Z') }) }
}

describe('purgar-fotos', () => {
  it('sin la clave del cron no hace nada', async () => {
    const { manejador, log } = simular({ vencidas: ['prestamos/a/salida.webp'] })
    expect((await manejador(pedir(null))).status).toBe(401)
    expect((await manejador(pedir('otra-clave'))).status).toBe(401)
    expect((await manejador(pedir(CLAVE, 'GET'))).status).toBe(405)
    expect(log.rpc).toEqual([])
  })

  it('borra solo lo que la base marcó (respeta una foto conservada entretanto) y registra la tarea', async () => {
    const { manejador, log } = simular({
      vencidas: ['prestamos/a/salida.webp', 'prestamos/b/salida.webp'], conservadas: ['prestamos/b/salida.webp'],
      huerfanas: ['prestamos/z/salida.webp'],
    })
    const r = await manejador(pedir())
    expect(r.status).toBe(200)
    expect(log.borradas).toEqual(['prestamos/a/salida.webp', 'prestamos/z/salida.webp'])
    expect(log.tarea).toEqual({
      p_tarea: 'purgar_fotos', p_inicio: '2026-10-09T08:00:00.000Z', p_resultado: 'ok',
      p_detalle: { marcadas: 1, borradas: 1, huerfanas_borradas: 1, errores: [] },
    })
  })

  it('si Storage falla, la tarea queda en error (se ve en el tablero) y responde 500', async () => {
    const { manejador, log } = simular({ vencidas: ['prestamos/a/salida.webp'], falla: { storage: 'Storage caído' } })
    const r = await manejador(pedir())
    expect(r.status).toBe(500)
    expect(log.tarea.p_resultado).toBe('error')
    expect(log.tarea.p_detalle.errores).toEqual(['borrar: Storage caído'])
  })

  it('si la base falla al listar, no borra nada y lo registra', async () => {
    const { manejador, log } = simular({ falla: { fotos_por_purgar: 'permission denied' } })
    const r = await manejador(pedir())
    expect(r.status).toBe(500)
    expect(log.borradas).toEqual([])
    expect(log.tarea.p_detalle.errores).toEqual(['permission denied'])
  })

  it('sin fotos vencidas registra una ejecución en orden', async () => {
    const { manejador, log } = simular()
    expect((await manejador(pedir())).status).toBe(200)
    expect(log.rpc).toEqual(['fotos_por_purgar', 'fotos_huerfanas', 'registrar_tarea'])
  })
})
