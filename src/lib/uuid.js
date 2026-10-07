// Identificador de operación generado en el cliente: hace idempotentes los
// reintentos (y habilitará el modo sin conexión más adelante, decisión D-13).
export function nuevoId() {
  return crypto.randomUUID()
}
