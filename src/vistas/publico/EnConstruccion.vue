<script setup>
import { useRoute } from 'vue-router'

const route = useRoute()
</script>

<template>
  <section class="contenedor en-construccion">
    <h1>{{ route.meta.titulo || 'Página' }}</h1>
    <p class="mensaje mensaje--aviso"><span>Esta sección está en construcción.</span></p>
    <RouterLink to="/" class="boton boton--contorno">Volver al inicio</RouterLink>
  </section>
</template>

<style scoped>
.en-construccion { padding-block: var(--esp-7); }
.en-construccion .mensaje { margin-bottom: var(--esp-5); }
</style>
