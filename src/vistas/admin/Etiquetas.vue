<script setup>
// Hoja de etiquetas QR para pegar en cada bici. El QR abre la página pública de
// la bici (#/b/BPV-015): cómo usarla y cómo reportarla si está sola o dañada.
// El enlace usa el código BPV (fijo), no el nombre del sistema: si el nombre
// cambia, las etiquetas impresas siguen sirviendo. Se imprime en A4 (24 por hoja).
import QRCode from 'qrcode'
import { computed, ref, watch } from 'vue'
import sitio from '../../../sitio.config.js'
import { codigoBici } from '../../lib/documento.js'

const desde = ref(1)
const hasta = ref(24)
const etiquetas = ref([])
const generando = ref(false)
const error = ref('')
const logo = `${import.meta.env.BASE_URL}marca/logo_sttv.png`

const rangoValido = computed(() => {
  const d = Number(desde.value)
  const h = Number(hasta.value)
  return Number.isInteger(d) && Number.isInteger(h) && d >= 1 && h <= 9999 && d <= h && h - d < 500
})

function urlBici(codigo) {
  return `${sitio.urlPublica}#/b/${codigo}`
}

async function generar() {
  if (!rangoValido.value) return
  generando.value = true
  error.value = ''
  try {
    const lista = []
    for (let n = Number(desde.value); n <= Number(hasta.value); n++) {
      const codigo = codigoBici(n)
      // SVG generado por la librería a partir de una URL propia: no hay datos de usuario.
      const svg = await QRCode.toString(urlBici(codigo), { type: 'svg', errorCorrectionLevel: 'M', margin: 0 })
      lista.push({ codigo, svg })
    }
    etiquetas.value = lista
  } catch (e) {
    error.value = `No se pudieron generar los códigos QR: ${e.message}`
  } finally {
    generando.value = false
  }
}

function imprimir() {
  window.print()
}

watch([desde, hasta], () => { etiquetas.value = [] })
</script>

<template>
  <section>
    <div class="admin-cabeza no-imprimir">
      <div>
        <h1>Etiquetas QR</h1>
        <p>Imprime en A4 (24 etiquetas por hoja), recorta y pega cada etiqueta junto al sticker de la bici.
          Prueba primero una hoja: el QR debe leerse con la cámara del celular a unos 30 cm.</p>
      </div>
    </div>

    <form class="filtros no-imprimir" @submit.prevent="generar">
      <label class="campo"><span>Desde el n.º</span><input v-model="desde" type="number" min="1" max="9999" /></label>
      <label class="campo"><span>Hasta el n.º</span><input v-model="hasta" type="number" min="1" max="9999" /></label>
      <button class="boton" type="submit" :disabled="!rangoValido || generando">{{ generando ? 'Generando…' : 'Generar' }}</button>
      <button class="boton boton--secundario" type="button" :disabled="!etiquetas.length" @click="imprimir">Imprimir</button>
    </form>
    <p v-if="!rangoValido" class="mensaje mensaje--aviso no-imprimir"><span>Rango no válido (máximo 500 etiquetas a la vez).</span></p>
    <p v-if="error" class="mensaje mensaje--error no-imprimir"><span>{{ error }}</span></p>

    <div class="hoja" aria-label="Hoja de etiquetas">
      <article v-for="e in etiquetas" :key="e.codigo" class="etiqueta">
        <header class="etiqueta__cabeza">
          <img :src="logo" alt="" width="52" height="25" />
          <span>{{ sitio.nombreCorto }}</span>
        </header>
        <div class="etiqueta__qr" v-html="e.svg"></div>
        <p class="etiqueta__codigo">{{ e.codigo }}</p>
        <p class="etiqueta__pie">Escanea: cómo usarla o reportarla</p>
      </article>
    </div>
  </section>
</template>

<style scoped>
.hoja { display: grid; grid-template-columns: repeat(auto-fill, minmax(62mm, 1fr)); gap: 4mm; }
/* A4 con márgenes de 10 mm: 190 × 277 mm útiles → 4 columnas × 6 filas = 24 etiquetas de ~45 × 43 mm. */
.etiqueta {
  border: 1px dashed var(--linea-fuerte); border-radius: 2mm; padding: 1.5mm; background: #ffffff; color: #000000;
  display: grid; justify-items: center; align-content: center; gap: 1mm; break-inside: avoid;
}
.etiqueta__cabeza { display: flex; align-items: center; gap: 1.5mm; font-weight: 650; font-size: 7pt; }
.etiqueta__cabeza img { width: 9mm; height: auto; }
.etiqueta__qr { width: 25mm; height: 25mm; }
.etiqueta__qr :deep(svg) { width: 100%; height: 100%; display: block; }
.etiqueta__codigo { margin: 0; font-size: 14pt; font-weight: 650; letter-spacing: 0.04em; line-height: 1; }
.etiqueta__pie { margin: 0; font-size: 5.5pt; }

@media print {
  @page { size: A4; margin: 10mm; }
  .hoja { grid-template-columns: repeat(4, 1fr); gap: 3mm; }
  .etiqueta { height: 43mm; }
}
</style>
