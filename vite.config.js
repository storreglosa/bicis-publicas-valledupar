import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'

// Política de seguridad de contenido (CSP). GitHub Pages no deja poner cabeceras,
// así que va en un <meta> (diseño §4). Solo en el build: el servidor de desarrollo
// necesita scripts y websockets propios que la política bloquearía.
//   Supabase: datos (https) y tiempo real (wss) del proyecto del build.
//   Cloudflare Turnstile: script e iframe de la verificación anti-robots.
//   OpenStreetMap: mosaicos del mapa. blob:/data:: vista previa de la foto y QR.
// frame-ancestors no funciona en <meta>; queda como riesgo residual (runbook §2.2).
export function politicaCsp(urlSupabase) {
  const supabase = urlSupabase ? new URL(urlSupabase) : null
  const conectar = supabase ? ` ${supabase.origin} wss://${supabase.host}` : ''
  return [
    "default-src 'self'",
    "script-src 'self' https://challenges.cloudflare.com",
    'frame-src https://challenges.cloudflare.com',
    `connect-src 'self'${conectar}`,
    "img-src 'self' data: blob: https://tile.openstreetmap.org",
    "style-src 'self' 'unsafe-inline'",
    "font-src 'self'",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
  ].join('; ')
}

function csp(urlSupabase) {
  return {
    name: 'csp-meta',
    apply: 'build',
    transformIndexHtml: () => [{
      tag: 'meta', injectTo: 'head-prepend',
      attrs: { 'http-equiv': 'Content-Security-Policy', content: politicaCsp(urlSupabase) },
    }],
  }
}

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), 'VITE_')
  return {
    // GitHub Pages sirve el sitio bajo /<nombre-del-repo>/
    base: '/bicis-publicas-valledupar/',
    plugins: [vue(), csp(env.VITE_SUPABASE_URL)],
    test: {
      include: ['tests/unit/**/*.test.js'],
    },
  }
})
