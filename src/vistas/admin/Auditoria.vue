<script setup>
// Auditoría (solo inserción) y bitácora de consultas de datos personales.
// En la auditoría, los datos personales aparecen como «huella:…», nunca en claro.
import { computed, ref } from 'vue'
import { useConsulta } from '../../composables/useConsulta.js'
import { traducirError } from '../../lib/errores.js'
import { supabase } from '../../lib/supabase.js'
import { fechaHora } from '../../lib/tiempo.js'

const LIMITE = 200
const pestana = ref('auditoria')
const filtro = ref({ tabla: '', accion: '' })
const filas = ref([])
const consultas = ref([])
const error = ref('')
const abierta = ref(null)

const cPersonal = useConsulta((sb) => sb.from('personal').select('id,nombre'))
const nombre = (id) => (id ? (cPersonal.datos.value ?? []).find((p) => p.id === id)?.nombre ?? 'cuenta desvinculada' : 'sistema')
const TABLAS = ['prestamos', 'bicicletas', 'personas', 'acudientes', 'autorizaciones_datos', 'puntos', 'eventos',
  'incidencias', 'sanciones', 'parametros', 'personal', 'politicas_tratamiento', 'tipos_documento']

const cambios = (f) => Object.keys(f.despues ?? f.antes ?? {}).join(', ')
const visibles = computed(() => filas.value)

async function cargar() {
  error.value = ''
  if (pestana.value === 'auditoria') {
    let q = supabase.from('auditoria').select('id,ocurrido_en,actor_id,tabla,operacion,registro_id,antes,despues,accion,motivo')
      .order('id', { ascending: false }).limit(LIMITE)
    if (filtro.value.tabla) q = q.eq('tabla', filtro.value.tabla)
    if (filtro.value.accion) q = q.ilike('accion', `%${filtro.value.accion.replace(/[%,()]/g, '')}%`)
    const { data, error: e } = await q
    if (e) error.value = traducirError(e).mensaje
    else filas.value = data
  } else {
    const { data, error: e } = await supabase.from('bitacora_consultas')
      .select('id,en,actor_id,tipo,encontrada,con_datos_personales,motivo').order('id', { ascending: false }).limit(LIMITE)
    if (e) error.value = traducirError(e).mensaje
    else consultas.value = data
  }
}

function cambiarPestana(p) {
  pestana.value = p
  cargar()
}

cargar()
</script>

<template>
  <section>
    <div class="admin-cabeza">
      <div><h1>Auditoría</h1><p>Quién hizo qué, cuándo y por qué. Los datos personales aparecen como huellas, nunca en claro.</p></div>
    </div>
    <div class="pestanas" role="tablist">
      <button role="tab" type="button" :aria-selected="pestana === 'auditoria'" @click="cambiarPestana('auditoria')">Cambios</button>
      <button role="tab" type="button" :aria-selected="pestana === 'bitacora'" @click="cambiarPestana('bitacora')">Consultas de datos personales</button>
    </div>
    <p v-if="error" class="mensaje mensaje--error"><span>{{ error }}</span></p>

    <template v-if="pestana === 'auditoria'">
      <form class="filtros" @submit.prevent="cargar">
        <label class="campo"><span>Tabla</span>
          <select v-model="filtro.tabla"><option value="">Todas</option><option v-for="t in TABLAS" :key="t" :value="t">{{ t }}</option></select></label>
        <label class="campo"><span>Acción contiene</span><input v-model="filtro.accion" placeholder="p. ej. anular" /></label>
        <button class="boton" type="submit">Filtrar</button>
      </form>
      <div class="tabla-desplazable">
        <table class="tabla-admin">
          <thead><tr><th>Cuándo</th><th>Quién</th><th>Tabla</th><th>Operación</th><th>Acción · motivo</th><th>Campos</th></tr></thead>
          <tbody>
            <template v-for="f in visibles" :key="f.id">
              <tr>
                <td>{{ fechaHora(f.ocurrido_en) }}</td><td>{{ nombre(f.actor_id) }}</td><td>{{ f.tabla }}</td><td>{{ f.operacion }}</td>
                <td>{{ f.accion ?? '—' }}<template v-if="f.motivo"> · {{ f.motivo }}</template></td>
                <td><button class="enlace" type="button" @click="abierta = abierta === f.id ? null : f.id">{{ cambios(f) || '—' }}</button></td>
              </tr>
              <tr v-if="abierta === f.id"><td colspan="6"><pre class="json">{{ JSON.stringify({ antes: f.antes, despues: f.despues }, null, 2) }}</pre></td></tr>
            </template>
            <tr v-if="!visibles.length"><td colspan="6" class="vacio">Sin registros.</td></tr>
          </tbody>
        </table>
      </div>
    </template>

    <div v-else class="tabla-desplazable">
      <table class="tabla-admin">
        <thead><tr><th>Cuándo</th><th>Quién</th><th>Tipo</th><th>Resultado</th><th>Motivo</th></tr></thead>
        <tbody>
          <tr v-for="c in consultas" :key="c.id">
            <td>{{ fechaHora(c.en) }}</td><td>{{ nombre(c.actor_id) }}</td><td>{{ c.tipo }}</td>
            <td>{{ c.tipo === 'exportar' ? (c.con_datos_personales ? 'con datos personales' : 'seudonimizada') : c.encontrada ? 'encontrada' : 'no encontrada' }}</td>
            <td>{{ c.motivo ?? '—' }}</td>
          </tr>
          <tr v-if="!consultas.length"><td colspan="5" class="vacio">Sin registros.</td></tr>
        </tbody>
      </table>
    </div>
  </section>
</template>

<style scoped>
.pestanas { display: flex; gap: var(--esp-2); margin-bottom: var(--esp-4); flex-wrap: wrap; }
.pestanas button { min-height: 40px; padding: 0 var(--esp-4); border: 2px solid var(--linea-fuerte); border-radius: var(--radio-m); background: var(--superficie); color: var(--tinta-1); font: inherit; font-weight: 600; cursor: pointer; }
.pestanas button[aria-selected='true'] { background: var(--tinta-1); border-color: var(--tinta-1); color: var(--superficie); }
.enlace { background: none; border: 0; padding: 0; color: var(--primario); text-decoration: underline; font: inherit; cursor: pointer; text-align: left; }
.json { margin: 0; white-space: pre-wrap; word-break: break-all; font-size: var(--texto-xs); background: var(--banda); padding: var(--esp-3); border-radius: var(--radio-s); }
</style>
