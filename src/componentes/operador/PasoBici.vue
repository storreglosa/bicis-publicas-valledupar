<script setup>
// Paso 2: elegir la bici por el número de su sticker. Se ven las disponibles en
// el punto y, al elegir una, sus novedades abiertas (daños reportados antes).
import { computed, onMounted, ref, watch } from 'vue'
import { codigoBici } from '../../lib/documento.js'
import { traducirError } from '../../lib/errores.js'
import { supabase } from '../../lib/supabase.js'

const props = defineProps({
  puntoId: { type: String, required: true },
  numeroInicial: { type: [String, Number], default: '' },
})
const emit = defineEmits(['lista', 'atras'])

const disponibles = ref([])
const cargando = ref(true)
const error = ref('')
const numero = ref(String(props.numeroInicial ?? ''))
const novedades = ref([])

const elegida = computed(() => disponibles.value.find((b) => b.numero === Number(numero.value)))
const avisoNoAqui = computed(() => numero.value && !cargando.value && !elegida.value
  ? `La ${codigoBici(numero.value)} no figura disponible en este punto. Revisa el número del sticker.` : '')

onMounted(async () => {
  const { data, error: e } = await supabase.from('bicicletas').select('id,numero,codigo')
    .eq('punto_actual_id', props.puntoId).eq('disponibilidad', 'disponible').order('numero')
  cargando.value = false
  if (e) error.value = traducirError(e).mensaje
  else disponibles.value = data
})

watch(elegida, async (b) => {
  novedades.value = []
  if (!b) return
  const { data, error: e } = await supabase.from('incidencias').select('tipo,gravedad,descripcion,reportada_en')
    .eq('bicicleta_id', b.id).neq('estado', 'cerrada').order('reportada_en', { ascending: false })
  if (e) error.value = traducirError(e).mensaje
  else novedades.value = data
})
</script>

<template>
  <div class="tarjeta-base">
    <h2>¿Qué bici se lleva?</h2>
    <label class="campo">
      <span>Número del sticker</span>
      <input v-model="numero" class="numero" type="number" inputmode="numeric" min="1" max="9999" autocomplete="off" />
      <small v-if="numero">Código: {{ codigoBici(numero) }}</small>
    </label>

    <p v-if="cargando">Cargando bicis del punto…</p>
    <template v-else>
      <p class="disponibles">Disponibles aquí ({{ disponibles.length }}):</p>
      <ul class="chips" aria-label="Bicis disponibles en este punto">
        <li v-for="b in disponibles" :key="b.id">
          <button type="button" class="chip" :aria-pressed="elegida?.id === b.id" @click="numero = String(b.numero)">
            {{ String(b.numero).padStart(3, '0') }}</button>
        </li>
      </ul>
      <p v-if="!disponibles.length" class="mensaje mensaje--aviso"><span>No hay bicis disponibles en este punto.</span></p>
    </template>

    <p v-if="avisoNoAqui" class="mensaje mensaje--aviso"><span>{{ avisoNoAqui }}</span></p>
    <div v-if="novedades.length" class="mensaje mensaje--aviso" role="status">
      <span><strong>Novedades abiertas de esta bici:</strong></span>
      <ul><li v-for="(n, i) in novedades" :key="i">{{ n.descripcion }} ({{ n.gravedad }})</li></ul>
      <span>Revísala con la persona antes de entregarla.</span>
    </div>
    <p v-if="error" class="mensaje mensaje--error" role="alert"><span>{{ error }}</span></p>

    <div class="acciones">
      <button class="boton" type="button" :disabled="!elegida" @click="emit('lista', elegida.numero)">Continuar</button>
      <button class="boton boton--contorno" type="button" @click="emit('atras')">Atrás</button>
    </div>
  </div>
</template>

<style scoped>
h2 { margin-top: 0; }
.numero { font-size: var(--texto-xl); font-weight: 650; max-width: 10rem; }
.disponibles { color: var(--tinta-2); margin-bottom: var(--esp-2); }
.chips { list-style: none; margin: 0 0 var(--esp-3); padding: 0; display: flex; flex-wrap: wrap; gap: var(--esp-2); max-height: 12rem; overflow-y: auto; }
.chip {
  min-width: 56px; min-height: var(--toque-min); border: 2px solid var(--linea-fuerte); border-radius: var(--radio-m);
  background: var(--superficie); color: var(--tinta-1); font: inherit; font-weight: 650; cursor: pointer;
}
.chip[aria-pressed='true'] { background: var(--secundario); border-color: var(--secundario); color: var(--sobre-secundario); }
.mensaje ul { margin: var(--esp-1) 0; }
</style>
