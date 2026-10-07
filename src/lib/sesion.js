// Sesión del personal (operadores y administradores).
// El rol NO se toma del navegador ni de los metadatos del usuario: lo responde
// la base con mi_perfil(), que lee la tabla personal (diseño §4). Si la cuenta no
// está vinculada o está inactiva, mi_perfil devuelve null y no hay acceso.
import { reactive, readonly } from 'vue'
import { traducirError } from './errores.js'
import { configurado, supabase } from './supabase.js'

const estado = reactive({ listo: !configurado, perfil: null })
let inicial = null

async function cargarPerfil() {
  const { data, error } = await supabase.rpc('mi_perfil')
  if (error) throw error
  estado.perfil = data ?? null
}

/** Resuelve la sesión una vez (al primer acceso a una ruta protegida). */
export function asegurarSesion() {
  if (!configurado) return Promise.resolve()
  inicial ??= (async () => {
    const { data } = await supabase.auth.getSession()
    if (data.session) {
      try {
        await cargarPerfil()
      } catch (e) {
        console.error('No se pudo cargar el perfil:', traducirError(e).codigo)
        estado.perfil = null
      }
    }
    estado.listo = true
  })()
  return inicial
}

function mensajeIngreso(error) {
  if (/invalid login credentials/i.test(error.message)) return 'Correo o clave incorrectos.'
  if (/email not confirmed/i.test(error.message)) return 'La cuenta no tiene el correo confirmado. Avisa al administrador.'
  return traducirError(error).mensaje
}

export async function ingresar(correo, clave) {
  const { error } = await supabase.auth.signInWithPassword({ email: correo.trim(), password: clave })
  if (error) return { error: mensajeIngreso(error) }
  try {
    await cargarPerfil()
  } catch (e) {
    await supabase.auth.signOut()
    return { error: traducirError(e).mensaje }
  }
  if (!estado.perfil) {
    await supabase.auth.signOut()
    return { error: 'Esta cuenta no está habilitada como personal del sistema. Pide a un administrador que la vincule.' }
  }
  estado.listo = true
  return {}
}

export async function salir() {
  estado.perfil = null
  if (configurado) await supabase.auth.signOut()
}

export async function cambiarClave(nueva) {
  const { error } = await supabase.auth.updateUser({ password: nueva })
  if (error) {
    if (/should be different/i.test(error.message)) return { error: 'La clave nueva debe ser distinta de la anterior.' }
    if (/password/i.test(error.message)) return { error: 'La clave no cumple los requisitos. Usa al menos 10 caracteres.' }
    return { error: traducirError(error).mensaje }
  }
  const r = await supabase.rpc('marcar_clave_cambiada')
  if (r.error) return { error: traducirError(r.error).mensaje }
  await cargarPerfil()
  return {}
}

if (configurado) {
  // Si el token vence o se cierra la sesión en otra pestaña, se pierde el acceso.
  supabase.auth.onAuthStateChange((evento) => {
    if (evento === 'SIGNED_OUT') estado.perfil = null
  })
}

export const sesion = readonly(estado)
