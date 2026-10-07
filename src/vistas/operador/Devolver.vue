<script setup>
// Devolución: número de la bici → revisión (sin novedad / con novedad) → confirmar.
// Con novedad se crea una incidencia y, si la bici queda fuera de servicio, deja de
// estar disponible. El id de operación hace idempotentes los reintentos.
import { computed, onMounted, ref } from 'vue'
import { usePuntoTrabajo } from '../../composables/usePuntoTrabajo.js'
import { codigoBici } from '../../lib/documento.js'
import { traducirError } from '../../lib/errores.js'
import { comprimirFoto } from '../../lib/foto.js'
import { supabase } from '../../lib/supabase.js'
import { duracion } from '../../lib/tiempo.js'
import { nuevoId } from '../../lib/uuid.js'

const { punto } = usePuntoTrabajo()
const idOperacion = ref(nuevoId())
const numero = ref('')
const conNovedad = ref(null)   // null = sin elegir
const novedad = ref({ tipo: 'dano', gravedad: 'leve', descripcion: '', fuera: false })
const fotoNovedad = ref(null)
const entrada = ref(null)
const subiendo = ref(false)
const observaciones = ref('')
const activos = ref([])
const resultado = ref(null)
const error = ref('')
const enviando = ref(false)

const tiposNovedad = [['dano', 'Daño'], ['accidente', 'Accidente'], ['retraso', 'Retraso'], ['conducta', 'Conducta'], ['otro', 'Otro']]
const gravedades = [['leve', 'Leve'], ['moderada', 'Moderada'], ['grave', 'Grave']]
const listo = computed(() => numero.value && conNovedad.value !== null
  && (!conNovedad.value || novedad.value.descripcion.trim().length >= 5) && !subiendo.value)

onMounted(async () => {
  if (!punto.value) return
  const { data } = await supabase.rpc('prestamos_activos', { p_punto_id: punto.value.id })
  activos.value = data ?? []
})

async function alElegirFoto(evento) {
  const archivo = evento.target.files?.[0]
  evento.target.value = ''
  if (!archivo) return
  subiendo.value = true
  error.value = ''
  try {
    const { blob, extension, tipo } = await comprimirFoto(archivo)
    const ruta = `incidencias/${nuevoId()}/novedad.${extension}`
    const { error: e } = await supabase.storage.from('evidencias').upload(ruta, blob, { contentType: tipo, upsert: false })
    if (e) throw e
    fotoNovedad.value = { ruta, kb: Math.round(blob.size / 1024) }
  } catch (e) {
    error.value = traducirError(e).mensaje
  } finally {
    subiendo.value = false
  }
}

async function confirmar() {
  error.value = ''
  enviando.value = true
  const { data, error: e } = await supabase.rpc('registrar_devolucion', {
    p_id_operacion: idOperacion.value,
    p_numero_bici: Number(numero.value),
    p_punto_id: punto.value.id,
    p_con_novedad: conNovedad.value,
    p_incidencia: conNovedad.value ? {
      tipo: novedad.value.tipo, gravedad: novedad.value.gravedad, descripcion: novedad.value.descripcion,
      deja_fuera_de_servicio: novedad.value.fuera, foto_ruta: fotoNovedad.value?.ruta ?? null,
    } : null,
    p_observaciones: observaciones.value || null,
  })
  enviando.value = false
  if (e) {
    error.value = traducirError(e).mensaje
    return
  }
  resultado.value = data
  activos.value = activos.value.filter((a) => a.numero !== Number(numero.value))
}

function otra() {
  idOperacion.value = nuevoId()
  numero.value = ''
  conNovedad.value = null
  novedad.value = { tipo: 'dano', gravedad: 'leve', descripcion: '', fuera: false }
  fotoNovedad.value = null
  observaciones.value = ''
  resultado.value = null
  error.value = ''
}
</script>

<template>
  <section class="contenedor pagina">
    <RouterLink to="/operador" class="volver">← Turno</RouterLink>
    <h1>Devolver</h1>
    <p v-if="punto" class="punto">Recibe en {{ punto.codigo }} · {{ punto.nombre }}</p>
    <p v-else class="mensaje mensaje--aviso"><span>Primero elige tu punto de trabajo en <RouterLink to="/operador">Turno</RouterLink>.</span></p>

    <div v-if="punto && !resultado" class="tarjeta-base">
      <label class="campo">
        <span>Número del sticker de la bici que llega</span>
        <input v-model="numero" class="numero" type="number" inputmode="numeric" min="1" max="9999" autocomplete="off" />
        <small v-if="numero">Código: {{ codigoBici(numero) }}</small>
      </label>
      <template v-if="activos.length">
        <p class="sugeridas">Salieron de este punto:</p>
        <ul class="chips">
          <li v-for="a in activos" :key="a.prestamo_id">
            <button type="button" class="chip" :aria-pressed="Number(numero) === a.numero" @click="numero = String(a.numero)">
              {{ a.codigo }} · {{ a.persona }}</button>
          </li>
        </ul>
      </template>

      <fieldset class="revision">
        <legend>Revisa la bici con la persona</legend>
        <div class="opciones">
          <button type="button" class="opcion" :aria-pressed="conNovedad === false" @click="conNovedad = false">Sin novedad</button>
          <button type="button" class="opcion opcion--novedad" :aria-pressed="conNovedad === true" @click="conNovedad = true">Con novedad</button>
        </div>
      </fieldset>

      <div v-if="conNovedad" class="novedad">
        <div class="fila-campos">
          <label class="campo"><span>Tipo</span>
            <select v-model="novedad.tipo"><option v-for="[v, t] in tiposNovedad" :key="v" :value="v">{{ t }}</option></select></label>
          <label class="campo"><span>Gravedad</span>
            <select v-model="novedad.gravedad"><option v-for="[v, t] in gravedades" :key="v" :value="v">{{ t }}</option></select></label>
        </div>
        <label class="campo"><span>¿Qué pasó?</span>
          <textarea v-model="novedad.descripcion" maxlength="1000" placeholder="Ej.: freno trasero suelto"></textarea>
          <small>No escribas datos personales aquí.</small></label>
        <label class="casilla"><input v-model="novedad.fuera" type="checkbox" />
          <span>La bici queda <strong>fuera de servicio</strong> (no se puede volver a prestar hasta repararla).</span></label>
        <input ref="entrada" class="visualmente-oculto" type="file" accept="image/*" capture="environment"
          tabindex="-1" aria-hidden="true" @change="alElegirFoto" />
        <button v-if="!fotoNovedad" type="button" class="boton boton--contorno" :disabled="subiendo" @click="entrada?.click()">
          {{ subiendo ? 'Subiendo foto…' : 'Foto del daño (opcional)' }}</button>
        <p v-else class="mensaje mensaje--exito"><span>Foto de la novedad guardada ({{ fotoNovedad.kb }} KB).</span></p>
      </div>

      <label class="campo observaciones"><span>Observaciones <small>(opcional)</small></span>
        <input v-model="observaciones" maxlength="500" autocomplete="off" /></label>

      <p v-if="error" class="mensaje mensaje--error" role="alert"><span>{{ error }}</span></p>
      <button class="boton boton--grande boton--bloque" type="button" :disabled="!listo || enviando" @click="confirmar">
        {{ enviando ? 'Registrando…' : 'Registrar devolución' }}</button>
    </div>

    <div v-if="resultado" class="tarjeta-base hecho">
      <p class="hecho__titulo">Devolución registrada</p>
      <p class="hecho__bici"><strong>{{ resultado.codigo }}</strong> · {{ resultado.persona }}</p>
      <p>Duración: <strong>{{ duracion(resultado.duracion_min) }}</strong></p>
      <p v-if="resultado.excedio" class="mensaje mensaje--aviso"><span>Superó la duración máxima del préstamo.</span></p>
      <p v-if="conNovedad" class="mensaje mensaje--aviso"><span>Quedó registrada la novedad para el administrador.</span></p>
      <div class="acciones">
        <button class="boton" type="button" @click="otra">Otra devolución</button>
        <RouterLink to="/operador" class="boton boton--contorno">Volver al turno</RouterLink>
      </div>
    </div>
  </section>
</template>

<style scoped>
.pagina { padding-block: var(--esp-4) var(--esp-6); max-width: 44rem; }
.volver { display: inline-block; margin-bottom: var(--esp-2); }
h1 { margin-bottom: var(--esp-1); }
.punto { color: var(--tinta-2); margin-bottom: var(--esp-4); }
.numero { font-size: var(--texto-xl); font-weight: 650; max-width: 10rem; }
.sugeridas { color: var(--tinta-2); margin-bottom: var(--esp-2); }
.chips { list-style: none; margin: 0 0 var(--esp-4); padding: 0; display: flex; flex-wrap: wrap; gap: var(--esp-2); }
.chip, .opcion {
  min-height: var(--toque-min); padding: 0 var(--esp-3); border: 2px solid var(--linea-fuerte); border-radius: var(--radio-m);
  background: var(--superficie); color: var(--tinta-1); font: inherit; font-weight: 600; cursor: pointer;
}
.chip[aria-pressed='true'] { background: var(--secundario); border-color: var(--secundario); color: var(--sobre-secundario); }
.revision { border: 0; padding: 0; margin: 0 0 var(--esp-4); }
.revision legend { font-weight: 650; margin-bottom: var(--esp-2); }
.opciones { display: grid; grid-template-columns: 1fr 1fr; gap: var(--esp-3); }
.opcion { min-height: 64px; font-size: var(--texto-l); }
.opcion[aria-pressed='true'] { background: var(--estado-disponible); border-color: var(--estado-disponible); color: var(--sobre-estado); }
.opcion--novedad[aria-pressed='true'] { background: var(--estado-pocas); border-color: var(--estado-pocas); }
.novedad { background: var(--banda); border-radius: var(--radio-m); padding: var(--esp-3) var(--esp-4); margin-bottom: var(--esp-4); }
.observaciones { margin-top: var(--esp-2); }
.hecho { border: 3px solid var(--exito); text-align: center; }
.hecho__titulo { color: var(--exito); font-weight: 650; font-size: var(--texto-l); margin-bottom: var(--esp-2); }
.hecho__bici { font-size: var(--texto-xl); }
.hecho .acciones { justify-content: center; }
.mensaje { margin: var(--esp-3) 0; }
</style>
