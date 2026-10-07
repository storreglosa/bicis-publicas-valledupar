// Disponibilidad pública en vivo (diseño §8).
// 1. Carga inicial de los puntos visibles.
// 2. Suscripción Realtime a disponibilidad_puntos (tabla sin datos personales).
// 3. Recarga completa cada 5 min: cubre los puntos que dejan de ser visibles
//    (RLS no le entrega a anon ese UPDATE) y el límite de 24 h de las conexiones.
// 4. Si el canal falla, sondeo cada 60 s y se avisa "actualizado hh:mm".
// 5. En segundo plano se suelta la conexión (el plan Free admite 200).
// 6. Recarga 3 s después de suscribirse: el servidor tarda un momento en activar
//    la suscripción tras 'SUBSCRIBED' y un cambio en ese hueco se perdería
//    (medido contra dev el 2026-10-07 con scripts/escuchar_tiempo_real.mjs).
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { traducirError } from '../lib/errores.js'
import { configurado, supabase } from '../lib/supabase.js'

const RECARGA_MS = 5 * 60 * 1000
const SONDEO_MS = 60 * 1000
const CALENTAMIENTO_MS = 3 * 1000
const COLUMNAS = 'punto_id,codigo,nombre,tipo,latitud,longitud,direccion,horario_texto,' +
  'evento_nombre,evento_inicia_en,evento_termina_en,abierto,bicis_disponibles,actualizado_en'

function normalizar(fila) {
  return { ...fila, latitud: Number(fila.latitud), longitud: Number(fila.longitud) }
}

export function useDisponibilidad() {
  const puntos = ref([])
  const estado = ref(configurado ? 'cargando' : 'sin_configurar') // cargando | conectando | en_vivo | sondeo | error | sin_configurar
  const actualizado = ref(null)
  const error = ref(null)
  let canal = null
  let temporizador = null
  let calentamiento = null
  let activo = false

  async function cargar() {
    const { data, error: e } = await supabase
      .from('disponibilidad_puntos')
      .select(COLUMNAS)
      .eq('visible', true)
      .order('codigo')
    if (e) {
      error.value = traducirError(e)
      if (!puntos.value.length) estado.value = 'error'
      return
    }
    puntos.value = data.map(normalizar)
    actualizado.value = new Date()
    error.value = null
    if (estado.value === 'cargando' || estado.value === 'error') estado.value = 'conectando'
  }

  function aplicarCambio(cambio) {
    const nueva = cambio.new
    const id = nueva?.punto_id ?? cambio.old?.punto_id
    const resto = puntos.value.filter((p) => p.punto_id !== id)
    puntos.value = cambio.eventType !== 'DELETE' && nueva?.visible
      ? [...resto, normalizar(nueva)].sort((a, b) => a.codigo.localeCompare(b.codigo))
      : resto
    actualizado.value = new Date()
  }

  function programar(ms) {
    clearInterval(temporizador)
    temporizador = setInterval(cargar, ms)
  }

  function suscribir() {
    canal = supabase
      .channel('disponibilidad-publica')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'disponibilidad_puntos' }, aplicarCambio)
      .subscribe((estadoCanal) => {
        if (!activo) return
        if (estadoCanal === 'SUBSCRIBED') {
          estado.value = 'en_vivo'
          programar(RECARGA_MS)
          clearTimeout(calentamiento)
          calentamiento = setTimeout(() => activo && cargar(), CALENTAMIENTO_MS)
        } else if (['CHANNEL_ERROR', 'TIMED_OUT', 'CLOSED'].includes(estadoCanal)) {
          estado.value = 'sondeo'
          programar(SONDEO_MS)
        }
      })
  }

  async function iniciar() {
    activo = true
    await cargar()
    if (activo) suscribir()
  }

  function detener() {
    activo = false
    clearInterval(temporizador)
    clearTimeout(calentamiento)
    if (canal) {
      supabase.removeChannel(canal)
      canal = null
    }
  }

  function alCambiarVisibilidad() {
    if (document.hidden) detener()
    else if (!activo) iniciar()
  }

  onMounted(() => {
    if (!configurado) return
    iniciar()
    document.addEventListener('visibilitychange', alCambiarVisibilidad)
  })

  onBeforeUnmount(() => {
    detener()
    document.removeEventListener('visibilitychange', alCambiarVisibilidad)
  })

  return { puntos, estado, actualizado, error, recargar: cargar }
}
