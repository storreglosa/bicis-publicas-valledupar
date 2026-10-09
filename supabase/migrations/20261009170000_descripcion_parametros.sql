-- La página pública de reglas muestra la descripción de los parámetros de retención.
-- La de las preinscripciones decía «se elimina», pero el sistema las anonimiza
-- (política v1.0 §8; migración 20261008150000): se alinea con lo que hace.
update public.parametros
   set descripcion = 'Días tras los que se anonimiza una preinscripción nunca validada'
 where clave = 'retencion.preinscripcion_sin_validar_dias';
