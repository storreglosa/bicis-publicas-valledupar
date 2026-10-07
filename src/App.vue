<script setup>
import sitio from '../sitio.config.js'

const logo = `${import.meta.env.BASE_URL}marca/logo_sttv.png`
// Versión de demostración conectada al proyecto de desarrollo (datos ficticios).
const esDemo = import.meta.env.VITE_DEMO === '1'
const anio = new Date().getFullYear()
</script>

<template>
  <a class="saltar" href="#contenido" @click.prevent="$refs.contenido.focus()">Saltar al contenido</a>

  <p v-if="esDemo" class="demo" role="note">
    <strong>DEMO — datos ficticios.</strong> Versión de prueba del sistema: no ingreses datos personales reales.
  </p>

  <header class="cabecera">
    <div class="contenedor cabecera__fila">
      <RouterLink to="/" class="marca">
        <img :src="logo" :alt="sitio.alcaldia + ' — Tránsito'" width="104" height="51" />
        <span class="marca__nombre">{{ sitio.nombreCorto }}</span>
      </RouterLink>
      <nav aria-label="Principal">
        <ul class="menu">
          <li><RouterLink to="/mapa">Mapa</RouterLink></li>
          <li><RouterLink to="/reglas">Reglas</RouterLink></li>
          <li><RouterLink to="/eventos">Eventos</RouterLink></li>
          <li><RouterLink to="/inscribirme" class="menu__destacado">Inscribirme</RouterLink></li>
        </ul>
      </nav>
    </div>
  </header>

  <main id="contenido" ref="contenido" tabindex="-1">
    <RouterView />
  </main>

  <footer class="pie">
    <div class="contenedor pie__fila">
      <div>
        <p class="pie__titulo">{{ sitio.nombre }}</p>
        <p>{{ sitio.entidad }} · {{ sitio.alcaldia }}</p>
      </div>
      <ul class="pie__enlaces" aria-label="Información legal">
        <li><RouterLink to="/politica-de-datos">Política de tratamiento de datos</RouterLink></li>
        <li><RouterLink to="/reglas">Términos y condiciones de uso</RouterLink></li>
        <li>
          <a v-if="sitio.contacto.pqrsdUrl" :href="sitio.contacto.pqrsdUrl" rel="noopener">PQRSD</a>
          <span v-else>PQRSD: canal por definir</span>
        </li>
        <li>© {{ anio }} {{ sitio.alcaldia }}. Derechos de autor por definir.</li>
      </ul>
    </div>
  </footer>
</template>

<style scoped>
.demo {
  margin: 0;
  padding: var(--esp-2) var(--esp-4);
  background: var(--aviso-fondo);
  color: var(--tinta-1);
  border-bottom: 2px solid var(--aviso);
  font-size: var(--texto-s);
  text-align: center;
}
.cabecera {
  background: var(--superficie);
  border-bottom: 1px solid var(--linea);
}
.cabecera__fila {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--esp-3);
  padding-block: var(--esp-2);
}
.marca {
  display: flex;
  align-items: center;
  gap: var(--esp-3);
  color: var(--tinta-1);
  text-decoration: none;
}
.marca__nombre {
  font-weight: 650;
  font-size: var(--texto-l);
  border-left: 2px solid var(--linea);
  padding-left: var(--esp-3);
}
.menu {
  display: flex;
  flex-wrap: wrap;
  gap: var(--esp-1) var(--esp-4);
  list-style: none;
  margin: 0;
  padding: 0;
}
.menu a {
  display: inline-flex;
  align-items: center;
  min-height: var(--toque-min);
  color: var(--tinta-1);
  font-weight: 600;
  text-decoration: none;
}
.menu a.router-link-active { color: var(--primario); text-decoration: underline; }
.menu__destacado { color: var(--primario) !important; }

main { min-height: 60vh; outline: none; }

.pie {
  margin-top: var(--esp-7);
  background: var(--banda);
  border-top: 1px solid var(--linea);
  font-size: var(--texto-s);
  color: var(--tinta-2);
}
.pie__fila {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: var(--esp-5);
  padding-block: var(--esp-6);
}
.pie__titulo { font-weight: 650; color: var(--tinta-1); margin-bottom: var(--esp-1); }
.pie__enlaces { list-style: none; margin: 0; padding: 0; display: grid; gap: var(--esp-2); }

@media (max-width: 480px) {
  .marca img { width: 84px; height: auto; }
  .marca__nombre { font-size: var(--texto-m); }
}
</style>
