// Markdown mínimo y seguro para textos publicados por el administrador
// (política de datos, reglamento). Primero se escapa TODO el HTML; después se
// aplican solo títulos, listas, párrafos y negrita. Ningún HTML del servidor
// llega crudo al DOM.

function escapar(texto) {
  return texto.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;').replaceAll("'", '&#39;')
}

function enLinea(texto) {
  return escapar(texto).replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
}

/** @param {string} md @returns {string} HTML seguro */
export function markdownSeguro(md) {
  const salida = []
  let lista = null
  let parrafo = []
  const cerrarParrafo = () => {
    if (parrafo.length) salida.push(`<p>${parrafo.map(enLinea).join(' ')}</p>`)
    parrafo = []
  }
  const cerrarLista = () => {
    if (lista) salida.push(`<ul>${lista.map((i) => `<li>${enLinea(i)}</li>`).join('')}</ul>`)
    lista = null
  }
  for (const cruda of String(md ?? '').split(/\r?\n/)) {
    const linea = cruda.trim()
    const titulo = /^(#{1,3})\s+(.*)$/.exec(linea)
    const item = /^[-*]\s+(.*)$/.exec(linea)
    if (!linea) {
      cerrarParrafo()
      cerrarLista()
    } else if (titulo) {
      cerrarParrafo()
      cerrarLista()
      const nivel = titulo[1].length + 1   // # → h2: el h1 lo pone la página
      salida.push(`<h${nivel}>${enLinea(titulo[2])}</h${nivel}>`)
    } else if (item) {
      cerrarParrafo()
      ;(lista ??= []).push(item[1])
    } else {
      cerrarLista()
      parrafo.push(linea)
    }
  }
  cerrarParrafo()
  cerrarLista()
  return salida.join('\n')
}
