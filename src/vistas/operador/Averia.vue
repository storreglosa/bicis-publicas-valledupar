<script setup>
// Reportar una bici operativa como averiada: deja de estar disponible hasta que el
// administrador la repare. (El operador no puede devolverla a operativa.)
import { ref } from 'vue'
import { codigoBici } from '../../lib/documento.js'
import { traducirError } from '../../lib/errores.js'
import { supabase } from '../../lib/supabase.js'

const numero = ref('')
const motivo = ref('')
const error = ref('')
const hecho = ref('')
const enviando = ref(false)

async function reportar() {
  error.value = ''
  hecho.value = ''
  enviando.value = true
  const { error: e } = await supabase.rpc('cambiar_condicion_bici', {
    p_numero: Number(numero.value), p_condicion: 'averiada', p_motivo: motivo.value,
  })
  enviando.value = false
  if (e) {
    error.value = traducirError(e).mensaje
    return
  }
  hecho.value = `${codigoBici(numero.value)} quedó fuera de servicio. El administrador verá el reporte.`
  numero.value = ''
  motivo.value = ''
}
</script>

<template>
  <section class="contenedor pagina">
    <RouterLink to="/operador" class="volver">← Turno</RouterLink>
    <h1>Reportar avería</h1>
    <form class="tarjeta-base" @submit.prevent="reportar">
      <label class="campo"><span>Número del sticker</span>
        <input v-model="numero" type="number" inputmode="numeric" min="1" max="9999" autocomplete="off" />
        <small v-if="numero">Código: {{ codigoBici(numero) }}</small></label>
      <label class="campo"><span>¿Qué tiene?</span>
        <input v-model="motivo" maxlength="500" placeholder="Ej.: llanta delantera pinchada" autocomplete="off" /></label>
      <p v-if="hecho" class="mensaje mensaje--exito" role="status"><span>{{ hecho }}</span></p>
      <p v-if="error" class="mensaje mensaje--error" role="alert"><span>{{ error }}</span></p>
      <button class="boton boton--bloque" type="submit" :disabled="!numero || motivo.trim().length < 5 || enviando">
        {{ enviando ? 'Reportando…' : 'Sacar de servicio' }}</button>
    </form>
  </section>
</template>

<style scoped>
.pagina { padding-block: var(--esp-4) var(--esp-6); max-width: 36rem; }
.volver { display: inline-block; margin-bottom: var(--esp-2); }
.mensaje { margin: var(--esp-3) 0; }
</style>
