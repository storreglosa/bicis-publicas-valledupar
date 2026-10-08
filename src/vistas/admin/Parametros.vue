<script setup>
// Parámetros de uso (D-06): cada regla se aplica solo si tiene valor. "No aplica"
// deja el valor en NULL. La base valida tipo, mínimo y máximo, y registra quién
// y cuándo cambió cada valor (auditoría).
import { computed, ref } from 'vue'
import { useConsulta } from '../../composables/useConsulta.js'
import { traducirError } from '../../lib/errores.js'
import { supabase } from '../../lib/supabase.js'
import { fechaHora } from '../../lib/tiempo.js'

const { datos, cargando, error, recargar } = useConsulta((sb) =>
  sb.from('parametros').select('clave,categoria,descripcion,tipo,unidad,minimo,maximo,publico,orden,valor,actualizado_en')
    .order('categoria').order('orden'))

const editando = ref(null)   // { clave, aplica, valor }
const guardando = ref(false)
const errorGuardar = ref('')

const grupos = computed(() => {
  const m = new Map()
  for (const p of datos.value ?? []) {
    if (!m.has(p.categoria)) m.set(p.categoria, [])
    m.get(p.categoria).push(p)
  }
  return [...m.entries()]
})

function mostrar(p) {
  if (p.valor === null) return 'No aplica'
  if (p.tipo === 'booleano') return p.valor ? 'Sí' : 'No'
  return `${p.valor}${p.unidad ? ` ${p.unidad}` : ''}`
}

function editar(p) {
  errorGuardar.value = ''
  editando.value = { clave: p.clave, tipo: p.tipo, aplica: p.valor !== null,
    valor: p.valor ?? (p.tipo === 'booleano' ? true : p.tipo === 'hora' ? '06:00' : ''), p }
}

async function guardar() {
  const e = editando.value
  let valor = null
  if (e.aplica) {
    if (e.tipo === 'entero') valor = Number.parseInt(e.valor, 10)
    else if (e.tipo === 'booleano') valor = Boolean(e.valor)
    else valor = String(e.valor)
    if (e.tipo === 'entero' && !Number.isInteger(valor)) {
      errorGuardar.value = 'Escribe un número entero.'
      return
    }
  }
  guardando.value = true
  const { error: err } = await supabase.from('parametros').update({ valor }).eq('clave', e.clave)
  guardando.value = false
  if (err) {
    errorGuardar.value = traducirError(err).mensaje
    return
  }
  editando.value = null
  recargar()
}
</script>

<template>
  <section>
    <div class="admin-cabeza">
      <div>
        <h1>Parámetros</h1>
        <p>Reglas de uso configurables. Mientras un parámetro diga «No aplica», esa regla no se exige.</p>
      </div>
    </div>
    <p v-if="error" class="mensaje mensaje--error"><span>{{ error.mensaje }}</span></p>
    <p v-else-if="cargando">Cargando…</p>

    <div v-for="[categoria, lista] in grupos" :key="categoria" class="tarjeta-base">
      <h2>{{ categoria }}</h2>
      <ul class="lista">
        <li v-for="p in lista" :key="p.clave" class="parametro">
          <div>
            <p class="parametro__nombre">{{ p.descripcion }}</p>
            <p class="parametro__meta"><code>{{ p.clave }}</code>
              <template v-if="p.minimo !== null || p.maximo !== null"> · rango {{ p.minimo ?? '—' }}–{{ p.maximo ?? '—' }}</template>
              · {{ p.publico ? 'visible al público' : 'interno' }}
              <template v-if="p.actualizado_en"> · cambiado {{ fechaHora(p.actualizado_en) }}</template></p>
          </div>
          <div class="parametro__valor">
            <strong :class="{ 'no-aplica': p.valor === null }">{{ mostrar(p) }}</strong>
            <button class="boton boton--contorno boton--pequeno" type="button" @click="editar(p)">Cambiar</button>
          </div>

          <form v-if="editando?.clave === p.clave" class="edicion" @submit.prevent="guardar">
            <label class="casilla"><input v-model="editando.aplica" type="checkbox" /><span>Esta regla aplica</span></label>
            <template v-if="editando.aplica">
              <label v-if="p.tipo === 'entero'" class="campo"><span>Valor ({{ p.unidad }})</span>
                <input v-model="editando.valor" type="number" inputmode="numeric" :min="p.minimo" :max="p.maximo" /></label>
              <label v-else-if="p.tipo === 'hora'" class="campo"><span>Hora</span>
                <input v-model="editando.valor" type="time" /></label>
              <label v-else-if="p.tipo === 'booleano'" class="casilla"><input v-model="editando.valor" type="checkbox" /><span>Sí</span></label>
              <label v-else class="campo"><span>Texto</span><textarea v-model="editando.valor" maxlength="2000"></textarea></label>
            </template>
            <p v-if="errorGuardar" class="mensaje mensaje--error" role="alert"><span>{{ errorGuardar }}</span></p>
            <div class="acciones">
              <button class="boton" type="submit" :disabled="guardando">{{ guardando ? 'Guardando…' : 'Guardar' }}</button>
              <button class="boton boton--contorno" type="button" @click="editando = null">Cancelar</button>
            </div>
          </form>
        </li>
      </ul>
    </div>
  </section>
</template>

<style scoped>
h2 { margin-top: 0; font-size: var(--texto-m); }
.lista { list-style: none; margin: 0; padding: 0; }
.parametro { display: grid; grid-template-columns: 1fr auto; gap: var(--esp-2) var(--esp-4); padding: var(--esp-3) 0; border-top: 1px solid var(--linea); }
.parametro:first-child { border-top: 0; }
.parametro__nombre { margin: 0; font-weight: 600; }
.parametro__meta { margin: 0; color: var(--tinta-2); font-size: var(--texto-xs); }
.parametro__valor { display: flex; align-items: center; gap: var(--esp-3); }
.no-aplica { color: var(--tinta-2); font-weight: 400; }
.edicion { grid-column: 1 / -1; background: var(--banda); border-radius: var(--radio-m); padding: var(--esp-3) var(--esp-4); }
.mensaje { margin: var(--esp-3) 0; }
@media (max-width: 560px) { .parametro { grid-template-columns: 1fr; } }
</style>
