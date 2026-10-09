<script setup>
import { useRouter } from 'vue-router'
import sitio from '../sitio.config.js'
import { useInactividad } from './composables/useInactividad.js'
import { salir, sesion } from './lib/sesion.js'

const router = useRouter()
useInactividad()

async function cerrarTurno() {
  await salir()
  router.push({ name: 'ingresar', query: { motivo: 'salida' } })
}

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
          <li v-if="!sesion.perfil"><RouterLink to="/inscribirme" class="menu__destacado">Inscribirme</RouterLink></li>
          <li v-if="!sesion.perfil"><RouterLink to="/ingresar" class="menu__boton">Módulo operación</RouterLink></li>
          <template v-if="sesion.perfil">
            <li><RouterLink to="/operador" class="menu__destacado">Turno</RouterLink></li>
            <li v-if="sesion.perfil.rol === 'administrador'"><RouterLink to="/admin" class="menu__destacado">Administración</RouterLink></li>
            <li><button type="button" class="menu__boton" @click="cerrarTurno">Cerrar turno</button></li>
          </template>
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
        <address class="pie__contacto">
          {{ sitio.contacto.direccion }}<br />
          <a :href="`mailto:${sitio.contacto.correo}`">{{ sitio.contacto.correo }}</a><br />
          {{ sitio.contacto.redes.usuario }} en
          <a :href="sitio.contacto.redes.instagram" rel="noopener">Instagram</a> y
          <a :href="sitio.contacto.redes.x" rel="noopener">X</a>
        </address>
      </div>
      <ul class="pie__enlaces" aria-label="Información legal">
        <li><RouterLink to="/politica-de-datos">Política de tratamiento de datos</RouterLink></li>
        <li><RouterLink to="/reglas">Términos y condiciones de uso</RouterLink></li>
        <li><a :href="`mailto:${sitio.contacto.correo}?subject=${encodeURIComponent('PQRSD - Bicis Públicas')}`">PQRSD: peticiones, quejas, reclamos, sugerencias y denuncias</a></li>
        <li>© {{ anio }} {{ sitio.alcaldia }} · {{ sitio.entidad }}</li>
        <li v-if="!sesion.perfil"><RouterLink to="/ingresar">Módulo operación</RouterLink></li>
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
/* Acciones del personal (ingresar / cerrar turno): botón con borde, separado de los enlaces ciudadanos. */
.menu .menu__boton {
  display: inline-flex; align-items: center; min-height: var(--toque-min); padding: 0 var(--esp-3);
  border: 2px solid var(--linea-fuerte); border-radius: var(--radio-m);
  background: var(--superficie); color: var(--tinta-1); font: inherit; font-weight: 600; cursor: pointer; text-decoration: none;
}
.menu .menu__boton:hover { border-color: var(--primario); }
.menu a.menu__boton.router-link-active { color: var(--tinta-1); text-decoration: none; border-color: var(--primario); }

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
.pie__contacto { font-style: normal; margin-top: var(--esp-3); line-height: 1.6; }
/* El correo institucional es largo y sin espacios: en 320 px debe poder partirse. */
.pie__contacto a, .pie__enlaces a { overflow-wrap: anywhere; }

@media (max-width: 480px) {
  .marca img { width: 84px; height: auto; }
  .marca__nombre { font-size: var(--texto-m); }
}
</style>
