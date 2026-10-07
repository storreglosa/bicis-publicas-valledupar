<script setup>
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { cambiarClave } from '../../lib/sesion.js'

const MINIMO = 10
const route = useRoute()
const router = useRouter()
const nueva = ref('')
const repetida = ref('')
const enviando = ref(false)
const error = ref('')

const problema = computed(() => {
  if (!nueva.value) return ''
  if (nueva.value.length < MINIMO) return `Usa al menos ${MINIMO} caracteres.`
  if (repetida.value && repetida.value !== nueva.value) return 'Las dos claves no coinciden.'
  return ''
})
const lista = computed(() => nueva.value.length >= MINIMO && nueva.value === repetida.value)

async function enviar() {
  if (!lista.value) return
  error.value = ''
  enviando.value = true
  const r = await cambiarClave(nueva.value)
  enviando.value = false
  if (r.error) {
    error.value = r.error
    return
  }
  const destino = typeof route.query.ir === 'string' && route.query.ir.startsWith('/') ? route.query.ir : '/operador'
  router.replace(destino)
}
</script>

<template>
  <section class="contenedor pagina estrecha">
    <h1>Cambia tu clave</h1>
    <p class="intro">Es tu primer ingreso: elige una clave personal que solo tú conozcas.</p>
    <form class="tarjeta-base" @submit.prevent="enviar" novalidate>
      <label class="campo">
        <span>Clave nueva</span>
        <input v-model="nueva" type="password" autocomplete="new-password" :aria-invalid="!!problema" required />
        <small>Mínimo {{ MINIMO }} caracteres.</small>
      </label>
      <label class="campo">
        <span>Repite la clave</span>
        <input v-model="repetida" type="password" autocomplete="new-password" required />
      </label>
      <p v-if="problema || error" class="mensaje mensaje--error" role="alert"><span>{{ error || problema }}</span></p>
      <button class="boton boton--bloque" type="submit" :disabled="!lista || enviando">
        {{ enviando ? 'Guardando…' : 'Guardar clave' }}
      </button>
    </form>
  </section>
</template>

<style scoped>
.pagina { padding-block: var(--esp-6); }
.estrecha { max-width: 28rem; }
.intro { color: var(--tinta-2); }
.mensaje { margin-bottom: var(--esp-4); }
</style>
