import { createRouter, createWebHashHistory } from 'vue-router'
import sitio from '../sitio.config.js'
import { asegurarSesion, sesion } from './lib/sesion.js'

// Modo hash: GitHub Pages no reescribe rutas, así que #/mapa funciona al
// recargar o compartir el enlace sin trucos de 404.html.

const enConstruccion = () => import('./vistas/publico/EnConstruccion.vue')
const personal = { rol: 'personal' }

const rutas = [
  { path: '/', name: 'inicio', component: () => import('./vistas/publico/Inicio.vue') },
  { path: '/mapa', name: 'mapa', component: () => import('./vistas/publico/Mapa.vue'), meta: { titulo: 'Mapa de puntos' } },
  { path: '/reglas', name: 'reglas', component: () => import('./vistas/publico/Reglas.vue'), meta: { titulo: 'Reglas de uso' } },
  { path: '/eventos', name: 'eventos', component: () => import('./vistas/publico/Eventos.vue'), meta: { titulo: 'Eventos' } },
  { path: '/inscribirme', name: 'inscribirme', component: enConstruccion, meta: { titulo: 'Inscribirme' } },
  { path: '/politica-de-datos/:version?', name: 'politica', component: () => import('./vistas/publico/Politica.vue'), meta: { titulo: 'Política de tratamiento de datos' } },
  { path: '/b/:codigo', name: 'bici', component: () => import('./vistas/publico/Bici.vue'), meta: { titulo: 'Bicicleta' } },

  // Personal (operadores y administradores)
  { path: '/ingresar', name: 'ingresar', component: () => import('./vistas/personal/Ingresar.vue'), meta: { titulo: 'Ingreso del personal' } },
  { path: '/cambiar-clave', name: 'cambiar-clave', component: () => import('./vistas/personal/CambiarClave.vue'), meta: { titulo: 'Cambiar clave', ...personal } },
  { path: '/operador', name: 'operador', component: () => import('./vistas/operador/Inicio.vue'), meta: { titulo: 'Turno', ...personal } },
  { path: '/operador/prestar', name: 'prestar', component: () => import('./vistas/operador/Prestar.vue'), meta: { titulo: 'Prestar', ...personal } },
  { path: '/operador/devolver', name: 'devolver', component: () => import('./vistas/operador/Devolver.vue'), meta: { titulo: 'Devolver', ...personal } },
  { path: '/operador/activos', name: 'activos', component: () => import('./vistas/operador/Activos.vue'), meta: { titulo: 'Préstamos activos', ...personal } },
  { path: '/operador/mover', name: 'mover', component: () => import('./vistas/operador/Mover.vue'), meta: { titulo: 'Mover bicis', ...personal } },
  { path: '/operador/averia', name: 'averia', component: () => import('./vistas/operador/Averia.vue'), meta: { titulo: 'Reportar avería', ...personal } },

  { path: '/:pathMatch(.*)*', name: 'no-encontrada', component: enConstruccion, meta: { titulo: 'Página no encontrada' } },
]

// Muestrario de la paleta: solo en desarrollo (punto de control C0).
if (import.meta.env.DEV) {
  rutas.unshift({ path: '/paleta', name: 'paleta', component: () => import('./vistas/publico/Paleta.vue'), meta: { titulo: 'Paleta' } })
}

const router = createRouter({
  history: createWebHashHistory(),
  routes: rutas,
  scrollBehavior: () => ({ top: 0 }),
})

// Rutas del personal: exigen sesión y perfil activo (lo responde la base, no el
// navegador). En el primer ingreso se obliga a cambiar la clave. La seguridad real
// está en la base (RLS y permisos); esto solo evita mostrar pantallas inútiles.
router.beforeEach(async (to) => {
  if (!to.meta.rol) return true
  await asegurarSesion()
  const perfil = sesion.perfil
  if (!perfil) return { name: 'ingresar', query: { ir: to.fullPath } }
  if (perfil.debe_cambiar_clave && to.name !== 'cambiar-clave') return { name: 'cambiar-clave', query: { ir: to.fullPath } }
  if (to.meta.rol === 'administrador' && perfil.rol !== 'administrador') return { name: 'operador' }
  return true
})

router.afterEach((to) => {
  document.title = to.meta.titulo ? `${to.meta.titulo} · ${sitio.nombre}` : sitio.nombre
})

export default router
