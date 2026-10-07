import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  // GitHub Pages sirve el sitio bajo /<nombre-del-repo>/
  base: '/bicis-publicas-valledupar/',
  plugins: [vue()],
  test: {
    include: ['tests/unit/**/*.test.js'],
  },
})
