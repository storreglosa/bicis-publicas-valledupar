<script setup>
// Ventana para gestionar o editar un registro. Se abre encima de la página, donde
// esté el usuario: antes los paneles aparecían al final de la lista o arriba de
// todo y el botón parecía no hacer nada. <dialog> nativo: Esc cierra, el foco
// queda dentro mientras está abierta y vuelve al botón que la abrió al cerrar.
// El padre la monta con v-if y la desmonta al recibir «cerrar».
import { onBeforeUnmount, onMounted, ref, useId } from 'vue'

defineProps({
  titulo: { type: String, required: true },
  aviso: { type: Object, default: null },       // { tipo, texto }: resultado de la última acción
  amplio: { type: Boolean, default: false },    // formularios con mapa o con tablas
})
const emit = defineEmits(['cerrar'])

const id = useId()
const dialogo = ref(null)
const abierta = ref(false)

onMounted(() => {
  dialogo.value.showModal()
  abierta.value = true      // el contenido se monta ya visible: el mapa necesita medir su contenedor
})
onBeforeUnmount(() => { if (dialogo.value?.open) dialogo.value.close() })
</script>

<template>
  <dialog ref="dialogo" class="dialogo" :class="{ 'dialogo--amplio': amplio }" :aria-labelledby="id"
    @cancel.prevent="emit('cerrar')">
    <div class="dialogo__cabeza">
      <h2 :id="id">{{ titulo }}</h2>
      <button class="boton boton--contorno boton--pequeno" type="button" @click="emit('cerrar')">Cerrar</button>
    </div>
    <p v-if="aviso?.texto" class="mensaje" :class="`mensaje--${aviso.tipo}`" role="status"><span>{{ aviso.texto }}</span></p>
    <slot v-if="abierta" />
  </dialog>
</template>

<style scoped>
.dialogo {
  width: 100%; max-width: min(40rem, 96vw); padding: 0 var(--esp-5) var(--esp-5);
  border: 0; border-radius: var(--radio-l); background: var(--superficie); color: var(--tinta-1); box-shadow: var(--sombra);
}
.dialogo--amplio { max-width: min(60rem, 96vw); }
.dialogo::backdrop { background: rgba(34, 28, 23, 0.45); }
/* La cabecera queda fija al desplazarse dentro de la ventana: «Cerrar» siempre a mano. */
.dialogo__cabeza {
  position: sticky; top: 0; z-index: 1; display: flex; justify-content: space-between; align-items: center; gap: var(--esp-3);
  padding: var(--esp-4) 0 var(--esp-3); margin-bottom: var(--esp-3); background: var(--superficie); border-bottom: 1px solid var(--linea);
}
.dialogo__cabeza h2 { margin: 0; font-size: var(--texto-l); }
.mensaje { margin-bottom: var(--esp-4); }
@media (max-width: 480px) { .dialogo { padding: 0 var(--esp-3) var(--esp-4); } }
</style>
