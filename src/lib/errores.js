// Traducción de los códigos de error que lanzan las funciones SQL
// (supabase/migrations/*: `raise exception using message = '<código>'`).
// tests/unit/errores.test.js verifica que cada código de las migraciones
// tenga aquí su mensaje. Un código desconocido NUNCA se silencia: se muestra un
// mensaje genérico con el código y se registra en la consola.

export const MENSAJES = {
  // Permisos y sesión
  no_autorizado: 'No tienes permiso para esta acción. Si crees que es un error, avisa al administrador.',
  no_puede_degradarse: 'No puedes quitarte a ti mismo el rol de administrador ni desactivar tu cuenta.',
  sin_administradores: 'Debe quedar al menos un administrador activo.',
  usuario_no_existe: 'No hay ninguna cuenta con ese correo. Créala primero en Supabase (Authentication).',
  usuario_no_confirmado: 'Esa cuenta no tiene el correo confirmado. Confírmala en Supabase (Authentication) antes de vincularla.',
  demasiadas_busquedas: 'Has hecho demasiadas búsquedas en pocos minutos. Espera un momento e inténtalo de nuevo.',
  ya_vinculado: 'Esa cuenta ya está vinculada al personal.',

  // Datos de la persona
  datos_invalidos: 'Los datos enviados no son válidos. Recarga la página e inténtalo de nuevo.',
  id_operacion_invalido: 'La operación no tiene un identificador válido. Recarga la página e inténtalo de nuevo.',
  tipo_documento_invalido: 'Elige un tipo de documento de la lista.',
  documento_invalido: 'El número de documento no es válido para ese tipo de documento.',
  nombre_invalido: 'Revisa el nombre y los apellidos: no pueden estar vacíos ni llevar números o símbolos.',
  telefono_invalido: 'Escribe un teléfono de 7 a 15 dígitos.',
  correo_invalido: 'El correo no es válido. Si no tienes correo, deja el campo vacío.',
  edad_invalida: 'Escribe la edad en años (entre 5 y 110).',
  sexo_genero_invalido: 'Elige una opción de sexo / género.',
  edad_no_coincide_documento: 'La cédula de ciudadanía solo la tienen mayores de 18 años. Revisa la edad o el tipo de documento.',
  falta_acudiente: 'Para menores de edad hay que registrar los datos del acudiente (madre, padre o representante legal).',
  acudiente_debe_ser_adulto: 'El acudiente debe ser mayor de edad (no puede identificarse con tarjeta de identidad).',
  acudiente_es_la_misma_persona: 'El acudiente no puede ser la misma persona inscrita.',
  parentesco_invalido: 'El acudiente debe ser la madre, el padre o el representante legal del menor.',
  persona_no_existe: 'No encontramos a esa persona.',
  persona_no_validada: 'Esta persona aún no ha sido validada. Verifica su documento original y valídala antes de prestar.',
  persona_sancionada: 'Esta persona tiene una suspensión vigente y no puede prestar bicicletas.',

  // Autorización de datos
  falta_autorizacion: 'Para inscribirse es obligatorio aceptar la autorización de tratamiento de datos personales.',
  falta_menor_escuchado: 'Para un menor de edad hay que dejar constancia de que se le escuchó y está de acuerdo.',
  politica_desactualizada: 'La política de tratamiento de datos cambió. Recarga la página para ver la versión vigente.',
  sin_politica_vigente: 'Todavía no hay una política de tratamiento de datos publicada. Avisa al administrador.',
  politica_inmutable: 'Una política publicada no se puede modificar; publica una versión nueva.',
  falta_autorizacion_vigente: 'Esta persona no ha autorizado la política de datos vigente. Registra la nueva autorización antes de prestar.',
  falta_autorizacion_foto: 'Esta persona no ha autorizado la foto de evidencia, que es obligatoria para prestar.',
  falta_autorizacion_presencial: 'Para un menor de edad, su acudiente debe autorizar en persona, aquí en el punto, con su documento.',

  // Bicicletas y puntos
  bici_no_existe: 'No hay ninguna bicicleta con ese número.',
  bici_ya_prestada: 'Esa bicicleta ya está prestada. Revisa el número del sticker.',
  bici_no_disponible: 'Esa bicicleta no está disponible (en taller, averiada o fuera de servicio).',
  bici_en_otro_punto: 'Esa bicicleta está registrada en otro punto. Muévela a este punto antes de prestarla.',
  bici_no_prestada: 'Esa bicicleta no tiene un préstamo activo.',
  bici_prestada: 'Esa bicicleta está prestada; primero hay que registrar su devolución.',
  bici_no_movible: 'Una bicicleta extraviada o dada de baja no se puede mover.',
  sin_bicis: 'Elige al menos una bicicleta.',
  rango_invalido: 'El rango de números no es válido (de 1 a 9999 y como máximo 1000 a la vez).',
  falta_punto: 'Indica en qué punto queda la bicicleta.',
  punto_no_existe: 'Ese punto no existe.',
  punto_taller: 'En el taller no se prestan bicicletas.',
  punto_inactivo: 'Este punto no está activo.',
  punto_cerrado: 'Ese punto está cerrado.',
  punto_con_bicis: 'Al punto todavía le quedan bicicletas. Muévelas antes de cerrarlo.',
  evento_no_en_curso: 'El evento de este punto no está en curso.',

  // Préstamo y devolución
  falta_foto: 'Falta la foto de evidencia. Tómala de nuevo y espera a que termine de subir.',
  foto_ruta_invalida: 'La foto no corresponde a este préstamo. Tómala de nuevo.',
  fuera_de_horario: 'Fuera del horario de préstamos.',
  edad_minima: 'Esta persona no cumple la edad mínima para prestar.',
  limite_prestamos_activos: 'Esta persona ya tiene el máximo de bicicletas prestadas a la vez.',
  limite_prestamos_dia: 'Esta persona ya alcanzó el máximo de préstamos de hoy.',
  id_operacion_reutilizado: 'Esta operación ya se registró con otros datos. Recarga la página e inténtalo de nuevo.',
  prestamo_no_existe: 'Ese préstamo no existe.',
  prestamo_no_activo: 'Ese préstamo ya no está activo.',
  motivo_insuficiente: 'Escribe un motivo más detallado.',
  texto_demasiado_largo: 'El texto es demasiado largo. Resúmelo en menos de 500 caracteres.',
  falta_incidencia: 'Describe la novedad: tipo, gravedad y qué pasó.',
  incidencia_tipo_invalido: 'Elige el tipo de novedad.',
  incidencia_gravedad_invalida: 'Elige la gravedad de la novedad.',
  incidencia_descripcion_corta: 'Describe la novedad con un poco más de detalle.',

  // Administración
  parametro_fuera_de_rango: 'Ese valor está fuera del rango permitido para el parámetro.',
  registro_inmutable: 'Ese registro no se puede modificar ni borrar.',
  sancion_inmutable: 'De una sanción solo se pueden cambiar el estado, la fecha final y el motivo de anulación.',
  incidencia_inmutable: 'De una incidencia solo se pueden cambiar el estado y la resolución.',
  tipo_punto_inmutable: 'El tipo de un punto (fijo, evento o taller) no se puede cambiar. Crea un punto nuevo.',
}

// Errores de Postgres que no lanza ninguna función, identificados por su código
// SQLSTATE: concurrencia (40P01, 40001) y tiempo de espera (57014).
const POR_CODIGO_SQL = {
  '40P01': 'Otra persona estaba registrando una operación sobre las mismas bicis. Inténtalo de nuevo.',
  '40001': 'Otra persona estaba registrando una operación sobre las mismas bicis. Inténtalo de nuevo.',
  '57014': 'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
}

const GENERICO = 'Ocurrió un error inesperado. Inténtalo de nuevo; si se repite, avisa al administrador con el código que aparece abajo.'

/**
 * Convierte un error de Supabase (o de red) en { codigo, mensaje } para mostrar.
 * @param {unknown} error
 * @returns {{ codigo: string, mensaje: string }}
 */
export function traducirError(error) {
  const codigo = (error && typeof error === 'object' && 'message' in error) ? String(error.message) : String(error)
  if (Object.hasOwn(MENSAJES, codigo)) {
    return { codigo, mensaje: MENSAJES[codigo] }
  }
  const sqlstate = error && typeof error === 'object' && 'code' in error ? String(error.code) : null
  if (sqlstate && Object.hasOwn(POR_CODIGO_SQL, sqlstate)) {
    return { codigo: 'reintentar', mensaje: POR_CODIGO_SQL[sqlstate] }
  }
  if (/failed to fetch|networkerror|load failed/i.test(codigo)) {
    return { codigo: 'sin_conexion', mensaje: 'No hay conexión con el servidor. Revisa los datos móviles e inténtalo de nuevo.' }
  }
  // Solo código y mensaje: el campo `details` de Postgres puede traer una fila con
  // datos personales y no debe quedar en la consola del dispositivo.
  console.error('Error no traducido:', { code: sqlstate, message: codigo })
  return { codigo, mensaje: GENERICO }
}
