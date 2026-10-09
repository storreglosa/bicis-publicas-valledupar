// Identidad del sitio: ÚNICO lugar donde se definen el nombre y los datos de
// contacto. Cambiar el nombre del sistema = cambiar este archivo.

export default {
  nombre: 'Bicis Públicas Valledupar', // provisional
  nombreCorto: 'Bicis Públicas',
  entidad: 'Secretaría de Tránsito y Transporte de Valledupar',
  alcaldia: 'Alcaldía de Valledupar',

  // Canal oficial de la Secretaría (lo entregó Santiago el 2026-10-09). El correo
  // es también el canal de PQRSD y de datos personales (política §1 y §10).
  contacto: {
    correo: 'atencionusuariotransito@valledupar-cesar.gov.co',
    direccion: 'Calle 16A # 10-24, Centro, Valledupar, Cesar',
    redes: { instagram: 'https://www.instagram.com/sectransitovpar/', x: 'https://x.com/sectransitovpar', usuario: '@sectransitovpar' },
  },

  urlPublica: 'https://storreglosa.github.io/bicis-publicas-valledupar/',

  // Prefijo del código de las bicicletas (BPV-001). Es fijo y NO se deriva del
  // nombre: los QR impresos no pueden cambiar si el sistema se renombra.
  prefijoBici: 'BPV',

  // Centro y zoom inicial del mapa (EPSG:4326).
  mapa: { centro: [10.4631, -73.2532], zoom: 14 },

  zonaHoraria: 'America/Bogota',
}
