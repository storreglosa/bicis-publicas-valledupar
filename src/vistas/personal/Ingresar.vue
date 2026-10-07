<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ingresar } from '../../lib/sesion.js'
import { configurado } from '../../lib/supabase.js'

const route = useRoute()
const router = useRouter()
const correo = ref('')
const clave = ref('')
const enviando = ref(false)
const error = ref('')

const avisos = {
  inactividad: 'Tu sesión se cerró por inactividad. Ingresa de nuevo.',
  salida: 'Cerraste el turno.',
}

async function enviar() {
  error.value = ''
  enviando.value = true
  const r = await ingresar(correo.value, clave.value)
  enviando.value = false
  if (r.error) {
    error.value = r.error
    clave.value = ''
    return
  }
  const destino = typeof route.query.ir === 'string' && route.query.ir.startsWith('/') ? route.query.ir : '/operador'
  router.replace(destino)
}
</script>

<template>
  <section class="contenedor pagina estrecha">
    <h1>Ingreso del personal</h1>
    <p class="intro">Solo para operadores y administradores del sistema. Si eres ciudadano, no necesitas cuenta:
      <RouterLink to="/inscribirme">inscríbete aquí</RouterLink>.</p>

    <p v-if="avisos[route.query.motivo]" class="mensaje mensaje--aviso"><span>{{ avisos[route.query.motivo] }}</span></p>
    <p v-if="!configurado" class="mensaje mensaje--error"><span>La conexión con la base de datos aún no está configurada.</span></p>

    <form class="tarjeta-base" @submit.prevent="enviar" novalidate>
      <label class="campo">
        <span>Correo</span>
        <input v-model="correo" type="email" autocomplete="username" inputmode="email" required />
      </label>
      <label class="campo">
        <span>Clave</span>
        <input v-model="clave" type="password" autocomplete="current-password" required />
      </label>
      <p v-if="error" class="mensaje mensaje--error" role="alert"><span>{{ error }}</span></p>
      <button class="boton boton--bloque" type="submit" :disabled="enviando || !correo || !clave || !configurado">
        {{ enviando ? 'Ingresando…' : 'Ingresar' }}
      </button>
    </form>
    <p class="nota">¿Olvidaste tu clave? Pide al administrador que la restablezca.</p>
  </section>
</template>

<style scoped>
.pagina { padding-block: var(--esp-6); }
.estrecha { max-width: 28rem; }
.intro, .nota { color: var(--tinta-2); }
.mensaje { margin-bottom: var(--esp-4); }
</style>
