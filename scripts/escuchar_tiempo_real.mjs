// Prueba de humo del tiempo real: se suscribe COMO VISITANTE ANÓNIMO (clave
// publishable) a disponibilidad_puntos e imprime cada cambio que llega.
//
//   node --env-file=.env.development.local scripts/escuchar_tiempo_real.mjs [segundos]
//
// Mientras escucha, cualquier préstamo, devolución o movimiento de bicis debe
// aparecer aquí. Sirve para verificar Realtime + RLS después de migrar.
import { createClient } from '@supabase/supabase-js'

const url = process.env.VITE_SUPABASE_URL
const clave = process.env.VITE_SUPABASE_PUBLISHABLE_KEY
if (!url || !clave) {
  console.error('Faltan VITE_SUPABASE_URL y VITE_SUPABASE_PUBLISHABLE_KEY (usa --env-file).')
  process.exit(2)
}
const segundos = Number(process.argv[2] ?? 30)
const cliente = createClient(url, clave, { auth: { persistSession: false } })
let recibidos = 0

cliente
  .channel('prueba-disponibilidad')
  .on('postgres_changes', { event: '*', schema: 'public', table: 'disponibilidad_puntos' }, (cambio) => {
    recibidos += 1
    const fila = cambio.new ?? {}
    console.log(`${new Date().toISOString()} ${cambio.eventType} ${fila.codigo ?? '?'} → ${fila.bicis_disponibles ?? '?'} disponibles`)
  })
  .subscribe((estado, error) => {
    console.log(`canal: ${estado}${error ? ` (${error.message})` : ''}`)
    if (estado === 'SUBSCRIBED') console.log(`Escuchando ${segundos} s…`)
  })

setTimeout(async () => {
  console.log(`Cambios recibidos: ${recibidos}`)
  await cliente.removeAllChannels()
  process.exit(recibidos > 0 ? 0 : 1)
}, segundos * 1000)
