import { createRouter, createWebHashHistory } from 'vue-router'
import sitio from '../sitio.config.js'

// Modo hash: GitHub Pages no reescribe rutas, así que #/mapa funciona al
// recargar o compartir el enlace sin trucos de 404.html.

const enConstruccion = () => import('./vistas/publico/EnConstruccion.vue')

const rutas = [
  { path: '/', name: 'inicio', component: () => import('./vistas/publico/Inicio.vue') },
  { path: '/mapa', name: 'mapa', component: enConstruccion, meta: { titulo: 'Mapa de puntos' } },
  { path: '/reglas', name: 'reglas', component: enConstruccion, meta: { titulo: 'Reglas de uso' } },
  { path: '/eventos', name: 'eventos', component: enConstruccion, meta: { titulo: 'Eventos' } },
  { path: '/inscribirme', name: 'inscribirme', component: enConstruccion, meta: { titulo: 'Inscribirme' } },
  { path: '/politica-de-datos', name: 'politica', component: enConstruccion, meta: { titulo: 'Política de tratamiento de datos' } },
  { path: '/b/:codigo', name: 'bici', component: enConstruccion, meta: { titulo: 'Bicicleta' } },
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
