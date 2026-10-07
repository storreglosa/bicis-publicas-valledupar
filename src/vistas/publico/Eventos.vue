<script setup>
import { computed } from 'vue'
import { useConsulta } from '../../composables/useConsulta.js'

const { datos, cargando, error } = useConsulta((sb) =>
  sb.from('eventos').select('id,nombre,descripcion,lugar_texto,inicia_en,termina_en,estado')
    .in('estado', ['planeado', 'en_curso']).order('inicia_en'))

const eventos = computed(() => datos.value ?? [])

function rango(e) {
  const opciones = { weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' }
  const inicio = new Date(e.inicia_en).toLocaleString('es-CO', opciones)
  const fin = new Date(e.termina_en).toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit' })
  return `${inicio} – ${fin}`
}
</script>

<template>
  <section class="contenedor pagina">
    <h1>Eventos</h1>
    <p class="intro">En ciclopaseos y jornadas habilitamos puntos temporales de préstamo. Lleva tu documento.</p>

    <p v-if="cargando">Cargando eventos…</p>
    <p v-else-if="error" class="mensaje mensaje--error"><span>{{ error.mensaje }}</span></p>
    <p v-else-if="!eventos.length" class="mensaje mensaje--aviso"><span>No hay eventos programados por ahora.</span></p>
    <ul v-else class="eventos">
      <li v-for="e in eventos" :key="e.id" class="evento">
        <span v-if="e.estado === 'en_curso'" class="evento__ahora">En curso</span>
        <h2>{{ e.nombre }}</h2>
        <p class="evento__cuando">{{ rango(e) }}</p>
        <p v-if="e.lugar_texto" class="evento__donde">{{ e.lugar_texto }}</p>
        <p v-if="e.descripcion">{{ e.descripcion }}</p>
      </li>
    </ul>
    <RouterLink to="/mapa" class="boton boton--contorno">Ver puntos en el mapa</RouterLink>
  </section>
</template>

<style scoped>
.pagina { padding-block: var(--esp-6); }
.intro { color: var(--tinta-2); max-width: 46ch; }
.eventos { list-style: none; padding: 0; margin: 0 0 var(--esp-5); display: grid; gap: var(--esp-3); }
.evento { background: var(--superficie); border: 1px solid var(--linea); border-left: 6px solid var(--primario); border-radius: var(--radio-l); padding: var(--esp-4) var(--esp-5); }
.evento h2 { margin-bottom: var(--esp-1); }
.evento__ahora { display: inline-block; margin-bottom: var(--esp-2); color: var(--estado-disponible); font-weight: 650; font-size: var(--texto-xs); text-transform: uppercase; letter-spacing: 0.06em; }
.evento__cuando { font-weight: 600; margin-bottom: var(--esp-1); }
.evento__donde { color: var(--tinta-2); }
</style>
