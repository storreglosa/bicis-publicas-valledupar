<script setup>
// Paso 1 del préstamo: identificar a la persona por su documento EXACTO
// (buscar_persona; queda en la bitácora), validarla con el documento original a
// la vista y, si hace falta, registrar su autorización presencial.
import { computed, ref } from 'vue'
import CasillasAutorizacion from './CasillasAutorizacion.vue'
import FormularioInscripcion from './FormularioInscripcion.vue'
import { normalizarDocumento } from '../../lib/documento.js'
import { traducirError } from '../../lib/errores.js'
import { supabase } from '../../lib/supabase.js'
import { nuevoId } from '../../lib/uuid.js'

const props = defineProps({
  tipos: { type: Array, required: true },
  politica: { type: Object, required: true },
  fotoObligatoria: { type: Boolean, default: true },
  personaInicial: { type: Object, default: null },
})
const emit = defineEmits(['lista'])

const tipo = ref('CC')
const numero = ref('')
const resumen = ref(props.personaInicial)
const noEncontrada = ref(false)
const inscribiendo = ref(false)
const ocupado = ref(false)
const error = ref('')
const vioDocumento = ref(false)
const aut = ref({ tratamiento: false, foto: false, menorEscuchado: false })
const corrigiendo = ref(false)
const correccion = ref({ telefono: '', edad: '' })

const r = computed(() => resumen.value)
const bloqueo = computed(() => r.value?.sancion
  ? `Tiene una suspensión vigente hasta ${r.value.sancion.hasta}: ${r.value.sancion.motivo}` : '')
const necesitaValidar = computed(() => r.value?.estado === 'preinscrita')
const necesitaAutorizacion = computed(() => Boolean(r.value) && (
  !r.value.autorizacion_vigente
  || (props.fotoObligatoria && !r.value.autoriza_foto)
  || (r.value.es_menor && !r.value.autorizacion_presencial)))
const autorizacionCompleta = computed(() => aut.value.tratamiento
  && (!props.fotoObligatoria || aut.value.foto) && (!r.value?.es_menor || aut.value.menorEscuchado))
const puedeContinuar = computed(() => Boolean(r.value) && !bloqueo.value && vioDocumento.value
  && (!necesitaAutorizacion.value || autorizacionCompleta.value))

function nuevaBusqueda() {
  resumen.value = null
  noEncontrada.value = false
  inscribiendo.value = false
  vioDocumento.value = false
  corrigiendo.value = false
  correccion.value = { telefono: '', edad: '' }
  aut.value = { tratamiento: false, foto: false, menorEscuchado: false }
  error.value = ''
}

async function buscar() {
  const doc = normalizarDocumento(numero.value)
  if (!doc) return
  nuevaBusqueda()
  ocupado.value = true
  const { data, error: e } = await supabase.rpc('buscar_persona', { p_tipo: tipo.value, p_numero: doc })
  ocupado.value = false
  if (e) {
    error.value = traducirError(e).mensaje
    return
  }
  if (data) resumen.value = data
  else noEncontrada.value = true
}

function alInscribir(datos) {
  resumen.value = datos
  inscribiendo.value = false
  noEncontrada.value = false
  vioDocumento.value = true   // se inscribió con el documento a la vista
}

async function continuar() {
  error.value = ''
  const correcciones = {}
  if (correccion.value.telefono) correcciones.telefono = correccion.value.telefono
  if (correccion.value.edad !== '') correcciones.edad = String(correccion.value.edad)
  const autorizacion = necesitaAutorizacion.value ? {
    id: nuevoId(), politica_version: props.politica.version,
    autoriza_tratamiento: aut.value.tratamiento, autoriza_foto: aut.value.foto,
    menor_escuchado: r.value.es_menor ? aut.value.menorEscuchado : null,
  } : null

  let datos = r.value
  ocupado.value = true
  if (necesitaValidar.value || Object.keys(correcciones).length) {
    const { data, error: e } = await supabase.rpc('validar_persona', {
      p_persona_id: r.value.id, p_correcciones: correcciones, p_autorizacion: autorizacion,
    })
    if (e) error.value = traducirError(e).mensaje
    else datos = data
  } else if (autorizacion) {
    const { data, error: e } = await supabase.rpc('registrar_autorizacion', {
      p_persona_id: r.value.id, p_autorizacion: autorizacion,
    })
    if (e) error.value = traducirError(e).mensaje
    else datos = data
  }
  ocupado.value = false
  if (!error.value) emit('lista', datos)
}
</script>

<template>
  <div>
    <form v-if="!r && !inscribiendo" class="tarjeta-base" @submit.prevent="buscar">
      <h2>¿Quién presta?</h2>
      <div class="fila-campos">
        <label class="campo"><span>Tipo de documento</span>
          <select v-model="tipo"><option v-for="t in tipos" :key="t.codigo" :value="t.codigo">{{ t.nombre }}</option></select>
        </label>
        <label class="campo"><span>Número del documento</span>
          <input v-model="numero" :inputmode="tipo === 'CC' || tipo === 'TI' ? 'numeric' : 'text'" autocomplete="off" />
        </label>
      </div>
      <button class="boton boton--bloque" type="submit" :disabled="!numero || ocupado">{{ ocupado ? 'Buscando…' : 'Buscar' }}</button>
      <div v-if="noEncontrada" class="no-encontrada">
        <p class="mensaje mensaje--aviso"><span>No hay nadie inscrito con ese documento.</span></p>
        <button class="boton boton--secundario" type="button" @click="inscribiendo = true">Inscribir aquí</button>
      </div>
    </form>

    <FormularioInscripcion v-if="inscribiendo" :tipos="tipos" :politica="politica" :foto-obligatoria="fotoObligatoria"
      :tipo-inicial="tipo" :numero-inicial="numero" @inscrita="alInscribir" @cancelar="nuevaBusqueda" />

    <div v-if="r" class="tarjeta-base persona">
      <div class="persona__cabeza">
        <h2>{{ r.nombres }} {{ r.apellidos }}</h2>
        <span class="etiqueta-estado" :class="r.estado === 'validada' ? 'etiqueta-estado--exito' : 'etiqueta-estado--aviso'">
          {{ r.estado === 'validada' ? 'Validada' : 'Preinscrita' }}</span>
      </div>
      <p class="datos">{{ r.tipo_documento }} {{ r.documento_enmascarado }} · {{ r.edad_estimada }} años
        · cel. {{ r.telefono_enmascarado }}<template v-if="r.es_menor"> · <strong>menor de edad</strong></template></p>
      <p v-if="r.acudiente" class="datos">Acudiente: {{ r.acudiente.nombres }} {{ r.acudiente.apellidos }}
        ({{ r.acudiente.parentesco }}) · {{ r.acudiente.tipo_documento }} {{ r.acudiente.documento_enmascarado }}</p>
      <p v-if="r.prestamos_activos" class="mensaje mensaje--aviso"><span>Ya tiene {{ r.prestamos_activos }} préstamo(s) activo(s).</span></p>
      <p v-if="bloqueo" class="mensaje mensaje--error" role="alert"><span>{{ bloqueo }}. No puede prestar.</span></p>

      <template v-if="!bloqueo">
        <label class="casilla verificacion">
          <input v-model="vioDocumento" type="checkbox" />
          <span><strong>Vi el documento original</strong> y coincide con estos datos (solo se mira; no se retiene).</span>
        </label>

        <button v-if="!corrigiendo" type="button" class="enlace" @click="corrigiendo = true">Corregir celular o edad</button>
        <div v-else class="fila-campos">
          <label class="campo"><span>Celular nuevo</span><input v-model="correccion.telefono" type="tel" inputmode="tel" /></label>
          <label class="campo"><span>Edad</span><input v-model="correccion.edad" type="number" inputmode="numeric" min="5" max="110" /></label>
        </div>

        <CasillasAutorizacion v-if="necesitaAutorizacion" v-model="aut" :politica="politica" :es-menor="r.es_menor"
          :acudiente="r.acudiente" :foto-obligatoria="fotoObligatoria" />
      </template>

      <p v-if="error" class="mensaje mensaje--error" role="alert"><span>{{ error }}</span></p>
      <div class="acciones">
        <button class="boton" type="button" :disabled="!puedeContinuar || ocupado" @click="continuar">
          {{ ocupado ? 'Guardando…' : necesitaValidar ? 'Validar y continuar' : 'Continuar' }}</button>
        <button class="boton boton--contorno" type="button" @click="nuevaBusqueda">Otra persona</button>
      </div>
    </div>
    <p v-if="error && !r" class="mensaje mensaje--error" role="alert"><span>{{ error }}</span></p>
  </div>
</template>

<style scoped>
h2 { margin: 0; }
.no-encontrada { margin-top: var(--esp-4); display: grid; gap: var(--esp-3); }
.persona__cabeza { display: flex; justify-content: space-between; align-items: start; gap: var(--esp-2); margin-bottom: var(--esp-2); }
.datos { color: var(--tinta-2); margin-bottom: var(--esp-2); }
.verificacion { margin-top: var(--esp-3); padding: var(--esp-3); background: var(--banda); border-radius: var(--radio-m); }
.enlace { background: none; border: 0; padding: var(--esp-2) 0; color: var(--primario); text-decoration: underline; font: inherit; cursor: pointer; min-height: var(--toque-min); }
.mensaje { margin: var(--esp-3) 0; }
</style>
