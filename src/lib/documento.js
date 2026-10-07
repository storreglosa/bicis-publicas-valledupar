// Normalización de documentos y teléfonos idéntica a la de la base de datos
// (privado.limpiar_documento / privado.limpiar_telefono). La validación que
// manda es la del servidor; esto solo adelanta el aviso en el formulario.

export function normalizarDocumento(numero) {
  return String(numero ?? '').replace(/[^0-9A-Za-z]/g, '').toUpperCase()
}

export function normalizarTelefono(telefono) {
  return String(telefono ?? '').trim().replace(/[^0-9+]/g, '')
}

export function telefonoValido(telefono) {
  return /^\+?[0-9]{7,15}$/.test(normalizarTelefono(telefono))
}

/** Código visible de una bici a partir del número del sticker (igual que la columna generada). */
export function codigoBici(numero, prefijo = 'BPV') {
  const n = String(Number(numero))
  return `${prefijo}-${n.padStart(Math.max(3, n.length), '0')}`
}
