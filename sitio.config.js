// Identidad del sitio: ÚNICO lugar donde se definen el nombre y los datos de
// contacto. Cambiar el nombre del sistema = cambiar este archivo.

export default {
  nombre: 'Bicis Públicas Valledupar', // provisional
  nombreCorto: 'Bicis Públicas',
  entidad: 'Secretaría de Tránsito y Transporte de Valledupar',
  alcaldia: 'Alcaldía de Valledupar',

  // Por definir con la STTV antes del piloto. Mientras sean null, el pie de
  // página muestra "por definir" en lugar de un enlace roto.
  contacto: {
    correo: null,
    telefono: null,
    pqrsdUrl: null,
  },

  urlPublica: 'https://storreglosa.github.io/bicis-publicas-valledupar/',

  // Prefijo del código de las bicicletas (BPV-001). Es fijo y NO se deriva del
  // nombre: los QR impresos no pueden cambiar si el sistema se renombra.
  prefijoBici: 'BPV',

  // Centro y zoom inicial del mapa (EPSG:4326).
  mapa: { centro: [10.4631, -73.2532], zoom: 14 },

  zonaHoraria: 'America/Bogota',
}
