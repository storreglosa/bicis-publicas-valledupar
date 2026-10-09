<script setup>
// Casillas de autorización de tratamiento de datos (Ley 1581 art. 9): nunca vienen
// marcadas. El operador lee el texto en voz alta y la persona (o su acudiente,
// si es menor) responde. Se registra la versión de la política aceptada.
defineProps({
  politica: { type: Object, required: true },
  esMenor: { type: Boolean, default: false },
  acudiente: { type: Object, default: null },
  fotoObligatoria: { type: Boolean, default: true },
})
const modelo = defineModel({ type: Object, required: true })
</script>

<template>
  <fieldset class="autorizacion">
    <legend>Autorización de datos personales <small>(política v{{ politica.version }})</small></legend>
    <p v-if="esMenor" class="mensaje mensaje--aviso">
      <span>Es menor de edad: autoriza su
        {{ acudiente ? `representante legal, ${acudiente.nombres} ${acudiente.apellidos},` : 'representante legal' }}
        <strong>presente en el punto</strong> con su documento original.</span>
    </p>
    <p class="leer">Lee en voz alta y marca solo si la persona {{ esMenor ? '(su representante legal)' : '' }} acepta:</p>
    <label class="casilla">
      <input v-model="modelo.tratamiento" type="checkbox" />
      <span>{{ politica.texto_autorizacion }}</span>
    </label>
    <label class="casilla">
      <input v-model="modelo.foto" type="checkbox" />
      <span>{{ politica.texto_autorizacion_foto }}
        <small v-if="fotoObligatoria"> (necesaria para prestar)</small></span>
    </label>
    <label v-if="esMenor" class="casilla">
      <input v-model="modelo.menorEscuchado" type="checkbox" />
      <span>Como representante legal del menor (madre, padre, tutor o curador), declaro que escuché su opinión antes de otorgar esta autorización y que la tuve en cuenta.</span>
    </label>
    <p class="politica">Texto completo: <RouterLink :to="`/politica-de-datos/${politica.version}`" target="_blank">política de tratamiento de datos</RouterLink>.</p>
  </fieldset>
</template>

<style scoped>
.autorizacion { border: 2px solid var(--linea-fuerte); border-radius: var(--radio-m); padding: var(--esp-3) var(--esp-4); margin: 0 0 var(--esp-4); }
legend { font-weight: 650; padding: 0 var(--esp-2); }
legend small { color: var(--tinta-2); font-weight: 400; }
.leer, .politica { color: var(--tinta-2); font-size: var(--texto-s); }
.mensaje { margin-bottom: var(--esp-3); }
</style>
