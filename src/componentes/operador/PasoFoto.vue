<script setup>
// Paso 3: foto de evidencia. Cámara nativa del celular (input capture), compresión
// en el navegador (sin EXIF ni GPS) y subida al bucket privado ANTES de registrar
// el préstamo: la base exige que la foto exista. La ruta va atada al id del
// préstamo; repetir la foto cambia ese id (no se sobrescribe evidencia).
import { ref } from 'vue'
import { traducirError } from '../../lib/errores.js'
import { comprimirFoto } from '../../lib/foto.js'
import { supabase } from '../../lib/supabase.js'

const props = defineProps({
  prestamoId: { type: String, required: true },
  personaYBici: { type: Boolean, default: true },
  fotoInicial: { type: Object, default: null },
})
const emit = defineEmits(['lista', 'repetir', 'atras', 'antes-de-camara'])

const entrada = ref(null)
const foto = ref(props.fotoInicial)
const procesando = ref(false)
const error = ref('')

function abrirCamara() {
  emit('antes-de-camara')   // guarda el borrador: algunos celulares recargan la página al volver
  entrada.value?.click()
}

async function alElegir(evento) {
  const archivo = evento.target.files?.[0]
  evento.target.value = ''
  if (!archivo) return
  error.value = ''
  procesando.value = true
  try {
    const { blob, extension, tipo } = await comprimirFoto(archivo)
    const ruta = `prestamos/${props.prestamoId}/salida.${extension}`
    const { error: e } = await supabase.storage.from('evidencias').upload(ruta, blob, { contentType: tipo, upsert: false })
    // Un reintento de la misma subida responde «ya existe»: la evidencia ya está.
    if (e && !/already exists|duplicate/i.test(e.message)) throw e
    foto.value = { ruta, kb: Math.round(blob.size / 1024), url: URL.createObjectURL(blob) }
  } catch (e) {
    error.value = e.message === 'foto_demasiado_grande'
      ? 'La foto quedó demasiado pesada. Tómala de nuevo con menos detalle de fondo.'
      : traducirError(e).mensaje
  } finally {
    procesando.value = false
  }
}

function repetir() {
  foto.value = null
  emit('repetir')
}
</script>

<template>
  <div class="tarjeta-base">
    <h2>Foto de evidencia</h2>
    <p class="instruccion">{{ personaYBici
      ? 'Toma una foto de la persona con la bicicleta, donde se vea el número del sticker.'
      : 'Toma una foto de la bicicleta donde se vea el número del sticker.' }}</p>

    <input ref="entrada" class="visualmente-oculto" type="file" accept="image/*" capture="environment"
      tabindex="-1" aria-hidden="true" @change="alElegir" />

    <div v-if="foto" class="vista">
      <img v-if="foto.url" :src="foto.url" alt="Foto de evidencia del préstamo" />
      <p class="mensaje mensaje--exito"><span>Foto guardada ({{ foto.kb }} KB).</span></p>
    </div>
    <button v-else class="boton boton--grande boton--bloque" type="button" :disabled="procesando" @click="abrirCamara">
      {{ procesando ? 'Procesando y subiendo…' : 'Tomar foto' }}</button>

    <p v-if="error" class="mensaje mensaje--error" role="alert"><span>{{ error }}</span></p>
    <div class="acciones">
      <button class="boton" type="button" :disabled="!foto || procesando" @click="emit('lista', foto)">Continuar</button>
      <button v-if="foto" class="boton boton--contorno" type="button" @click="repetir">Repetir foto</button>
      <button class="boton boton--contorno" type="button" @click="emit('atras')">Atrás</button>
    </div>
  </div>
</template>

<style scoped>
h2 { margin-top: 0; }
.instruccion { color: var(--tinta-2); }
.vista img { display: block; width: 100%; max-height: 22rem; object-fit: contain; border-radius: var(--radio-m); background: var(--banda); }
.mensaje { margin: var(--esp-3) 0; }
</style>
