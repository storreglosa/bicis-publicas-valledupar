<script setup>
// Preinscripción pública (hito 1e). La persona deja sus datos y su autorización; la
// primera vez que preste, un operador ve su documento original y la valida en el
// punto. La envía la Edge Function `preinscribir` (Turnstile + límite de intentos),
// que responde solo «inscrito» o «ya inscrito»: nunca devuelve datos.
import { computed, reactive, ref } from 'vue'
import { RouterLink } from 'vue-router'
import Turnstile from '../../componentes/publico/Turnstile.vue'
import { useCatalogos } from '../../composables/useCatalogos.js'
import { normalizarDocumento, telefonoValido } from '../../lib/documento.js'
import { traducirError } from '../../lib/errores.js'
import { configurado, supabase } from '../../lib/supabase.js'
import { nuevoId } from '../../lib/uuid.js'

const claveSitio = import.meta.env.VITE_TURNSTILE_SITE_KEY ?? ''
const esDemo = import.meta.env.VITE_DEMO === '1'
const { tipos, politica, fotoPersonaObligatoria, error: errorCatalogos, listo } = useCatalogos()

const SEXOS = [['mujer', 'Mujer'], ['hombre', 'Hombre'], ['otro', 'Otro'], ['prefiere_no_responder', 'Prefiero no responder']]
const PARENTESCOS = [['madre', 'Madre'], ['padre', 'Padre'], ['representante_legal', 'Representante legal']]

function vacio() {
  // Identificadores fijos por formulario: un reintento tras un fallo de red no duplica.
  return {
    idOperacion: nuevoId(), idAutorizacion: nuevoId(),
    tipo: 'CC', numero: '', nombres: '', apellidos: '', telefono: '', correo: '', edad: '', sexo: '',
    acu: { tipo: 'CC', numero: '', nombres: '', apellidos: '', telefono: '', parentesco: '' },
    aut: { tratamiento: false, foto: false, menorEscuchado: false },
  }
}
const f = reactive(vacio())
const token = ref('')
const verificacion = ref(null)
const enviando = ref(false)
const error = ref('')
const resultado = ref('')        // 'inscrito' | 'ya_inscrito'

const tipoActual = computed(() => tipos.value.find((t) => t.codigo === f.tipo))
const esMenor = computed(() => Boolean(tipoActual.value?.implica_menor) || (f.edad !== '' && Number(f.edad) < 18))
const adultos = computed(() => tipos.value.filter((t) => !t.implica_menor))

const falta = computed(() => {
  if (!f.numero.trim()) return 'el número de documento'
  if (!f.nombres.trim() || !f.apellidos.trim()) return 'tus nombres y apellidos'
  if (!telefonoValido(f.telefono)) return 'un celular válido'
  if (f.edad === '') return 'tu edad'
  if (!f.sexo) return 'sexo / género'
  if (esMenor.value) {
    const a = f.acu
    if (!a.numero.trim() || !a.nombres.trim() || !a.apellidos.trim() || !telefonoValido(a.telefono) || !a.parentesco) {
      return 'los datos completos del acudiente'
    }
    if (!f.aut.menorEscuchado) return 'la declaración del acudiente sobre la opinión del menor'
  }
  if (!f.aut.tratamiento) return 'la autorización de tratamiento de datos'
  if (fotoPersonaObligatoria.value && !f.aut.foto) return 'la autorización de la foto (sin ella no se puede prestar)'
  if (!token.value) return 'completar la verificación anti-robots'
  return ''
})

async function codigoDeError(e) {
  if (e?.context instanceof Response) {
    try { return (await e.context.json()).error ?? 'error_interno' } catch { return 'error_interno' }
  }
  return e?.name === 'FunctionsFetchError' ? 'Failed to fetch' : String(e?.message ?? 'error_interno')
}

async function enviar() {
  error.value = ''
  enviando.value = true
  const persona = {
    id_operacion: f.idOperacion,
    tipo_documento: f.tipo,
    numero_documento: normalizarDocumento(f.numero),
    nombres: f.nombres, apellidos: f.apellidos, telefono: f.telefono,
    correo: f.correo.trim() || null, edad: String(f.edad), sexo_genero: f.sexo,
    autorizacion: {
      id: f.idAutorizacion, politica_version: politica.value.version,
      autoriza_tratamiento: f.aut.tratamiento, autoriza_foto: f.aut.foto,
      menor_escuchado: esMenor.value ? f.aut.menorEscuchado : null,
    },
  }
  if (esMenor.value) {
    persona.acudiente = {
      tipo_documento: f.acu.tipo, numero_documento: normalizarDocumento(f.acu.numero),
      nombres: f.acu.nombres, apellidos: f.acu.apellidos, telefono: f.acu.telefono, parentesco: f.acu.parentesco,
    }
  }
  const { data, error: e } = await supabase.functions.invoke('preinscribir', { body: { persona, turnstile: token.value } })
  enviando.value = false
  verificacion.value?.reiniciar()           // el token ya se usó
  if (e) {
    error.value = traducirError(await codigoDeError(e)).mensaje
    return
  }
  resultado.value = data?.resultado === 'ya_inscrito' ? 'ya_inscrito' : 'inscrito'
  window.scrollTo({ top: 0 })
}

function otraPersona() {
  Object.assign(f, vacio())
  resultado.value = ''
  error.value = ''
}
</script>

<template>
  <section class="contenedor inscribirme">
    <h1>Inscribirme</h1>

    <div v-if="resultado === 'inscrito'" class="tarjeta-base resultado" role="status">
      <p class="resultado__titulo">Listo: quedaste preinscrito.</p>
      <p>La primera vez que vayas a prestar una bici, muéstrale tu <strong>documento original</strong> al operador
        en el punto para validar tu inscripción.<template v-if="esMenor"> Ve con tu acudiente: debe presentar su
        documento y autorizar en persona.</template></p>
      <div class="acciones">
        <RouterLink to="/mapa" class="boton">Ver puntos y bicis disponibles</RouterLink>
        <button class="boton boton--contorno" type="button" @click="otraPersona">Inscribir a otra persona</button>
      </div>
    </div>

    <div v-else-if="resultado === 'ya_inscrito'" class="tarjeta-base resultado" role="status">
      <p class="resultado__titulo">Ese documento ya está inscrito.</p>
      <p>No tienes que hacer nada más: acércate a cualquier punto con tu documento original y un operador te atiende.</p>
      <div class="acciones">
        <RouterLink to="/mapa" class="boton">Ver puntos</RouterLink>
        <button class="boton boton--contorno" type="button" @click="otraPersona">Inscribir a otra persona</button>
      </div>
    </div>

    <template v-else>
      <p class="intro">Déjanos tus datos y ahórrate tiempo en el punto. La primera vez que prestes, el operador
        mira tu documento original (no lo retiene) y valida tu inscripción.</p>
      <p v-if="esDemo" class="mensaje mensaje--aviso"><span><strong>Versión de prueba:</strong> usa datos inventados,
        no los tuyos.</span></p>

      <p v-if="!configurado || !claveSitio" class="mensaje mensaje--aviso"><span>La inscripción en línea todavía no está
        disponible. Puedes inscribirte directamente en cualquier punto con tu documento original.</span></p>
      <p v-else-if="errorCatalogos" class="mensaje mensaje--error"><span>{{ errorCatalogos.mensaje }}</span></p>
      <p v-else-if="!listo">Cargando…</p>

      <form v-else class="tarjeta-base" novalidate @submit.prevent="enviar">
        <h2>Tus datos</h2>
        <div class="fila-campos">
          <label class="campo"><span>Tipo de documento</span>
            <select v-model="f.tipo"><option v-for="t in tipos" :key="t.codigo" :value="t.codigo">{{ t.nombre }}</option></select></label>
          <label class="campo"><span>Número de documento</span>
            <input v-model="f.numero" :inputmode="f.tipo === 'CC' || f.tipo === 'TI' ? 'numeric' : 'text'" autocomplete="off" maxlength="20" /></label>
        </div>
        <div class="fila-campos">
          <label class="campo"><span>Nombres</span><input v-model="f.nombres" autocomplete="given-name" maxlength="80" /></label>
          <label class="campo"><span>Apellidos</span><input v-model="f.apellidos" autocomplete="family-name" maxlength="80" /></label>
        </div>
        <div class="fila-campos">
          <label class="campo"><span>Celular</span><input v-model="f.telefono" type="tel" inputmode="tel" autocomplete="tel" maxlength="20" /></label>
          <label class="campo"><span>Correo <small>(opcional)</small></span><input v-model="f.correo" type="email" inputmode="email" autocomplete="email" maxlength="120" /></label>
        </div>
        <div class="fila-campos">
          <label class="campo"><span>Edad</span><input v-model="f.edad" type="number" inputmode="numeric" min="5" max="110" /></label>
          <label class="campo"><span>Sexo / género</span>
            <select v-model="f.sexo"><option value="" disabled>Elige…</option>
              <option v-for="[v, t] in SEXOS" :key="v" :value="v">{{ t }}</option></select></label>
        </div>

        <fieldset v-if="esMenor" class="grupo">
          <legend>Acudiente</legend>
          <p class="mensaje mensaje--aviso"><span>Eres menor de edad: tu madre, padre o representante legal debe llenar
            esta parte contigo y acompañarte al punto la primera vez, con su documento original.</span></p>
          <div class="fila-campos">
            <label class="campo"><span>Parentesco</span>
              <select v-model="f.acu.parentesco"><option value="" disabled>Elige…</option>
                <option v-for="[v, t] in PARENTESCOS" :key="v" :value="v">{{ t }}</option></select></label>
            <label class="campo"><span>Tipo de documento</span>
              <select v-model="f.acu.tipo"><option v-for="t in adultos" :key="t.codigo" :value="t.codigo">{{ t.nombre }}</option></select></label>
            <label class="campo"><span>Número</span><input v-model="f.acu.numero" inputmode="numeric" autocomplete="off" maxlength="20" /></label>
          </div>
          <div class="fila-campos">
            <label class="campo"><span>Nombres</span><input v-model="f.acu.nombres" autocomplete="off" maxlength="80" /></label>
            <label class="campo"><span>Apellidos</span><input v-model="f.acu.apellidos" autocomplete="off" maxlength="80" /></label>
            <label class="campo"><span>Celular</span><input v-model="f.acu.telefono" type="tel" inputmode="tel" autocomplete="off" maxlength="20" /></label>
          </div>
        </fieldset>

        <fieldset class="grupo">
          <legend>Autorización de datos personales <small>(política v{{ politica.version }})</small></legend>
          <p class="nota">Léela y marca solo si estás de acuerdo{{ esMenor ? ' (la marca tu acudiente)' : '' }}.
            Texto completo: <RouterLink :to="`/politica-de-datos/${politica.version}`" target="_blank">política de tratamiento de datos</RouterLink>.</p>
          <label class="casilla"><input v-model="f.aut.tratamiento" type="checkbox" /><span>{{ politica.texto_autorizacion }}</span></label>
          <label class="casilla"><input v-model="f.aut.foto" type="checkbox" />
            <span>{{ politica.texto_autorizacion_foto }}<small v-if="fotoPersonaObligatoria"> (necesaria para prestar)</small></span></label>
          <label v-if="esMenor" class="casilla"><input v-model="f.aut.menorEscuchado" type="checkbox" />
            <span>Como acudiente, declaro que escuché la opinión del menor antes de autorizar y la tuve en cuenta.</span></label>
        </fieldset>

        <Turnstile ref="verificacion" v-model="token" :clave-sitio="claveSitio" />

        <p v-if="error" class="mensaje mensaje--error" role="alert"><span>{{ error }}</span></p>
        <p v-if="falta" class="nota">Para enviar falta {{ falta }}.</p>
        <button class="boton" type="submit" :disabled="enviando || !!falta">{{ enviando ? 'Enviando…' : 'Inscribirme' }}</button>
      </form>
    </template>
  </section>
</template>

<style scoped>
.inscribirme { padding-block: var(--esp-5) var(--esp-7); max-width: 48rem; }
.intro { color: var(--tinta-2); font-size: var(--texto-m); }
h2 { margin-top: 0; font-size: var(--texto-l); }
.grupo { border: 1px solid var(--linea); border-radius: var(--radio-m); padding: var(--esp-3) var(--esp-4); margin: 0 0 var(--esp-4); }
.grupo legend { font-weight: 650; padding: 0 var(--esp-2); }
.grupo legend small { color: var(--tinta-2); font-weight: 400; }
.nota { color: var(--tinta-2); font-size: var(--texto-s); }
.mensaje { margin-bottom: var(--esp-4); }
.resultado__titulo { font-size: var(--texto-l); font-weight: 650; margin-top: 0; }
.resultado { border: 2px solid var(--exito); }
</style>
