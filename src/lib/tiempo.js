// Fechas y duraciones en hora de Colombia. Los tiempos transcurridos se calculan
// con la hora del SERVIDOR (las funciones devuelven `ahora_servidor`), no con el
// reloj del celular, que puede estar desajustado.

const ZONA = 'America/Bogota'

export function hora(fecha) {
  if (!fecha) return '—'
  return new Date(fecha).toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit', timeZone: ZONA })
}

export function fechaHora(fecha) {
  if (!fecha) return '—'
  return new Date(fecha).toLocaleString('es-CO', {
    day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit', timeZone: ZONA,
  })
}

/** 65 → "1 h 05 min"; 7 → "7 min". */
export function duracion(minutos) {
  const m = Math.max(0, Math.floor(minutos))
  if (m < 60) return `${m} min`
  return `${Math.floor(m / 60)} h ${String(m % 60).padStart(2, '0')} min`
}

/** Diferencia (ms) entre el reloj del servidor y el del dispositivo. */
export function desfase(ahoraServidor) {
  return ahoraServidor ? new Date(ahoraServidor).getTime() - Date.now() : 0
}

export function minutosDesde(fecha, desfaseMs = 0) {
  return (Date.now() + desfaseMs - new Date(fecha).getTime()) / 60000
}
