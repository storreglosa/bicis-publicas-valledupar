// Edge Function pública de preinscripción (verify_jwt = false: la llama un visitante
// sin cuenta). La lógica está en nucleo.js; aquí solo se conecta con el entorno.
// Secretos de la función: TURNSTILE_SECRET_KEY, SAL_IP, ORIGENES_PERMITIDOS y SOLO_DATOS_FICTICIOS
// (=1 en la demo de dev; scripts/desplegar_funciones.sh). SUPABASE_URL y SUPABASE_SECRET_KEYS los inyecta Supabase.
import { createClient } from 'npm:@supabase/supabase-js@2.117.3'
import { crearHuellaIp, crearManejador, crearVerificadorTurnstile } from './nucleo.js'

const env = (clave: string) => Deno.env.get(clave) ?? ''
const secreto = env('TURNSTILE_SECRET_KEY')
const sal = env('SAL_IP')
const claveServicio = JSON.parse(env('SUPABASE_SECRET_KEYS') || '{}').default ?? ''
const admin = createClient(env('SUPABASE_URL'), claveServicio, { auth: { persistSession: false, autoRefreshToken: false } })

Deno.serve(crearManejador({
  origenesPermitidos: env('ORIGENES_PERMITIDOS').split(',').map((o) => o.trim()).filter(Boolean),
  configuracionCompleta: Boolean(secreto && sal.length >= 32 && claveServicio),
  soloDatosFicticios: env('SOLO_DATOS_FICTICIOS') === '1',
  verificarTurnstile: crearVerificadorTurnstile(secreto),
  huellaIp: crearHuellaIp(sal),
  preinscribir: (persona: unknown, huella: string) => admin.rpc('preinscribir', { p: persona, p_ip_huella: huella }),
}))
