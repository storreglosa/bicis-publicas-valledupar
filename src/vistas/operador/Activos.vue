<script setup>
// Préstamos activos que salieron de este punto, con el tiempo transcurrido según
// la hora del servidor. Se recarga cada minuto.
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { usePuntoTrabajo } from '../../composables/usePuntoTrabajo.js'
import { traducirError } from '../../lib/errores.js'
import { supabase } from '../../lib/supabase.js'
import { desfase, duracion, hora, minutosDesde } from '../../lib/tiempo.js'

const { punto } = usePuntoTrabajo()
const filas = ref([])
const desfaseMs = ref(0)
const cargando = ref(true)
const error = ref('')
const ahora = ref(Date.now())
let recarga = null
let reloj = null

async function cargar() {
  if (!punto.value) return
  const { data, error: e } = await supabase.rpc('prestamos_activos', { p_punto_id: punto.value.id })
  cargando.value = false
  if (e) {
    error.value = traducirError(e).mensaje
    return
  }
  error.value = ''
  filas.value = data
  if (data.length) desfaseMs.value = desfase(data[0].ahora_servidor)
}

const vista = computed(() => {
  void ahora.value   // recalcula con el reloj
  return filas.value.map((f) => ({
    ...f,
    transcurrido: duracion(minutosDesde(f.salida_en, desfaseMs.value)),
    vencido: f.vence_en && Date.now() + desfaseMs.value > new Date(f.vence_en).getTime(),
  }))
})

onMounted(() => {
  cargar()
  recarga = setInterval(cargar, 60_000)
  reloj = setInterval(() => (ahora.value = Date.now()), 30_000)
})
onBeforeUnmount(() => {
  clearInterval(recarga)
  clearInterval(reloj)
})
</script>

<template>
  <section class="contenedor pagina">
    <RouterLink to="/operador" class="volver">← Turno</RouterLink>
    <h1>Préstamos activos</h1>
    <p v-if="punto" class="punto">Salieron de {{ punto.codigo }} · {{ punto.nombre }}</p>
    <p v-else class="mensaje mensaje--aviso"><span>Primero elige tu punto de trabajo en <RouterLink to="/operador">Turno</RouterLink>.</span></p>

    <p v-if="error" class="mensaje mensaje--error"><span>{{ error }}</span></p>
    <p v-else-if="punto && cargando">Cargando…</p>
    <p v-else-if="punto && !vista.length" class="mensaje mensaje--exito"><span>No hay bicis prestadas desde este punto.</span></p>
    <ul v-else class="lista">
      <li v-for="f in vista" :key="f.prestamo_id" class="fila" :class="{ 'fila--vencida': f.vencido }">
        <span class="fila__bici">{{ f.codigo }}</span>
        <span class="fila__persona">{{ f.persona }}<template v-if="f.es_menor"> · menor</template></span>
        <span class="fila__tiempo">{{ f.transcurrido }}</span>
        <span class="fila__salida">salió {{ hora(f.salida_en) }}<template v-if="f.vence_en"> · vence {{ hora(f.vence_en) }}</template></span>
        <span v-if="f.vencido" class="etiqueta-estado etiqueta-estado--error">Vencido</span>
      </li>
    </ul>
  </section>
</template>

<style scoped>
.pagina { padding-block: var(--esp-4) var(--esp-6); max-width: 44rem; }
.volver { display: inline-block; margin-bottom: var(--esp-2); }
h1 { margin-bottom: var(--esp-1); }
.punto { color: var(--tinta-2); margin-bottom: var(--esp-4); }
.lista { list-style: none; margin: 0; padding: 0; display: grid; gap: var(--esp-2); }
.fila {
  display: grid; grid-template-columns: auto 1fr auto; gap: var(--esp-1) var(--esp-3); align-items: baseline;
  background: var(--superficie); border: 1px solid var(--linea); border-left: 6px solid var(--secundario);
  border-radius: var(--radio-m); padding: var(--esp-3) var(--esp-4);
}
.fila--vencida { border-left-color: var(--error); }
.fila__bici { font-weight: 650; font-size: var(--texto-l); }
.fila__tiempo { font-weight: 650; }
.fila__salida { grid-column: 1 / -1; color: var(--tinta-2); font-size: var(--texto-s); }
</style>
