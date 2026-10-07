// Foto de evidencia: se reduce y recomprime en el navegador antes de subirla.
// Objetivo 80–150 KB (1 GB de Storage ≈ 8.000 fotos). Al redibujar en un canvas
// se descarta el EXIF, incluida la ubicación GPS del celular del operador.

const LADO_MAX = 1280
const OBJETIVO_BYTES = 150 * 1024
const LIMITE_BUCKET_BYTES = 512 * 1024   // file_size_limit del bucket 'evidencias'

export function dimensiones(ancho, alto, ladoMax = LADO_MAX) {
  const escala = Math.min(1, ladoMax / Math.max(ancho, alto))
  return { ancho: Math.round(ancho * escala), alto: Math.round(alto * escala) }
}

function aBlob(canvas, tipo, calidad) {
  return new Promise((resolver, rechazar) => {
    canvas.toBlob((blob) => (blob ? resolver(blob) : rechazar(new Error('foto_no_procesada'))), tipo, calidad)
  })
}

async function codificar(imagen, ladoMax) {
  const { ancho, alto } = dimensiones(imagen.width, imagen.height, ladoMax)
  const canvas = document.createElement('canvas')
  canvas.width = ancho
  canvas.height = alto
  canvas.getContext('2d').drawImage(imagen, 0, 0, ancho, alto)
  let ultima
  for (const calidad of [0.7, 0.6, 0.5]) {
    let blob = await aBlob(canvas, 'image/webp', calidad)
    if (blob.type !== 'image/webp') {
      // Navegadores sin codificador WebP (algunos Safari) devuelven PNG: se usa JPEG.
      blob = await aBlob(canvas, 'image/jpeg', calidad + 0.05)
    }
    ultima = blob
    if (blob.size <= OBJETIVO_BYTES) break
  }
  return ultima
}

/**
 * @param {File} archivo foto tomada con la cámara
 * @returns {Promise<{ blob: Blob, extension: 'webp' | 'jpg', tipo: string }>}
 */
export async function comprimirFoto(archivo) {
  const imagen = await createImageBitmap(archivo, { imageOrientation: 'from-image' })
  try {
    let blob = await codificar(imagen, LADO_MAX)
    if (blob.size > OBJETIVO_BYTES * 2) {
      blob = await codificar(imagen, 960)
    }
    if (blob.size > LIMITE_BUCKET_BYTES) {
      throw new Error('foto_demasiado_grande')
    }
    const extension = blob.type === 'image/webp' ? 'webp' : 'jpg'
    return { blob, extension, tipo: blob.type }
  } finally {
    imagen.close?.()
  }
}
