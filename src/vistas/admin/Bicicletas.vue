<script setup>
// Flota: alta de bicis por rango de stickers, datos descriptivos, condición física
// (operativa, averiada, en reparación, extraviada, baja), novedades abiertas e
// historial. La disponibilidad y la ubicación solo cambian por funciones auditadas.
import { computed, ref } from 'vue'
import { useConsulta } from '../../composables/useConsulta.js'
import { traducirError } from '../../lib/errores.js'
import { supabase } from '../../lib/supabase.js'
import { fechaHora } from '../../lib/tiempo.js'

const consultaBicis = useConsulta((sb) => sb.from('bicicletas')
  .select('id,numero,codigo,disponibilidad,condicion,punto_actual_id,marca,modelo,color,talla,numero_serie,fecha_ingreso,nota_operativa,ultimo_movimiento_en')
  .order('numero'))
const consultaPuntos = useConsulta((sb) => sb.from('puntos').select('id,codigo,nombre,tipo,estado').order('codigo'))

const filtro = ref({ texto: '', condicion: '', punto: '' })
const alta = ref({ desde: 1, hasta: 130, punto: '' })
const mensaje = ref({ tipo: '', texto: '' })
const elegida = ref(null)
const detalle = ref({ novedades: [], historial: [] })
const cambio = ref({ condicion: '', motivo: '', punto: '' })
const resolucion = ref({})

const CONDICIONES = { operativa: 'Operativa', averiada: 'Averiada', en_reparacion: 'En reparación', extraviada: 'Extraviada', baja: 'De baja' }
const DISPONIBILIDAD = { disponible: 'Disponible', prestada: 'Prestada', no_disponible: 'No disponible' }

const puntos = computed(() => consultaPuntos.datos.value ?? [])
const nombrePunto = (id) => {
  const p = puntos.value.find((x) => x.id === id)
  return p ? `${p.codigo} · ${p.nombre}` : '—'
}
const bicis = computed(() => (consultaBicis.datos.value ?? []).filter((b) =>
  (!filtro.value.texto || b.codigo.includes(filtro.value.texto.toUpperCase()) || String(b.numero) === filtro.value.texto.trim())
  && (!filtro.value.condicion || b.condicion === filtro.value.condicion)
  && (!filtro.value.punto || b.punto_actual_id === filtro.value.punto)))
const resumen = computed(() => {
  const r = { total: 0, disponible: 0, prestada: 0, no_disponible: 0 }
  for (const b of consultaBicis.datos.value ?? []) { r.total++; r[b.disponibilidad]++ }
  return r
})

function avisar(tipo, texto) { mensaje.value = { tipo, texto } }

async function crear() {
  avisar('', '')
  const { data, error } = await supabase.rpc('crear_bicicletas', {
    p_desde: Number(alta.value.desde), p_hasta: Number(alta.value.hasta), p_punto_id: alta.value.punto,
  })
  if (error) return avisar('error', traducirError(error).mensaje)
  avisar('exito', `${data} bici(s) creada(s). Las que ya existían no se tocaron.`)
  consultaBicis.recargar()
}

async function abrir(b) {
  elegida.value = { ...b }
  cambio.value = { condicion: b.condicion, motivo: '', punto: '' }
  resolucion.value = {}
  const [n, h] = await Promise.all([
    supabase.from('incidencias').select('id,tipo,gravedad,descripcion,reportada_en,estado,foto_ruta')
      .eq('bicicleta_id', b.id).neq('estado', 'cerrada').order('reportada_en', { ascending: false }),
    supabase.from('v_prestamos_admin').select('id,estado,punto_salida,punto_devolucion,salida_en,devuelto_en,duracion_min,con_novedad')
      .eq('bici_numero', b.numero).order('salida_en', { ascending: false }).limit(10),
  ])
  if (n.error || h.error) avisar('error', traducirError(n.error ?? h.error).mensaje)
  detalle.value = { novedades: n.data ?? [], historial: h.data ?? [] }
}

async function guardarDatos() {
  const b = elegida.value
  const { error } = await supabase.from('bicicletas').update({
    marca: b.marca || null, modelo: b.modelo || null, color: b.color || null, talla: b.talla || null,
    numero_serie: b.numero_serie || null, fecha_ingreso: b.fecha_ingreso || null, nota_operativa: b.nota_operativa || null,
  }).eq('id', b.id)
  if (error) return avisar('error', traducirError(error).mensaje)
  avisar('exito', `Datos de la ${b.codigo} guardados.`)
  consultaBicis.recargar()
}

async function cambiarCondicion() {
  const b = elegida.value
  const { error } = await supabase.rpc('cambiar_condicion_bici', {
    p_numero: b.numero, p_condicion: cambio.value.condicion, p_motivo: cambio.value.motivo,
    p_punto_id: cambio.value.punto || null,
  })
  if (error) return avisar('error', traducirError(error).mensaje)
  avisar('exito', `La ${b.codigo} quedó ${CONDICIONES[cambio.value.condicion].toLowerCase()}.`)
  elegida.value = null
  consultaBicis.recargar()
}

async function cerrarNovedad(n) {
  const texto = (resolucion.value[n.id] ?? '').trim()
  if (texto.length < 5) return avisar('error', 'Escribe cómo se resolvió la novedad.')
  const { error } = await supabase.from('incidencias').update({ estado: 'cerrada', resolucion: texto }).eq('id', n.id)
  if (error) return avisar('error', traducirError(error).mensaje)
  detalle.value.novedades = detalle.value.novedades.filter((x) => x.id !== n.id)
  avisar('exito', 'Novedad cerrada.')
}
</script>

<template>
  <section>
    <div class="admin-cabeza">
      <div>
        <h1>Bicicletas</h1>
        <p>{{ resumen.total }} en total · {{ resumen.disponible }} disponibles · {{ resumen.prestada }} prestadas ·
          {{ resumen.no_disponible }} no disponibles</p>
      </div>
    </div>

    <p v-if="mensaje.texto" class="mensaje" :class="`mensaje--${mensaje.tipo}`" role="status"><span>{{ mensaje.texto }}</span></p>

    <details class="tarjeta-base" :open="resumen.total === 0">
      <summary><strong>Dar de alta bicis</strong> (por número de sticker)</summary>
      <form class="fila-campos alta" @submit.prevent="crear">
        <label class="campo"><span>Desde el n.º</span><input v-model="alta.desde" type="number" min="1" max="9999" /></label>
        <label class="campo"><span>Hasta el n.º</span><input v-model="alta.hasta" type="number" min="1" max="9999" /></label>
        <label class="campo"><span>Quedan en el punto</span>
          <select v-model="alta.punto"><option value="" disabled>Elige…</option>
            <option v-for="p in puntos.filter((x) => x.estado !== 'cerrado')" :key="p.id" :value="p.id">{{ p.codigo }} · {{ p.nombre }}</option>
          </select></label>
        <div class="campo"><span>&nbsp;</span><button class="boton" type="submit" :disabled="!alta.punto">Crear</button></div>
      </form>
    </details>

    <div class="filtros">
      <label class="campo"><span>Buscar n.º o código</span><input v-model="filtro.texto" placeholder="Ej.: 15 o BPV-015" /></label>
      <label class="campo"><span>Condición</span>
        <select v-model="filtro.condicion"><option value="">Todas</option>
          <option v-for="(t, v) in CONDICIONES" :key="v" :value="v">{{ t }}</option></select></label>
      <label class="campo"><span>Punto</span>
        <select v-model="filtro.punto"><option value="">Todos</option>
          <option v-for="p in puntos" :key="p.id" :value="p.id">{{ p.codigo }} · {{ p.nombre }}</option></select></label>
    </div>

    <p v-if="consultaBicis.error.value" class="mensaje mensaje--error"><span>{{ consultaBicis.error.value.mensaje }}</span></p>
    <p v-else-if="consultaBicis.cargando.value">Cargando…</p>
    <div v-else class="tabla-desplazable">
      <table class="tabla-admin">
        <thead><tr><th>Código</th><th>Disponibilidad</th><th>Condición</th><th>Punto</th><th>Último movimiento</th><th></th></tr></thead>
        <tbody>
          <tr v-for="b in bicis" :key="b.id">
            <td><strong>{{ b.codigo }}</strong></td>
            <td>{{ DISPONIBILIDAD[b.disponibilidad] }}</td>
            <td><span class="etiqueta-estado" :class="b.condicion === 'operativa' ? 'etiqueta-estado--exito' : 'etiqueta-estado--aviso'">
              {{ CONDICIONES[b.condicion] }}</span></td>
            <td>{{ b.disponibilidad === 'prestada' ? 'En préstamo' : nombrePunto(b.punto_actual_id) }}</td>
            <td>{{ fechaHora(b.ultimo_movimiento_en) }}</td>
            <td><button class="boton boton--contorno boton--pequeno" type="button" @click="abrir(b)">Gestionar</button></td>
          </tr>
          <tr v-if="!bicis.length"><td colspan="6" class="vacio">No hay bicis con esos filtros.</td></tr>
        </tbody>
      </table>
    </div>

    <div v-if="elegida" class="tarjeta-base gestion">
      <div class="admin-cabeza">
        <h2>{{ elegida.codigo }}</h2>
        <button class="boton boton--contorno boton--pequeno" type="button" @click="elegida = null">Cerrar</button>
      </div>

      <h3>Condición física</h3>
      <form class="fila-campos" @submit.prevent="cambiarCondicion">
        <label class="campo"><span>Nueva condición</span>
          <select v-model="cambio.condicion"><option v-for="(t, v) in CONDICIONES" :key="v" :value="v">{{ t }}</option></select></label>
        <label class="campo"><span>Punto donde queda <small>(opcional)</small></span>
          <select v-model="cambio.punto"><option value="">El actual</option>
            <option v-for="p in puntos.filter((x) => x.estado !== 'cerrado')" :key="p.id" :value="p.id">{{ p.codigo }} · {{ p.nombre }}</option></select></label>
        <label class="campo"><span>Motivo</span><input v-model="cambio.motivo" maxlength="500" /></label>
        <div class="campo"><span>&nbsp;</span>
          <button class="boton" type="submit" :disabled="elegida.disponibilidad === 'prestada' || cambio.motivo.trim().length < 5">Cambiar</button></div>
      </form>
      <p v-if="elegida.disponibilidad === 'prestada'" class="nota">Está prestada: primero hay que registrar su devolución.</p>

      <h3>Novedades abiertas</h3>
      <p v-if="!detalle.novedades.length" class="vacio">Sin novedades abiertas.</p>
      <div v-for="n in detalle.novedades" :key="n.id" class="novedad">
        <p><strong>{{ n.descripcion }}</strong> · {{ n.tipo }} · {{ n.gravedad }} · {{ fechaHora(n.reportada_en) }}</p>
        <div class="fila-campos">
          <label class="campo"><span>Cómo se resolvió</span><input v-model="resolucion[n.id]" maxlength="1000" /></label>
          <div class="campo"><span>&nbsp;</span><button class="boton boton--secundario" type="button" @click="cerrarNovedad(n)">Cerrar novedad</button></div>
        </div>
      </div>

      <h3>Datos de la bici</h3>
      <form @submit.prevent="guardarDatos">
        <div class="fila-campos">
          <label class="campo"><span>Marca</span><input v-model="elegida.marca" /></label>
          <label class="campo"><span>Modelo</span><input v-model="elegida.modelo" /></label>
          <label class="campo"><span>Color</span><input v-model="elegida.color" /></label>
          <label class="campo"><span>Talla</span><input v-model="elegida.talla" /></label>
          <label class="campo"><span>N.º de serie del marco</span><input v-model="elegida.numero_serie" /></label>
          <label class="campo"><span>Fecha de ingreso</span><input v-model="elegida.fecha_ingreso" type="date" /></label>
        </div>
        <label class="campo"><span>Nota operativa</span><input v-model="elegida.nota_operativa" maxlength="500" /></label>
        <button class="boton boton--contorno" type="submit">Guardar datos</button>
      </form>

      <h3>Últimos préstamos</h3>
      <p v-if="!detalle.historial.length" class="vacio">Sin préstamos registrados.</p>
      <table v-else class="tabla-admin">
        <thead><tr><th>Salida</th><th>De → a</th><th>Duración</th><th>Estado</th></tr></thead>
        <tbody><tr v-for="h in detalle.historial" :key="h.id">
          <td>{{ fechaHora(h.salida_en) }}</td><td>{{ h.punto_salida }} → {{ h.punto_devolucion ?? '—' }}</td>
          <td>{{ h.duracion_min != null ? `${h.duracion_min} min` : '—' }}</td>
          <td>{{ h.estado }}<template v-if="h.con_novedad"> · con novedad</template></td>
        </tr></tbody>
      </table>
    </div>
  </section>
</template>

<style scoped>
summary { cursor: pointer; min-height: var(--toque-min); display: flex; align-items: center; gap: var(--esp-2); }
.alta { margin-top: var(--esp-3); }
.gestion { border: 2px solid var(--secundario); }
.gestion h2 { margin: 0; }
.gestion h3 { margin-top: var(--esp-5); font-size: var(--texto-m); }
.nota { color: var(--tinta-2); font-size: var(--texto-s); }
.novedad { background: var(--aviso-fondo); border-radius: var(--radio-m); padding: var(--esp-3); margin-bottom: var(--esp-3); }
.novedad p { margin: 0 0 var(--esp-2); }
.mensaje { margin-bottom: var(--esp-4); }
</style>
