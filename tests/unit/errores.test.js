import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { MENSAJES, traducirError } from '../../src/lib/errores.js'

const carpeta = join(import.meta.dirname, '../../supabase/migrations')
const codigosSql = new Set(
  readdirSync(carpeta)
    .filter((f) => f.endsWith('.sql'))
    .flatMap((f) => [...readFileSync(join(carpeta, f), 'utf8').matchAll(/message = '([a-z_]+)'/g)].map((m) => m[1])),
)

describe('errores', () => {
  afterEach(() => vi.restoreAllMocks())

  it('cada código que lanzan las funciones SQL tiene mensaje en español', () => {
    const sinMensaje = [...codigosSql].filter((c) => !Object.hasOwn(MENSAJES, c))
    expect(sinMensaje).toEqual([])
  })

  it('no hay mensajes para códigos que ya no existen en SQL', () => {
    const huerfanos = Object.keys(MENSAJES).filter((c) => !codigosSql.has(c))
    expect(huerfanos).toEqual([])
  })

  it('traduce el error que devuelve Supabase', () => {
    expect(traducirError({ message: 'bici_ya_prestada', code: 'P0001' })).toEqual({
      codigo: 'bici_ya_prestada',
      mensaje: MENSAJES.bici_ya_prestada,
    })
  })

  it('traduce interbloqueos y tiempos de espera por su SQLSTATE', () => {
    expect(traducirError({ code: '40P01', message: 'deadlock detected' }).codigo).toBe('reintentar')
    expect(traducirError({ code: '57014', message: 'canceling statement due to statement timeout' }).codigo).toBe('reintentar')
  })

  it('nunca registra el detalle del error (puede traer datos personales)', () => {
    const consola = vi.spyOn(console, 'error').mockImplementation(() => {})
    traducirError({ code: '23514', message: 'algo', details: 'Failing row contains (00123456, 3001234567)' })
    expect(JSON.stringify(consola.mock.calls)).not.toContain('00123456')
  })

  it('reconoce la falta de conexión', () => {
    expect(traducirError(new TypeError('Failed to fetch')).codigo).toBe('sin_conexion')
  })

  it('un código desconocido no se silencia: mensaje genérico y registro en consola', () => {
    const consola = vi.spyOn(console, 'error').mockImplementation(() => {})
    const r = traducirError({ message: 'algo_nuevo' })
    expect(r.codigo).toBe('algo_nuevo')
    expect(r.mensaje).toMatch(/inesperado/)
    expect(consola).toHaveBeenCalled()
  })
})
