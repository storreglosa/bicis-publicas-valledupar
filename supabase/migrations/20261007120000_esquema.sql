-- Esquema del sistema de bicicletas públicas (Fase 1a).
-- Diseño: docs/diseno-detallado.md §3 (con los ajustes de docs/decisiones.md).
--
-- Principios:
--   * Estados explícitos (enums); nunca se deducen de un NULL.
--   * Nada se borra de las tablas de negocio: se anula o se anonimiza.
--   * Lo único que ve el público es disponibilidad_puntos (sin datos personales).
--   * Coordenadas en EPSG:4326 con 6 decimales.

-- 0. Endurecimiento de privilegios ANTES de crear cualquier objeto (revisión de
--    seguridad M-3 y B-7). Así ninguna función o tabla nace expuesta, aunque una
--    migración posterior falle a mitad de un despliegue.
--    * Postgres concede EXECUTE a PUBLIC sobre toda función nueva: es un privilegio
--      global y solo se revoca de forma global.
--    * El esquema clásico de Supabase concede ALL en public a los roles de la API.
alter default privileges revoke execute on functions from public;
alter default privileges in schema public revoke all on tables from anon, authenticated, service_role;
alter default privileges in schema public revoke all on sequences from anon, authenticated, service_role;
alter default privileges in schema public revoke all on functions from anon, authenticated, service_role;

create schema if not exists privado;
comment on schema privado is 'Funciones auxiliares y tablas internas. NO se expone por la API.';

-- Tipos ----------------------------------------------------------------------
create type public.rol_personal        as enum ('administrador', 'operador');
create type public.disponibilidad_bici as enum ('disponible', 'prestada', 'no_disponible');
create type public.condicion_bici      as enum ('operativa', 'averiada', 'en_reparacion', 'extraviada', 'baja');
create type public.tipo_punto          as enum ('fijo', 'evento', 'taller');
create type public.estado_punto        as enum ('activo', 'inactivo', 'oculto', 'cerrado');
create type public.estado_evento       as enum ('planeado', 'en_curso', 'finalizado', 'cancelado');
create type public.estado_inscripcion  as enum ('preinscrita', 'validada', 'anonimizada');
create type public.canal               as enum ('web', 'punto');
create type public.otorgante           as enum ('titular', 'acudiente');
create type public.estado_autorizacion as enum ('vigente', 'revocada');
create type public.estado_prestamo     as enum ('activo', 'finalizado', 'no_devuelto', 'anulado');
create type public.contenido_foto      as enum ('persona_y_bici', 'solo_bici');
create type public.estado_foto         as enum ('almacenada', 'eliminada');
create type public.tipo_incidencia     as enum ('dano', 'accidente', 'perdida', 'robo', 'retraso', 'conducta', 'otro');
create type public.gravedad            as enum ('leve', 'moderada', 'grave');
create type public.estado_incidencia   as enum ('abierta', 'en_gestion', 'cerrada');
create type public.tipo_sancion        as enum ('amonestacion', 'suspension');
create type public.estado_sancion      as enum ('vigente', 'cumplida', 'anulada');
create type public.sexo_genero         as enum ('mujer', 'hombre', 'otro', 'prefiere_no_responder');

-- Ajustes internos -----------------------------------------------------------
create table privado.ajustes (
  clave text primary key,
  valor text not null
);
-- Sal para las huellas de la auditoría: se genera una vez, al azar, en cada base.
insert into privado.ajustes (clave, valor)
values ('sal_huellas', encode(sha256(convert_to(gen_random_uuid()::text || gen_random_uuid()::text, 'UTF8')), 'hex'));

create table privado.ejecuciones_tareas (
  id bigint generated always as identity primary key,
  tarea text not null,
  inicio timestamptz not null default now(),
  fin timestamptz,
  resultado text not null check (resultado in ('ok', 'error', 'en_curso')),
  detalle jsonb
);

-- Catálogo de documentos -----------------------------------------------------
create table public.tipos_documento (
  codigo text primary key check (codigo ~ '^[A-Z]{2,4}$'),
  nombre text not null,
  implica_menor boolean not null default false,
  patron text not null,               -- expresión regular del número normalizado
  orden smallint not null default 0,
  activo boolean not null default true
);
insert into public.tipos_documento (codigo, nombre, implica_menor, patron, orden) values
  ('CC',  'Cédula de ciudadanía',            false, '^[0-9]{3,10}$',    1),
  ('TI',  'Tarjeta de identidad',            true,  '^[0-9]{6,11}$',    2),
  ('CE',  'Cédula de extranjería',           false, '^[0-9A-Z]{3,15}$', 3),
  ('PPT', 'Permiso por protección temporal', false, '^[0-9A-Z]{3,15}$', 4),
  ('PA',  'Pasaporte',                       false, '^[0-9A-Z]{4,20}$', 5);

-- Personal (cuentas de Supabase Auth con rol en la app) ----------------------
create table public.personal (
  id uuid primary key references auth.users (id) on delete restrict,
  nombre text not null check (length(btrim(nombre)) between 3 and 120),
  rol public.rol_personal not null,
  activo boolean not null default true,
  debe_cambiar_clave boolean not null default true,
  creado_en timestamptz not null default now(),
  creado_por uuid references public.personal (id)
);

-- Personas usuarias del servicio --------------------------------------------
create table public.acudientes (
  id uuid primary key default gen_random_uuid(),
  tipo_documento text not null references public.tipos_documento (codigo),
  numero_documento text not null check (numero_documento ~ '^[0-9A-Z]{3,20}$'),
  nombres text not null check (length(btrim(nombres)) between 1 and 80),
  apellidos text not null check (length(btrim(apellidos)) between 1 and 80),
  telefono text not null check (telefono ~ '^\+?[0-9]{7,15}$'),
  correo text check (correo is null or (correo = lower(correo) and correo ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')),
  -- Sal propia para las huellas de la auditoría (ver privado.auditar).
  sal_huella text not null default encode(sha256(convert_to(gen_random_uuid()::text || clock_timestamp()::text, 'UTF8')), 'hex'),
  creado_en timestamptz not null default now(),
  unique (tipo_documento, numero_documento)
);

create table public.personas (
  id uuid primary key default gen_random_uuid(),
  tipo_documento text not null references public.tipos_documento (codigo),
  numero_documento text not null check (numero_documento ~ '^[0-9A-Z]{3,20}$'),
  nombres text not null check (length(btrim(nombres)) between 1 and 80),
  apellidos text not null check (length(btrim(apellidos)) between 1 and 80),
  telefono text not null check (telefono ~ '^\+?[0-9]{7,15}$'),
  correo text check (correo is null or (correo = lower(correo) and correo ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')),
  edad_declarada smallint not null check (edad_declarada between 5 and 110),
  edad_declarada_en date not null default current_date,
  sexo_genero public.sexo_genero not null,
  acudiente_id uuid references public.acudientes (id),
  -- Solo el representante legal puede autorizar el tratamiento de datos de un
  -- menor (D. 1377/2013 art. 12). Pendiente de confirmar con Jurídica.
  acudiente_parentesco text check (acudiente_parentesco in ('madre', 'padre', 'representante_legal')),
  estado public.estado_inscripcion not null default 'preinscrita',
  origen public.canal not null,
  validada_en timestamptz,
  validada_por uuid references public.personal (id),
  id_operacion uuid not null unique,  -- idempotencia de la inscripción
  -- Sal propia para las huellas de la auditoría. Al anonimizar se reemplaza: las
  -- huellas ya escritas en la auditoría inmutable quedan sin vínculo con la persona.
  sal_huella text not null default encode(sha256(convert_to(gen_random_uuid()::text || clock_timestamp()::text, 'UTF8')), 'hex'),
  creada_en timestamptz not null default now(),
  actualizada_en timestamptz not null default now(),
  unique (tipo_documento, numero_documento),
  check (estado <> 'validada' or (validada_en is not null and validada_por is not null)),
  check ((acudiente_id is null) = (acudiente_parentesco is null))
);
create index personas_acudiente on public.personas (acudiente_id) where acudiente_id is not null;

-- Política de tratamiento versionada y autorizaciones ------------------------
create table public.politicas_tratamiento (
  id smallint generated always as identity primary key,
  version text not null unique check (version ~ '^[0-9]+(\.[0-9]+)?$'),
  vigente_desde date not null,
  texto_md text not null check (length(texto_md) >= 200),
  texto_autorizacion text not null check (length(texto_autorizacion) >= 20),
  texto_autorizacion_foto text not null check (length(texto_autorizacion_foto) >= 20),
  sha256 text not null,                -- lo calcula un trigger
  vigente boolean not null default false,
  publicada_por uuid references public.personal (id),
  publicada_en timestamptz not null default now()
);
create unique index una_politica_vigente on public.politicas_tratamiento ((true)) where vigente;

create table public.autorizaciones_datos (
  id uuid primary key,                 -- UUID del cliente
  persona_id uuid not null references public.personas (id),
  politica_id smallint not null references public.politicas_tratamiento (id),
  otorgada_por public.otorgante not null,
  acudiente_id uuid references public.acudientes (id),
  menor_escuchado boolean,             -- D. 1377/2013 art. 12: derecho del menor a ser escuchado
  autoriza_tratamiento boolean not null check (autoriza_tratamiento),
  autoriza_foto boolean not null,
  canal public.canal not null,
  registrada_por uuid references public.personal (id),
  otorgada_en timestamptz not null default now(),
  estado public.estado_autorizacion not null default 'vigente',
  revocada_en timestamptz,
  motivo_revocacion text,
  check ((otorgada_por = 'acudiente') = (acudiente_id is not null)),
  check (otorgada_por = 'titular' or menor_escuchado is not null),
  check ((canal = 'punto') = (registrada_por is not null)),
  check ((estado = 'revocada') = (revocada_en is not null))
);
create unique index una_autorizacion_vigente
  on public.autorizaciones_datos (persona_id, politica_id) where estado = 'vigente';

-- Eventos, puntos y bicicletas -----------------------------------------------
create table public.eventos (
  id uuid primary key default gen_random_uuid(),
  nombre text not null check (length(btrim(nombre)) between 3 and 120),
  descripcion text check (length(descripcion) <= 2000),
  lugar_texto text check (length(lugar_texto) <= 200),
  inicia_en timestamptz not null,
  termina_en timestamptz not null,
  estado public.estado_evento not null default 'planeado',
  publicado boolean not null default false,
  creado_en timestamptz not null default now(),
  check (termina_en > inicia_en)
);

create table public.puntos (
  id uuid primary key default gen_random_uuid(),
  -- Código estable (P01, E001, T01): es lo que se imprime; no se deriva del nombre.
  codigo text not null unique check (codigo ~ '^[A-Z][0-9A-Z]{1,9}$'),
  nombre text not null check (length(btrim(nombre)) between 3 and 120),
  tipo public.tipo_punto not null,
  estado public.estado_punto not null default 'inactivo',
  evento_id uuid references public.eventos (id),
  -- EPSG:4326. CHECK con un recuadro amplio del municipio de Valledupar.
  latitud numeric(8, 6) not null check (latitud between 9.7 and 11.0),
  longitud numeric(9, 6) not null check (longitud between -74.0 and -72.8),
  direccion text check (length(direccion) <= 200),
  horario_texto text check (length(horario_texto) <= 200),
  capacidad smallint check (capacidad is null or capacidad > 0),
  notas_internas text check (length(notas_internas) <= 1000),
  creado_en timestamptz not null default now(),
  check ((tipo = 'evento') = (evento_id is not null))
);
create index puntos_evento on public.puntos (evento_id) where evento_id is not null;

create table public.bicicletas (
  id uuid primary key default gen_random_uuid(),
  numero integer not null unique check (numero between 1 and 9999),   -- sticker físico
  -- El prefijo BPV es fijo (no se deriva del nombre configurable del sitio).
  -- greatest() evita que lpad trunque números de 4 cifras.
  codigo text generated always as
    ('BPV-' || lpad(numero::text, greatest(3, length(numero::text)), '0')) stored unique,
  disponibilidad public.disponibilidad_bici not null default 'no_disponible',
  condicion public.condicion_bici not null default 'operativa',
  punto_actual_id uuid references public.puntos (id),
  marca text,
  modelo text,
  color text,
  talla text,
  numero_serie text unique,
  fecha_ingreso date,
  nota_operativa text check (length(nota_operativa) <= 500),
  ultimo_movimiento_en timestamptz not null default now(),
  check (disponibilidad <> 'prestada' or (punto_actual_id is null and condicion = 'operativa')),
  check (disponibilidad = 'prestada' or condicion in ('extraviada', 'baja') or punto_actual_id is not null),
  check (disponibilidad <> 'disponible' or condicion = 'operativa'),
  check (condicion not in ('extraviada', 'baja') or disponibilidad = 'no_disponible')
);
create index bicicletas_punto on public.bicicletas (punto_actual_id) where punto_actual_id is not null;

-- Proyección pública: lo único que ve el público y lo que transmite Realtime.
-- Sin ninguna columna interna (Realtime envía la fila completa).
create table public.disponibilidad_puntos (
  punto_id uuid primary key references public.puntos (id) on delete cascade,
  codigo text not null,
  nombre text not null,
  tipo public.tipo_punto not null,
  latitud numeric(8, 6) not null,
  longitud numeric(9, 6) not null,
  direccion text,
  horario_texto text,
  evento_nombre text,
  evento_inicia_en timestamptz,
  evento_termina_en timestamptz,
  abierto boolean not null,
  visible boolean not null,
  bicis_disponibles integer not null,
  actualizado_en timestamptz not null default now()
);

-- Libro de préstamos ---------------------------------------------------------
create table public.prestamos (
  id uuid primary key,                 -- UUID del cliente = llave de idempotencia
  bicicleta_id uuid not null references public.bicicletas (id),
  persona_id uuid not null references public.personas (id),
  autorizacion_id uuid not null references public.autorizaciones_datos (id),
  estado public.estado_prestamo not null default 'activo',
  punto_salida_id uuid not null references public.puntos (id),
  operador_salida_id uuid not null references public.personal (id),
  salida_en timestamptz not null default now(),
  salida_cliente_en timestamptz,       -- hora del dispositivo, solo informativa
  edad_estimada smallint not null,
  es_menor boolean not null,
  acudiente_id uuid references public.acudientes (id),
  foto_ruta text not null check (foto_ruta ~ ('^prestamos/' || id::text || '/salida\.(webp|jpg)$')),
  foto_contenido public.contenido_foto not null,
  foto_estado public.estado_foto not null default 'almacenada',
  foto_eliminada_en timestamptz,
  foto_retener boolean not null default false,
  observaciones_salida text check (length(observaciones_salida) <= 500),
  devolucion_id_operacion uuid unique,
  punto_devolucion_id uuid references public.puntos (id),
  operador_devolucion_id uuid references public.personal (id),
  devuelto_en timestamptz,
  con_novedad boolean,
  devolucion_forzada boolean not null default false,
  observaciones_devolucion text check (length(observaciones_devolucion) <= 500),
  cerrado_en timestamptz,
  cerrado_por uuid references public.personal (id),
  motivo_cierre text check (length(motivo_cierre) <= 500),
  check (estado <> 'activo' or (devuelto_en is null and punto_devolucion_id is null and cerrado_en is null)),
  check (estado <> 'finalizado' or (devuelto_en is not null and punto_devolucion_id is not null
         and operador_devolucion_id is not null and con_novedad is not null and devolucion_id_operacion is not null)),
  check ((estado in ('anulado', 'no_devuelto')) = (cerrado_en is not null and coalesce(length(motivo_cierre), 0) >= 10)),
  check (devuelto_en is null or devuelto_en >= salida_en),
  check ((foto_estado = 'eliminada') = (foto_eliminada_en is not null)),
  check (es_menor = (acudiente_id is not null))
);
create unique index prestamos_un_activo_por_bici on public.prestamos (bicicleta_id) where estado = 'activo';
create index prestamos_activos_persona on public.prestamos (persona_id) where estado = 'activo';
create index prestamos_persona_fecha on public.prestamos (persona_id, salida_en desc);
create index prestamos_salida on public.prestamos (salida_en desc);
create index prestamos_fotos_purgables on public.prestamos (devuelto_en)
  where foto_estado = 'almacenada' and not foto_retener;

-- Incidencias y sanciones ----------------------------------------------------
create table public.incidencias (
  id uuid primary key default gen_random_uuid(),
  bicicleta_id uuid not null references public.bicicletas (id),
  prestamo_id uuid references public.prestamos (id),
  tipo public.tipo_incidencia not null,
  gravedad public.gravedad not null,
  descripcion text not null check (length(btrim(descripcion)) between 5 and 1000),
  deja_fuera_de_servicio boolean not null default false,
  estado public.estado_incidencia not null default 'abierta',
  reportada_por uuid not null references public.personal (id),
  reportada_en timestamptz not null default now(),
  foto_ruta text,
  cerrada_por uuid references public.personal (id),
  cerrada_en timestamptz,
  resolucion text check (length(resolucion) <= 1000),
  check ((estado = 'cerrada') = (cerrada_en is not null and resolucion is not null))
);
create index incidencias_abiertas_bici on public.incidencias (bicicleta_id) where estado <> 'cerrada';

create table public.sanciones (
  id uuid primary key default gen_random_uuid(),
  persona_id uuid not null references public.personas (id),
  prestamo_id uuid references public.prestamos (id),
  incidencia_id uuid references public.incidencias (id),
  tipo public.tipo_sancion not null,
  motivo text not null check (length(btrim(motivo)) between 10 and 500),
  desde date not null default current_date,
  hasta date,
  estado public.estado_sancion not null default 'vigente',
  impuesta_por uuid not null references public.personal (id),
  impuesta_en timestamptz not null default now(),
  anulada_por uuid references public.personal (id),
  anulada_en timestamptz,
  motivo_anulacion text check (length(motivo_anulacion) <= 500),
  check (tipo <> 'suspension' or hasta is not null),   -- nada de suspensiones indefinidas implícitas
  check (hasta is null or hasta >= desde),
  check ((estado = 'anulada') = (anulada_en is not null))
);
create index sanciones_vigentes_persona on public.sanciones (persona_id) where estado = 'vigente';

-- Parámetros configurables (valor NULL = la regla no aplica) -----------------
create table public.parametros (
  clave text primary key check (clave ~ '^[a-z_]+\.[a-z_]+$'),
  categoria text not null,
  descripcion text not null,
  tipo text not null check (tipo in ('entero', 'hora', 'booleano', 'texto')),
  unidad text,
  minimo numeric,
  maximo numeric,
  publico boolean not null,
  orden smallint not null default 0,
  valor jsonb,
  actualizado_en timestamptz,
  actualizado_por uuid references public.personal (id),
  check (valor is null
    or (tipo = 'entero'   and jsonb_typeof(valor) = 'number' and (valor #>> '{}') ~ '^-?[0-9]+$')
    or (tipo = 'hora'     and jsonb_typeof(valor) = 'string' and (valor #>> '{}') ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$')
    or (tipo = 'booleano' and jsonb_typeof(valor) = 'boolean')
    or (tipo = 'texto'    and jsonb_typeof(valor) = 'string'))
);

-- Solo definiciones, sin valor (decisión D-06), salvo la foto obligatoria (D-10).
insert into public.parametros (clave, categoria, descripcion, tipo, unidad, minimo, maximo, publico, orden, valor) values
  ('reglas_uso.duracion_maxima_min', 'Reglas de uso', 'Duración máxima de un préstamo', 'entero', 'minutos', 5, 1440, true, 10, null),
  ('reglas_uso.max_prestamos_activos_persona', 'Reglas de uso', 'Bicicletas que una persona puede tener prestadas a la vez', 'entero', 'bicicletas', 1, 10, true, 20, null),
  ('reglas_uso.max_prestamos_dia_persona', 'Reglas de uso', 'Préstamos por persona en un mismo día', 'entero', 'préstamos', 1, 50, true, 30, null),
  ('reglas_uso.edad_minima', 'Reglas de uso', 'Edad mínima para prestar una bicicleta', 'entero', 'años', 5, 18, true, 40, null),
  ('horario.hora_inicio_prestamos', 'Horario', 'Hora desde la que se presta', 'hora', null, null, null, true, 10, null),
  ('horario.hora_limite_prestamos', 'Horario', 'Hora hasta la que se presta', 'hora', null, null, null, true, 20, null),
  ('horario.hora_limite_devolucion', 'Horario', 'Hora límite para devolver', 'hora', null, null, null, true, 30, null),
  ('sanciones.tolerancia_retraso_min', 'Sanciones', 'Minutos de tolerancia antes de considerar retraso', 'entero', 'minutos', 0, 240, true, 10, null),
  ('sanciones.dias_suspension_por_retraso', 'Sanciones', 'Días de suspensión por retraso', 'entero', 'días', 1, 365, true, 20, null),
  ('sanciones.retrasos_para_suspension', 'Sanciones', 'Retrasos acumulados que generan suspensión', 'entero', 'retrasos', 1, 20, true, 30, null),
  ('sanciones.texto_reglamento', 'Sanciones', 'Texto o referencia del reglamento de uso vigente', 'texto', null, null, null, true, 40, null),
  ('alertas.prestamo_largo_min', 'Alertas', 'Alertar préstamos que superen esta duración', 'entero', 'minutos', 5, 2880, false, 10, null),
  ('alertas.bici_inactiva_dias', 'Alertas', 'Alertar bicicletas sin movimiento durante estos días', 'entero', 'días', 1, 90, false, 20, null),
  ('retencion.fotos_dias', 'Retención de datos', 'Días que se conserva la foto de un préstamo devuelto sin novedad', 'entero', 'días', 1, 365, true, 10, null),
  ('retencion.preinscripcion_sin_validar_dias', 'Retención de datos', 'Días tras los que se elimina una preinscripción nunca validada', 'entero', 'días', 7, 730, true, 20, null),
  ('retencion.bitacora_meses', 'Retención de datos', 'Meses que se conserva la bitácora de consultas de datos personales', 'entero', 'meses', 6, 60, true, 40, null),
  ('retencion.anonimizar_inactivos_meses', 'Retención de datos', 'Meses sin préstamos tras los que se anonimiza a una persona', 'entero', 'meses', 6, 120, true, 30, null),
  ('evidencia.foto_persona_obligatoria', 'Evidencia', 'Sí: la foto del préstamo muestra a la persona con la bici. No: solo la bici con su sticker', 'booleano', null, null, null, true, 10, 'true');

-- Auditoría y trazabilidad ---------------------------------------------------
create table public.auditoria (
  id bigint generated always as identity primary key,
  ocurrido_en timestamptz not null default now(),
  actor_id uuid,                       -- auth.uid(); NULL = sistema o servicio
  tabla text not null,
  operacion text not null check (operacion in ('INSERT', 'UPDATE', 'DELETE')),
  registro_id text,
  antes jsonb,
  despues jsonb,
  accion text,                         -- p. ej. 'prestamo.anular' (de app.accion)
  motivo text                          -- de app.motivo
);
create index auditoria_registro on public.auditoria (tabla, registro_id);
create index auditoria_fecha on public.auditoria (ocurrido_en desc);

create table public.bitacora_consultas (
  id bigint generated always as identity primary key,
  en timestamptz not null default now(),
  actor_id uuid not null,
  tipo text not null check (tipo in ('buscar_persona', 'ver_persona', 'exportar')),
  huella_documento text,
  encontrada boolean,
  con_datos_personales boolean not null default false,
  motivo text check (length(motivo) <= 500),
  detalle jsonb
);
create index bitacora_actor_fecha on public.bitacora_consultas (actor_id, en desc);

-- RLS activa desde que las tablas existen (revisión de seguridad M-3). Sin políticas,
-- ningún rol de la API ve nada; las políticas y los permisos se conceden en
-- 20261007120400_permisos.sql.
alter table public.tipos_documento       enable row level security;
alter table public.personal              enable row level security;
alter table public.acudientes            enable row level security;
alter table public.personas              enable row level security;
alter table public.politicas_tratamiento enable row level security;
alter table public.autorizaciones_datos  enable row level security;
alter table public.eventos               enable row level security;
alter table public.puntos                enable row level security;
alter table public.bicicletas            enable row level security;
alter table public.disponibilidad_puntos enable row level security;
alter table public.prestamos             enable row level security;
alter table public.incidencias           enable row level security;
alter table public.sanciones             enable row level security;
alter table public.parametros            enable row level security;
alter table public.auditoria             enable row level security;
alter table public.bitacora_consultas    enable row level security;
