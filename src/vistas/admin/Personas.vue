<script setup>
// Personas inscritas: búsqueda, detalle (datos, acudiente, autorizaciones,
// sanciones, historial) y suspensión. La lista muestra el documento enmascarado;
// el detalle completo solo al abrir una persona. Quién impone o anula una sanción
// lo fija la base (no se puede atribuir a otro).
import { computed, ref } from 'vue'
import Dialogo from '../../componentes/admin/Dialogo.vue'
import { traducirError } from '../../lib/errores.js'
import { normalizarDocumento } from '../../lib/documento.js'
import { supabase } from '../../lib/supabase.js'
import { fechaHora } from '../../lib/tiempo.js'

const POR_PAGINA = 50
const busqueda = ref({ texto: '', estado: '' })
const filas = ref([])
const pagina = ref(0)
const total = ref(0)
const cargando = ref(false)
const mensaje = ref({ tipo: '', texto: '' })
const persona = ref(null)
const detalle = ref({ acudiente: null, autorizaciones: [], sanciones: [], historial: [] })
const suspension = ref({ hasta: '', motivo: '' })
const anulacion = ref({})

const ESTADOS = { preinscrita: 'Preinscrita', validada: 'Validada', anonimizada: 'Anonimizada' }
const SEXO = { mujer: 'Mujer', hombre: 'Hombre', otro: 'Otro', prefiere_no_responder: 'Prefiere no responder' }
const enmascarar = (v) => (v && v.length > 4 ? `****${v.slice(-4)}` : '****')
const hoy = new Date().toISOString().slice(0, 10)
const paginas = computed(() => Math.max(1, Math.ceil(total.value / POR_PAGINA)))

function avisar(tipo, texto) { mensaje.value = { tipo, texto } }

async function buscar(p = 0) {
  cargando.value = true
  pagina.value = p
  let q = supabase.from('personas')
    .select('id,tipo_documento,numero_documento,nombres,apellidos,estado,origen,creada_en', { count: 'exact' })
    .neq('estado', 'anonimizada').order('creada_en', { ascending: false })
    .range(p * POR_PAGINA, p * POR_PAGINA + POR_PAGINA - 1)
  const texto = busqueda.value.texto.trim()
  if (texto) {
    const doc = normalizarDocumento(texto)
    q = /^[0-9A-Z]{3,}$/.test(doc) && /\d/.test(doc)
      ? q.eq('numero_documento', doc)
      : q.or(`nombres.ilike.%${texto.replace(/[%,()]/g, '')}%,apellidos.ilike.%${texto.replace(/[%,()]/g, '')}%`)
  }
  if (busqueda.value.estado) q = q.eq('estado', busqueda.value.estado)
  const { data, error, count } = await q
  cargando.value = false
  if (error) return avisar('error', traducirError(error).mensaje)
  filas.value = data
  total.value = count ?? data.length
}

async function abrir(id) {
  avisar('', '')
  const [p, a, s, h] = await Promise.all([
    supabase.from('personas').select('id,tipo_documento,numero_documento,nombres,apellidos,telefono,correo,edad_declarada,edad_declarada_en,sexo_genero,acudiente_id,acudiente_parentesco,estado,origen,validada_en,creada_en').eq('id', id).single(),
    supabase.from('autorizaciones_datos').select('id,otorgada_por,canal,autoriza_foto,otorgada_en,estado,menor_escuchado,politica_id').eq('persona_id', id).order('otorgada_en', { ascending: false }),
    supabase.from('sanciones').select('id,tipo,motivo,desde,hasta,estado,impuesta_en,motivo_anulacion').eq('persona_id', id).order('impuesta_en', { ascending: false }),
    supabase.from('v_prestamos_admin').select('id,bici_codigo,estado,punto_salida,punto_devolucion,salida_en,duracion_min,con_novedad').eq('persona_id', id).order('salida_en', { ascending: false }).limit(20),
  ])
  const fallo = p.error ?? a.error ?? s.error ?? h.error
  if (fallo) return avisar('error', traducirError(fallo).mensaje)
  let acudiente = null
  if (p.data.acudiente_id) {
    const r = await supabase.from('acudientes').select('tipo_documento,numero_documento,nombres,apellidos,telefono,correo').eq('id', p.data.acudiente_id).single()
    acudiente = r.data
  }
  persona.value = p.data
  detalle.value = { acudiente, autorizaciones: a.data, sanciones: s.data, historial: h.data }
  suspension.value = { hasta: '', motivo: '' }
  return true
}

async function suspender() {
  const { error } = await supabase.from('sanciones').insert({
    persona_id: persona.value.id, tipo: 'suspension', motivo: suspension.value.motivo, desde: hoy, hasta: suspension.value.hasta,
  })
  if (error) return avisar('error', /check/i.test(error.message) ? 'Revisa la fecha final y el motivo (10 a 500 caracteres).' : traducirError(error).mensaje)
  // Recarga la ficha (eso limpia el aviso) y después confirma; si la recarga falla, queda su error.
  if (await abrir(persona.value.id)) avisar('exito', 'Suspensión registrada. La persona no podrá prestar hasta esa fecha.')
}

async function anular(s) {
  const motivo = (anulacion.value[s.id] ?? '').trim()
  if (motivo.length < 5) return avisar('error', 'Escribe el motivo de la anulación.')
  const { error } = await supabase.from('sanciones').update({ estado: 'anulada', motivo_anulacion: motivo }).eq('id', s.id)
  if (error) return avisar('error', traducirError(error).mensaje)
  if (await abrir(persona.value.id)) avisar('exito', 'Sanción anulada.')
}

buscar()
</script>

<template>
  <section>
    <div class="admin-cabeza">
      <div><h1>Personas</h1><p>{{ total }} inscrita(s). Los datos completos solo se ven al abrir una persona.</p></div>
    </div>
    <p v-if="mensaje.texto && !persona" class="mensaje" :class="`mensaje--${mensaje.tipo}`" role="status"><span>{{ mensaje.texto }}</span></p>

    <form class="filtros" @submit.prevent="buscar(0)">
      <label class="campo"><span>Documento o nombre</span><input v-model="busqueda.texto" autocomplete="off" /></label>
      <label class="campo"><span>Estado</span>
        <select v-model="busqueda.estado"><option value="">Todas</option><option value="preinscrita">Preinscritas</option><option value="validada">Validadas</option></select></label>
      <button class="boton" type="submit">Buscar</button>
    </form>

    <div class="tabla-desplazable">
      <table class="tabla-admin">
        <thead><tr><th>Nombre</th><th>Documento</th><th>Estado</th><th>Inscrita</th><th></th></tr></thead>
        <tbody>
          <tr v-for="p in filas" :key="p.id">
            <td>{{ p.nombres }} {{ p.apellidos }}</td><td>{{ p.tipo_documento }} {{ enmascarar(p.numero_documento) }}</td>
            <td>{{ ESTADOS[p.estado] }}</td><td>{{ fechaHora(p.creada_en) }} · {{ p.origen === 'web' ? 'en línea' : 'en punto' }}</td>
            <td><button class="boton boton--contorno boton--pequeno" type="button" @click="abrir(p.id)">Abrir</button></td>
          </tr>
          <tr v-if="!cargando && !filas.length"><td colspan="5" class="vacio">Sin resultados.</td></tr>
        </tbody>
      </table>
    </div>
    <div v-if="paginas > 1" class="acciones">
      <button class="boton boton--contorno boton--pequeno" type="button" :disabled="pagina === 0" @click="buscar(pagina - 1)">Anterior</button>
      <span>Página {{ pagina + 1 }} de {{ paginas }}</span>
      <button class="boton boton--contorno boton--pequeno" type="button" :disabled="pagina + 1 >= paginas" @click="buscar(pagina + 1)">Siguiente</button>
    </div>

    <Dialogo v-if="persona" :titulo="`${persona.nombres} ${persona.apellidos}`" :aviso="mensaje" amplio @cerrar="persona = null">
      <dl class="datos">
        <dt>Documento</dt><dd>{{ persona.tipo_documento }} {{ persona.numero_documento }}</dd>
        <dt>Celular</dt><dd>{{ persona.telefono }}</dd>
        <dt>Correo</dt><dd>{{ persona.correo ?? '—' }}</dd>
        <dt>Edad declarada</dt><dd>{{ persona.edad_declarada }} (el {{ persona.edad_declarada_en }})</dd>
        <dt>Sexo / género</dt><dd>{{ SEXO[persona.sexo_genero] }}</dd>
        <dt>Estado</dt><dd>{{ ESTADOS[persona.estado] }}<template v-if="persona.validada_en"> · validada {{ fechaHora(persona.validada_en) }}</template></dd>
      </dl>
      <template v-if="detalle.acudiente">
        <h3>Acudiente ({{ persona.acudiente_parentesco }})</h3>
        <p>{{ detalle.acudiente.nombres }} {{ detalle.acudiente.apellidos }} · {{ detalle.acudiente.tipo_documento }}
          {{ detalle.acudiente.numero_documento }} · {{ detalle.acudiente.telefono }}</p>
      </template>

      <h3>Autorizaciones de datos</h3>
      <ul class="lista">
        <li v-for="a in detalle.autorizaciones" :key="a.id">{{ fechaHora(a.otorgada_en) }} · {{ a.canal === 'punto' ? 'en el punto' : 'en línea' }}
          · otorgada por {{ a.otorgada_por }} · foto {{ a.autoriza_foto ? 'sí' : 'no' }} · <strong>{{ a.estado }}</strong></li>
      </ul>

      <h3>Sanciones</h3>
      <p v-if="!detalle.sanciones.length" class="vacio">Sin sanciones.</p>
      <div v-for="s in detalle.sanciones" :key="s.id" class="sancion">
        <p><strong>{{ s.tipo }}</strong> {{ s.desde }} → {{ s.hasta ?? '—' }} · {{ s.estado }} · {{ s.motivo }}</p>
        <div v-if="s.estado === 'vigente'" class="fila-campos">
          <label class="campo"><span>Motivo de anulación</span><input v-model="anulacion[s.id]" maxlength="500" /></label>
          <div class="campo"><span>&nbsp;</span><button class="boton boton--contorno" type="button" @click="anular(s)">Anular</button></div>
        </div>
      </div>
      <form class="suspender" @submit.prevent="suspender">
        <h4>Suspender</h4>
        <div class="fila-campos">
          <label class="campo"><span>Hasta (inclusive)</span><input v-model="suspension.hasta" type="date" :min="hoy" /></label>
          <label class="campo"><span>Motivo</span><input v-model="suspension.motivo" maxlength="500" placeholder="Según el reglamento vigente" /></label>
        </div>
        <button class="boton" type="submit" :disabled="!suspension.hasta || suspension.motivo.trim().length < 10">Registrar suspensión</button>
      </form>

      <h3>Últimos préstamos</h3>
      <p v-if="!detalle.historial.length" class="vacio">Sin préstamos.</p>
      <table v-else class="tabla-admin">
        <thead><tr><th>Salida</th><th>Bici</th><th>De → a</th><th>Duración</th><th>Estado</th></tr></thead>
        <tbody><tr v-for="h in detalle.historial" :key="h.id">
          <td>{{ fechaHora(h.salida_en) }}</td><td>{{ h.bici_codigo }}</td><td>{{ h.punto_salida }} → {{ h.punto_devolucion ?? '—' }}</td>
          <td>{{ h.duracion_min != null ? `${h.duracion_min} min` : '—' }}</td><td>{{ h.estado }}<template v-if="h.con_novedad"> · novedad</template></td>
        </tr></tbody>
      </table>
    </Dialogo>
  </section>
</template>

<style scoped>
h3 { margin-top: var(--esp-5); font-size: var(--texto-m); }
.datos { display: grid; grid-template-columns: auto 1fr; gap: var(--esp-1) var(--esp-4); margin: 0; }
.datos dt { color: var(--tinta-2); }
.datos dd { margin: 0; }
.lista { margin: 0; padding-left: var(--esp-5); }
.sancion { background: var(--banda); border-radius: var(--radio-m); padding: var(--esp-3); margin-bottom: var(--esp-3); }
.sancion p { margin: 0 0 var(--esp-2); }
.suspender { margin-top: var(--esp-4); padding-top: var(--esp-3); border-top: 1px solid var(--linea); }
.mensaje { margin-bottom: var(--esp-4); }
.acciones { align-items: center; }
</style>
