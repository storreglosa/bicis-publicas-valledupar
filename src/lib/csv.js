// Exportación CSV para Excel: UTF-8 con BOM (utf-8-sig), separador coma,
// fechas ISO. Convención de intercambio de la STTV.

function celda(valor) {
  if (valor === null || valor === undefined) return ''
  const texto = valor instanceof Date ? valor.toISOString() : String(valor)
  return /[",\r\n]/.test(texto) ? `"${texto.replaceAll('"', '""')}"` : texto
}

/**
 * @param {Array<Record<string, unknown>>} filas
 * @param {Array<{ clave: string, titulo: string }>} columnas
 * @returns {string} texto CSV con BOM inicial
 */
export function aCsv(filas, columnas) {
  const encabezado = columnas.map((c) => celda(c.titulo)).join(',')
  const cuerpo = filas.map((f) => columnas.map((c) => celda(f[c.clave])).join(','))
  return '﻿' + [encabezado, ...cuerpo].join('\r\n') + '\r\n'
}

export function descargarCsv(texto, nombreArchivo) {
  const url = URL.createObjectURL(new Blob([texto], { type: 'text/csv;charset=utf-8' }))
  const a = Object.assign(document.createElement('a'), { href: url, download: nombreArchivo })
  document.body.append(a)
  a.click()
  a.remove()
  URL.revokeObjectURL(url)
}
