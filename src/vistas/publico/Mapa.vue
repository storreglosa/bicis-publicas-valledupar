<script setup>
import { computed, ref } from 'vue'
import EstadoEnVivo from '../../componentes/EstadoEnVivo.vue'
import MapaPuntos from '../../componentes/MapaPuntos.vue'
import { useDisponibilidad } from '../../composables/useDisponibilidad.js'
import { enlaceComoLlegar, estadoPunto, textoBicis } from '../../lib/puntos.js'

const { puntos, estado, actualizado, error } = useDisponibilidad()
const vista = ref('mapa')
const filtro = ref('todos')

const visibles = computed(() => puntos.value.filter((p) =>
  filtro.value === 'todos' || (filtro.value === 'fijos' ? p.tipo === 'fijo' : p.tipo === 'evento')))

const totalBicis = computed(() => visibles.value.reduce((s, p) => s + (p.abierto ? p.bicis_disponibles : 0), 0))

function fechaEvento(p) {
  if (!p.evento_inicia_en) return ''
  return new Date(p.evento_inicia_en).toLocaleString('es-CO', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}
</script>

<template>
  <section class="contenedor pagina">
    <div class="pagina__cabeza">
      <div>
        <h1>Puntos y bicis disponibles</h1>
        <EstadoEnVivo :estado="estado" :actualizado="actualizado" :error="error" />
      </div>
      <p v-if="puntos.length" class="resumen"><strong>{{ totalBicis }}</strong> bicis disponibles en puntos abiertos</p>
    </div>

    <div class="controles">
      <div class="segmentado" role="group" aria-label="Vista">
        <button type="button" :aria-pressed="vista === 'mapa'" @click="vista = 'mapa'">Mapa</button>
        <button type="button" :aria-pressed="vista === 'lista'" @click="vista = 'lista'">Lista</button>
      </div>
      <label class="filtro">Mostrar
        <select v-model="filtro">
          <option value="todos">Todos los puntos</option>
          <option value="fijos">Puntos fijos</option>
          <option value="eventos">Puntos de evento</option>
        </select>
      </label>
    </div>

    <MapaPuntos v-if="vista === 'mapa'" :puntos="visibles" />

    <ul v-show="vista === 'lista'" class="lista" aria-label="Lista de puntos">
      <li v-if="!visibles.length && estado !== 'cargando'" class="lista__vacia">No hay puntos para mostrar.</li>
      <li v-for="p in visibles" :key="p.punto_id" class="tarjeta">
        <div class="tarjeta__fila">
          <h2>{{ p.nombre }}</h2>
          <span class="etiqueta" :class="`etiqueta--${estadoPunto(p).clave}`">{{ estadoPunto(p).etiqueta }}</span>
        </div>
        <p class="tarjeta__bicis">{{ textoBicis(p.bicis_disponibles) }}</p>
        <p v-if="p.evento_nombre" class="tarjeta__meta">Evento: {{ p.evento_nombre }} · {{ fechaEvento(p) }}</p>
        <p v-if="p.direccion" class="tarjeta__meta">{{ p.direccion }}</p>
        <p v-if="p.horario_texto" class="tarjeta__meta">{{ p.horario_texto }}</p>
        <a :href="enlaceComoLlegar(p)" target="_blank" rel="noopener">Cómo llegar</a>
      </li>
    </ul>

    <aside class="invitacion">
      <p><strong>¿Primera vez?</strong> Inscríbete en línea y presenta tu documento al operador del punto.</p>
      <RouterLink to="/inscribirme" class="boton">Inscribirme</RouterLink>
    </aside>
  </section>
</template>

<style scoped>
.pagina { padding-block: var(--esp-6); }
.pagina__cabeza { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: end; gap: var(--esp-3); margin-bottom: var(--esp-4); }
.resumen { margin: 0; color: var(--tinta-2); }
.resumen strong { color: var(--tinta-1); font-size: var(--texto-l); }
.controles { display: flex; flex-wrap: wrap; gap: var(--esp-3); align-items: center; justify-content: space-between; margin-bottom: var(--esp-3); }
.segmentado { display: inline-flex; border: 2px solid var(--linea-fuerte); border-radius: var(--radio-m); overflow: hidden; }
.segmentado button { min-height: var(--toque-min); padding: 0 var(--esp-5); border: 0; background: var(--superficie); color: var(--tinta-1); font: inherit; font-weight: 600; cursor: pointer; }
.segmentado button[aria-pressed='true'] { background: var(--tinta-1); color: var(--superficie); }
.filtro { display: inline-flex; align-items: center; gap: var(--esp-2); font-weight: 600; }
.filtro select { min-height: var(--toque-min); padding: 0 var(--esp-3); border: 2px solid var(--linea-fuerte); border-radius: var(--radio-m); background: var(--superficie); font: inherit; color: var(--tinta-1); }
.lista { list-style: none; margin: 0; padding: 0; display: grid; gap: var(--esp-3); grid-template-columns: repeat(auto-fill, minmax(17rem, 1fr)); }
.lista__vacia { color: var(--tinta-2); }
.tarjeta { background: var(--superficie); border: 1px solid var(--linea); border-radius: var(--radio-l); padding: var(--esp-4); }
.tarjeta__fila { display: flex; justify-content: space-between; align-items: start; gap: var(--esp-2); }
.tarjeta h2 { font-size: var(--texto-m); margin: 0; }
.tarjeta__bicis { font-size: var(--texto-l); font-weight: 650; margin: var(--esp-2) 0; }
.tarjeta__meta { color: var(--tinta-2); font-size: var(--texto-s); margin: 0 0 var(--esp-1); }
.etiqueta { white-space: nowrap; font-size: var(--texto-xs); font-weight: 650; text-transform: uppercase; letter-spacing: 0.04em; }
.etiqueta--disponible { color: var(--estado-disponible); }
.etiqueta--pocas { color: var(--estado-pocas); }
.etiqueta--sin { color: var(--estado-sin); }
.etiqueta--sin-dato { color: var(--estado-sin-dato); }
.invitacion { margin-top: var(--esp-6); display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: var(--esp-3); background: var(--banda); border-radius: var(--radio-l); padding: var(--esp-5); }
.invitacion p { margin: 0; max-width: 40ch; }
</style>
