<script setup>
import sitio from '../../../sitio.config.js'

const pasos = [
  { n: 1, titulo: 'Inscríbete', texto: 'Llena el formulario en línea una sola vez. Si eres menor de edad, te inscribe tu representante legal (madre, padre, tutor o curador).' },
  { n: 2, titulo: 'Ve a un punto con tu documento', texto: 'El operador verifica tu documento (solo lo mira; no se lo queda) y te entrega una bicicleta.' },
  { n: 3, titulo: 'Pedalea y devuélvela', texto: 'Devuélvela en un punto habilitado. El operador revisa que llegue en buen estado.' },
]
</script>

<template>
  <section class="portada">
    <div class="contenedor">
      <p class="portada__antetitulo">{{ sitio.alcaldia }} · Tránsito</p>
      <h1>{{ sitio.nombre }}</h1>
      <p class="portada__lema">Bicicletas para moverte por Valledupar y para los eventos de la ciudad.</p>
      <div class="portada__acciones">
        <RouterLink to="/mapa" class="boton">Ver puntos y bicis disponibles</RouterLink>
        <RouterLink to="/inscribirme" class="boton boton--contorno">Inscribirme</RouterLink>
      </div>
    </div>
  </section>

  <section class="contenedor pasos" aria-labelledby="como-funciona">
    <h2 id="como-funciona">Cómo funciona</h2>
    <ol class="pasos__lista">
      <li v-for="p in pasos" :key="p.n" class="paso">
        <span class="paso__numero" aria-hidden="true">{{ p.n }}</span>
        <h3>{{ p.titulo }}</h3>
        <p>{{ p.texto }}</p>
      </li>
    </ol>
  </section>
</template>

<style scoped>
.portada {
  background: var(--banda);
  padding-block: var(--esp-7);
}
.portada__antetitulo {
  color: var(--secundario);
  font-weight: 600;
  font-size: var(--texto-s);
  text-transform: uppercase;
  letter-spacing: 0.06em;
  margin-bottom: var(--esp-2);
}
.portada h1 { font-size: clamp(var(--texto-xl), 6vw, var(--texto-xxl)); max-width: 20ch; }
.portada__lema { font-size: var(--texto-l); color: var(--tinta-2); max-width: 36ch; }
.portada__acciones { display: flex; flex-wrap: wrap; gap: var(--esp-3); margin-top: var(--esp-5); }

.pasos { padding-block: var(--esp-7) 0; }
.pasos__lista {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: var(--esp-4);
  grid-template-columns: repeat(auto-fit, minmax(16rem, 1fr));
}
.paso {
  background: var(--superficie);
  border: 1px solid var(--linea);
  border-radius: var(--radio-l);
  padding: var(--esp-5);
}
.paso__numero {
  display: inline-grid;
  place-items: center;
  width: 2.25rem;
  height: 2.25rem;
  border-radius: 50%;
  background: var(--primario);
  color: var(--sobre-primario);
  font-weight: 650;
  margin-bottom: var(--esp-3);
}
.paso p { color: var(--tinta-2); margin: 0; }
</style>
