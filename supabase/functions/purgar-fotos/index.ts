// Edge Function de purga diaria de fotos (verify_jwt = false: la autentica la
// cabecera x-clave-cron, que pg_cron toma de Vault). La lógica está en nucleo.js.
// Secreto de la función: CLAVE_CRON (scripts/desplegar_funciones.sh).
import { createClient } from 'npm:@supabase/supabase-js@2.117.3'
import { crearManejador } from './nucleo.js'

const env = (clave: string) => Deno.env.get(clave) ?? ''
const claveServicio = JSON.parse(env('SUPABASE_SECRET_KEYS') || '{}').default ?? ''
const admin = createClient(env('SUPABASE_URL'), claveServicio, { auth: { persistSession: false, autoRefreshToken: false } })

Deno.serve(crearManejador({
  claveCron: env('CLAVE_CRON'),
  rpc: (fn: string, args: Record<string, unknown>) => admin.rpc(fn, args),
  borrarArchivos: (rutas: string[]) => admin.storage.from('evidencias').remove(rutas),
}))
