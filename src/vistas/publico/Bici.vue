<script setup>
// Destino del QR pegado en cada bici (#/b/BPV-015). No consulta la base de
// datos: solo identifica la bici y explica qué hacer.
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import sitio from '../../../sitio.config.js'

const route = useRoute()
const codigo = computed(() => String(route.params.codigo ?? '').toUpperCase())
const valido = computed(() => new RegExp(`^${sitio.prefijoBici}-[0-9]{3,4}$`).test(codigo.value))
</script>

<template>
  <section class="contenedor pagina">
    <template v-if="valido">
      <p class="antetitulo">Bicicleta del sistema</p>
      <h1 class="codigo">{{ codigo }}</h1>
      <p>Esta bicicleta pertenece a <strong>{{ sitio.nombre }}</strong>, de la {{ sitio.entidad }}.</p>

      <div class="opciones">
        <div class="opcion">
          <h2>¿Quieres usarla?</h2>
          <p>Inscríbete una vez y pídela en cualquier punto con tu documento.</p>
          <RouterLink to="/inscribirme" class="boton">Inscribirme</RouterLink>
        </div>
        <div class="opcion">
          <h2>¿La encontraste sola o dañada?</h2>
          <p>Avísanos indicando el código <strong>{{ codigo }}</strong> y dónde está.</p>
          <a :href="`mailto:${sitio.contacto.correo}?subject=${encodeURIComponent(`Bicicleta ${codigo}`)}`" class="boton boton--secundario">Avisar a la Secretaría</a>
          <p class="nota">Se abre tu correo dirigido a {{ sitio.contacto.correo }}.</p>
        </div>
      </div>
    </template>
    <template v-else>
      <h1>Código no reconocido</h1>
      <p>El código «{{ codigo }}» no corresponde a una bicicleta del sistema.</p>
    </template>
    <RouterLink to="/mapa">Ver puntos de préstamo</RouterLink>
  </section>
</template>

<style scoped>
.nota { color: var(--tinta-2); font-size: var(--texto-s); overflow-wrap: anywhere; }
.pagina { padding-block: var(--esp-6); }
.antetitulo { color: var(--secundario); font-weight: 650; text-transform: uppercase; letter-spacing: 0.06em; font-size: var(--texto-s); margin-bottom: var(--esp-1); }
.codigo { font-size: clamp(2.5rem, 12vw, 4rem); letter-spacing: 0.02em; }
.opciones { display: grid; gap: var(--esp-4); grid-template-columns: repeat(auto-fit, minmax(16rem, 1fr)); margin: var(--esp-5) 0; }
.opcion { background: var(--superficie); border: 1px solid var(--linea); border-radius: var(--radio-l); padding: var(--esp-5); }
</style>
