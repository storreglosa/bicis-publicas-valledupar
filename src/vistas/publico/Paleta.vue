<script setup>
// Muestrario de la paleta para el punto de control C0. Solo existe en
// desarrollo (ver router.js). Lee los colores de tokens.css en vivo.
import { onMounted, ref } from 'vue'

const grupos = [
  { titulo: 'Fondos', tokens: ['--fondo', '--banda', '--superficie'] },
  { titulo: 'Texto', tokens: ['--tinta-1', '--tinta-2'] },
  { titulo: 'Acción', tokens: ['--primario', '--primario-hover', '--secundario', '--secundario-hover'] },
  { titulo: 'Estado del punto', tokens: ['--estado-disponible', '--estado-pocas', '--estado-sin', '--estado-sin-dato'] },
  { titulo: 'Bordes', tokens: ['--linea', '--linea-fuerte'] },
]

const valores = ref({})

function luminancia(hex) {
  const c = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4))
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
}
function contraste(a, b) {
  const [x, y] = [luminancia(a), luminancia(b)].sort((m, n) => n - m)
  return ((x + 0.05) / (y + 0.05)).toFixed(1)
}

onMounted(() => {
  const css = getComputedStyle(document.documentElement)
  const todos = grupos.flatMap((g) => g.tokens).concat(['--sobre-primario'])
  valores.value = Object.fromEntries(todos.map((t) => [t, css.getPropertyValue(t).trim()]))
})

const marcadores = [
  { n: 12, estado: 'disponible', etiqueta: 'Disponible' },
  { n: 2, estado: 'pocas', etiqueta: 'Pocas' },
  { n: 0, estado: 'sin', etiqueta: 'Sin bicis' },
  { n: '–', estado: 'sin-dato', etiqueta: 'Sin dato' },
]
</script>

<template>
  <section class="contenedor muestrario">
    <h1>Paleta — punto de control C0</h1>
    <p>Colores de <code>src/estilos/tokens.css</code>. El contraste se mide contra el fondo arena; la
      prueba <code>tests/test_contraste.py</code> los verifica contra todos los fondos.</p>

    <div v-for="g in grupos" :key="g.titulo" class="grupo">
      <h2>{{ g.titulo }}</h2>
      <ul class="muestras">
        <li v-for="t in g.tokens" :key="t" class="muestra">
          <span class="muestra__color" :style="{ background: `var(${t})` }"></span>
          <code>{{ t }}</code>
          <span>{{ valores[t] }}</span>
          <span v-if="valores[t] && valores['--fondo']" class="muestra__ratio">
            {{ contraste(valores[t], valores['--fondo']) }}:1 sobre arena
          </span>
        </li>
      </ul>
    </div>

    <h2>Botones</h2>
    <div class="fila">
      <button class="boton" type="button">Prestar</button>
      <button class="boton boton--secundario" type="button">Devolver</button>
      <button class="boton boton--contorno" type="button">Inscribirme</button>
      <button class="boton" type="button" disabled>Deshabilitado</button>
    </div>

    <h2>Marcadores del mapa</h2>
    <p>El número y la palabra van siempre impresos: el color nunca es la única señal.</p>
    <div class="fila">
      <div v-for="m in marcadores" :key="m.estado" class="marcador-demo">
        <span class="marcador" :style="{ background: `var(--estado-${m.estado})` }">{{ m.n }}</span>
        <span :style="{ color: `var(--estado-${m.estado})` }" class="marcador-demo__txt">{{ m.etiqueta }}</span>
      </div>
    </div>

    <h2>Mensajes</h2>
    <div class="pila">
      <p class="mensaje mensaje--exito"><span>Préstamo registrado. Entrega la BPV-015.</span></p>
      <p class="mensaje mensaje--aviso"><span>Nota abierta en esta bici: timbre suelto.</span></p>
      <p class="mensaje mensaje--error"><span>Esta bicicleta ya está prestada.</span></p>
    </div>
  </section>
</template>

<style scoped>
.muestrario { padding-block: var(--esp-6); }
.grupo { margin-bottom: var(--esp-5); }
.muestras { list-style: none; padding: 0; margin: 0; display: grid; gap: var(--esp-3);
  grid-template-columns: repeat(auto-fill, minmax(13rem, 1fr)); }
.muestra { display: grid; gap: var(--esp-1); font-size: var(--texto-s); }
.muestra__color { height: 4rem; border-radius: var(--radio-m); border: 1px solid var(--linea); }
.muestra__ratio { color: var(--tinta-2); }
.fila { display: flex; flex-wrap: wrap; gap: var(--esp-3); margin-bottom: var(--esp-5); align-items: center; }
.pila { display: grid; gap: var(--esp-3); }
.marcador-demo { display: flex; align-items: center; gap: var(--esp-2); }
.marcador { display: inline-grid; place-items: center; min-width: 2.5rem; height: 2.5rem; padding: 0 var(--esp-2);
  border-radius: 999px; color: var(--sobre-estado); font-weight: 650; border: 2px solid var(--superficie);
  box-shadow: var(--sombra); }
.marcador-demo__txt { font-weight: 600; }
</style>
