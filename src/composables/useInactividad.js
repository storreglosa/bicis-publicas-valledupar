// Cierre de sesión por inactividad (20 min) para tabletas o celulares compartidos
// en los puntos (Res. MinTIC 1519/2020, Anexo 3: control de sesiones).
import { onBeforeUnmount, watch } from 'vue'
import { useRouter } from 'vue-router'
import { salir, sesion } from '../lib/sesion.js'

const LIMITE_MS = 20 * 60 * 1000
const EVENTOS = ['pointerdown', 'keydown', 'touchstart', 'scroll']

export function useInactividad() {
  const router = useRouter()
  let temporizador = null

  function reiniciar() {
    clearTimeout(temporizador)
    temporizador = setTimeout(async () => {
      await salir()
      router.push({ name: 'ingresar', query: { motivo: 'inactividad' } })
    }, LIMITE_MS)
  }

  function activar() {
    EVENTOS.forEach((e) => window.addEventListener(e, reiniciar, { passive: true }))
    reiniciar()
  }

  function desactivar() {
    clearTimeout(temporizador)
    EVENTOS.forEach((e) => window.removeEventListener(e, reiniciar))
  }

  watch(() => sesion.perfil, (perfil) => (perfil ? activar() : desactivar()), { immediate: true })
  onBeforeUnmount(desactivar)
}
