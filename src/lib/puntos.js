// Estado visible de un punto en el mapa y la lista. El color nunca va solo:
// siempre se imprime el número y la etiqueta.
export const POCAS_BICIS = 2

export function estadoPunto(punto) {
  if (!punto.abierto) return { clave: 'sin-dato', etiqueta: 'Cerrado' }
  if (punto.bicis_disponibles === 0) return { clave: 'sin', etiqueta: 'Sin bicis' }
  if (punto.bicis_disponibles <= POCAS_BICIS) return { clave: 'pocas', etiqueta: 'Pocas bicis' }
  return { clave: 'disponible', etiqueta: 'Disponible' }
}

export function enlaceComoLlegar(punto) {
  return `https://www.google.com/maps/dir/?api=1&destination=${punto.latitud},${punto.longitud}`
}

export function textoBicis(n) {
  return n === 1 ? '1 bici disponible' : `${n} bicis disponibles`
}
