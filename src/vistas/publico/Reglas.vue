<script setup>
// Reglas de uso: solo se muestran los parámetros con valor (NULL = no aplica,
// decisión D-06). Las normas del ciclista citan su fuente; DEBEN pasar por el
// agente verificador-normativo antes de la publicación en producción (plan 1g).
import { computed } from 'vue'
import sitio from '../../../sitio.config.js'
import { useConsulta } from '../../composables/useConsulta.js'
import { markdownSeguro } from '../../lib/markdown.js'

const { datos, cargando, error } = useConsulta((sb) =>
  sb.from('parametros').select('clave,categoria,descripcion,tipo,unidad,valor,orden').eq('publico', true).order('orden'))

function formatear(p) {
  if (p.tipo === 'booleano') {
    if (p.clave === 'evidencia.foto_persona_obligatoria') {
      return p.valor ? 'En cada préstamo el operador toma una foto de la persona con la bicicleta.'
        : 'En cada préstamo el operador toma una foto de la bicicleta con su sticker.'
    }
    return p.valor ? 'Sí' : 'No'
  }
  if (p.tipo === 'hora') return p.valor
  if (p.tipo === 'entero') return `${p.valor} ${p.unidad ?? ''}`.trim()
  return p.valor
}

const grupos = computed(() => {
  const conValor = (datos.value ?? []).filter((p) => p.valor !== null && p.tipo !== 'texto')
  const porCategoria = new Map()
  for (const p of conValor) {
    if (!porCategoria.has(p.categoria)) porCategoria.set(p.categoria, [])
    porCategoria.get(p.categoria).push(p)
  }
  return [...porCategoria.entries()]
})

const reglamento = computed(() => (datos.value ?? []).find((p) => p.clave === 'sanciones.texto_reglamento' && p.valor))
</script>

<template>
  <section class="contenedor pagina texto-largo">
    <h1>Reglas de uso</h1>

    <p v-if="cargando">Cargando reglas…</p>
    <p v-else-if="error" class="mensaje mensaje--error"><span>{{ error.mensaje }}</span></p>
    <template v-else>
      <p v-if="!grupos.length" class="mensaje mensaje--aviso">
        <span>La Secretaría está definiendo las reglas de uso (duración del préstamo, horarios y sanciones). Mientras
          tanto, el operador del punto te indica las condiciones.</span>
      </p>
      <div v-for="[categoria, parametros] in grupos" :key="categoria" class="grupo">
        <h2>{{ categoria }}</h2>
        <dl>
          <template v-for="p in parametros" :key="p.clave">
            <dt>{{ p.descripcion }}</dt>
            <dd>{{ formatear(p) }}</dd>
          </template>
        </dl>
      </div>
      <div v-if="reglamento" class="grupo">
        <h2>Reglamento</h2>
        <div v-html="markdownSeguro(reglamento.valor)"></div>
      </div>
    </template>

    <h2>Al prestar y devolver</h2>
    <ul>
      <li>Presenta tu documento original. El operador solo lo mira; nunca se lo queda.</li>
      <li>Revisa la bicicleta con el operador antes de salir: frenos, llantas, cadena y timbre.</li>
      <li>La bicicleta es personal: no la prestes a otra persona.</li>
      <li>Devuélvela en un punto habilitado y espera a que el operador registre la devolución.</li>
    </ul>

    <h2>Normas para circular en bicicleta</h2>
    <p class="fuente">Código Nacional de Tránsito (Ley 769 de 2002, artículos 94 y 95), Ley 1811 de 2016 y Ley 2486 de 2025.</p>
    <ul>
      <li>Circula por la derecha, a no más de un metro de la acera u orilla, y nunca por los andenes.</li>
      <li>Respeta las señales de tránsito y los semáforos como cualquier vehículo.</li>
      <li>En grupo, circula uno detrás de otro.</li>
      <li>No te sujetes de otros vehículos ni lleves a otra persona si la bicicleta no está hecha para eso.</li>
      <li>Usa las señales con el brazo para indicar giros.</li>
      <li>De noche (entre las 6:00 p. m. y las 6:00 a. m.) usa prenda reflectiva.</li>
      <li>Los conductores deben adelantarte a una distancia mínima de 1,50 metros.</li>
    </ul>

    <h2>Si te roban la bicicleta o tienes un accidente</h2>
    <ol>
      <li>Ponte a salvo y, si hay heridos, llama a la línea de emergencias 123.</li>
      <li>Denuncia el hurto ante la Policía o la Fiscalía.</li>
      <li>
        Avisa a la Secretaría de Tránsito:
        <a v-if="sitio.contacto.pqrsdUrl" :href="sitio.contacto.pqrsdUrl" rel="noopener">canal de PQRSD</a>
        <span v-else>canal por definir</span>.
      </li>
    </ol>
  </section>
</template>

<style scoped>
.pagina { padding-block: var(--esp-6); }
.texto-largo { max-width: 46rem; }
.texto-largo h2 { margin-top: var(--esp-6); }
.grupo dl { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: var(--esp-2) var(--esp-4); margin: 0; }
.grupo dt { color: var(--tinta-2); }
.grupo dd { margin: 0; font-weight: 650; text-align: right; }
.fuente { color: var(--tinta-2); font-size: var(--texto-s); }
li { margin-bottom: var(--esp-2); }
@media (max-width: 480px) {
  .grupo dl { grid-template-columns: 1fr; }
  .grupo dd { text-align: left; margin-bottom: var(--esp-2); }
}
</style>
