import { createRouter, createWebHashHistory } from 'vue-router'
import sitio from '../sitio.config.js'

// Modo hash: GitHub Pages no reescribe rutas, así que #/mapa funciona al
// recargar o compartir el enlace sin trucos de 404.html.

const enConstruccion = () => import('./vistas/publico/EnConstruccion.vue')

const rutas = [
  { path: '/', name: 'inicio', component: () => import('./vistas/publico/Inicio.vue') },
  { path: '/mapa', name: 'mapa', component: () => import('./vistas/publico/Mapa.vue'), meta: { titulo: 'Mapa de puntos' } },
  { path: '/reglas', name: 'reglas', component: () => import('./vistas/publico/Reglas.vue'), meta: { titulo: 'Reglas de uso' } },
  { path: '/eventos', name: 'eventos', component: () => import('./vistas/publico/Eventos.vue'), meta: { titulo: 'Eventos' } },
  { path: '/inscribirme', name: 'inscribirme', component: enConstruccion, meta: { titulo: 'Inscribirme' } },
  { path: '/politica-de-datos/:version?', name: 'politica', component: () => import('./vistas/publico/Politica.vue'), meta: { titulo: 'Política de tratamiento de datos' } },
  { path: '/b/:codigo', name: 'bici', component: () => import('./vistas/publico/Bici.vue'), meta: { titulo: 'Bicicleta' } },
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

router.afterEach((to) => {
  document.title = to.meta.titulo ? `${to.meta.titulo} · ${sitio.nombre}` : sitio.nombre
})

export default router
