<script setup>
// Modo «Presentar»: recorrido de unos 3 minutos para mostrar el sistema en reunión
// (televisor, pantalla completa). Mismo patrón que el tablero SAST: una línea de
// tiempo con subtítulos; Espacio pausa, ← → cambian de escena, Esc sale. El guion
// está en src/presentacion/guion.js y los clips en public/presentacion/ (datos ficticios).
import QRCode from 'qrcode'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import sitio from '../../../sitio.config.js'
import { DURACION_TOTAL, ESCENAS } from '../../presentacion/guion.js'

const router = useRouter()
const BASE = `${import.meta.env.BASE_URL}presentacion/`
const logo = `${import.meta.env.BASE_URL}marca/logo_sttv.png`
const reducido = typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches

const fase = ref('inicio')            // inicio | corriendo | fin
const indice = ref(0)
const t = ref(0)                      // segundos dentro de la escena
const pausado = ref(false)
const video = ref(null)
const qr = ref('')
const inicios = ref({})               // segundo del clip donde empieza lo que se muestra

const escena = computed(() => ESCENAS[indice.value])
const transcurrido = computed(() => ESCENAS.slice(0, indice.value).reduce((s, e) => s + e.duracion, 0) + t.value)
const visibles = (lista) => (lista ?? []).filter(([en]) => t.value >= en)
const frase = computed(() => {
  const f = visibles(escena.value.frases)
  return f.length ? f[f.length - 1][1] : ''
})
const contador = computed(() => {
  const c = escena.value.contador
  return c && { ...c, valor: t.value >= c.en ? c.a : c.de, cambio: t.value >= c.en }
})
const mmss = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`

let cuadro = null
let anterior = 0
function avanzar(ahora) {
  if (fase.value === 'corriendo' && !pausado.value) {
    t.value += Math.min(0.25, (ahora - anterior) / 1000)
    if (t.value >= escena.value.duracion) irA(indice.value + 1)
  }
  anterior = ahora
  cuadro = requestAnimationFrame(avanzar)
}

async function sincronizarVideo() {
  await nextTick()
  const v = video.value
  if (!v) return
  const inicio = (inicios.value[escena.value.clip] ?? 0) + t.value
  if (Math.abs(v.currentTime - inicio) > 0.4) v.currentTime = inicio
  if (pausado.value) v.pause()
  else v.play().catch(() => {})
}

function irA(i) {
  if (i >= ESCENAS.length) { fase.value = 'fin'; return }
  indice.value = Math.max(0, i)
  t.value = 0
  sincronizarVideo()
}

function comenzar() {
  document.documentElement.requestFullscreen?.().catch(() => {})
  fase.value = 'corriendo'
  pausado.value = false
  irA(0)
}
function alternarPausa() {
  if (fase.value !== 'corriendo') return
  pausado.value = !pausado.value
  sincronizarVideo()
}
function salir() {
  if (document.fullscreenElement) document.exitFullscreen?.().catch(() => {})
  router.push('/')
}

function tecla(e) {
  if (e.key === 'Escape') return salir()
  if (fase.value === 'inicio' && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); return comenzar() }
  if (fase.value !== 'corriendo') return
  if (e.key === ' ') { e.preventDefault(); alternarPausa() }
  if (e.key === 'ArrowRight') irA(indice.value + 1)
  if (e.key === 'ArrowLeft') irA(t.value > 2 ? indice.value : indice.value - 1)
}

watch(indice, sincronizarVideo)

onMounted(async () => {
  document.body.classList.add('presentando')
  addEventListener('keydown', tecla)
  anterior = performance.now()
  cuadro = requestAnimationFrame(avanzar)
  const qrEscena = ESCENAS.find((e) => e.tipo === 'qr')
  qr.value = await QRCode.toString(`${sitio.urlPublica}#/b/${qrEscena.codigo}`, { type: 'svg', errorCorrectionLevel: 'M', margin: 0 })
  try { inicios.value = await (await fetch(`${BASE}clips.json`)).json() } catch { inicios.value = {} }
})
onBeforeUnmount(() => {
  document.body.classList.remove('presentando')
  removeEventListener('keydown', tecla)
  cancelAnimationFrame(cuadro)
})
</script>

<template>
  <section class="escenario" aria-label="Presentación de Bicis Públicas Valledupar" :class="{ reducido }">
    <header class="barra">
      <img :src="logo" alt="Alcaldía de Valledupar — Tránsito" width="104" height="51" />
      <span class="barra__nombre">{{ sitio.nombre }}</span>
      <span class="barra__demo">Versión de demostración · datos ficticios</span>
    </header>

    <!-- Portada antes de empezar (el clic permite la pantalla completa) -->
    <div v-if="fase === 'inicio'" class="lienzo portada">
      <h1>{{ sitio.nombre }}</h1>
      <p class="portada__sub">Así funciona el sistema de bicicletas públicas de la Secretaría de Tránsito y Transporte.</p>
      <button class="boton boton--grande" type="button" autofocus @click="comenzar">Comenzar la presentación</button>
      <p class="pista">Unos {{ Math.round(DURACION_TOTAL / 60) }} minutos · Espacio: pausa · ← →: escenas · Esc: salir</p>
    </div>

    <div v-else-if="fase === 'fin'" class="lienzo portada">
      <h1>Gracias</h1>
      <p class="portada__sub">{{ sitio.urlPublica.replace('https://', '') }}</p>
      <div class="acciones-fin">
        <button class="boton boton--grande" type="button" @click="comenzar">Ver de nuevo</button>
        <button class="boton boton--contorno boton--grande" type="button" @click="salir">Salir</button>
      </div>
    </div>

    <template v-else>
      <Transition name="escena" mode="out-in">
        <div :key="escena.id" class="lienzo" :class="`lienzo--${escena.tipo}`">
          <!-- 1. Portada con la cifra de la flota -->
          <template v-if="escena.tipo === 'portada'">
            <p class="antetitulo">Secretaría de Tránsito y Transporte de Valledupar</p>
            <h1>{{ escena.titulo }}</h1>
            <p class="cifra-flota"><strong>130</strong> bicicletas · puntos fijos y eventos</p>
          </template>

          <!-- 2 y 4. Celular con el clip y puntos clave -->
          <template v-else-if="escena.tipo === 'telefono'">
            <div class="telefono"><video ref="video" :src="`${BASE}${escena.clip}.webm`" muted playsinline preload="auto" @loadedmetadata="sincronizarVideo"></video></div>
            <div class="lado">
              <h2>{{ escena.titulo }}</h2>
              <ul class="puntos">
                <li v-for="[, texto] in visibles(escena.puntos)" :key="texto">{{ texto }}</li>
              </ul>
              <div v-if="contador" class="contador" :class="{ 'contador--cambio': contador.cambio }" aria-live="polite">
                <span class="contador__etiqueta">Bicis disponibles en {{ contador.punto }}</span>
                <span class="contador__valor">{{ contador.valor }}</span>
              </div>
            </div>
          </template>

          <!-- 3. Sticker QR y la página que abre -->
          <template v-else-if="escena.tipo === 'qr'">
            <div class="sticker">
              <div class="sticker__qr" v-html="qr"></div>
              <span class="sticker__codigo">{{ escena.codigo }}</span>
            </div>
            <span class="flecha" aria-hidden="true">→</span>
            <div class="telefono"><img :src="`${BASE}bici.png`" :alt="`Página de la bicicleta ${escena.codigo}`" /></div>
            <h2 class="titulo-lateral">{{ escena.titulo }}</h2>
          </template>

          <!-- 5. Pantalla de la oficina -->
          <template v-else-if="escena.tipo === 'pantalla'">
            <h2>{{ escena.titulo }}</h2>
            <div class="monitor"><video ref="video" :src="`${BASE}${escena.clip}.webm`" muted playsinline preload="auto" @loadedmetadata="sincronizarVideo"></video></div>
          </template>

          <!-- 6. Confianza: cuatro tarjetas -->
          <template v-else-if="escena.tipo === 'tarjetas'">
            <h2>{{ escena.titulo }}</h2>
            <div class="tarjetas">
              <article v-for="[en, icono, titulo, texto] in escena.tarjetas" :key="icono" class="tarjeta" :class="{ 'tarjeta--visible': t >= en }">
                <svg class="tarjeta__icono" viewBox="0 0 24 24" aria-hidden="true">
                  <path v-if="icono === 'roles'" d="M12 2 4 5v6c0 5 3.4 9.4 8 11 4.6-1.6 8-6 8-11V5l-8-3Z" />
                  <path v-else-if="icono === 'registro'" d="M7 3h10a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Zm2 5h6M9 12h6M9 16h4" />
                  <path v-else-if="icono === 'candado'" d="M6 10V8a6 6 0 1 1 12 0v2m-13 0h14v11H5V10Zm7 4v3" />
                  <path v-else d="M5 12.5 10 17 19 7" />
                </svg>
                <h3>{{ titulo }}</h3>
                <p>{{ texto }}</p>
              </article>
            </div>
          </template>

          <!-- 7. Hoy: la cifra -->
          <template v-else-if="escena.tipo === 'cifra'">
            <p class="antetitulo">{{ escena.titulo }}</p>
            <p class="cifra">{{ escena.cifra }}</p>
            <p class="cifra__texto">{{ escena.texto }}</p>
          </template>

          <!-- 8. Para crecer -->
          <template v-else-if="escena.tipo === 'lista'">
            <h2>{{ escena.titulo }}</h2>
            <div class="items">
              <article v-for="[en, titulo, texto] in escena.items" :key="titulo" class="item" :class="{ 'item--visible': t >= en }">
                <h3>{{ titulo }}</h3>
                <p>{{ texto }}</p>
              </article>
            </div>
          </template>
        </div>
      </Transition>

      <p class="subtitulo" aria-live="polite">{{ frase }}</p>

      <footer class="control">
        <button type="button" class="control__boton" aria-label="Escena anterior" @click="irA(t > 2 ? indice : indice - 1)">‹</button>
        <button type="button" class="control__boton" :aria-label="pausado ? 'Continuar' : 'Pausar'" @click="alternarPausa">{{ pausado ? '▶' : '❚❚' }}</button>
        <button type="button" class="control__boton" aria-label="Escena siguiente" @click="irA(indice + 1)">›</button>
        <ol class="progreso" aria-label="Escenas">
          <li v-for="(e, i) in ESCENAS" :key="e.id" :class="{ hecha: i < indice, actual: i === indice }"
            :style="i === indice ? { '--avance': `${Math.min(100, (t / e.duracion) * 100)}%` } : null">
            <span class="visualmente-oculto">{{ e.titulo }}</span>
          </li>
        </ol>
        <span class="tiempo">{{ mmss(transcurrido) }} / {{ mmss(DURACION_TOTAL) }}</span>
        <button type="button" class="control__boton control__salir" @click="salir">Salir</button>
      </footer>
    </template>
  </section>
</template>

<style scoped>
.escenario {
  position: fixed; inset: 0; z-index: 2000; display: grid; grid-template-rows: auto 1fr auto auto;
  background: radial-gradient(circle at 20% 10%, #fff8ee 0%, var(--fondo) 55%, var(--banda) 100%);
  color: var(--tinta-1); overflow: hidden; font-size: clamp(16px, 1.15vw, 22px);
}
.barra { display: flex; align-items: center; gap: 1em; padding: 1em 2em 0; }
.barra img { height: 2.6em; width: auto; }
.barra__nombre { font-weight: 650; font-size: 1.2em; border-left: 2px solid var(--linea); padding-left: 1em; }
.barra__demo { margin-left: auto; font-size: 0.85em; color: var(--tinta-2); background: var(--aviso-fondo); border-radius: 999px; padding: 0.3em 0.9em; }

.lienzo { display: flex; align-items: center; justify-content: center; gap: 4vw; padding: 2vh 4vw; min-height: 0; }
h1 { font-size: 3.6em; line-height: 1.05; margin: 0.2em 0; text-align: center; }
h2 { font-size: 2.3em; margin: 0 0 0.6em; line-height: 1.1; }
h3 { font-size: 1.35em; margin: 0.3em 0; }
.antetitulo { color: var(--secundario); font-weight: 650; letter-spacing: 0.06em; text-transform: uppercase; font-size: 1.1em; margin: 0; }

.portada { flex-direction: column; text-align: center; gap: 1.2em; }
.portada__sub { font-size: 1.5em; color: var(--tinta-2); max-width: 32em; margin: 0; }
.pista { color: var(--tinta-2); font-size: 0.95em; }
.acciones-fin { display: flex; gap: 1em; }
.lienzo--portada { flex-direction: column; text-align: center; }
.cifra-flota { font-size: 1.6em; color: var(--tinta-2); margin: 0; }
.cifra-flota strong { font-size: 2.2em; color: var(--primario); display: block; line-height: 1; }

.telefono {
  height: min(66vh, 46vw); aspect-ratio: 390 / 844; flex: none; border: 0.7em solid #221c17; border-radius: 2.4em;
  overflow: hidden; background: #221c17; box-shadow: 0 1.2em 3em rgba(34, 28, 23, 0.25);
}
.telefono video, .telefono img { width: 100%; height: 100%; object-fit: cover; display: block; }
.lado { max-width: 34em; }
.puntos { list-style: none; margin: 0; padding: 0; display: grid; gap: 0.7em; font-size: 1.45em; }
.puntos li { padding-left: 1.4em; position: relative; animation: aparece 0.5s ease both; }
.puntos li::before { content: ''; position: absolute; left: 0; top: 0.45em; width: 0.6em; height: 0.6em; border-radius: 50%; background: var(--secundario); }

.contador { margin-top: 1.4em; display: inline-grid; gap: 0.2em; background: var(--superficie); border: 2px solid var(--linea); border-radius: var(--radio-l); padding: 0.8em 1.2em; box-shadow: var(--sombra); }
.contador__etiqueta { color: var(--tinta-2); }
.contador__valor { font-size: 3.2em; font-weight: 700; line-height: 1; color: var(--estado-disponible); font-variant-numeric: tabular-nums; }
.contador--cambio .contador__valor { animation: late 0.9s ease; }

.lienzo--qr { flex-wrap: wrap; align-content: center; }
.lienzo--qr .telefono { height: min(54vh, 40vw); }
.sticker { background: var(--superficie); border: 3px solid #221c17; border-radius: 1.2em; padding: 1.4em; display: grid; justify-items: center; gap: 0.6em; box-shadow: 0 1.2em 3em rgba(34, 28, 23, 0.2); }
.sticker__qr { width: min(30vh, 22vw); aspect-ratio: 1; }
.sticker__qr :deep(svg) { width: 100%; height: 100%; display: block; }
.sticker__codigo { font-size: 2em; font-weight: 700; letter-spacing: 0.04em; }
.flecha { font-size: 4em; color: var(--primario); }
.titulo-lateral { flex-basis: 100%; text-align: center; order: -1; }

.lienzo--pantalla { flex-direction: column; gap: 1.5vh; }
.monitor { width: min(70vw, 100vh); aspect-ratio: 1280 / 800; border: 0.6em solid #221c17; border-radius: 1em; overflow: hidden; background: #221c17; box-shadow: 0 1.2em 3em rgba(34, 28, 23, 0.25); }
.monitor video { width: 100%; height: 100%; object-fit: cover; display: block; }

.lienzo--tarjetas, .lienzo--lista { flex-direction: column; }
.tarjetas { display: grid; grid-template-columns: repeat(2, minmax(0, 26em)); gap: 1.4em; }
.tarjeta, .item {
  background: var(--superficie); border: 2px solid var(--linea); border-radius: var(--radio-l); padding: 1.3em 1.5em;
  box-shadow: var(--sombra); opacity: 0.12; transform: translateY(0.8em); transition: opacity 0.6s, transform 0.6s;
}
.tarjeta--visible, .item--visible { opacity: 1; transform: none; border-color: var(--secundario); }
.tarjeta p, .item p { margin: 0; color: var(--tinta-2); font-size: 1.1em; }
.tarjeta__icono { width: 2.4em; height: 2.4em; fill: none; stroke: var(--secundario); stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; }

.lienzo--cifra { flex-direction: column; gap: 0.4em; text-align: center; }
.cifra { font-size: 9em; font-weight: 750; line-height: 1; color: var(--primario); margin: 0; }
.cifra__texto { font-size: 1.8em; max-width: 24em; margin: 0; }
.items { display: grid; gap: 1.4em; max-width: 50em; width: 100%; }
.item h3 { color: var(--primario); font-size: 1.6em; }

.subtitulo {
  margin: 0 auto 1.2vh; max-width: 62em; min-height: 2.6em; text-align: center; font-size: 1.65em; line-height: 1.3;
  padding: 0.4em 1em; color: #fff; background: rgba(34, 28, 23, 0.86); border-radius: var(--radio-m);
}
.subtitulo:empty { visibility: hidden; }

.control { display: flex; align-items: center; gap: 0.8em; padding: 0 2em 1.2em; }
.control__boton { min-width: 2.6em; height: 2.6em; border: 2px solid var(--linea-fuerte); border-radius: 999px; background: var(--superficie); color: var(--tinta-1); font: inherit; cursor: pointer; }
.control__salir { margin-left: 0.4em; padding: 0 1em; }
.progreso { list-style: none; margin: 0; padding: 0; display: flex; gap: 0.4em; flex: 1; }
.progreso li { flex: 1; height: 0.45em; border-radius: 999px; background: var(--linea); overflow: hidden; position: relative; }
.progreso li.hecha { background: var(--secundario); }
.progreso li.actual::after { content: ''; position: absolute; inset: 0 auto 0 0; width: var(--avance, 0%); background: var(--secundario); }
.tiempo { font-variant-numeric: tabular-nums; color: var(--tinta-2); min-width: 6.5em; text-align: right; }

.escena-enter-active, .escena-leave-active { transition: opacity 0.45s ease, transform 0.45s ease; }
.escena-enter-from { opacity: 0; transform: translateY(1.2em); }
.escena-leave-to { opacity: 0; transform: translateY(-0.8em); }
.reducido .escena-enter-active, .reducido .escena-leave-active, .reducido .tarjeta, .reducido .item { transition: none; }
@keyframes aparece { from { opacity: 0; transform: translateX(-0.6em); } to { opacity: 1; transform: none; } }
@keyframes late { 0% { transform: scale(1); } 40% { transform: scale(1.25); color: var(--primario); } 100% { transform: scale(1); } }
@media (prefers-reduced-motion: reduce) { .puntos li, .contador--cambio .contador__valor { animation: none; } }
@media (max-width: 760px) {
  .lienzo { flex-direction: column; } .tarjetas { grid-template-columns: 1fr; } .telefono { height: 42vh; }
  .barra__nombre, .tiempo { display: none; }
}
</style>

<style>
body.presentando { overflow: hidden; }
</style>
