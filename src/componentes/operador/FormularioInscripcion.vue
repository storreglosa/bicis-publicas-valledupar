<script setup>
// Inscripción en el punto de una persona que no se preinscribió. Queda validada
// al momento (el operador vio el documento) y con autorización presencial.
import { computed, reactive, ref } from 'vue'
import CasillasAutorizacion from './CasillasAutorizacion.vue'
import { normalizarDocumento, telefonoValido } from '../../lib/documento.js'
import { traducirError } from '../../lib/errores.js'
import { supabase } from '../../lib/supabase.js'
import { nuevoId } from '../../lib/uuid.js'

const props = defineProps({
  tipos: { type: Array, required: true },
  politica: { type: Object, required: true },
  fotoObligatoria: { type: Boolean, default: true },
  tipoInicial: { type: String, default: 'CC' },
  numeroInicial: { type: String, default: '' },
})
const emit = defineEmits(['inscrita', 'cancelar'])

// Identificadores fijos por formulario: si la red falla y se reintenta, no se duplica.
const idOperacion = nuevoId()
const idAutorizacion = nuevoId()

const f = reactive({
  tipo: props.tipoInicial, numero: props.numeroInicial, nombres: '', apellidos: '',
  telefono: '', correo: '', edad: '', sexo: '',
  acu: { tipo: 'CC', numero: '', nombres: '', apellidos: '', telefono: '', parentesco: '' },
})
const aut = ref({ tratamiento: false, foto: false, menorEscuchado: false })
const enviando = ref(false)
const error = ref('')
const yaInscrita = ref(false)

const tipoActual = computed(() => props.tipos.find((t) => t.codigo === f.tipo))
const esMenor = computed(() => tipoActual.value?.implica_menor || (f.edad !== '' && Number(f.edad) < 18))
const adultos = computed(() => props.tipos.filter((t) => !t.implica_menor))
const sexos = [
  ['mujer', 'Mujer'], ['hombre', 'Hombre'], ['otro', 'Otro'], ['prefiere_no_responder', 'Prefiere no responder'],
]
const parentescos = [['madre', 'Madre'], ['padre', 'Padre'], ['representante_legal', 'Representante legal']]

const completo = computed(() => {
  const base = f.numero && f.nombres.trim() && f.apellidos.trim() && telefonoValido(f.telefono) && f.edad && f.sexo
  const acu = !esMenor.value || (f.acu.numero && f.acu.nombres.trim() && f.acu.apellidos.trim()
    && telefonoValido(f.acu.telefono) && f.acu.parentesco)
  const autOk = aut.value.tratamiento && (!props.fotoObligatoria || aut.value.foto) && (!esMenor.value || aut.value.menorEscuchado)
  return Boolean(base && acu && autOk)
})

async function enviar() {
  error.value = ''
  yaInscrita.value = false
  enviando.value = true
  const p = {
    id_operacion: idOperacion,
    tipo_documento: f.tipo,
    numero_documento: normalizarDocumento(f.numero),
    nombres: f.nombres, apellidos: f.apellidos, telefono: f.telefono,
    correo: f.correo || null, edad: String(f.edad), sexo_genero: f.sexo,
    autorizacion: {
      id: idAutorizacion, politica_version: props.politica.version,
      autoriza_tratamiento: aut.value.tratamiento, autoriza_foto: aut.value.foto,
      menor_escuchado: esMenor.value ? aut.value.menorEscuchado : null,
    },
  }
  if (esMenor.value) {
    p.acudiente = {
      tipo_documento: f.acu.tipo, numero_documento: normalizarDocumento(f.acu.numero),
      nombres: f.acu.nombres, apellidos: f.acu.apellidos, telefono: f.acu.telefono, parentesco: f.acu.parentesco,
    }
  }
  const { data, error: e } = await supabase.rpc('registrar_persona_en_punto', { p })
  if (e) {
    enviando.value = false
    error.value = traducirError(e).mensaje
    return
  }
  if (data.resultado === 'ya_inscrito') {
    enviando.value = false
    yaInscrita.value = true
    return
  }
  // Recién inscrita: se busca para mostrar su resumen (queda en la bitácora).
  const r = await supabase.rpc('buscar_persona', { p_tipo: p.tipo_documento, p_numero: p.numero_documento })
  enviando.value = false
  if (r.error) {
    error.value = traducirError(r.error).mensaje
    return
  }
  emit('inscrita', r.data)
}
</script>

<template>
  <form class="tarjeta-base" novalidate @submit.prevent="enviar">
    <h3>Inscribir en el punto</h3>
    <p class="nota">Copia los datos del documento original que te muestra la persona. No lo retengas.</p>

    <div class="fila-campos">
      <label class="campo"><span>Tipo de documento</span>
        <select v-model="f.tipo"><option v-for="t in tipos" :key="t.codigo" :value="t.codigo">{{ t.nombre }}</option></select>
      </label>
      <label class="campo"><span>Número</span>
        <input v-model="f.numero" :inputmode="f.tipo === 'CC' || f.tipo === 'TI' ? 'numeric' : 'text'" autocomplete="off" />
      </label>
    </div>
    <div class="fila-campos">
      <label class="campo"><span>Nombres</span><input v-model="f.nombres" autocomplete="off" /></label>
      <label class="campo"><span>Apellidos</span><input v-model="f.apellidos" autocomplete="off" /></label>
    </div>
    <div class="fila-campos">
      <label class="campo"><span>Celular</span><input v-model="f.telefono" type="tel" inputmode="tel" autocomplete="off" /></label>
      <label class="campo"><span>Correo <small>(opcional)</small></span><input v-model="f.correo" type="email" inputmode="email" autocomplete="off" /></label>
    </div>
    <div class="fila-campos">
      <label class="campo"><span>Edad</span><input v-model="f.edad" type="number" inputmode="numeric" min="5" max="110" /></label>
      <label class="campo"><span>Sexo / género</span>
        <select v-model="f.sexo"><option value="" disabled>Elige…</option>
          <option v-for="[v, t] in sexos" :key="v" :value="v">{{ t }}</option></select>
      </label>
    </div>

    <fieldset v-if="esMenor" class="acudiente">
      <legend>Acudiente (madre, padre o representante legal) — debe estar presente</legend>
      <div class="fila-campos">
        <label class="campo"><span>Tipo de documento</span>
          <select v-model="f.acu.tipo"><option v-for="t in adultos" :key="t.codigo" :value="t.codigo">{{ t.nombre }}</option></select>
        </label>
        <label class="campo"><span>Número</span><input v-model="f.acu.numero" inputmode="numeric" autocomplete="off" /></label>
      </div>
      <div class="fila-campos">
        <label class="campo"><span>Nombres</span><input v-model="f.acu.nombres" autocomplete="off" /></label>
        <label class="campo"><span>Apellidos</span><input v-model="f.acu.apellidos" autocomplete="off" /></label>
      </div>
      <div class="fila-campos">
        <label class="campo"><span>Celular</span><input v-model="f.acu.telefono" type="tel" inputmode="tel" autocomplete="off" /></label>
        <label class="campo"><span>Parentesco</span>
          <select v-model="f.acu.parentesco"><option value="" disabled>Elige…</option>
            <option v-for="[v, t] in parentescos" :key="v" :value="v">{{ t }}</option></select>
        </label>
      </div>
    </fieldset>

    <CasillasAutorizacion v-model="aut" :politica="politica" :es-menor="esMenor" :foto-obligatoria="fotoObligatoria" />

    <p v-if="yaInscrita" class="mensaje mensaje--aviso" role="alert">
      <span>Esa persona ya está inscrita. Búscala por su documento.</span>
    </p>
    <p v-if="error" class="mensaje mensaje--error" role="alert"><span>{{ error }}</span></p>
    <div class="acciones">
      <button class="boton" type="submit" :disabled="!completo || enviando">{{ enviando ? 'Inscribiendo…' : 'Inscribir y continuar' }}</button>
      <button class="boton boton--contorno" type="button" @click="emit('cancelar')">Volver a buscar</button>
    </div>
  </form>
</template>

<style scoped>
h3 { margin-top: 0; }
.nota { color: var(--tinta-2); font-size: var(--texto-s); }
.acudiente { border: 2px dashed var(--linea-fuerte); border-radius: var(--radio-m); padding: var(--esp-3) var(--esp-4); margin: 0 0 var(--esp-4); }
.acudiente legend { font-weight: 650; padding: 0 var(--esp-2); }
.mensaje { margin: var(--esp-3) 0; }
</style>
