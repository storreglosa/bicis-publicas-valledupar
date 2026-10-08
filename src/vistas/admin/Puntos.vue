<script setup>
// Puntos (fijos, de evento, taller) y eventos. El código de un punto (P01, E001,
// T01) es estable: se imprime y no cambia aunque cambie el nombre. El tipo no se
// cambia después de creado; un punto de evento se cierra solo si no le quedan bicis.
import { computed, ref } from 'vue'
import SelectorUbicacion from '../../componentes/admin/SelectorUbicacion.vue'
import { useConsulta } from '../../composables/useConsulta.js'
import { traducirError } from '../../lib/errores.js'
import { supabase } from '../../lib/supabase.js'
import { aEntradaLocal, deEntradaLocal, fechaHora } from '../../lib/tiempo.js'

const cPuntos = useConsulta((sb) => sb.from('puntos')
  .select('id,codigo,nombre,tipo,estado,evento_id,latitud,longitud,direccion,horario_texto,capacidad,notas_internas').order('codigo'))
const cEventos = useConsulta((sb) => sb.from('eventos')
  .select('id,nombre,descripcion,lugar_texto,inicia_en,termina_en,estado,publicado').order('inicia_en', { ascending: false }))
const cConteo = useConsulta((sb) => sb.from('bicicletas').select('punto_actual_id'))

const TIPOS = { fijo: 'Fijo', evento: 'Evento', taller: 'Taller' }
const ESTADOS = { activo: 'Activo', inactivo: 'Inactivo (visible, cerrado)', oculto: 'Oculto', cerrado: 'Cerrado' }
const ESTADOS_EVENTO = { planeado: 'Planeado', en_curso: 'En curso', finalizado: 'Finalizado', cancelado: 'Cancelado' }

const mensaje = ref({ tipo: '', texto: '' })
const punto = ref(null)      // en edición (nuevo si no tiene id)
const evento = ref(null)
const guardando = ref(false)

const eventos = computed(() => cEventos.datos.value ?? [])
const bicisPorPunto = computed(() => {
  const m = {}
  for (const b of cConteo.datos.value ?? []) m[b.punto_actual_id] = (m[b.punto_actual_id] ?? 0) + 1
  return m
})
const nombreEvento = (id) => eventos.value.find((e) => e.id === id)?.nombre ?? '—'

function avisar(tipo, texto) { mensaje.value = { tipo, texto } }
function recargarTodo() { cPuntos.recargar(); cEventos.recargar(); cConteo.recargar() }

function nuevoPunto() {
  punto.value = { codigo: '', nombre: '', tipo: 'fijo', estado: 'inactivo', evento_id: '', direccion: '', horario_texto: '',
    capacidad: '', notas_internas: '', ubicacion: { latitud: '', longitud: '' } }
}
function editarPunto(p) {
  punto.value = { ...p, evento_id: p.evento_id ?? '', capacidad: p.capacidad ?? '',
    ubicacion: { latitud: Number(p.latitud), longitud: Number(p.longitud) } }
}

async function guardarPunto() {
  const p = punto.value
  guardando.value = true
  const comunes = {
    nombre: p.nombre, estado: p.estado, evento_id: p.tipo === 'evento' ? p.evento_id || null : null,
    latitud: p.ubicacion.latitud, longitud: p.ubicacion.longitud, direccion: p.direccion || null,
    horario_texto: p.horario_texto || null, capacidad: p.capacidad === '' ? null : Number(p.capacidad),
    notas_internas: p.notas_internas || null,
  }
  const { error } = p.id
    ? await supabase.from('puntos').update({
      nombre: comunes.nombre, estado: comunes.estado, evento_id: comunes.evento_id, latitud: comunes.latitud,
      longitud: comunes.longitud, direccion: comunes.direccion, horario_texto: comunes.horario_texto,
      capacidad: comunes.capacidad, notas_internas: comunes.notas_internas,
    }).eq('id', p.id)
    : await supabase.from('puntos').insert({
      codigo: p.codigo.trim().toUpperCase(), tipo: p.tipo, nombre: comunes.nombre, estado: comunes.estado,
      evento_id: comunes.evento_id, latitud: comunes.latitud, longitud: comunes.longitud, direccion: comunes.direccion,
      horario_texto: comunes.horario_texto, capacidad: comunes.capacidad, notas_internas: comunes.notas_internas,
    })
  guardando.value = false
  if (error) return avisar('error', /duplicate key|unique/i.test(error.message) ? 'Ya existe un punto con ese código.' : traducirError(error).mensaje)
  avisar('exito', `Punto ${p.codigo || ''} guardado.`)
  punto.value = null
  recargarTodo()
}

async function cerrarPunto(p) {
  const { error } = await supabase.rpc('cerrar_punto_evento', { p_punto_id: p.id })
  if (error) return avisar('error', traducirError(error).mensaje)
  avisar('exito', `Punto ${p.codigo} cerrado.`)
  recargarTodo()
}

function nuevoEvento() {
  evento.value = { nombre: '', descripcion: '', lugar_texto: '', inicia: '', termina: '', estado: 'planeado', publicado: false }
}
function editarEvento(e) {
  evento.value = { ...e, inicia: aEntradaLocal(e.inicia_en), termina: aEntradaLocal(e.termina_en) }
}

async function guardarEvento() {
  const e = evento.value
  guardando.value = true
  const { error } = e.id
    ? await supabase.from('eventos').update({
      nombre: e.nombre, descripcion: e.descripcion || null, lugar_texto: e.lugar_texto || null,
      inicia_en: deEntradaLocal(e.inicia), termina_en: deEntradaLocal(e.termina), estado: e.estado, publicado: e.publicado,
    }).eq('id', e.id)
    : await supabase.from('eventos').insert({
      nombre: e.nombre, descripcion: e.descripcion || null, lugar_texto: e.lugar_texto || null,
      inicia_en: deEntradaLocal(e.inicia), termina_en: deEntradaLocal(e.termina), estado: e.estado, publicado: e.publicado,
    })
  guardando.value = false
  if (error) return avisar('error', /check/i.test(error.message) ? 'Revisa las fechas: el fin debe ser posterior al inicio.' : traducirError(error).mensaje)
  avisar('exito', `Evento «${e.nombre}» guardado.`)
  evento.value = null
  recargarTodo()
}
</script>

<template>
  <section>
    <div class="admin-cabeza">
      <div><h1>Puntos y eventos</h1><p>Dónde se prestan y devuelven las bicis.</p></div>
      <div class="acciones">
        <button class="boton" type="button" @click="nuevoPunto">Nuevo punto</button>
        <button class="boton boton--contorno" type="button" @click="nuevoEvento">Nuevo evento</button>
      </div>
    </div>
    <p v-if="mensaje.texto" class="mensaje" :class="`mensaje--${mensaje.tipo}`" role="status"><span>{{ mensaje.texto }}</span></p>

    <form v-if="punto" class="tarjeta-base editor" @submit.prevent="guardarPunto">
      <h2>{{ punto.id ? `Editar ${punto.codigo}` : 'Nuevo punto' }}</h2>
      <div class="fila-campos">
        <label class="campo"><span>Código</span>
          <input v-model="punto.codigo" :disabled="!!punto.id" maxlength="10" placeholder="P05, E002, T02" />
          <small>Se imprime; no cambia después.</small></label>
        <label class="campo"><span>Tipo</span>
          <select v-model="punto.tipo" :disabled="!!punto.id"><option v-for="(t, v) in TIPOS" :key="v" :value="v">{{ t }}</option></select></label>
        <label class="campo"><span>Estado</span>
          <select v-model="punto.estado"><option v-for="(t, v) in ESTADOS" :key="v" :value="v" :disabled="v === 'cerrado'">{{ t }}</option></select></label>
      </div>
      <label class="campo"><span>Nombre</span><input v-model="punto.nombre" maxlength="120" /></label>
      <label v-if="punto.tipo === 'evento'" class="campo"><span>Evento</span>
        <select v-model="punto.evento_id"><option value="" disabled>Elige el evento…</option>
          <option v-for="e in eventos.filter((x) => ['planeado', 'en_curso'].includes(x.estado))" :key="e.id" :value="e.id">{{ e.nombre }}</option></select></label>
      <div class="fila-campos">
        <label class="campo"><span>Dirección</span><input v-model="punto.direccion" maxlength="200" /></label>
        <label class="campo"><span>Horario (texto público)</span><input v-model="punto.horario_texto" maxlength="200" placeholder="Lunes a sábado, 6:00 a. m. – 6:00 p. m." /></label>
        <label class="campo"><span>Capacidad <small>(opcional)</small></span><input v-model="punto.capacidad" type="number" min="1" /></label>
      </div>
      <SelectorUbicacion v-model="punto.ubicacion" />
      <label class="campo"><span>Notas internas</span><input v-model="punto.notas_internas" maxlength="1000" /></label>
      <div class="acciones">
        <button class="boton" type="submit" :disabled="guardando || !punto.codigo || punto.nombre.trim().length < 3
          || punto.ubicacion.latitud === '' || (punto.tipo === 'evento' && !punto.evento_id)">Guardar punto</button>
        <button class="boton boton--contorno" type="button" @click="punto = null">Cancelar</button>
      </div>
    </form>

    <form v-if="evento" class="tarjeta-base editor" @submit.prevent="guardarEvento">
      <h2>{{ evento.id ? 'Editar evento' : 'Nuevo evento' }}</h2>
      <label class="campo"><span>Nombre</span><input v-model="evento.nombre" maxlength="120" /></label>
      <div class="fila-campos">
        <label class="campo"><span>Inicia (hora de Colombia)</span><input v-model="evento.inicia" type="datetime-local" /></label>
        <label class="campo"><span>Termina</span><input v-model="evento.termina" type="datetime-local" /></label>
        <label class="campo"><span>Estado</span>
          <select v-model="evento.estado"><option v-for="(t, v) in ESTADOS_EVENTO" :key="v" :value="v">{{ t }}</option></select></label>
      </div>
      <label class="campo"><span>Lugar</span><input v-model="evento.lugar_texto" maxlength="200" /></label>
      <label class="campo"><span>Descripción</span><textarea v-model="evento.descripcion" maxlength="2000"></textarea></label>
      <label class="casilla"><input v-model="evento.publicado" type="checkbox" /><span>Publicado (aparece en la página de eventos y en el mapa)</span></label>
      <p class="nota">Solo se presta en los puntos de un evento mientras esté «En curso».</p>
      <div class="acciones">
        <button class="boton" type="submit" :disabled="guardando || evento.nombre.trim().length < 3 || !evento.inicia || !evento.termina">Guardar evento</button>
        <button class="boton boton--contorno" type="button" @click="evento = null">Cancelar</button>
      </div>
    </form>

    <h2>Puntos</h2>
    <p v-if="cPuntos.error.value" class="mensaje mensaje--error"><span>{{ cPuntos.error.value.mensaje }}</span></p>
    <div v-else class="tabla-desplazable">
      <table class="tabla-admin">
        <thead><tr><th>Código</th><th>Nombre</th><th>Tipo</th><th>Estado</th><th>Bicis</th><th>Evento</th><th></th></tr></thead>
        <tbody>
          <tr v-for="p in cPuntos.datos.value ?? []" :key="p.id">
            <td><strong>{{ p.codigo }}</strong></td><td>{{ p.nombre }}</td><td>{{ TIPOS[p.tipo] }}</td>
            <td>{{ ESTADOS[p.estado] }}</td><td>{{ bicisPorPunto[p.id] ?? 0 }}</td>
            <td>{{ p.evento_id ? nombreEvento(p.evento_id) : '—' }}</td>
            <td class="botones">
              <button v-if="p.estado !== 'cerrado'" class="boton boton--contorno boton--pequeno" type="button" @click="editarPunto(p)">Editar</button>
              <button v-if="p.tipo === 'evento' && p.estado !== 'cerrado'" class="boton boton--contorno boton--pequeno" type="button"
                :disabled="(bicisPorPunto[p.id] ?? 0) > 0" :title="(bicisPorPunto[p.id] ?? 0) > 0 ? 'Mueve primero sus bicis' : ''"
                @click="cerrarPunto(p)">Cerrar</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <h2>Eventos</h2>
    <div class="tabla-desplazable">
      <table class="tabla-admin">
        <thead><tr><th>Nombre</th><th>Inicia</th><th>Termina</th><th>Estado</th><th>Publicado</th><th></th></tr></thead>
        <tbody>
          <tr v-for="e in eventos" :key="e.id">
            <td>{{ e.nombre }}</td><td>{{ fechaHora(e.inicia_en) }}</td><td>{{ fechaHora(e.termina_en) }}</td>
            <td>{{ ESTADOS_EVENTO[e.estado] }}</td><td>{{ e.publicado ? 'Sí' : 'No' }}</td>
            <td><button class="boton boton--contorno boton--pequeno" type="button" @click="editarEvento(e)">Editar</button></td>
          </tr>
          <tr v-if="!eventos.length"><td colspan="6" class="vacio">No hay eventos.</td></tr>
        </tbody>
      </table>
    </div>
  </section>
</template>

<style scoped>
h2 { font-size: var(--texto-l); }
.editor { border: 2px solid var(--secundario); }
.editor h2 { margin-top: 0; }
.nota { color: var(--tinta-2); font-size: var(--texto-s); }
.botones { display: flex; gap: var(--esp-2); flex-wrap: wrap; }
.mensaje { margin-bottom: var(--esp-4); }
</style>
