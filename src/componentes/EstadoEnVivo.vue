<script setup>
import { computed } from 'vue'

const props = defineProps({
  estado: { type: String, required: true },
  actualizado: { type: Date, default: null },
  error: { type: Object, default: null },
})

const hora = computed(() => props.actualizado
  ? props.actualizado.toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit' })
  : null)

const texto = computed(() => {
  switch (props.estado) {
    case 'en_vivo': return `En vivo · actualizado ${hora.value}`
    case 'sondeo': return `Actualizado ${hora.value ?? '—'} · se refresca cada minuto`
    case 'cargando': return 'Cargando disponibilidad…'
    case 'sin_configurar': return 'La conexión con la base de datos aún no está configurada.'
    default: return props.error?.mensaje ?? 'No se pudo cargar la disponibilidad.'
  }
})
</script>

<template>
  <p class="en-vivo" :class="`en-vivo--${estado}`" role="status" aria-live="polite">
    <span class="en-vivo__punto" aria-hidden="true"></span>{{ texto }}
  </p>
</template>

<style scoped>
.en-vivo {
  display: inline-flex;
  align-items: center;
  gap: var(--esp-2);
  margin: 0;
  font-size: var(--texto-s);
  color: var(--tinta-2);
}
.en-vivo__punto {
  width: 0.625rem;
  height: 0.625rem;
  border-radius: 50%;
  background: var(--estado-sin-dato);
}
.en-vivo--en_vivo .en-vivo__punto { background: var(--estado-disponible); animation: latido 2s ease-in-out infinite; }
.en-vivo--sondeo .en-vivo__punto { background: var(--estado-pocas); }
.en-vivo--error, .en-vivo--sin_configurar { color: var(--error); }
.en-vivo--error .en-vivo__punto, .en-vivo--sin_configurar .en-vivo__punto { background: var(--error); }
@keyframes latido { 50% { opacity: 0.35; } }
</style>
