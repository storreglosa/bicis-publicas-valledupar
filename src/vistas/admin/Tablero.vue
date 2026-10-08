<script setup>
// Tablero (diseño §6, wireframe 3): indicadores del día, alertas, préstamos por
// hora y bicis por punto. Formas según la skill dataviz: números sueltos → tarjetas
// de indicador; magnitud por hora → columnas de una serie; parte de un total por
// punto → medidores. Las alertas llevan ícono y texto, nunca solo color.
import { computed, onMounted, ref } from 'vue'
import GraficoColumnas from '../../componentes/admin/GraficoColumnas.vue'
import { traducirError } from '../../lib/errores.js'
import { supabase } from '../../lib/supabase.js'
import { fechaHora, hora } from '../../lib/tiempo.js'

const LIMITE_STORAGE = 1024 ** 3        // 1 GB (plan Free)
const LIMITE_BD = 500 * 1024 ** 2       // 500 MB (plan Free)
const UMBRAL_USO = 0.7

const t = ref(null)
const cargando = ref(false)
const error = ref('')

async function cargar() {
  cargando.value = true
  const { data, error: e } = await supabase.rpc('tablero_resumen')
  cargando.value = false
  if (e) error.value = traducirError(e).mensaje
  else { error.value = ''; t.value = data }
}
onMounted(cargar)

const numero = (n) => (n ?? 0).toLocaleString('es-CO')
const mb = (b) => `${(b / 1024 ** 2).toLocaleString('es-CO', { maximumFractionDigits: 0 })} MB`

const indicadores = computed(() => t.value && [
  { etiqueta: 'Bicis disponibles', valor: t.value.bicis.disponible, nota: `de ${numero(t.value.bicis.total)} en total` },
  { etiqueta: 'Prestadas ahora', valor: t.value.prestamos_activos },
  { etiqueta: 'No disponibles', valor: t.value.bicis.no_disponible,
    nota: `${t.value.bicis.averiada} averiadas · ${t.value.bicis.en_reparacion} en reparación` },
  { etiqueta: 'Préstamos hoy', valor: t.value.prestamos_hoy },
])

const alertas = computed(() => {
  if (!t.value) return []
  const a = []
  if (t.value.prestamos_vencidos > 0) a.push({ nivel: 'critico', texto: `${t.value.prestamos_vencidos} préstamo(s) superan la duración máxima`, a: '/admin/prestamos' })
  if (t.value.retencion_fotos_dias === null) a.push({ nivel: 'atencion', texto: 'La retención de fotos no está configurada: las fotos no se borran y el almacenamiento se llena en semanas', a: '/admin/parametros' })
  if (t.value.storage_bytes / LIMITE_STORAGE >= UMBRAL_USO) a.push({ nivel: 'atencion', texto: `Almacenamiento de fotos al ${Math.round(t.value.storage_bytes / LIMITE_STORAGE * 100)} %` })
  if (t.value.bd_bytes / LIMITE_BD >= UMBRAL_USO) a.push({ nivel: 'atencion', texto: `Base de datos al ${Math.round(t.value.bd_bytes / LIMITE_BD * 100)} %` })
  if (!t.value.ultimo_respaldo) a.push({ nivel: 'atencion', texto: 'No hay respaldos registrados de la base de datos' })
  else if (Date.now() - new Date(t.value.ultimo_respaldo).getTime() > 8 * 864e5) a.push({ nivel: 'atencion', texto: `Último respaldo: ${fechaHora(t.value.ultimo_respaldo)}` })
  if (t.value.incidencias_abiertas > 0) a.push({ nivel: 'atencion', texto: `${t.value.incidencias_abiertas} novedad(es) de bicis sin cerrar`, a: '/admin/bicicletas' })
  if (!t.value.ultima_purga) a.push({ nivel: 'info', texto: 'El borrado automático de fotos aún no se ha ejecutado' })
  else if (t.value.ultima_purga.resultado !== 'ok') a.push({ nivel: 'critico', texto: `La última purga de fotos falló (${fechaHora(t.value.ultima_purga.fin)})` })
  if (t.value.preinscritas_sin_validar > 0) a.push({ nivel: 'info', texto: `${t.value.preinscritas_sin_validar} preinscripción(es) sin validar`, a: '/admin/personas' })
  return a
})
const NIVELES = { critico: 'Crítico', atencion: 'Atención', info: 'Información' }

const porHora = computed(() => {
  if (!t.value) return []
  const conteo = Object.fromEntries((t.value.por_hora_hoy ?? []).map((h) => [h.hora, h.prestamos]))
  const horas = Object.keys(conteo).map(Number)
  const desde = Math.min(5, ...horas)
  const hasta = Math.max(21, ...horas)
  return Array.from({ length: hasta - desde + 1 }, (_, i) => ({ etiqueta: String(desde + i), valor: conteo[desde + i] ?? 0 }))
})

const usos = computed(() => t.value && [
  { etiqueta: 'Fotos de evidencia', usado: t.value.storage_bytes, limite: LIMITE_STORAGE, texto: `${mb(t.value.storage_bytes)} de 1 GB` },
  { etiqueta: 'Base de datos', usado: t.value.bd_bytes, limite: LIMITE_BD, texto: `${mb(t.value.bd_bytes)} de 500 MB` },
])
</script>

<template>
  <section>
    <div class="admin-cabeza">
      <div><h1>Tablero</h1><p v-if="t">Actualizado {{ hora(t.ahora_servidor) }} · hoy en hora de Colombia</p></div>
      <button class="boton boton--contorno" type="button" :disabled="cargando" @click="cargar">{{ cargando ? 'Actualizando…' : 'Actualizar' }}</button>
    </div>
    <p v-if="error" class="mensaje mensaje--error"><span>{{ error }}</span></p>

    <template v-if="t">
      <ul class="indicadores" :class="{ 'recargando': cargando }">
        <li v-for="i in indicadores" :key="i.etiqueta" class="indicador">
          <span class="indicador__etiqueta">{{ i.etiqueta }}</span>
          <span class="indicador__valor">{{ numero(i.valor) }}</span>
          <span v-if="i.nota" class="indicador__nota">{{ i.nota }}</span>
        </li>
      </ul>

      <section class="tarjeta-base" aria-labelledby="t-alertas">
        <h2 id="t-alertas">Alertas</h2>
        <p v-if="!alertas.length" class="sin-alertas"><span class="punto punto--ok" aria-hidden="true"></span>Todo en orden.</p>
        <ul v-else class="alertas">
          <li v-for="(a, i) in alertas" :key="i" :class="`alerta alerta--${a.nivel}`">
            <span class="punto" :class="`punto--${a.nivel}`" aria-hidden="true"></span>
            <span class="alerta__nivel">{{ NIVELES[a.nivel] }}</span>
            <span class="alerta__texto">{{ a.texto }}</span>
            <RouterLink v-if="a.a" :to="a.a" class="alerta__ir">Revisar</RouterLink>
          </li>
        </ul>
      </section>

      <div class="rejilla">
        <section class="tarjeta-base">
          <GraficoColumnas titulo="Préstamos por hora, hoy" unidad="préstamos" :datos="porHora"
            :etiqueta-eje="(d) => `${d.etiqueta} h`" :cada-etiqueta="3" />
        </section>

        <section class="tarjeta-base" aria-labelledby="t-puntos">
          <h2 id="t-puntos" class="subtitulo">Bicis disponibles por punto</h2>
          <ul class="medidores">
            <li v-for="p in t.por_punto" :key="p.codigo" class="medidor">
              <div class="medidor__fila">
                <span>{{ p.codigo }} · {{ p.nombre }}</span>
                <span class="medidor__cifra">{{ p.disponibles }} de {{ p.total }}</span>
              </div>
              <div class="medidor__pista" role="meter" :aria-valuenow="p.disponibles" aria-valuemin="0" :aria-valuemax="p.total"
                :aria-label="`${p.codigo}: ${p.disponibles} de ${p.total} disponibles`">
                <div class="medidor__relleno" :style="{ width: `${p.total ? (p.disponibles / p.total) * 100 : 0}%` }"></div>
              </div>
            </li>
          </ul>
        </section>
      </div>

      <section class="tarjeta-base" aria-labelledby="t-recursos">
        <h2 id="t-recursos" class="subtitulo">Uso del plan gratuito</h2>
        <ul class="medidores">
          <li v-for="u in usos" :key="u.etiqueta" class="medidor">
            <div class="medidor__fila"><span>{{ u.etiqueta }}</span><span class="medidor__cifra">{{ u.texto }}</span></div>
            <div class="medidor__pista" role="meter" :aria-valuenow="u.usado" aria-valuemin="0" :aria-valuemax="u.limite" :aria-label="`${u.etiqueta}: ${u.texto}`">
              <div class="medidor__relleno" :class="{ 'medidor__relleno--alto': u.usado / u.limite >= UMBRAL_USO }"
                :style="{ width: `${Math.max(1, Math.min(100, (u.usado / u.limite) * 100))}%` }"></div>
            </div>
          </li>
        </ul>
      </section>
    </template>
    <p v-else-if="cargando">Cargando…</p>
  </section>
</template>

<style scoped>
h2 { margin-top: 0; font-size: var(--texto-m); }
.subtitulo { font-size: var(--texto-m); }
.indicadores { list-style: none; margin: 0 0 var(--esp-4); padding: 0; display: grid; gap: var(--esp-3); grid-template-columns: repeat(auto-fit, minmax(11rem, 1fr)); transition: opacity 0.2s; }
.recargando { opacity: 0.6; }
.indicador { background: var(--superficie); border: 1px solid var(--linea); border-radius: var(--radio-l); padding: var(--esp-4); display: grid; gap: var(--esp-1); }
.indicador__etiqueta { color: var(--tinta-2); font-size: var(--texto-s); }
.indicador__valor { font-size: var(--texto-xxl); font-weight: 650; line-height: 1.1; color: var(--tinta-1); }
.indicador__nota { color: var(--tinta-2); font-size: var(--texto-xs); }
.alertas { list-style: none; margin: 0; padding: 0; display: grid; gap: var(--esp-2); }
.alerta { display: grid; grid-template-columns: auto auto 1fr auto; gap: var(--esp-2); align-items: baseline; padding: var(--esp-2) 0; border-top: 1px solid var(--linea); }
.alerta:first-child { border-top: 0; }
.alerta__nivel { font-weight: 650; font-size: var(--texto-xs); text-transform: uppercase; letter-spacing: 0.04em; color: var(--tinta-1); }
.alerta__texto { color: var(--tinta-1); }
.alerta__ir { font-size: var(--texto-s); }
.punto { display: inline-block; width: 0.75rem; height: 0.75rem; border-radius: 50%; }
.punto--critico { background: var(--error); }
.punto--atencion { background: var(--aviso); }
.punto--info { background: var(--tinta-2); }
.punto--ok { background: var(--exito); margin-right: var(--esp-2); }
.sin-alertas { margin: 0; color: var(--tinta-1); }
.rejilla { display: grid; gap: var(--esp-4); grid-template-columns: repeat(auto-fit, minmax(20rem, 1fr)); }
.rejilla .tarjeta-base { margin-bottom: 0; }
.rejilla { margin-bottom: var(--esp-4); }
.medidores { list-style: none; margin: 0; padding: 0; display: grid; gap: var(--esp-3); }
.medidor__fila { display: flex; justify-content: space-between; gap: var(--esp-2); font-size: var(--texto-s); margin-bottom: var(--esp-1); color: var(--tinta-1); }
.medidor__cifra { font-weight: 650; font-variant-numeric: tabular-nums; }
.medidor__pista { height: 10px; background: var(--serie-1-pista); border-radius: 4px; overflow: hidden; }
.medidor__relleno { height: 100%; background: var(--serie-1); border-radius: 0 4px 4px 0; }
.medidor__relleno--alto { background: var(--aviso); }
@media (max-width: 560px) { .alerta { grid-template-columns: auto 1fr; } .alerta__texto { grid-column: 1 / -1; } }
</style>
