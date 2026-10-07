<script setup>
import { computed } from 'vue'
import { useConsulta } from '../../composables/useConsulta.js'
import { usePuntoTrabajo } from '../../composables/usePuntoTrabajo.js'
import { sesion } from '../../lib/sesion.js'

const { punto, elegir, olvidar } = usePuntoTrabajo()
const { datos, cargando, error } = useConsulta((sb) =>
  sb.from('puntos').select('id,codigo,nombre,tipo,estado').eq('estado', 'activo').order('codigo'))

const puntos = computed(() => datos.value ?? [])
const tipos = { fijo: 'Punto fijo', evento: 'Punto de evento', taller: 'Taller' }

// Si el punto recordado dejó de estar activo, se pide elegir otro.
const puntoVigente = computed(() =>
  punto.value && (cargando.value || puntos.value.some((p) => p.id === punto.value.id)) ? punto.value : null)

const acciones = computed(() => [
  { a: '/operador/prestar', titulo: 'Prestar', texto: 'Registrar la salida de una bici', principal: true, oculto: punto.value?.tipo === 'taller' },
  { a: '/operador/devolver', titulo: 'Devolver', texto: 'Recibir una bici y revisar su estado', principal: true },
  { a: '/operador/activos', titulo: 'Préstamos activos', texto: 'Bicis que salieron de este punto' },
  { a: '/operador/mover', titulo: 'Mover bicis', texto: 'Reubicar bicis entre puntos o al taller' },
  { a: '/operador/averia', titulo: 'Reportar avería', texto: 'Sacar de servicio una bici dañada' },
].filter((x) => !x.oculto))
</script>

<template>
  <section class="contenedor pagina">
    <p class="saludo">Hola, {{ sesion.perfil?.nombre }}</p>
    <h1>Turno del operador</h1>

    <p v-if="error" class="mensaje mensaje--error"><span>{{ error.mensaje }}</span></p>

    <div v-if="!puntoVigente" class="tarjeta-base">
      <h2>¿En qué punto trabajas hoy?</h2>
      <p v-if="cargando">Cargando puntos…</p>
      <ul v-else class="lista-puntos">
        <li v-for="p in puntos" :key="p.id">
          <button type="button" class="opcion-punto" @click="elegir(p)">
            <strong>{{ p.codigo }} · {{ p.nombre }}</strong>
            <span>{{ tipos[p.tipo] }}</span>
          </button>
        </li>
        <li v-if="!puntos.length" class="vacio">No hay puntos activos. Pide al administrador que active uno.</li>
      </ul>
    </div>

    <template v-else>
      <div class="punto-actual">
        <div>
          <span class="etiqueta-estado">{{ tipos[puntoVigente.tipo] }}</span>
          <p class="punto-actual__nombre">{{ puntoVigente.codigo }} · {{ puntoVigente.nombre }}</p>
        </div>
        <button type="button" class="boton boton--contorno" @click="olvidar">Cambiar punto</button>
      </div>

      <nav aria-label="Acciones del turno">
        <ul class="acciones-turno">
          <li v-for="x in acciones" :key="x.a">
            <RouterLink :to="x.a" class="accion" :class="{ 'accion--principal': x.principal }">
              <strong>{{ x.titulo }}</strong>
              <span>{{ x.texto }}</span>
            </RouterLink>
          </li>
        </ul>
      </nav>
    </template>
  </section>
</template>

<style scoped>
.pagina { padding-block: var(--esp-5) var(--esp-6); }
.saludo { color: var(--tinta-2); margin-bottom: var(--esp-1); }
.lista-puntos, .acciones-turno { list-style: none; margin: 0; padding: 0; display: grid; gap: var(--esp-3); }
.opcion-punto {
  width: 100%; min-height: var(--toque-min); display: grid; gap: var(--esp-1); text-align: left;
  padding: var(--esp-3) var(--esp-4); border: 2px solid var(--linea-fuerte); border-radius: var(--radio-m);
  background: var(--superficie); color: var(--tinta-1); font: inherit; cursor: pointer;
}
.opcion-punto span { color: var(--tinta-2); font-size: var(--texto-s); }
.opcion-punto:hover { border-color: var(--primario); }
.vacio { color: var(--tinta-2); }
.punto-actual {
  display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: var(--esp-3);
  background: var(--banda); border-radius: var(--radio-l); padding: var(--esp-4); margin-bottom: var(--esp-5);
}
.punto-actual__nombre { font-weight: 650; font-size: var(--texto-l); margin: var(--esp-1) 0 0; }
.acciones-turno { grid-template-columns: repeat(auto-fit, minmax(15rem, 1fr)); }
.accion {
  display: grid; gap: var(--esp-1); min-height: 88px; padding: var(--esp-4);
  border: 2px solid var(--linea-fuerte); border-radius: var(--radio-l);
  background: var(--superficie); color: var(--tinta-1); text-decoration: none;
}
.accion strong { font-size: var(--texto-l); }
.accion span { color: var(--tinta-2); }
.accion--principal { background: var(--primario); border-color: var(--primario); }
.accion--principal strong, .accion--principal span { color: var(--sobre-primario); }
.accion:hover { border-color: var(--primario-hover); }
.accion--principal:hover { background: var(--primario-hover); }
</style>
