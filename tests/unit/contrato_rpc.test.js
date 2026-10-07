// Contrato frontend ↔ base: cada supabase.rpc('fn', { ... }) del código debe usar
// una función que existe en las migraciones, solo parámetros que la función
// declara, y todos los obligatorios (los que no tienen DEFAULT).
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

const RAIZ = join(import.meta.dirname, '../..')

function archivos(dir, extensiones) {
  return readdirSync(dir).flatMap((n) => {
    const ruta = join(dir, n)
    if (statSync(ruta).isDirectory()) return archivos(ruta, extensiones)
    return extensiones.some((e) => n.endsWith(e)) ? [ruta] : []
  })
}

// Firmas SQL: create [or replace] function public.nombre(p_a tipo, p_b tipo default x, ...)
const firmas = new Map()
for (const ruta of archivos(join(RAIZ, 'supabase/migrations'), ['.sql'])) {
  const sql = readFileSync(ruta, 'utf8')
  for (const m of sql.matchAll(/create (?:or replace )?function public\.(\w+)\(([\s\S]*?)\)\s*returns/g)) {
    const params = m[2].split(',').map((p) => p.trim()).filter(Boolean).map((p) => ({
      nombre: p.split(/\s+/)[0],
      obligatorio: !/\bdefault\b/i.test(p),
    }))
    firmas.set(m[1], params)
  }
}

// Llamadas en el frontend: supabase.rpc('nombre'[, { ...objeto... }])
function clavesDeObjeto(texto, inicio) {
  // Recorre el literal de objeto respetando llaves anidadas y devuelve las claves de nivel 0.
  let nivel = 0
  let actual = ''
  const trozos = []
  for (let i = inicio; i < texto.length; i++) {
    const c = texto[i]
    if (c === '{' || c === '[' || c === '(') nivel++
    if (c === '}' || c === ']' || c === ')') nivel--
    if (nivel === 0) { trozos.push(actual); break }
    if (nivel === 1 && c === ',') { trozos.push(actual); actual = ''; continue }
    if (!(nivel === 1 && c === '{' && i === inicio)) actual += c
  }
  return trozos
    .map((t) => t.replace(/^\{/, '').trim())
    .filter(Boolean)
    .map((t) => (t.match(/^(\w+)\s*:/) ?? t.match(/^(\w+)$/))?.[1])
    .filter(Boolean)
}

const llamadas = []
for (const ruta of archivos(join(RAIZ, 'src'), ['.vue', '.js'])) {
  const codigo = readFileSync(ruta, 'utf8')
  for (const m of codigo.matchAll(/supabase\.rpc\('(\w+)'(\s*,\s*\{)?/g)) {
    const claves = m[2] ? clavesDeObjeto(codigo, m.index + m[0].length - 1) : []
    llamadas.push({ archivo: ruta.replace(RAIZ + '/', ''), fn: m[1], claves })
  }
}

describe('contrato RPC frontend ↔ migraciones', () => {
  it('encuentra llamadas y firmas', () => {
    expect(llamadas.length).toBeGreaterThan(5)
    expect(firmas.size).toBeGreaterThan(10)
  })

  it.each(llamadas.map((l) => [`${l.fn} en ${l.archivo}`, l]))('%s', (_n, l) => {
    const params = firmas.get(l.fn)
    expect(params, `la función public.${l.fn} no existe en las migraciones`).toBeDefined()
    const nombres = params.map((p) => p.nombre)
    for (const clave of l.claves) expect(nombres, `parámetro desconocido ${clave}`).toContain(clave)
    for (const p of params.filter((x) => x.obligatorio)) expect(l.claves, `falta ${p.nombre}`).toContain(p.nombre)
  })
})
