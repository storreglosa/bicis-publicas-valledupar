<script setup>
// Historial de préstamos con filtros, foto de evidencia (enlace firmado de 60 s),
// operaciones de excepción (anular, forzar devolución, cerrar como no devuelto;
// siempre con motivo y auditadas) y exportación CSV (utf-8-sig) seudonimizada por
// defecto. Incluir nombres y documentos exige un motivo y queda en la bitácora.
import { computed, ref } from 'vue'
import Dialogo from '../../componentes/admin/Dialogo.vue'
import { useConsulta } from '../../composables/useConsulta.js'
import { aCsv, descargarCsv } from '../../lib/csv.js'
import { traducirError } from '../../lib/errores.js'
import { supabase } from '../../lib/supabase.js'
import { duracion, fechaHora } from '../../lib/tiempo.js'

const LIMITE = 1000
const hoy = new Date().toISOString().slice(0, 10)
const hace30 = new Date(Date.now() - 30 * 864e5).toISOString().slice(0, 10)
const filtro = ref({ desde: hace30, hasta: hoy, estado: '', bici: '' })
const filas = ref([])
const cargando = ref(false)
const mensaje = ref({ tipo: '', texto: '' })
const accion = ref(null)   // { tipo, fila, motivo, punto }
const exportar = ref({ conDatos: false, motivo: '' })

const cPuntos = useConsulta((sb) => sb.from('puntos').select('id,codigo,nombre,estado').neq('estado', 'cerrado').order('codigo'))
const ESTADOS = { activo: 'Activo', finalizado: 'Finalizado', no_devuelto: 'No devuelto', anulado: 'Anulado' }
const truncado = computed(() => filas.value.length >= LIMITE)
const TITULOS = { anular: 'Anular préstamo', forzar: 'Forzar devolución', no_devuelto: 'Cerrar como no devuelto', conservar: 'Conservar foto' }

function abrirAccion(tipo, fila) {
  avisar('', '')
  accion.value = { tipo, fila, motivo: '', punto: '' }
}

function avisar(tipo, texto) { mensaje.value = { tipo, texto } }

async function cargar() {
  cargando.value = true
  let q = supabase.from('v_prestamos_admin').select('*')
    .gte('salida_en', `${filtro.value.desde}T00:00:00-05:00`).lte('salida_en', `${filtro.value.hasta}T23:59:59-05:00`)
    .order('salida_en', { ascending: false }).limit(LIMITE)
  if (filtro.value.estado) q = q.eq('estado', filtro.value.estado)
  if (filtro.value.bici) q = q.eq('bici_numero', Number(filtro.value.bici))
  const { data, error } = await q
  cargando.value = false
  if (error) return avisar('error', traducirError(error).mensaje)
  filas.value = data
}

async function verFoto(f) {
  const { data, error } = await supabase.storage.from('evidencias').createSignedUrl(f.foto_ruta, 60)
  if (error) return avisar('error', /not found/i.test(error.message) ? 'La foto ya no está (se borró por la política de retención).' : traducirError(error).mensaje)
  window.open(data.signedUrl, '_blank', 'noopener')
}

async function ejecutar() {
  const a = accion.value
  const llamada = a.tipo === 'anular'
    ? supabase.rpc('anular_prestamo', { p_prestamo_id: a.fila.id, p_motivo: a.motivo })
    : a.tipo === 'forzar'
      ? supabase.rpc('forzar_devolucion', { p_prestamo_id: a.fila.id, p_punto_id: a.punto, p_motivo: a.motivo })
      : a.tipo === 'conservar'
        ? supabase.rpc('conservar_foto', { p_prestamo_id: a.fila.id, p_motivo: a.motivo })
        : supabase.rpc('cerrar_no_devuelto', { p_prestamo_id: a.fila.id, p_motivo: a.motivo })
  const { error } = await llamada
  if (error) return avisar('error', traducirError(error).mensaje)
  avisar('exito', a.tipo === 'conservar'
    ? `La foto del préstamo de la ${a.fila.bici_codigo} se conservará: la purga automática no la borra.`
    : `Préstamo de la ${a.fila.bici_codigo} actualizado.`)
  accion.value = null
  cargar()
}

const COLUMNAS_BASE = [
  { clave: 'id', titulo: 'prestamo_id' }, { clave: 'estado', titulo: 'estado' }, { clave: 'bici_codigo', titulo: 'bici' },
  { clave: 'persona_id', titulo: 'persona_id' }, { clave: 'edad_estimada', titulo: 'edad' }, { clave: 'es_menor', titulo: 'es_menor' },
  { clave: 'sexo_genero', titulo: 'sexo_genero' }, { clave: 'punto_salida', titulo: 'punto_salida' },
  { clave: 'punto_devolucion', titulo: 'punto_devolucion' }, { clave: 'salida_en', titulo: 'salida' },
  { clave: 'devuelto_en', titulo: 'devolucion' }, { clave: 'duracion_min', titulo: 'duracion_min' },
  { clave: 'con_novedad', titulo: 'con_novedad' }, { clave: 'devolucion_forzada', titulo: 'devolucion_forzada' },
  { clave: 'operador_salida', titulo: 'operador_salida' }, { clave: 'operador_devolucion', titulo: 'operador_devolucion' },
]
const COLUMNAS_PERSONALES = [
  { clave: 'tipo_documento', titulo: 'tipo_documento' }, { clave: 'numero_documento', titulo: 'numero_documento' },
  { clave: 'nombres', titulo: 'nombres' }, { clave: 'apellidos', titulo: 'apellidos' },
]

async function descargar() {
  const conDatos = exportar.value.conDatos
  const { error } = await supabase.rpc('registrar_exportacion', {
    p_con_datos_personales: conDatos, p_motivo: exportar.value.motivo || null,
    p_detalle: { filtros: filtro.value, filas: filas.value.length },
  })
  if (error) return avisar('error', traducirError(error).mensaje)
  const columnas = conDatos ? [...COLUMNAS_BASE, ...COLUMNAS_PERSONALES] : COLUMNAS_BASE
  descargarCsv(aCsv(filas.value, columnas), `${hoy}_bicis_prestamos${conDatos ? '_con-datos-personales' : ''}.csv`)
  avisar('exito', `Exportadas ${filas.value.length} filas${conDatos ? ' con datos personales (quedó en la bitácora)' : ' seudonimizadas'}.`)
  exportar.value = { conDatos: false, motivo: '' }
}

cargar()
</script>

<template>
  <section>
    <div class="admin-cabeza">
      <div><h1>Préstamos</h1><p>{{ filas.length }} préstamo(s) en el periodo{{ truncado ? ` (se muestran los ${LIMITE} más recientes)` : '' }}.</p></div>
    </div>
    <p v-if="mensaje.texto && !accion" class="mensaje" :class="`mensaje--${mensaje.tipo}`" role="status"><span>{{ mensaje.texto }}</span></p>

    <form class="filtros" @submit.prevent="cargar">
      <label class="campo"><span>Desde</span><input v-model="filtro.desde" type="date" /></label>
      <label class="campo"><span>Hasta</span><input v-model="filtro.hasta" type="date" /></label>
      <label class="campo"><span>Estado</span>
        <select v-model="filtro.estado"><option value="">Todos</option><option v-for="(t, v) in ESTADOS" :key="v" :value="v">{{ t }}</option></select></label>
      <label class="campo"><span>N.º de bici</span><input v-model="filtro.bici" type="number" min="1" /></label>
      <button class="boton" type="submit">Filtrar</button>
    </form>

    <Dialogo v-if="accion" :titulo="`${TITULOS[accion.tipo]} · ${accion.fila.bici_codigo}`" :aviso="mensaje" @cerrar="accion = null">
      <p>{{ accion.fila.nombres }} {{ accion.fila.apellidos?.charAt(0) }}. · salió de {{ accion.fila.punto_salida }} el {{ fechaHora(accion.fila.salida_en) }}</p>
      <p class="nota" v-if="accion.tipo === 'anular'">Para préstamos registrados por error: la bici vuelve al punto de salida.</p>
      <p class="nota" v-if="accion.tipo === 'no_devuelto'">La bici queda «extraviada» y se abre una incidencia de pérdida; la foto se conserva.</p>
      <p class="nota" v-if="accion.tipo === 'conservar'">La purga automática no borrará esta foto. Úsalo ante un reclamo o un daño
        descubierto después de la devolución.</p>
      <label v-if="accion.tipo === 'forzar'" class="campo"><span>Punto donde quedó la bici</span>
        <select v-model="accion.punto"><option value="" disabled>Elige…</option>
          <option v-for="p in cPuntos.datos.value ?? []" :key="p.id" :value="p.id">{{ p.codigo }} · {{ p.nombre }}</option></select></label>
      <label class="campo"><span>Motivo (queda en la auditoría)</span><input v-model="accion.motivo" maxlength="500" /></label>
      <div class="acciones">
        <button class="boton" type="button" :disabled="accion.motivo.trim().length < 10 || (accion.tipo === 'forzar' && !accion.punto)" @click="ejecutar">Confirmar</button>
        <button class="boton boton--contorno" type="button" @click="accion = null">Cancelar</button>
      </div>
    </Dialogo>

    <p v-if="cargando">Cargando…</p>
    <div v-else class="tabla-desplazable">
      <table class="tabla-admin">
        <thead><tr><th>Salida</th><th>Bici</th><th>Persona</th><th>De → a</th><th>Duración</th><th>Estado</th><th>Foto</th><th></th></tr></thead>
        <tbody>
          <tr v-for="f in filas" :key="f.id">
            <td>{{ fechaHora(f.salida_en) }}</td><td><strong>{{ f.bici_codigo }}</strong></td>
            <td>{{ f.nombres }} {{ f.apellidos?.charAt(0) }}.<template v-if="f.es_menor"> (menor)</template></td>
            <td>{{ f.punto_salida }} → {{ f.punto_devolucion ?? '—' }}</td>
            <td>{{ f.duracion_min != null ? duracion(f.duracion_min) : '—' }}</td>
            <td>{{ ESTADOS[f.estado] }}<template v-if="f.con_novedad"> · novedad</template><template v-if="f.devolucion_forzada"> · forzada</template></td>
            <td class="botones"><template v-if="f.foto_estado === 'almacenada'">
                <button class="boton boton--contorno boton--pequeno" type="button" @click="verFoto(f)">Ver</button>
                <span v-if="f.foto_retener" class="nota">conservada</span>
                <button v-else class="boton boton--contorno boton--pequeno" type="button" @click="abrirAccion('conservar', f)">Conservar</button>
              </template>
              <span v-else>borrada</span></td>
            <td class="botones">
              <template v-if="f.estado === 'activo'">
                <button class="boton boton--contorno boton--pequeno" type="button" @click="abrirAccion('forzar', f)">Forzar devolución</button>
                <button class="boton boton--contorno boton--pequeno" type="button" @click="abrirAccion('anular', f)">Anular</button>
                <button class="boton boton--contorno boton--pequeno" type="button" @click="abrirAccion('no_devuelto', f)">No devuelto</button>
              </template>
            </td>
          </tr>
          <tr v-if="!filas.length"><td colspan="8" class="vacio">Sin préstamos en el periodo.</td></tr>
        </tbody>
      </table>
    </div>

    <form class="tarjeta-base" @submit.prevent="descargar">
      <h2>Exportar a CSV (Excel)</h2>
      <p class="nota">Por defecto, sin nombres ni documentos: cada persona aparece como un identificador interno.</p>
      <label class="casilla"><input v-model="exportar.conDatos" type="checkbox" /><span>Incluir nombres y documentos</span></label>
      <label v-if="exportar.conDatos" class="campo"><span>Motivo (queda en la bitácora)</span><input v-model="exportar.motivo" maxlength="500" /></label>
      <button class="boton boton--secundario" type="submit" :disabled="!filas.length || (exportar.conDatos && exportar.motivo.trim().length < 10)">
        Descargar {{ filas.length }} fila(s)</button>
    </form>
  </section>
</template>

<style scoped>
h2 { font-size: var(--texto-l); margin-top: 0; }
.nota { color: var(--tinta-2); font-size: var(--texto-s); }
.botones { display: flex; flex-wrap: wrap; gap: var(--esp-1); }
.mensaje { margin-bottom: var(--esp-4); }
</style>
