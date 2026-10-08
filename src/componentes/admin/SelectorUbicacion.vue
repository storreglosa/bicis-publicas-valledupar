<script setup>
// Elegir la ubicación de un punto tocando el mapa. Coordenadas en EPSG:4326 con
// 6 decimales (la base las limita a un recuadro amplio del municipio).
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import sitio from '../../../sitio.config.js'

const modelo = defineModel({ type: Object, required: true })   // { latitud, longitud }
const contenedor = ref(null)
let mapa = null
let marcador = null

function poner(lat, lon) {
  if (!mapa || lat == null || lon == null || lat === '' || lon === '') return
  const pos = [Number(lat), Number(lon)]
  marcador ? marcador.setLatLng(pos) : (marcador = L.circleMarker(pos, { radius: 10, color: '#b4460a', weight: 3 }).addTo(mapa))
}

onMounted(() => {
  const inicio = modelo.value.latitud ? [Number(modelo.value.latitud), Number(modelo.value.longitud)] : sitio.mapa.centro
  mapa = L.map(contenedor.value).setView(inicio, modelo.value.latitud ? 16 : sitio.mapa.zoom)
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19, attribution: '&copy; colaboradores de OpenStreetMap',
  }).addTo(mapa)
  mapa.on('click', (e) => {
    modelo.value = { latitud: Number(e.latlng.lat.toFixed(6)), longitud: Number(e.latlng.lng.toFixed(6)) }
  })
  poner(modelo.value.latitud, modelo.value.longitud)
})

watch(modelo, (v) => poner(v.latitud, v.longitud), { deep: true })
onBeforeUnmount(() => mapa?.remove())
</script>

<template>
  <div>
    <div ref="contenedor" class="selector" role="application" aria-label="Mapa para ubicar el punto: toca el lugar exacto"></div>
    <div class="fila-campos">
      <label class="campo"><span>Latitud</span><input v-model="modelo.latitud" type="number" step="0.000001" /></label>
      <label class="campo"><span>Longitud</span><input v-model="modelo.longitud" type="number" step="0.000001" /></label>
    </div>
  </div>
</template>

<style scoped>
.selector { height: 18rem; border-radius: var(--radio-m); border: 1px solid var(--linea); margin-bottom: var(--esp-3); z-index: 0; }
</style>
