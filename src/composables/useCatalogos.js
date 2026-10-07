// Catálogos que usan los formularios del operador: tipos de documento, política
// de datos vigente (textos de las casillas) y si la foto debe mostrar a la persona.
import { ref } from 'vue'
import { traducirError } from '../lib/errores.js'
import { configurado, supabase } from '../lib/supabase.js'

const tipos = ref([])
const politica = ref(null)
const fotoPersonaObligatoria = ref(true)
const error = ref(null)
const listo = ref(false)
let carga = null

async function cargar() {
  const [t, p, f] = await Promise.all([
    supabase.from('tipos_documento').select('codigo,nombre,implica_menor').eq('activo', true).order('orden'),
    supabase.from('politicas_tratamiento').select('version,texto_autorizacion,texto_autorizacion_foto').eq('vigente', true).maybeSingle(),
    supabase.from('parametros').select('valor').eq('clave', 'evidencia.foto_persona_obligatoria').maybeSingle(),
  ])
  const fallo = t.error ?? p.error ?? f.error
  if (fallo) {
    error.value = traducirError(fallo)
    carga = null  // permite reintentar
    return
  }
  tipos.value = t.data
  politica.value = p.data
  fotoPersonaObligatoria.value = f.data?.valor === true
  error.value = p.data ? null : { codigo: 'sin_politica_vigente', mensaje: traducirError({ message: 'sin_politica_vigente' }).mensaje }
  listo.value = true
}

export function useCatalogos() {
  if (configurado) carga ??= cargar()
  return { tipos, politica, fotoPersonaObligatoria, error, listo }
}
