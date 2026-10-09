<script setup>
// Política de tratamiento de datos: la vigente y el historial de versiones
// (D. 1377/2013 art. 13). Las autorizaciones guardan la versión que aceptaron.
// En la demo solo se muestra la vigente: las anteriores fueron borradores de prueba.
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useConsulta } from '../../composables/useConsulta.js'
import { markdownSeguro } from '../../lib/markdown.js'

const route = useRoute()
const esDemo = import.meta.env.VITE_DEMO === '1'
const { datos, cargando, error } = useConsulta((sb) =>
  sb.from('politicas_tratamiento').select('version,vigente_desde,texto_md,vigente,sha256').order('id', { ascending: false }))

const versiones = computed(() => datos.value ?? [])
const politica = computed(() =>
  (esDemo ? null : versiones.value.find((p) => p.version === route.params.version)) ??
  versiones.value.find((p) => p.vigente) ?? null)
</script>

<template>
  <section class="contenedor pagina texto-largo">
    <h1>Política de tratamiento de datos personales</h1>

    <p v-if="cargando">Cargando…</p>
    <p v-else-if="error" class="mensaje mensaje--error"><span>{{ error.mensaje }}</span></p>
    <p v-else-if="!politica" class="mensaje mensaje--aviso">
      <span>La política de tratamiento de datos está en revisión y se publicará antes de abrir las inscripciones.</span>
    </p>
    <template v-else>
      <p class="meta">
        Versión {{ politica.version }} · vigente desde {{ politica.vigente_desde }}
        <span v-if="!politica.vigente"> · <strong>versión anterior</strong></span>
      </p>
      <article class="politica" v-html="markdownSeguro(politica.texto_md)"></article>
      <p class="huella">Huella del texto (SHA-256): <code>{{ politica.sha256 }}</code></p>

      <details v-if="!esDemo && versiones.length > 1" class="historial">
        <summary>Versiones anteriores</summary>
        <ul>
          <li v-for="v in versiones" :key="v.version">
            <RouterLink :to="`/politica-de-datos/${v.version}`">Versión {{ v.version }} ({{ v.vigente_desde }})</RouterLink>
            <span v-if="v.vigente"> — vigente</span>
          </li>
        </ul>
      </details>
    </template>
  </section>
</template>

<style scoped>
.pagina { padding-block: var(--esp-6); }
.texto-largo { max-width: 46rem; }
.meta { color: var(--tinta-2); }
.politica :deep(h2) { margin-top: var(--esp-5); }
.politica :deep(li) { margin-bottom: var(--esp-2); }
.huella { margin-top: var(--esp-6); font-size: var(--texto-xs); color: var(--tinta-2); overflow-wrap: anywhere; }
.historial { margin-top: var(--esp-4); }
</style>
