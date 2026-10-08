<script setup>
// Política de tratamiento de datos: versiones publicadas (inmutables) y publicación
// de una nueva. Al publicarla, toda persona necesita una nueva autorización antes
// de su siguiente préstamo (D. 1377/2013 art. 5).
import { ref } from 'vue'
import { useConsulta } from '../../composables/useConsulta.js'
import { traducirError } from '../../lib/errores.js'
import { supabase } from '../../lib/supabase.js'
import { fechaHora } from '../../lib/tiempo.js'

const { datos, error, recargar } = useConsulta((sb) => sb.from('politicas_tratamiento')
  .select('id,version,vigente_desde,vigente,sha256,publicada_en').order('id', { ascending: false }))

const nueva = ref(null)
const confirmo = ref(false)
const mensaje = ref({ tipo: '', texto: '' })

function empezar() {
  nueva.value = { version: '', vigente_desde: new Date().toISOString().slice(0, 10), texto_md: '', texto_autorizacion: '', texto_autorizacion_foto: '' }
  confirmo.value = false
}

async function publicar() {
  const n = nueva.value
  const { error: e } = await supabase.rpc('publicar_politica', {
    p_version: n.version, p_vigente_desde: n.vigente_desde, p_texto_md: n.texto_md,
    p_texto_autorizacion: n.texto_autorizacion, p_texto_autorizacion_foto: n.texto_autorizacion_foto,
  })
  if (e) {
    mensaje.value = { tipo: 'error', texto: /check|unique/i.test(e.message)
      ? 'Revisa la versión (única, p. ej. 1.0) y que los textos tengan la extensión mínima.' : traducirError(e).mensaje }
    return
  }
  mensaje.value = { tipo: 'exito', texto: `Política ${n.version} publicada y vigente.` }
  nueva.value = null
  recargar()
}
</script>

<template>
  <section>
    <div class="admin-cabeza">
      <div><h1>Política de datos</h1><p>Las versiones publicadas no se pueden editar: cada cambio es una versión nueva.</p></div>
      <button v-if="!nueva" class="boton" type="button" @click="empezar">Publicar nueva versión</button>
    </div>
    <p v-if="mensaje.texto" class="mensaje" :class="`mensaje--${mensaje.tipo}`" role="status"><span>{{ mensaje.texto }}</span></p>
    <p v-if="error" class="mensaje mensaje--error"><span>{{ error.mensaje }}</span></p>

    <form v-if="nueva" class="tarjeta-base editor" @submit.prevent="publicar">
      <p class="mensaje mensaje--aviso"><span>Publica solo el texto aprobado por Jurídica. Al publicarlo, todas las personas
        deberán autorizar de nuevo antes de su siguiente préstamo.</span></p>
      <div class="fila-campos">
        <label class="campo"><span>Versión</span><input v-model="nueva.version" placeholder="1.0" /></label>
        <label class="campo"><span>Vigente desde</span><input v-model="nueva.vigente_desde" type="date" /></label>
      </div>
      <label class="campo"><span>Texto de la política (Markdown: # títulos, - listas, **negrita**)</span>
        <textarea v-model="nueva.texto_md" rows="14"></textarea></label>
      <label class="campo"><span>Texto de la casilla de autorización</span><textarea v-model="nueva.texto_autorizacion" rows="3"></textarea></label>
      <label class="campo"><span>Texto de la casilla de la foto</span><textarea v-model="nueva.texto_autorizacion_foto" rows="3"></textarea></label>
      <label class="casilla"><input v-model="confirmo" type="checkbox" /><span>Confirmo que es el texto aprobado.</span></label>
      <div class="acciones">
        <button class="boton" type="submit" :disabled="!confirmo || !nueva.version || nueva.texto_md.length < 200">Publicar</button>
        <button class="boton boton--contorno" type="button" @click="nueva = null">Cancelar</button>
      </div>
    </form>

    <div class="tabla-desplazable">
      <table class="tabla-admin">
        <thead><tr><th>Versión</th><th>Vigente desde</th><th>Publicada</th><th>Estado</th><th>Huella</th><th></th></tr></thead>
        <tbody>
          <tr v-for="p in datos ?? []" :key="p.id">
            <td><strong>{{ p.version }}</strong></td><td>{{ p.vigente_desde }}</td><td>{{ fechaHora(p.publicada_en) }}</td>
            <td>{{ p.vigente ? 'Vigente' : 'Anterior' }}</td><td><code>{{ p.sha256.slice(0, 12) }}…</code></td>
            <td><RouterLink :to="`/politica-de-datos/${p.version}`" target="_blank">Ver</RouterLink></td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>

<style scoped>
.editor { border: 2px solid var(--secundario); }
.mensaje { margin-bottom: var(--esp-4); }
</style>
