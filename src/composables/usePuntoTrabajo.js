// Punto donde el operador trabaja en este turno. Se recuerda en el dispositivo
// (localStorage) porque no es un dato personal: solo el código del punto.
import { ref } from 'vue'

const CLAVE = 'bicis.punto_trabajo'

function leer() {
  try {
    return JSON.parse(localStorage.getItem(CLAVE)) ?? null
  } catch {
    return null
  }
}

const punto = ref(leer())

export function usePuntoTrabajo() {
  function elegir(p) {
    punto.value = { id: p.id, codigo: p.codigo, nombre: p.nombre, tipo: p.tipo }
    try {
      localStorage.setItem(CLAVE, JSON.stringify(punto.value))
    } catch {
      // Sin almacenamiento (modo privado): el punto dura mientras la pestaña esté abierta.
    }
  }
  function olvidar() {
    punto.value = null
    try {
      localStorage.removeItem(CLAVE)
    } catch {
      // ídem
    }
  }
  return { punto, elegir, olvidar }
}
