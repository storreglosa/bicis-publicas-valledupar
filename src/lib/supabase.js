// Cliente de Supabase. La URL y la clave publishable son públicas por diseño
// (la seguridad la dan RLS y los permisos de la base). La clave secreta nunca
// llega aquí.
import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const clavePublica = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY

export const configurado = Boolean(url && clavePublica)

export const supabase = configurado
  ? createClient(url, clavePublica, {
      auth: {
        // sessionStorage y no localStorage: en tabletas compartidas la sesión
        // muere al cerrar la pestaña.
        storage: globalThis.sessionStorage,
        persistSession: true,
        autoRefreshToken: true,
      },
    })
  : null
