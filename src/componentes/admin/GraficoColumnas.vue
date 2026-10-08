<script setup>
// Columnas de una sola serie (skill dataviz): marcas finas (≤ 16 px), punta
// redondeada de 4 px y base recta, rejilla de 1 px recesiva, valor impreso solo en
// el máximo, tooltip al pasar el cursor o al enfocar con el teclado, y vista de
// tabla equivalente. Una sola serie: sin leyenda (el título dice qué se grafica).
import { computed, ref } from 'vue'

const props = defineProps({
  titulo: { type: String, required: true },
  datos: { type: Array, required: true },          // [{ etiqueta, valor }]
  unidad: { type: String, default: '' },           // "préstamos"
  etiquetaEje: { type: Function, default: (d) => d.etiqueta },
  cadaEtiqueta: { type: Number, default: 1 },     // mostrar 1 de cada n etiquetas del eje
})

const ALTO = 160
const RANURA = 28
const GROSOR = 16
const MARGEN_SUP = 18
const verTabla = ref(false)
const activo = ref(null)

function techo(v) {
  if (v <= 0) return 1
  const p = 10 ** Math.floor(Math.log10(v))
  return [1, 2, 5, 10].map((m) => m * p).find((m) => m >= v)
}

const maximo = computed(() => techo(Math.max(0, ...props.datos.map((d) => d.valor))))
const ancho = computed(() => props.datos.length * RANURA)
const indiceMax = computed(() => {
  let i = -1
  props.datos.forEach((d, j) => { if (d.valor > 0 && (i < 0 || d.valor > props.datos[i].valor)) i = j })
  return i
})
const total = computed(() => props.datos.reduce((s, d) => s + d.valor, 0))
const y = (v) => MARGEN_SUP + (ALTO - MARGEN_SUP) * (1 - v / maximo.value)

function columna(d, i) {
  const x = i * RANURA + (RANURA - GROSOR) / 2
  const alto = ALTO - y(d.valor)
  if (alto <= 0) return ''
  const r = Math.min(4, alto, GROSOR / 2)
  // Punta redondeada arriba, base recta sobre la línea base.
  return `M${x},${ALTO} V${ALTO - alto + r} Q${x},${ALTO - alto} ${x + r},${ALTO - alto} H${x + GROSOR - r}`
    + ` Q${x + GROSOR},${ALTO - alto} ${x + GROSOR},${ALTO - alto + r} V${ALTO} Z`
}

const guias = computed(() => [0, maximo.value / 2, maximo.value])
const texto = (d) => `${props.etiquetaEje(d)}: ${d.valor} ${props.unidad}`
</script>

<template>
  <figure class="grafico">
    <figcaption class="grafico__cabeza">
      <span class="grafico__titulo">{{ titulo }}</span>
      <button class="enlace" type="button" :aria-pressed="verTabla" @click="verTabla = !verTabla">
        {{ verTabla ? 'Ver gráfico' : 'Ver tabla' }}</button>
    </figcaption>

    <div v-if="!verTabla" class="grafico__lienzo">
      <p v-if="total === 0" class="vacio">Sin datos en el periodo.</p>
      <svg v-else :viewBox="`-28 0 ${ancho + 28} ${ALTO + 22}`" role="img" :aria-label="`${titulo}. Total: ${total} ${unidad}.`"
        preserveAspectRatio="xMidYMid meet">
        <g class="guias" aria-hidden="true">
          <template v-for="g in guias" :key="g">
            <line :x1="0" :x2="ancho" :y1="y(g)" :y2="y(g)" />
            <text :x="-6" :y="y(g) + 4" text-anchor="end">{{ g.toLocaleString('es-CO') }}</text>
          </template>
        </g>
        <g v-for="(d, i) in datos" :key="d.etiqueta" class="col" :class="{ 'col--activa': activo === i }"
          tabindex="0" :aria-label="texto(d)" @pointerenter="activo = i" @pointerleave="activo = null"
          @focus="activo = i" @blur="activo = null">
          <rect class="col__zona" :x="i * RANURA" y="0" :width="RANURA" :height="ALTO" />
          <path class="col__marca" :d="columna(d, i)" />
          <text v-if="i === indiceMax" class="col__valor" :x="i * RANURA + RANURA / 2" :y="y(d.valor) - 5" text-anchor="middle">{{ d.valor }}</text>
          <text v-if="i % cadaEtiqueta === 0" class="col__eje" :x="i * RANURA + RANURA / 2" :y="ALTO + 16" text-anchor="middle">{{ etiquetaEje(d) }}</text>
        </g>
      </svg>
      <div v-if="activo !== null && datos[activo]" class="tooltip" role="status"
        :style="{ left: `${((activo + 0.5) * RANURA + 28) / (ancho + 28) * 100}%` }">
        <strong>{{ datos[activo].valor }} {{ unidad }}</strong>
        <span>{{ etiquetaEje(datos[activo]) }}</span>
      </div>
    </div>

    <table v-else class="tabla-admin">
      <thead><tr><th>Periodo</th><th>{{ unidad }}</th></tr></thead>
      <tbody><tr v-for="d in datos" :key="d.etiqueta"><td>{{ etiquetaEje(d) }}</td><td>{{ d.valor }}</td></tr></tbody>
    </table>
  </figure>
</template>

<style scoped>
.grafico { margin: 0; }
.grafico__cabeza { display: flex; justify-content: space-between; align-items: baseline; gap: var(--esp-2); margin-bottom: var(--esp-2); }
.grafico__titulo { font-weight: 650; }
.grafico__lienzo { position: relative; }
svg { width: 100%; height: auto; display: block; overflow: visible; font-family: var(--fuente); }
.guias line { stroke: var(--rejilla); stroke-width: 1; vector-effect: non-scaling-stroke; }
.guias text, .col__eje { fill: var(--tinta-2); font-size: 11px; font-variant-numeric: tabular-nums; }
.col__zona { fill: transparent; }
.col__marca { fill: var(--serie-1); }
.col--activa .col__marca { opacity: 0.8; }
.col:focus { outline: none; }
.col:focus-visible .col__zona { stroke: var(--foco); stroke-width: 2; }
.col__valor { fill: var(--tinta-1); font-size: 12px; font-weight: 650; }
.tooltip {
  position: absolute; top: 0; transform: translateX(-50%); pointer-events: none; display: grid; gap: 2px;
  background: var(--superficie); border: 1px solid var(--linea); border-radius: var(--radio-s);
  padding: var(--esp-1) var(--esp-2); box-shadow: var(--sombra); font-size: var(--texto-xs); white-space: nowrap;
}
.tooltip strong { font-size: var(--texto-s); color: var(--tinta-1); }
.tooltip span { color: var(--tinta-2); }
.enlace { background: none; border: 0; padding: 0; color: var(--primario); text-decoration: underline; font: inherit; font-size: var(--texto-s); cursor: pointer; min-height: 32px; }
.vacio { color: var(--tinta-2); }
</style>
