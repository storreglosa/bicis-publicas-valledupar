<script setup>
// Puntos (fijos, de evento, taller) y eventos. El código de un punto (P01, E01,
// T01) es estable: se imprime y no cambia aunque cambie el nombre. El tipo no se
// cambia después de creado; un punto de evento se cierra solo si no le quedan bicis.
// Un evento se crea junto con su punto de préstamo, ubicado en el mapa; después se
// le pueden agregar más puntos desde la misma ventana.
import { computed, ref, watch } from 'vue'
import Dialogo from '../../componentes/admin/Dialogo.vue'
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
const PREFIJOS = { fijo: 'P', evento: 'E', taller: 'T' }
const ESTADOS = { activo: 'Activo', inactivo: 'Inactivo (visible, cerrado)', oculto: 'Oculto', cerrado: 'Cerrado' }
const ESTADOS_EVENTO = { planeado: 'Planeado', en_curso: 'En curso', finalizado: 'Finalizado', cancelado: 'Cancelado' }

const mensaje = ref({ tipo: '', texto: '' })
const punto = ref(null)      // en edición (nuevo si no tiene id)
const evento = ref(null)     // en edición; puntoNuevo: punto que se crea con el evento (o null)
const guardando = ref(false)

const puntos = computed(() => cPuntos.datos.value ?? [])
const eventos = computed(() => cEventos.datos.value ?? [])
const bicisPorPunto = computed(() => {
  const m = {}
  for (const b of cConteo.datos.value ?? []) m[b.punto_actual_id] = (m[b.punto_actual_id] ?? 0) + 1
  return m
})
const nombreEvento = (id) => eventos.value.find((e) => e.id === id)?.nombre ?? '—'
const puntosDe = (eventoId) => puntos.value.filter((p) => p.evento_id === eventoId)
const puntosDelEvento = computed(() => (evento.value?.id ? puntosDe(evento.value.id) : []))
const hayDialogo = computed(() => !!(punto.value || evento.value))

function avisar(tipo, texto) { mensaje.value = { tipo, texto } }
function recargarTodo() { cPuntos.recargar(); cEventos.recargar(); cConteo.recargar() }

// Siguiente código libre del tipo (P05, E02, T02), con el mismo número de cifras que los existentes.
function siguienteCodigo(prefijo) {
  const nums = puntos.value.map((p) => p.codigo.match(new RegExp(`^${prefijo}(\\d+)$`))).filter(Boolean)
  const ancho = nums.length ? Math.max(...nums.map((m) => m[1].length)) : 2
  const siguiente = nums.length ? Math.max(...nums.map((m) => Number(m[1]))) + 1 : 1
  return `${prefijo}${String(siguiente).padStart(ancho, '0')}`
}

function errorDePunto(error) {
  if (error.code === '23505' || /duplicate key|unique/i.test(error.message)) return 'Ya existe un punto con ese código.'
  if (/latitud|longitud/i.test(error.message)) return 'La ubicación queda fuera de Valledupar: márcala de nuevo en el mapa.'
  if (/codigo/i.test(error.message)) return 'El código empieza con una letra y lleva de 2 a 10 letras o números, sin espacios.'
  return traducirError(error).mensaje
}

function nuevoPunto() {
  avisar('', '')
  punto.value = { codigo: siguienteCodigo('P'), nombre: '', tipo: 'fijo', estado: 'inactivo', evento_id: '', direccion: '',
    horario_texto: '', capacidad: '', notas_internas: '', ubicacion: { latitud: '', longitud: '' } }
}
function editarPunto(p) {
  avisar('', '')
  punto.value = { ...p, evento_id: p.evento_id ?? '', capacidad: p.capacidad ?? '',
    direccion: p.direccion ?? '', horario_texto: p.horario_texto ?? '', notas_internas: p.notas_internas ?? '',
    ubicacion: { latitud: Number(p.latitud), longitud: Number(p.longitud) } }
}
// En un punto nuevo, al cambiar el tipo se actualiza el código sugerido (si no lo editaron a mano).
watch(() => punto.value?.tipo, (tipo, antes) => {
  const p = punto.value
  if (!p || p.id || !antes || !tipo) return
  if (p.codigo === siguienteCodigo(PREFIJOS[antes])) p.codigo = siguienteCodigo(PREFIJOS[tipo])
})

const faltaPunto = computed(() => {
  const p = punto.value
  if (!p) return ''
  if (!p.codigo.trim()) return 'el código'
  if (p.nombre.trim().length < 3) return 'el nombre (mínimo 3 letras)'
  if (p.tipo === 'evento' && !p.evento_id) return 'elegir el evento'
  if (p.ubicacion.latitud === '' || p.ubicacion.longitud === '') return 'ubicar el punto en el mapa'
  return ''
})

async function guardarPunto() {
  const p = punto.value
  guardando.value = true
  const comunes = {
    nombre: p.nombre.trim(), estado: p.estado, evento_id: p.tipo === 'evento' ? p.evento_id || null : null,
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
  if (error) return avisar('error', errorDePunto(error))
  avisar('exito', `Punto ${p.codigo.trim().toUpperCase()} guardado.`)
  punto.value = null
  recargarTodo()
}

async function cerrarPunto(p) {
  const { error } = await supabase.rpc('cerrar_punto_evento', { p_punto_id: p.id })
  if (error) return avisar('error', traducirError(error).mensaje)
  avisar('exito', `Punto ${p.codigo} cerrado.`)
  recargarTodo()
}

function puntoDeEvento() {
  return { codigo: siguienteCodigo('E'), nombre: '', estado: 'activo', ubicacion: { latitud: '', longitud: '' } }
}
function nuevoEvento() {
  avisar('', '')
  evento.value = { nombre: '', descripcion: '', lugar_texto: '', inicia: '', termina: '', estado: 'planeado', publicado: false,
    puntoNuevo: puntoDeEvento() }
}
function editarEvento(e) {
  avisar('', '')
  evento.value = { ...e, descripcion: e.descripcion ?? '', lugar_texto: e.lugar_texto ?? '',
    inicia: aEntradaLocal(e.inicia_en), termina: aEntradaLocal(e.termina_en), puntoNuevo: null }
}

const faltaEvento = computed(() => {
  const e = evento.value
  if (!e) return ''
  if (e.nombre.trim().length < 3) return 'el nombre del evento (mínimo 3 letras)'
  if (!e.inicia || !e.termina) return 'la fecha y hora de inicio y de fin'
  if (e.termina <= e.inicia) return 'que el fin sea posterior al inicio'
  if (e.puntoNuevo && !e.puntoNuevo.codigo.trim()) return 'el código del punto'
  if (e.puntoNuevo && (e.puntoNuevo.ubicacion.latitud === '' || e.puntoNuevo.ubicacion.longitud === '')) return 'ubicar el punto de préstamo en el mapa'
  return ''
})

// Dos escrituras: el evento (pidiendo su id) y luego su punto. Si el punto falla, el
// evento ya quedó guardado: la ventana sigue abierta en modo edición para reintentar
// solo el punto, sin duplicar el evento.
async function guardarEvento() {
  const e = evento.value
  guardando.value = true
  if (e.id) {
    const { error } = await supabase.from('eventos').update({
      nombre: e.nombre.trim(), descripcion: e.descripcion || null, lugar_texto: e.lugar_texto || null,
      inicia_en: deEntradaLocal(e.inicia), termina_en: deEntradaLocal(e.termina), estado: e.estado, publicado: e.publicado,
    }).eq('id', e.id)
    if (error) { guardando.value = false; return avisar('error', traducirError(error).mensaje) }
  } else {
    const { data, error } = await supabase.from('eventos').insert({
      nombre: e.nombre.trim(), descripcion: e.descripcion || null, lugar_texto: e.lugar_texto || null,
      inicia_en: deEntradaLocal(e.inicia), termina_en: deEntradaLocal(e.termina), estado: e.estado, publicado: e.publicado,
    }).select('id').single()
    if (error) { guardando.value = false; return avisar('error', traducirError(error).mensaje) }
    e.id = data.id
  }
  let codigo = ''
  if (e.puntoNuevo) {
    const pn = e.puntoNuevo
    codigo = pn.codigo.trim().toUpperCase()
    const { error } = await supabase.from('puntos').insert({
      codigo, tipo: 'evento', nombre: pn.nombre.trim() || e.nombre.trim(), estado: pn.estado, evento_id: e.id,
      latitud: pn.ubicacion.latitud, longitud: pn.ubicacion.longitud,
    })
    if (error) {
      guardando.value = false
      recargarTodo()
      return avisar('error', `El evento quedó guardado, pero el punto no: ${errorDePunto(error)} Corrígelo y vuelve a guardar.`)
    }
  }
  guardando.value = false
  avisar('exito', `Evento «${e.nombre.trim()}» guardado${codigo ? ` con su punto ${codigo}` : ''}.`)
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
    <p v-if="mensaje.texto && !hayDialogo" class="mensaje" :class="`mensaje--${mensaje.tipo}`" role="status"><span>{{ mensaje.texto }}</span></p>

    <h2>Puntos</h2>
    <p v-if="cPuntos.error.value" class="mensaje mensaje--error"><span>{{ cPuntos.error.value.mensaje }}</span></p>
    <div v-else class="tabla-desplazable">
      <table class="tabla-admin">
        <thead><tr><th>Código</th><th>Nombre</th><th>Tipo</th><th>Estado</th><th>Bicis</th><th>Evento</th><th></th></tr></thead>
        <tbody>
          <tr v-for="p in puntos" :key="p.id">
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
        <thead><tr><th>Nombre</th><th>Inicia</th><th>Termina</th><th>Estado</th><th>Publicado</th><th>Puntos</th><th></th></tr></thead>
        <tbody>
          <tr v-for="e in eventos" :key="e.id">
            <td>{{ e.nombre }}</td><td>{{ fechaHora(e.inicia_en) }}</td><td>{{ fechaHora(e.termina_en) }}</td>
            <td>{{ ESTADOS_EVENTO[e.estado] }}</td><td>{{ e.publicado ? 'Sí' : 'No' }}</td>
            <td>{{ puntosDe(e.id).map((p) => p.codigo).join(', ') || 'Sin punto' }}</td>
            <td><button class="boton boton--contorno boton--pequeno" type="button" @click="editarEvento(e)">Editar</button></td>
          </tr>
          <tr v-if="!eventos.length"><td colspan="7" class="vacio">No hay eventos.</td></tr>
        </tbody>
      </table>
    </div>

    <Dialogo v-if="evento" :titulo="evento.id ? `Editar evento: ${evento.nombre}` : 'Nuevo evento'" :aviso="mensaje" amplio
      @cerrar="evento = null">
      <form @submit.prevent="guardarEvento">
        <label class="campo"><span>Nombre del evento</span><input v-model="evento.nombre" maxlength="120" /></label>
        <div class="fila-campos fila-campos--fechas">
          <label class="campo"><span>Inicia (hora de Colombia)</span><input v-model="evento.inicia" type="datetime-local" /></label>
          <label class="campo"><span>Termina</span><input v-model="evento.termina" type="datetime-local" /></label>
          <label class="campo"><span>Estado</span>
            <select v-model="evento.estado"><option v-for="(t, v) in ESTADOS_EVENTO" :key="v" :value="v">{{ t }}</option></select></label>
        </div>
        <label class="campo"><span>Lugar (texto público)</span><input v-model="evento.lugar_texto" maxlength="200" placeholder="Ej.: Balneario Hurtado, entrada principal" /></label>
        <label class="campo"><span>Descripción</span><textarea v-model="evento.descripcion" maxlength="2000"></textarea></label>
        <label class="casilla"><input v-model="evento.publicado" type="checkbox" /><span>Publicado (aparece en la página de eventos y sus puntos en el mapa)</span></label>
        <p class="nota">Solo se presta en los puntos de un evento mientras esté «En curso».</p>

        <fieldset class="puntos-evento">
          <legend>Puntos de préstamo del evento</legend>
          <ul v-if="puntosDelEvento.length" class="lista-puntos">
            <li v-for="p in puntosDelEvento" :key="p.id">
              <span><strong>{{ p.codigo }}</strong> · {{ p.nombre }} · {{ ESTADOS[p.estado] }} · {{ bicisPorPunto[p.id] ?? 0 }} bici(s)</span>
              <button v-if="p.estado !== 'cerrado'" class="boton boton--contorno boton--pequeno" type="button" @click="editarPunto(p)">Editar punto</button>
            </li>
          </ul>
          <p v-else-if="!evento.puntoNuevo" class="nota">Este evento todavía no tiene punto de préstamo.</p>

          <div v-if="evento.puntoNuevo" class="punto-nuevo">
            <p class="nota"><strong>Toca el mapa en el lugar exacto del punto.</strong> Se crea al guardar el evento.</p>
            <div class="fila-campos">
              <label class="campo"><span>Código del punto <small>(se imprime; no cambia)</small></span>
                <input v-model="evento.puntoNuevo.codigo" maxlength="10" /></label>
              <label class="campo"><span>Nombre del punto <small>(opcional)</small></span>
                <input v-model="evento.puntoNuevo.nombre" maxlength="120" :placeholder="evento.nombre || 'El nombre del evento'" /></label>
              <label class="campo"><span>Estado del punto</span>
                <select v-model="evento.puntoNuevo.estado"><option value="activo">Activo</option><option value="inactivo">Inactivo (visible, cerrado)</option>
                  <option value="oculto">Oculto</option></select></label>
            </div>
            <SelectorUbicacion v-model="evento.puntoNuevo.ubicacion" />
            <button class="boton boton--contorno boton--pequeno" type="button" @click="evento.puntoNuevo = null">
              {{ puntosDelEvento.length ? 'No agregar este punto' : 'Sin punto por ahora' }}</button>
          </div>
          <button v-else class="boton boton--contorno" type="button" @click="evento.puntoNuevo = puntoDeEvento()">
            {{ puntosDelEvento.length ? 'Agregar otro punto en el mapa' : 'Ubicar el punto en el mapa' }}</button>
        </fieldset>

        <p v-if="faltaEvento" class="nota">Para guardar falta {{ faltaEvento }}.</p>
        <div class="acciones">
          <button class="boton" type="submit" :disabled="guardando || !!faltaEvento">{{ guardando ? 'Guardando…' : 'Guardar evento' }}</button>
          <button class="boton boton--contorno" type="button" @click="evento = null">Cancelar</button>
        </div>
      </form>
    </Dialogo>

    <Dialogo v-if="punto" :titulo="punto.id ? `Editar punto ${punto.codigo}` : 'Nuevo punto'" :aviso="mensaje" amplio @cerrar="punto = null">
      <form @submit.prevent="guardarPunto">
        <div class="fila-campos">
          <label class="campo"><span>Código <small>(se imprime; no cambia)</small></span>
            <input v-model="punto.codigo" :disabled="!!punto.id" maxlength="10" placeholder="P05, E02, T02" /></label>
          <label class="campo"><span>Tipo</span>
            <select v-model="punto.tipo" :disabled="!!punto.id"><option v-for="(t, v) in TIPOS" :key="v" :value="v">{{ t }}</option></select></label>
          <label class="campo"><span>Estado</span>
            <select v-model="punto.estado"><option v-for="(t, v) in ESTADOS" :key="v" :value="v" :disabled="v === 'cerrado'">{{ t }}</option></select></label>
        </div>
        <label class="campo"><span>Nombre</span><input v-model="punto.nombre" maxlength="120" /></label>
        <label v-if="punto.tipo === 'evento'" class="campo"><span>Evento</span>
          <select v-model="punto.evento_id"><option value="" disabled>Elige el evento…</option>
            <option v-for="e in eventos.filter((x) => ['planeado', 'en_curso'].includes(x.estado) || x.id === punto.evento_id)" :key="e.id" :value="e.id">{{ e.nombre }}</option></select>
          <small v-if="!punto.id">Para un evento nuevo es más fácil usar «Nuevo evento»: ahí mismo ubicas su punto.</small></label>
        <div class="fila-campos">
          <label class="campo"><span>Dirección</span><input v-model="punto.direccion" maxlength="200" /></label>
          <label class="campo"><span>Horario (texto público)</span><input v-model="punto.horario_texto" maxlength="200" placeholder="Lunes a sábado, 6:00 a. m. – 6:00 p. m." /></label>
          <label class="campo"><span>Capacidad <small>(opcional)</small></span><input v-model="punto.capacidad" type="number" min="1" /></label>
        </div>
        <p class="nota"><strong>Toca el mapa en el lugar exacto del punto.</strong></p>
        <SelectorUbicacion v-model="punto.ubicacion" />
        <label class="campo"><span>Notas internas</span><input v-model="punto.notas_internas" maxlength="1000" /></label>
        <p v-if="faltaPunto" class="nota">Para guardar falta {{ faltaPunto }}.</p>
        <div class="acciones">
          <button class="boton" type="submit" :disabled="guardando || !!faltaPunto">{{ guardando ? 'Guardando…' : 'Guardar punto' }}</button>
          <button class="boton boton--contorno" type="button" @click="punto = null">Cancelar</button>
        </div>
      </form>
    </Dialogo>
  </section>
</template>

<style scoped>
h2 { font-size: var(--texto-l); }
.puntos-evento { border: 1px solid var(--linea); border-radius: var(--radio-m); padding: var(--esp-3) var(--esp-4) var(--esp-4); margin: var(--esp-4) 0; }
.puntos-evento legend { font-weight: 650; padding: 0 var(--esp-2); }
.lista-puntos { list-style: none; margin: 0 0 var(--esp-3); padding: 0; display: grid; gap: var(--esp-2); }
.lista-puntos li { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: var(--esp-2); }
.punto-nuevo { margin-bottom: var(--esp-2); }
.nota { color: var(--tinta-2); font-size: var(--texto-s); }
.botones { display: flex; gap: var(--esp-2); flex-wrap: wrap; }
.mensaje { margin-bottom: var(--esp-4); }
</style>
