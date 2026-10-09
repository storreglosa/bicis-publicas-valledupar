// Guion del modo «Presentar» (src/vistas/publico/Presentacion.vue): unos 3 minutos.
// Cada escena dura `duracion` segundos; `frases` son los subtítulos [segundo, texto] y
// `puntos`, `tarjetas` e `items` aparecen en el segundo indicado. Los clips se graban
// con scripts/grabar_presentacion.mjs (datos ficticios). Para cambiar un texto o un
// tiempo basta editar este archivo.

export const ESCENAS = [
  {
    id: 'problema', tipo: 'portada', titulo: 'Bicis Públicas Valledupar', duracion: 12,
    frases: [
      [0, 'La Secretaría de Tránsito y Transporte tiene 130 bicicletas para prestar, en puntos fijos y en eventos.'],
      [6, 'Hasta ahora no había una herramienta para saber quién tiene cada una, dónde está y cuántas hay disponibles.'],
    ],
  },
  {
    id: 'ciudadano', tipo: 'telefono', titulo: 'El ciudadano', clip: 'ciudadano', duracion: 25,
    puntos: [[1, 'Desde el celular, sin descargar nada'], [7, 'Mapa en vivo de bicis disponibles'],
      [14, 'Eventos y reglas de uso'], [19, 'Inscripción en línea']],
    frases: [
      [0, 'Cualquier persona entra a la página desde su celular, sin descargar ninguna aplicación.'],
      [7, 'Ve en un mapa en vivo cuántas bicicletas hay disponibles en cada punto.'],
      [15, 'Consulta los eventos y las reglas de uso, y puede inscribirse en línea antes de ir al punto.'],
    ],
  },
  {
    id: 'qr', tipo: 'qr', titulo: 'Cada bici con su código QR', codigo: 'BPV-015', duracion: 15,
    frases: [
      [0, 'Cada bicicleta conserva su número y lleva un sticker con un código QR.'],
      [7, 'Al escanearlo se abre la página de esa bici: cómo pedirla, o cómo avisar si está sola o dañada.'],
    ],
  },
  {
    id: 'operador', tipo: 'telefono', titulo: 'El operador en el punto', clip: 'operador', duracion: 35,
    contador: { en: 28, punto: 'Plaza Alfonso López', de: 35, a: 34 },
    puntos: [[1, 'Busca a la persona por su documento'], [11, 'Elige la bici'], [15, 'Toma la foto de evidencia'],
      [22, 'Confirma: queda registrado'], [28, 'El mapa se actualiza solo']],
    frases: [
      [0, 'En el punto, el operador atiende desde su celular.'],
      [5, 'Busca a la persona por su documento, que solo mira: nunca lo retiene.'],
      [12, 'Elige la bicicleta y toma una foto de la persona con la bici, como evidencia de la entrega.'],
      [22, 'Confirma, y el préstamo queda registrado con la hora exacta.'],
      [28, 'El mapa público se actualiza solo: hay una bici menos disponible en ese punto.'],
    ],
  },
  {
    id: 'secretaria', tipo: 'pantalla', titulo: 'La Secretaría', clip: 'admin', duracion: 30,
    frases: [
      [0, 'Desde la oficina, la Secretaría ve el día completo en un tablero.'],
      [7, 'Bicis disponibles y prestadas, préstamos por hora y alertas cuando algo necesita atención.'],
      [14, 'Consulta el historial de cada préstamo y lo descarga en Excel.'],
      [21, 'Administra puntos, eventos y bicicletas, e imprime las etiquetas QR.'],
    ],
  },
  {
    id: 'confianza', tipo: 'tarjetas', titulo: 'Seguro y confiable', duracion: 30,
    tarjetas: [
      [1, 'roles', 'Cada quien ve solo lo que le toca',
        'El operador solo busca por número de documento. Los datos completos solo los ve la administración.'],
      [8, 'registro', 'Todo queda registrado', 'Quién hizo qué y cuándo. Ese registro no se puede borrar.'],
      [15, 'candado', 'Datos personales protegidos',
        'Las fotos se borran solas a los 7 días y hay copias de seguridad cifradas. Diseñado conforme a la Ley 1581 de 2012.'],
      [22, 'check', 'Sin trampas', 'Una bici no se puede prestar dos veces, ni registrar un préstamo sin foto.'],
    ],
    frases: [
      [0, 'Detrás hay una base de datos segura. Cada quien ve solo lo que le toca.'],
      [8, 'Todo queda registrado: quién hizo qué y cuándo, y nadie lo puede borrar.'],
      [15, 'Los datos personales están protegidos: las fotos se borran solas y hay copias de seguridad cifradas.'],
      [22, 'Y no se puede hacer trampa: una bici no se presta dos veces, ni sin foto.'],
    ],
  },
  {
    id: 'hoy', tipo: 'cifra', titulo: 'Hoy', cifra: '$0', duracion: 12,
    texto: 'Funciona con servicios gratuitos y alcanza para los eventos programados.',
    frases: [[0, 'Hoy funciona con servicios gratuitos: no ha costado nada y alcanza para los eventos programados.']],
  },
  {
    id: 'crecer', tipo: 'lista', titulo: 'Para un sistema de bicicletas públicas permanente', duracion: 18,
    items: [
      [1, 'Plan de servicios', 'Copias de seguridad diarias automáticas, sin pausas por inactividad y más capacidad. Desde US$25 al mes.'],
      [8, 'Dominio propio', 'Una dirección oficial para la página, por ejemplo bicis.valledupar-cesar.gov.co.'],
    ],
    frases: [
      [0, 'Para crecer a un sistema de bicicletas públicas permanente, sería pertinente un plan de servicios pagado…'],
      [8, '…y un dominio propio para la página, con la dirección oficial de la Alcaldía.'],
    ],
  },
]

export const DURACION_TOTAL = ESCENAS.reduce((s, e) => s + e.duracion, 0)
