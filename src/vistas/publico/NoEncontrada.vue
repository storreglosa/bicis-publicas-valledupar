<script setup>
// Ruta desconocida (p. ej. un enlace viejo o mal copiado).
</script>

<template>
  <section class="contenedor no-encontrada">
    <h1>Página no encontrada</h1>
    <p>La dirección que abriste no existe en Bicis Públicas Valledupar. Puede que el enlace esté incompleto.</p>
    <div class="acciones">
      <RouterLink to="/" class="boton">Ir al inicio</RouterLink>
      <RouterLink to="/mapa" class="boton boton--contorno">Ver puntos y bicis disponibles</RouterLink>
    </div>
  </section>
</template>

<style scoped>
.no-encontrada { padding-block: var(--esp-7); }
.no-encontrada p { margin-bottom: var(--esp-5); }
</style>
