import { describe, expect, it } from 'vitest'
import { aCsv } from '../../src/lib/csv.js'
import { codigoBici, normalizarDocumento, normalizarTelefono, telefonoValido } from '../../src/lib/documento.js'
import { dimensiones } from '../../src/lib/foto.js'

describe('csv', () => {
  const columnas = [{ clave: 'bici', titulo: 'Bici' }, { clave: 'nota', titulo: 'Nota' }]

  it('empieza con BOM (utf-8-sig) para que Excel lea las tildes', () => {
    expect(aCsv([], columnas).charCodeAt(0)).toBe(0xfeff)
  })

  it('escapa comas, comillas y saltos de línea', () => {
    const texto = aCsv([{ bici: 'BPV-001', nota: 'freno, "suelto"\notra línea' }], columnas)
    expect(texto).toBe('﻿Bici,Nota\r\nBPV-001,"freno, ""suelto""\notra línea"\r\n')
  })

  it('vacíos y nulos quedan en blanco', () => {
    expect(aCsv([{ bici: null }], columnas)).toBe('﻿Bici,Nota\r\n,\r\n')
  })
})

describe('documento', () => {
  it('normaliza igual que la base de datos', () => {
    expect(normalizarDocumento(' 1.065-123 456 ')).toBe('1065123456')
    expect(normalizarDocumento('ab-12 34')).toBe('AB1234')
  })

  it('valida teléfonos', () => {
    expect(normalizarTelefono('300 123-4567')).toBe('3001234567')
    expect(telefonoValido('+57 300 123 4567')).toBe(true)
    expect(telefonoValido('123')).toBe(false)
  })

  it('genera el código de la bici como la columna generada en SQL', () => {
    expect(codigoBici(1)).toBe('BPV-001')
    expect(codigoBici(130)).toBe('BPV-130')
    expect(codigoBici(1234)).toBe('BPV-1234')
  })
})

describe('foto', () => {
  it('reduce el lado mayor a 1280 px sin deformar', () => {
    expect(dimensiones(4000, 3000)).toEqual({ ancho: 1280, alto: 960 })
    expect(dimensiones(3000, 4000)).toEqual({ ancho: 960, alto: 1280 })
  })

  it('no agranda fotos pequeñas', () => {
    expect(dimensiones(800, 600)).toEqual({ ancho: 800, alto: 600 })
  })
})
