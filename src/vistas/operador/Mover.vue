<script setup>
// Mover bicis de este punto a otro (reubicación, llevar al taller o a un evento).
// Siempre con motivo: queda en la auditoría.
import { computed, onMounted, ref } from 'vue'
import { usePuntoTrabajo } from '../../composables/usePuntoTrabajo.js'
import { traducirError } from '../../lib/errores.js'
import { supabase } from '../../lib/supabase.js'

const { punto } = usePuntoTrabajo()
const bicis = ref([])
const puntos = ref([])
const elegidas = ref(new Set())
const destino = ref('')
const motivo = ref('')
const error = ref('')
const hecho = ref('')
const enviando = ref(false)

const listo = computed(() => elegidas.value.size && destino.value && motivo.value.trim().length >= 5)

async function cargar() {
  const [b, p] = await Promise.all([
    supabase.from('bicicletas').select('numero,codigo,disponibilidad,condicion')
      .eq('punto_actual_id', punto.value.id).neq('disponibilidad', 'prestada').order('numero'),
    supabase.from('puntos').select('id,codigo,nombre,tipo,estado').neq('estado', 'cerrado').neq('id', punto.value.id).order('codigo'),
  ])
  if (b.error || p.error) error.value = traducirError(b.error ?? p.error).mensaje
  bicis.value = b.data ?? []
  puntos.value = p.data ?? []
}

onMounted(() => punto.value && cargar())

function alternar(n) {
  const s = new Set(elegidas.value)
  s.has(n) ? s.delete(n) : s.add(n)
  elegidas.value = s
}

async function mover() {
  error.value = ''
  hecho.value = ''
  enviando.value = true
  const { data, error: e } = await supabase.rpc('mover_bicis', {
    p_numeros: [...elegidas.value], p_punto_destino: destino.value, p_motivo: motivo.value,
  })
  enviando.value = false
  if (e) {
    error.value = traducirError(e).mensaje
    return
  }
  const d = puntos.value.find((p) => p.id === destino.value)
  hecho.value = `${data} bici(s) movida(s) a ${d.codigo} · ${d.nombre}.`
  elegidas.value = new Set()
  motivo.value = ''
  cargar()
}
</script>

<template>
  <section class="contenedor pagina">
    <RouterLink to="/operador" class="volver">← Turno</RouterLink>
    <h1>Mover bicis</h1>
    <p v-if="!punto" class="mensaje mensaje--aviso"><span>Primero elige tu punto de trabajo en <RouterLink to="/operador">Turno</RouterLink>.</span></p>

    <div v-else class="tarjeta-base">
      <p class="ayuda">Bicis que están en {{ punto.codigo }} · {{ punto.nombre }}. Toca las que vas a mover:</p>
      <ul class="chips">
        <li v-for="b in bicis" :key="b.numero">
          <button type="button" class="chip" :aria-pressed="elegidas.has(b.numero)" @click="alternar(b.numero)">
            {{ String(b.numero).padStart(3, '0') }}<small v-if="b.condicion !== 'operativa'"> · {{ b.condicion }}</small></button>
        </li>
      </ul>
      <p v-if="!bicis.length" class="mensaje mensaje--aviso"><span>No hay bicis en este punto.</span></p>

      <label class="campo"><span>Llevar a</span>
        <select v-model="destino"><option value="" disabled>Elige el punto de destino…</option>
          <option v-for="p in puntos" :key="p.id" :value="p.id">{{ p.codigo }} · {{ p.nombre }}{{ p.tipo === 'taller' ? ' (taller)' : '' }}</option>
        </select></label>
      <label class="campo"><span>Motivo</span>
        <input v-model="motivo" maxlength="500" placeholder="Ej.: reubicación para el evento del domingo" autocomplete="off" /></label>

      <p v-if="hecho" class="mensaje mensaje--exito" role="status"><span>{{ hecho }}</span></p>
      <p v-if="error" class="mensaje mensaje--error" role="alert"><span>{{ error }}</span></p>
      <button class="boton boton--bloque" type="button" :disabled="!listo || enviando" @click="mover">
        {{ enviando ? 'Moviendo…' : `Mover ${elegidas.size || ''} bici(s)` }}</button>
    </div>
  </section>
</template>

<style scoped>
.pagina { padding-block: var(--esp-4) var(--esp-6); max-width: 44rem; }
.volver { display: inline-block; margin-bottom: var(--esp-2); }
.ayuda { color: var(--tinta-2); }
.chips { list-style: none; margin: 0 0 var(--esp-4); padding: 0; display: flex; flex-wrap: wrap; gap: var(--esp-2); max-height: 14rem; overflow-y: auto; }
.chip {
  min-width: 56px; min-height: var(--toque-min); padding: 0 var(--esp-2); border: 2px solid var(--linea-fuerte); border-radius: var(--radio-m);
  background: var(--superficie); color: var(--tinta-1); font: inherit; font-weight: 650; cursor: pointer;
}
.chip[aria-pressed='true'] { background: var(--secundario); border-color: var(--secundario); color: var(--sobre-secundario); }
.mensaje { margin: var(--esp-3) 0; }
</style>
