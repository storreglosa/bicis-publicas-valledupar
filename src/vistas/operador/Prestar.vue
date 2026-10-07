<script setup>
// Préstamo en 4 pasos: persona → bici → foto → confirmar (diseño §6, wireframe 2).
// El borrador vive en sessionStorage (se borra al cerrar la pestaña): si el
// celular recarga la página al volver de la cámara, la operación no se pierde.
import { computed, onMounted, ref, watch } from 'vue'
import PasoBici from '../../componentes/operador/PasoBici.vue'
import PasoFoto from '../../componentes/operador/PasoFoto.vue'
import PasoPersona from '../../componentes/operador/PasoPersona.vue'
import { useCatalogos } from '../../composables/useCatalogos.js'
import { usePuntoTrabajo } from '../../composables/usePuntoTrabajo.js'
import { codigoBici } from '../../lib/documento.js'
import { traducirError } from '../../lib/errores.js'
import { supabase } from '../../lib/supabase.js'
import { hora } from '../../lib/tiempo.js'
import { nuevoId } from '../../lib/uuid.js'

const BORRADOR = 'bicis.borrador_prestamo'
const PASOS = ['Persona', 'Bici', 'Foto', 'Confirmar']

const { punto } = usePuntoTrabajo()
const { tipos, politica, fotoPersonaObligatoria, error: errorCatalogos, listo } = useCatalogos()

const paso = ref(1)
const prestamoId = ref(nuevoId())
const persona = ref(null)
const numero = ref(null)
const foto = ref(null)
const resultado = ref(null)
const error = ref('')
const enviando = ref(false)

const codigo = computed(() => (numero.value ? codigoBici(numero.value) : ''))

function guardar() {
  try {
    sessionStorage.setItem(BORRADOR, JSON.stringify({
      punto: punto.value?.id, paso: paso.value, prestamoId: prestamoId.value, persona: persona.value,
      numero: numero.value, foto: foto.value && { ruta: foto.value.ruta, kb: foto.value.kb },
    }))
  } catch {
    // sin almacenamiento de sesión: el borrador solo vive en memoria
  }
}

function borrar() {
  try {
    sessionStorage.removeItem(BORRADOR)
  } catch {
    // ídem
  }
}

onMounted(() => {
  try {
    const b = JSON.parse(sessionStorage.getItem(BORRADOR))
    if (b && b.punto === punto.value?.id && b.paso < 5) {
      ({ paso: paso.value, prestamoId: prestamoId.value, persona: persona.value, numero: numero.value, foto: foto.value } = b)
    }
  } catch {
    borrar()
  }
})
watch([paso, persona, numero, foto, prestamoId], guardar, { deep: true })

function nuevoPrestamo() {
  borrar()
  paso.value = 1
  prestamoId.value = nuevoId()
  persona.value = null
  numero.value = null
  foto.value = null
  resultado.value = null
  error.value = ''
}

function repetirFoto() {
  foto.value = null
  prestamoId.value = nuevoId()   // la evidencia no se sobrescribe: nueva ruta
}

async function confirmar() {
  error.value = ''
  enviando.value = true
  const { data, error: e } = await supabase.rpc('registrar_prestamo', {
    p_id: prestamoId.value,
    p_persona_id: persona.value.id,
    p_numero_bici: numero.value,
    p_punto_id: punto.value.id,
    p_foto_ruta: foto.value.ruta,
    p_salida_cliente_en: new Date().toISOString(),
  })
  enviando.value = false
  if (e) {
    const t = traducirError(e)
    error.value = t.mensaje
    // Lleva al paso donde se puede corregir.
    if (['bici_ya_prestada', 'bici_no_disponible', 'bici_en_otro_punto', 'bici_no_existe'].includes(t.codigo)) paso.value = 2
    if (['falta_foto', 'foto_ruta_invalida'].includes(t.codigo)) { repetirFoto(); paso.value = 3 }
    return
  }
  resultado.value = data
  paso.value = 5
  borrar()
}
</script>

<template>
  <section class="contenedor pagina">
    <RouterLink to="/operador" class="volver">← Turno</RouterLink>
    <h1>Prestar</h1>
    <p v-if="punto" class="punto">{{ punto.codigo }} · {{ punto.nombre }}</p>

    <p v-if="!punto" class="mensaje mensaje--aviso"><span>Primero elige tu punto de trabajo en <RouterLink to="/operador">Turno</RouterLink>.</span></p>
    <p v-else-if="errorCatalogos" class="mensaje mensaje--error"><span>{{ errorCatalogos.mensaje }}</span></p>
    <p v-else-if="!listo">Cargando…</p>

    <template v-else>
      <ol v-if="paso <= 4" class="pasos" aria-label="Pasos del préstamo">
        <li v-for="(nombre, i) in PASOS" :key="nombre" :class="{ actual: paso === i + 1, completo: paso > i + 1 }"
          :aria-current="paso === i + 1 ? 'step' : undefined">
          <span class="pasos__n">{{ i + 1 }}</span>{{ nombre }}
        </li>
      </ol>

      <PasoPersona v-if="paso === 1" :tipos="tipos" :politica="politica" :foto-obligatoria="fotoPersonaObligatoria"
        :persona-inicial="persona" @lista="(p) => { persona = p; paso = 2 }" />

      <PasoBici v-else-if="paso === 2" :punto-id="punto.id" :numero-inicial="numero ?? ''"
        @lista="(n) => { numero = n; paso = 3 }" @atras="paso = 1" />

      <PasoFoto v-else-if="paso === 3" :key="prestamoId" :prestamo-id="prestamoId" :persona-y-bici="fotoPersonaObligatoria"
        :foto-inicial="foto" @antes-de-camara="guardar" @lista="(f) => { foto = f; paso = 4 }"
        @repetir="repetirFoto" @atras="paso = 2" />

      <div v-else-if="paso === 4" class="tarjeta-base">
        <h2>Confirmar préstamo</h2>
        <dl class="resumen">
          <dt>Persona</dt><dd>{{ persona.nombres }} {{ persona.apellidos }}<template v-if="persona.es_menor"> (menor)</template></dd>
          <dt>Bici</dt><dd class="resumen__bici">{{ codigo }}</dd>
          <dt>Punto</dt><dd>{{ punto.codigo }} · {{ punto.nombre }}</dd>
          <dt>Foto</dt><dd>guardada ({{ foto.kb }} KB)</dd>
        </dl>
        <p v-if="error" class="mensaje mensaje--error" role="alert"><span>{{ error }}</span></p>
        <button class="boton boton--grande boton--bloque" type="button" :disabled="enviando" @click="confirmar">
          {{ enviando ? 'Registrando…' : 'Prestar' }}</button>
        <div class="acciones"><button class="boton boton--contorno" type="button" @click="paso = 3">Atrás</button></div>
      </div>

      <div v-else-if="paso === 5" class="tarjeta-base hecho">
        <p class="hecho__titulo">Préstamo registrado</p>
        <p class="hecho__bici">Entrega la <strong>{{ resultado.codigo }}</strong></p>
        <p>Salida: {{ hora(resultado.salida_en) }}<template v-if="resultado.vence_en"> · Devolver antes de las
          <strong>{{ hora(resultado.vence_en) }}</strong></template></p>
        <div class="acciones">
          <button class="boton" type="button" @click="nuevoPrestamo">Nuevo préstamo</button>
          <RouterLink to="/operador" class="boton boton--contorno">Volver al turno</RouterLink>
        </div>
      </div>
    </template>
  </section>
</template>

<style scoped>
.pagina { padding-block: var(--esp-4) var(--esp-6); max-width: 44rem; }
.volver { display: inline-block; margin-bottom: var(--esp-2); }
h1 { margin-bottom: var(--esp-1); }
.punto { color: var(--tinta-2); margin-bottom: var(--esp-4); }
.pasos { list-style: none; padding: 0; margin: 0 0 var(--esp-4); display: grid; grid-template-columns: repeat(4, 1fr); gap: var(--esp-1); font-size: var(--texto-xs); color: var(--tinta-2); }
.pasos li { display: grid; justify-items: center; gap: 2px; text-align: center; }
.pasos__n { display: grid; place-items: center; width: 2rem; height: 2rem; border-radius: 50%; border: 2px solid var(--linea-fuerte); font-weight: 650; background: var(--superficie); }
.pasos .actual { color: var(--tinta-1); font-weight: 650; }
.pasos .actual .pasos__n { background: var(--primario); border-color: var(--primario); color: var(--sobre-primario); }
.pasos .completo .pasos__n { background: var(--secundario); border-color: var(--secundario); color: var(--sobre-secundario); }
.resumen { display: grid; grid-template-columns: auto 1fr; gap: var(--esp-2) var(--esp-4); margin: 0 0 var(--esp-4); }
.resumen dt { color: var(--tinta-2); }
.resumen dd { margin: 0; font-weight: 600; }
.resumen__bici { font-size: var(--texto-l); }
.hecho { border: 3px solid var(--exito); text-align: center; }
.hecho__titulo { color: var(--exito); font-weight: 650; font-size: var(--texto-l); margin-bottom: var(--esp-2); }
.hecho__bici { font-size: var(--texto-xl); }
.hecho .acciones { justify-content: center; }
.mensaje { margin: var(--esp-3) 0; }
</style>
