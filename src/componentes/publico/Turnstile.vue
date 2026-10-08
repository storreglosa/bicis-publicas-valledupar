<script>
// Una sola carga del script de Cloudflare para toda la página.
let carga = null
const URL_SCRIPT = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit'

function cargarScript() {
  carga ??= new Promise((resolver, rechazar) => {
    if (window.turnstile) return resolver(window.turnstile)
    const s = document.createElement('script')
    s.src = URL_SCRIPT
    s.async = true
    s.onload = () => (window.turnstile ? resolver(window.turnstile) : rechazar(new Error('turnstile_no_carga')))
    s.onerror = () => { carga = null; rechazar(new Error('turnstile_no_carga')) }
    document.head.appendChild(s)
  })
  return carga
}
</script>

<script setup>
// Verificación anti-robots de Cloudflare Turnstile para la preinscripción. Entrega
// el token con v-model. El token sirve una sola vez y vence a los 300 s: después de
// cada envío el padre llama a reiniciar().
import { onBeforeUnmount, onMounted, ref } from 'vue'

const token = defineModel({ type: String, default: '' })
const props = defineProps({ claveSitio: { type: String, required: true } })
const contenedor = ref(null)
const fallo = ref('')
let widget = null

onMounted(async () => {
  try {
    const turnstile = await cargarScript()
    widget = turnstile.render(contenedor.value, {
      sitekey: props.claveSitio, language: 'es', theme: 'light',
      callback: (t) => { token.value = t; fallo.value = '' },
      'expired-callback': () => { token.value = '' },
      'error-callback': () => {
        token.value = ''
        fallo.value = 'La verificación anti-robots falló. Recarga la página e inténtalo de nuevo.'
      },
    })
  } catch {
    fallo.value = 'No cargó la verificación anti-robots. Revisa tu conexión y recarga la página.'
  }
})
onBeforeUnmount(() => { if (widget != null) window.turnstile?.remove(widget) })

defineExpose({
  reiniciar() {
    token.value = ''
    if (widget != null) window.turnstile?.reset(widget)
  },
})
</script>

<template>
  <div class="verificacion">
    <div ref="contenedor"></div>
    <p v-if="fallo" class="mensaje mensaje--error" role="alert"><span>{{ fallo }}</span></p>
  </div>
</template>

<style scoped>
.verificacion { margin-bottom: var(--esp-4); min-height: 65px; }
</style>
