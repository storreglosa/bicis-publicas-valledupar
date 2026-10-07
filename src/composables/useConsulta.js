// Consulta simple de una sola vez (parámetros, eventos, política) con estado
// de carga y error traducido. Nada se silencia: el error queda en `error`.
import { onMounted, ref } from 'vue'
import { traducirError } from '../lib/errores.js'
import { configurado, supabase } from '../lib/supabase.js'

/**
 * @param {(cliente: import('@supabase/supabase-js').SupabaseClient) => PromiseLike<{ data: any, error: any }>} consulta
 */
export function useConsulta(consulta) {
  const datos = ref(null)
  const cargando = ref(configurado)
  const error = ref(configurado ? null : { codigo: 'sin_configurar', mensaje: 'La conexión con la base de datos aún no está configurada.' })

  async function cargar() {
    if (!configurado) return
    cargando.value = true
    const { data, error: e } = await consulta(supabase)
    if (e) error.value = traducirError(e)
    else {
      datos.value = data
      error.value = null
    }
    cargando.value = false
  }

  onMounted(cargar)
  return { datos, cargando, error, recargar: cargar }
}
