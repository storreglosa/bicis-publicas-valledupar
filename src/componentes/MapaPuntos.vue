<script setup>
// Mapa Leaflet de los puntos. Recibe los puntos ya filtrados; el contenido de
// los popups se arma con nodos DOM (textContent), nunca con HTML del servidor.
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import sitio from '../../sitio.config.js'
import { enlaceComoLlegar, estadoPunto, textoBicis } from '../lib/puntos.js'

const props = defineProps({ puntos: { type: Array, required: true } })

const contenedor = ref(null)
let mapa = null
let capa = null
let ajustado = false

function popup(punto) {
  const estado = estadoPunto(punto)
  const caja = document.createElement('div')
  caja.className = 'popup-punto'
  const titulo = document.createElement('strong')
  titulo.textContent = punto.nombre
  const linea = document.createElement('p')
  linea.textContent = `${estado.etiqueta} · ${textoBicis(punto.bicis_disponibles)}`
  caja.append(titulo, linea)
  if (punto.evento_nombre) {
    const ev = document.createElement('p')
    ev.textContent = `Evento: ${punto.evento_nombre}`
    caja.append(ev)
  }
  if (punto.horario_texto) {
    const h = document.createElement('p')
    h.textContent = punto.horario_texto
    caja.append(h)
  }
  const a = document.createElement('a')
  a.href = enlaceComoLlegar(punto)
  a.target = '_blank'
  a.rel = 'noopener'
  a.textContent = 'Cómo llegar'
  caja.append(a)
  return caja
}

function dibujar() {
  if (!mapa) return
  capa.clearLayers()
  for (const p of props.puntos) {
    const estado = estadoPunto(p)
    const numero = Number.isInteger(p.bicis_disponibles) ? p.bicis_disponibles : '–'
    const icono = L.divIcon({
      className: 'marcador-leaflet',
      html: `<span class="marcador marcador--${estado.clave}${p.tipo === 'evento' ? ' marcador--evento' : ''}">${numero}</span>`,
      iconSize: [44, 44],
      iconAnchor: [22, 22],
    })
    L.marker([p.latitud, p.longitud], {
      icon: icono,
      title: `${p.nombre}: ${estado.etiqueta}, ${textoBicis(p.bicis_disponibles)}`,
      alt: p.nombre,
      keyboard: true,
    }).bindPopup(() => popup(p)).addTo(capa)
  }
  if (!ajustado && props.puntos.length) {
    mapa.fitBounds(L.latLngBounds(props.puntos.map((p) => [p.latitud, p.longitud])), { padding: [40, 40], maxZoom: 16 })
    ajustado = true
  }
}

function miUbicacion() {
  mapa?.locate({ setView: true, maxZoom: 16 })
}

onMounted(() => {
  mapa = L.map(contenedor.value, { zoomControl: true }).setView(sitio.mapa.centro, sitio.mapa.zoom)
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; colaboradores de <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
  }).addTo(mapa)
  capa = L.layerGroup().addTo(mapa)
  mapa.on('locationfound', (e) => L.circleMarker(e.latlng, { radius: 8, color: '#0b6e64' }).addTo(capa))
  dibujar()
})

watch(() => props.puntos, dibujar, { deep: true })

onBeforeUnmount(() => {
  mapa?.remove()
  mapa = null
})
</script>

<template>
  <div class="mapa">
    <div ref="contenedor" class="mapa__lienzo" role="region" aria-label="Mapa de puntos de préstamo"></div>
    <button type="button" class="boton boton--secundario mapa__ubicacion" @click="miUbicacion">Mi ubicación</button>
  </div>
</template>

<style scoped>
.mapa { position: relative; }
.mapa__lienzo {
  height: min(60vh, 32rem);
  min-height: 18rem;
  border-radius: var(--radio-l);
  border: 1px solid var(--linea);
  z-index: 0;
}
.mapa__ubicacion {
  position: absolute;
  right: var(--esp-3);
  bottom: var(--esp-5);
  z-index: 500;
  min-height: 40px;
  padding: var(--esp-1) var(--esp-4);
  box-shadow: var(--sombra);
}
</style>

<style>
/* Marcadores (fuera de scoped: Leaflet los inserta fuera del componente). */
.marcador-leaflet { background: none; border: 0; }
.marcador {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  border-radius: 50%;
  border: 3px solid #ffffff;
  box-shadow: var(--sombra);
  color: var(--sobre-estado);
  font: 650 1rem/1 var(--fuente);
}
.marcador--disponible { background: var(--estado-disponible); }
.marcador--pocas { background: var(--estado-pocas); }
.marcador--sin { background: var(--estado-sin); }
.marcador--sin-dato { background: var(--estado-sin-dato); }
.marcador--evento { border-radius: 12px; }
.popup-punto p { margin: var(--esp-1) 0; }
</style>
