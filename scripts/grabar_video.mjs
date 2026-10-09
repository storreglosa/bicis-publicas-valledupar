// Graba el modo «Presentar» completo como video MP4 (1920×1080, H.264) para reenviar,
// sobre el build de la demo servido en local y con los clips ya grabados:
//   npx vite build --mode development --outDir dist-demo
//   npx vite preview --mode development --outDir dist-demo --port 4174
//   node scripts/grabar_video.mjs [salida.mp4]      (por defecto capturas/presentacion.mp4)
// Captura los cuadros con el screencast de Chromium (JPEG con su marca de tiempo) y los
// arma con ffmpeg a 30 cuadros por segundo; así el video conserva los tiempos del guion.
// Oculta los botones (en el video no se usan). Los cuadros van a capturas/ porque /tmp
// está en memoria en WSL. Requiere ffmpeg con libx264 (FFMPEG=ruta, o el entorno conda «video»).
import { chromium } from '@playwright/test'
import { spawnSync } from 'node:child_process'
import { existsSync, mkdirSync, rmSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { join, resolve } from 'node:path'
import { DURACION_TOTAL } from '../src/presentacion/guion.js'

const BASE = process.env.BASE_URL ?? 'http://localhost:4174/bicis-publicas-valledupar/'
const RAIZ = new URL('..', import.meta.url).pathname
const SALIDA = resolve(process.argv[2] ?? join(RAIZ, 'capturas/presentacion.mp4'))
const CUADROS = join(RAIZ, 'capturas/video-cuadros')
const FFMPEG = process.env.FFMPEG ?? [`${homedir()}/miniconda3/envs/video/bin/ffmpeg`, 'ffmpeg'].find((r) => r === 'ffmpeg' || existsSync(r))
const CIERRE = 4   // segundos de la pantalla «Gracias» al final

rmSync(CUADROS, { recursive: true, force: true })
mkdirSync(CUADROS, { recursive: true })

const navegador = await chromium.launch({ executablePath: `${homedir()}/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome` })
const pagina = await navegador.newPage({ viewport: { width: 1920, height: 1080 } })
await pagina.goto(BASE + '#/presentacion')
await pagina.addStyleTag({ content: '.control, .acciones-fin { display: none !important; } .subtitulo { margin-bottom: 4vh !important; }' })
const comenzar = pagina.getByRole('button', { name: 'Comenzar la presentación' })
await comenzar.waitFor()

const cuadros = []
const cdp = await pagina.context().newCDPSession(pagina)
cdp.on('Page.screencastFrame', ({ data, metadata, sessionId }) => {
  const archivo = join(CUADROS, `${String(cuadros.length).padStart(5, '0')}.jpg`)
  writeFileSync(archivo, Buffer.from(data, 'base64'))
  cuadros.push({ archivo, t: metadata.timestamp })
  cdp.send('Page.screencastFrameAck', { sessionId }).catch(() => {})
})
await comenzar.click()   // la portada con el botón no entra al video
const inicio = Date.now()
await cdp.send('Page.startScreencast', { format: 'jpeg', quality: 92, maxWidth: 1920, maxHeight: 1080, everyNthFrame: 1 })
await pagina.getByRole('heading', { name: 'Gracias' }).waitFor({ timeout: 240_000 })
const duracion = (Date.now() - inicio) / 1000
await pagina.waitForTimeout(CIERRE * 1000)
await cdp.send('Page.stopScreencast')
await navegador.close()

// Lista para el demuxer concat: cada cuadro dura hasta el siguiente (reloj de los
// cuadros, sin mezclarlo con el de Node); el último se sostiene CIERRE segundos.
const lineas = cuadros.flatMap((c, i) => {
  const dura = i + 1 < cuadros.length ? cuadros[i + 1].t - c.t : CIERRE
  return [`file '${c.archivo}'`, `duration ${Math.max(0.001, dura).toFixed(4)}`]
})
if (process.env.CONSERVAR) writeFileSync(join(CUADROS, 'tiempos.json'), JSON.stringify(cuadros.map((c) => c.t)))
const lista = join(CUADROS, 'lista.txt')
writeFileSync(lista, lineas.join('\n') + '\n')

const r = spawnSync(FFMPEG, ['-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', lista,
  // Los JPEG son de rango completo; el MP4 va en rango limitado BT.709 (yuv420p), el que los
  // celulares y WhatsApp esperan: si no, se ven los colores lavados.
  '-vf', 'fps=30,scale=in_range=pc:out_range=tv:in_color_matrix=bt601:out_color_matrix=bt709,format=yuv420p',
  '-colorspace', 'bt709', '-color_primaries', 'bt709', '-color_trc', 'bt709', '-color_range', 'tv',
  '-c:v', 'libx264', '-preset', 'slow', '-crf', '20',
  // Sin -t, ffmpeg alarga el último cuadro unos segundos de más.
  '-t', (cuadros.at(-1).t - cuadros[0].t + CIERRE).toFixed(3), '-movflags', '+faststart', SALIDA], { stdio: 'inherit' })
if (r.status !== 0) throw new Error(`ffmpeg terminó con código ${r.status}`)
if (!process.env.CONSERVAR) rmSync(CUADROS, { recursive: true, force: true })
console.log(`${cuadros.length} cuadros → ${SALIDA}`)
// Si el equipo estuvo muy cargado, la presentación dura más que el guion y los subtítulos
// se atrasan frente a los clips: conviene repetir la grabación con menos programas abiertos.
console.log(`presentación: ${duracion.toFixed(1)} s (guion: ${DURACION_TOTAL} s, desfase ${(duracion - DURACION_TOTAL).toFixed(1)} s)`)
