import { afterEach, describe, expect, it, vi } from 'vitest'
import { aEntradaLocal, deEntradaLocal, desfase, duracion, hora, minutosDesde } from '../../src/lib/tiempo.js'

describe('tiempo', () => {
  afterEach(() => vi.useRealTimers())

  it('formatea duraciones', () => {
    expect(duracion(7)).toBe('7 min')
    expect(duracion(65)).toBe('1 h 05 min')
    expect(duracion(-3)).toBe('0 min')
  })

  it('muestra la hora de Colombia sin importar la zona del dispositivo', () => {
    // 15:42 UTC = 10:42 en Bogotá (UTC-5)
    expect(hora('2026-10-07T15:42:00Z')).toMatch(/10:42/)
  })

  it('calcula el transcurrido con la hora del servidor', () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-10-07T15:00:00Z'))           // reloj del celular atrasado 10 min
    const d = desfase('2026-10-07T15:10:00Z')                      // hora del servidor
    expect(d).toBe(10 * 60 * 1000)
    expect(Math.round(minutosDesde('2026-10-07T14:40:00Z', d))).toBe(30)
  })
})


describe('entradas de fecha y hora', () => {
  it('ida y vuelta en hora de Colombia', () => {
    expect(deEntradaLocal('2026-10-11T07:00')).toBe('2026-10-11T07:00:00-05:00')
    expect(aEntradaLocal('2026-10-11T12:00:00Z')).toBe('2026-10-11T07:00')
    expect(aEntradaLocal(deEntradaLocal('2026-12-31T23:30'))).toBe('2026-12-31T23:30')
  })
})
