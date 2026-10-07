-- Funciones del sistema (RPC). Diseño: docs/diseno-detallado.md §4 y §5.
--
-- Todas son SECURITY DEFINER con search_path vacío y nombres de esquema completos.
-- Los errores se lanzan con un código corto en el mensaje (p. ej. 'bici_ya_prestada');
-- src/lib/errores.js los traduce a español. Ningún error se silencia.
-- Los permisos (quién puede ejecutar cada una) están en la migración de permisos.

-- ============================================================================
-- Auxiliares (esquema privado, no expuesto)
-- ============================================================================

create function privado.rol_actual() returns public.rol_personal
language sql stable security definer set search_path = '' as $$
  select p.rol from public.personal p where p.id = (select auth.uid()) and p.activo
$$;

create function privado.es_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(privado.rol_actual() = 'administrador', false)
$$;

create function privado.es_personal() returns boolean
language sql stable security definer set search_path = '' as $$
  select privado.rol_actual() is not null
$$;

create function privado.exigir_rol(variadic p_roles public.rol_personal[]) returns public.rol_personal
language plpgsql stable security definer set search_path = '' as $$
declare
  v_rol public.rol_personal := privado.rol_actual();
begin
  if v_rol is null or not (v_rol = any (p_roles)) then
    raise exception using message = 'no_autorizado', errcode = '42501';
  end if;
  return v_rol;
end $$;

-- Deja constancia de qué hace la función y por qué (lo recoge privado.auditar).
create function privado.registrar_accion(p_accion text, p_motivo text default null) returns void
language sql volatile set search_path = '' as $$
  select set_config('app.accion', p_accion, true), set_config('app.motivo', coalesce(p_motivo, ''), true);
$$;

create function privado.parametro(p_clave text) returns jsonb
language sql stable security definer set search_path = '' as $$
  select p.valor from public.parametros p where p.clave = p_clave
$$;

create function privado.parametro_entero(p_clave text) returns integer
language sql stable set search_path = '' as $$
  select (privado.parametro(p_clave) #>> '{}')::integer
$$;

create function privado.parametro_hora(p_clave text) returns time
language sql stable set search_path = '' as $$
  select (privado.parametro(p_clave) #>> '{}')::time
$$;

create function privado.parametro_booleano(p_clave text) returns boolean
language sql stable set search_path = '' as $$
  select (privado.parametro(p_clave) #>> '{}')::boolean
$$;

create function privado.ahora_local() returns timestamp
language sql stable set search_path = '' as $$
  select now() at time zone 'America/Bogota'
$$;

-- Edad estimada hoy = edad declarada + años completos transcurridos desde la declaración.
create function privado.edad_estimada(p_edad smallint, p_declarada_en date) returns integer
language sql stable set search_path = '' as $$
  select p_edad + date_part('year', age(current_date, p_declarada_en))::integer
$$;

create function privado.enmascarar(p_valor text) returns text
language sql immutable set search_path = '' as $$
  select case when p_valor is null then null
              when length(p_valor) <= 4 then repeat('*', length(p_valor))
              else repeat('*', 4) || right(p_valor, 4) end
$$;

create function privado.a_uuid(p_texto text, p_error text) returns uuid
language plpgsql immutable set search_path = '' as $$
begin
  return p_texto::uuid;
exception when invalid_text_representation then
  raise exception using message = p_error;
end $$;

-- Limpieza y validación de datos de entrada ---------------------------------
create function privado.limpiar_documento(p_tipo text, p_numero text) returns text[]
language plpgsql stable security definer set search_path = '' as $$
declare
  v_tipo public.tipos_documento;
  v_numero text := upper(regexp_replace(coalesce(p_numero, ''), '[^0-9A-Za-z]', '', 'g'));
begin
  select * into v_tipo from public.tipos_documento t where t.codigo = upper(btrim(coalesce(p_tipo, ''))) and t.activo;
  if not found then
    raise exception using message = 'tipo_documento_invalido';
  end if;
  if v_numero !~ v_tipo.patron then
    raise exception using message = 'documento_invalido';
  end if;
  return array[v_tipo.codigo, v_numero];
end $$;

create function privado.limpiar_nombre(p_valor text) returns text
language plpgsql immutable set search_path = '' as $$
declare
  v text := regexp_replace(btrim(coalesce(p_valor, '')), '\s+', ' ', 'g');
begin
  if length(v) < 1 or length(v) > 80 or v ~ '[0-9<>{}@]' then
    raise exception using message = 'nombre_invalido';
  end if;
  return v;
end $$;

create function privado.limpiar_telefono(p_valor text) returns text
language plpgsql immutable set search_path = '' as $$
declare
  v text := regexp_replace(btrim(coalesce(p_valor, '')), '[^0-9+]', '', 'g');
begin
  if v !~ '^\+?[0-9]{7,15}$' then
    raise exception using message = 'telefono_invalido';
  end if;
  return v;
end $$;

create function privado.limpiar_correo(p_valor text) returns text
language plpgsql immutable set search_path = '' as $$
declare
  v text := nullif(lower(btrim(coalesce(p_valor, ''))), '');
begin
  if v is not null and (length(v) > 120 or v !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$') then
    raise exception using message = 'correo_invalido';
  end if;
  return v;
end $$;

create function privado.limpiar_edad(p_valor text) returns smallint
language plpgsql immutable set search_path = '' as $$
begin
  if coalesce(btrim(p_valor), '') !~ '^[0-9]{1,3}$' or btrim(p_valor)::integer not between 5 and 110 then
    raise exception using message = 'edad_invalida';
  end if;
  return btrim(p_valor)::smallint;
end $$;

create function privado.limpiar_sexo(p_valor text) returns public.sexo_genero
language plpgsql immutable set search_path = '' as $$
begin
  if p_valor is null or not (p_valor = any (enum_range(null::public.sexo_genero)::text[])) then
    raise exception using message = 'sexo_genero_invalido';
  end if;
  return p_valor::public.sexo_genero;
end $$;

-- Disponibilidad que corresponde a una bici según su condición y su punto.
create function privado.disponibilidad_para(p_condicion public.condicion_bici, p_punto uuid)
returns public.disponibilidad_bici
language sql stable security definer set search_path = '' as $$
  select case
    when p_condicion <> 'operativa' or p_punto is null then 'no_disponible'::public.disponibilidad_bici
    when exists (select 1 from public.puntos p where p.id = p_punto and (p.tipo = 'taller' or p.estado = 'cerrado'))
      then 'no_disponible'::public.disponibilidad_bici
    else 'disponible'::public.disponibilidad_bici
  end
$$;

-- ============================================================================
-- Personas, acudientes y autorizaciones
-- ============================================================================

-- Registra una autorización de tratamiento sobre la política vigente.
-- Quién autoriza lo decide el sistema (no el cliente): titular si es adulto,
-- acudiente si es menor, con constancia de que se escuchó al menor.
create function privado.crear_autorizacion(p_persona uuid, p_aut jsonb, p_canal public.canal, p_operador uuid)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_per record;
  v_pol record;
  v_es_menor boolean;
  v_id uuid;
begin
  if p_aut is null or jsonb_typeof(p_aut) <> 'object' then
    raise exception using message = 'falta_autorizacion';
  end if;

  select per.*, t.implica_menor into v_per
    from public.personas per join public.tipos_documento t on t.codigo = per.tipo_documento
   where per.id = p_persona;
  if not found then
    raise exception using message = 'persona_no_existe';
  end if;
  v_es_menor := v_per.implica_menor or privado.edad_estimada(v_per.edad_declarada, v_per.edad_declarada_en) < 18;

  select pt.id, pt.version into v_pol from public.politicas_tratamiento pt where pt.vigente;
  if not found then
    raise exception using message = 'sin_politica_vigente';
  end if;
  if coalesce(p_aut ->> 'politica_version', '') <> v_pol.version then
    raise exception using message = 'politica_desactualizada';
  end if;
  if coalesce((p_aut ->> 'autoriza_tratamiento')::boolean, false) is not true then
    raise exception using message = 'falta_autorizacion';
  end if;
  if v_es_menor then
    if v_per.acudiente_id is null then
      raise exception using message = 'falta_acudiente';
    end if;
    if coalesce((p_aut ->> 'menor_escuchado')::boolean, false) is not true then
      raise exception using message = 'falta_menor_escuchado';
    end if;
  end if;

  v_id := coalesce(privado.a_uuid(nullif(p_aut ->> 'id', ''), 'id_operacion_invalido'), gen_random_uuid());
  if exists (select 1 from public.autorizaciones_datos a where a.id = v_id) then
    return v_id;  -- reintento de la misma operación
  end if;

  -- Una nueva autorización sobre la misma política reemplaza a la anterior.
  update public.autorizaciones_datos a
     set estado = 'revocada', revocada_en = now(), motivo_revocacion = 'reemplazada por una nueva autorización'
   where a.persona_id = p_persona and a.politica_id = v_pol.id and a.estado = 'vigente';

  insert into public.autorizaciones_datos
    (id, persona_id, politica_id, otorgada_por, acudiente_id, menor_escuchado,
     autoriza_tratamiento, autoriza_foto, canal, registrada_por)
  values
    (v_id, p_persona, v_pol.id,
     case when v_es_menor then 'acudiente'::public.otorgante else 'titular'::public.otorgante end,
     case when v_es_menor then v_per.acudiente_id end,
     case when v_es_menor then true end,
     true,
     coalesce((p_aut ->> 'autoriza_foto')::boolean, false),
     p_canal,
     case when p_canal = 'punto' then p_operador end);
  return v_id;
end $$;

-- Crea una persona (y su acudiente si es menor) con su autorización.
-- Si el documento ya existe NO modifica nada y responde 'ya_inscrito'.
create function privado.crear_persona(p jsonb, p_canal public.canal, p_operador uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_id_op uuid;
  v_doc text[];
  v_existente uuid;
  v_tipo public.tipos_documento;
  v_nombres text;
  v_apellidos text;
  v_telefono text;
  v_correo text;
  v_edad smallint;
  v_sexo public.sexo_genero;
  v_es_menor boolean;
  v_acu jsonb := p -> 'acudiente';
  v_acu_doc text[];
  v_acu_tipo public.tipos_documento;
  v_acu_id uuid;
  v_parentesco text;
  v_persona uuid;
begin
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception using message = 'datos_invalidos';
  end if;
  v_id_op := privado.a_uuid(p ->> 'id_operacion', 'id_operacion_invalido');
  if v_id_op is null then
    raise exception using message = 'id_operacion_invalido';
  end if;

  select per.id into v_persona from public.personas per where per.id_operacion = v_id_op;
  if found then
    return jsonb_build_object('resultado', 'inscrito', 'persona_id', v_persona);  -- reintento
  end if;

  v_doc := privado.limpiar_documento(p ->> 'tipo_documento', p ->> 'numero_documento');
  select per.id into v_existente from public.personas per
   where per.tipo_documento = v_doc[1] and per.numero_documento = v_doc[2];
  if found then
    return jsonb_build_object('resultado', 'ya_inscrito', 'persona_id', v_existente);
  end if;

  select * into v_tipo from public.tipos_documento t where t.codigo = v_doc[1];
  v_nombres := privado.limpiar_nombre(p ->> 'nombres');
  v_apellidos := privado.limpiar_nombre(p ->> 'apellidos');
  v_telefono := privado.limpiar_telefono(p ->> 'telefono');
  v_correo := privado.limpiar_correo(p ->> 'correo');
  v_edad := privado.limpiar_edad(p ->> 'edad');
  v_sexo := privado.limpiar_sexo(p ->> 'sexo_genero');
  -- La cédula de ciudadanía solo la tienen mayores de edad.
  if v_tipo.codigo = 'CC' and v_edad < 18 then
    raise exception using message = 'edad_no_coincide_documento';
  end if;
  v_es_menor := v_tipo.implica_menor or v_edad < 18;

  if v_es_menor then
    if v_acu is null or jsonb_typeof(v_acu) <> 'object' then
      raise exception using message = 'falta_acudiente';
    end if;
    v_acu_doc := privado.limpiar_documento(v_acu ->> 'tipo_documento', v_acu ->> 'numero_documento');
    select * into v_acu_tipo from public.tipos_documento t where t.codigo = v_acu_doc[1];
    if v_acu_tipo.implica_menor then
      raise exception using message = 'acudiente_debe_ser_adulto';
    end if;
    if v_acu_doc = v_doc then
      raise exception using message = 'acudiente_es_la_misma_persona';
    end if;
    v_parentesco := v_acu ->> 'parentesco';
    if v_parentesco is null or v_parentesco not in ('madre', 'padre', 'representante_legal') then
      raise exception using message = 'parentesco_invalido';
    end if;
    select a.id into v_acu_id from public.acudientes a
     where a.tipo_documento = v_acu_doc[1] and a.numero_documento = v_acu_doc[2];
    if not found then
      insert into public.acudientes (tipo_documento, numero_documento, nombres, apellidos, telefono, correo)
      values (v_acu_doc[1], v_acu_doc[2],
              privado.limpiar_nombre(v_acu ->> 'nombres'), privado.limpiar_nombre(v_acu ->> 'apellidos'),
              privado.limpiar_telefono(v_acu ->> 'telefono'), privado.limpiar_correo(v_acu ->> 'correo'))
      returning id into v_acu_id;
    end if;
  end if;

  begin
    insert into public.personas
      (tipo_documento, numero_documento, nombres, apellidos, telefono, correo, edad_declarada,
       sexo_genero, acudiente_id, acudiente_parentesco, estado, origen, validada_en, validada_por, id_operacion)
    values
      (v_doc[1], v_doc[2], v_nombres, v_apellidos, v_telefono, v_correo, v_edad,
       v_sexo, v_acu_id, case when v_es_menor then v_parentesco end,
       case when p_canal = 'punto' then 'validada'::public.estado_inscripcion else 'preinscrita'::public.estado_inscripcion end,
       p_canal,
       case when p_canal = 'punto' then now() end,
       case when p_canal = 'punto' then p_operador end,
       v_id_op)
    returning id into v_persona;
  exception when unique_violation then
    -- Otra solicitud inscribió el mismo documento al mismo tiempo.
    select per.id into v_existente from public.personas per
     where per.tipo_documento = v_doc[1] and per.numero_documento = v_doc[2];
    return jsonb_build_object('resultado', 'ya_inscrito', 'persona_id', v_existente);
  end;

  perform privado.crear_autorizacion(v_persona, p -> 'autorizacion', p_canal, p_operador);
  return jsonb_build_object('resultado', 'inscrito', 'persona_id', v_persona);
end $$;

-- Resumen de una persona para el operador (sin documento ni teléfono completos).
create function privado.resumen_persona(p_persona uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v record;
  v_edad integer;
  v_es_menor boolean;
  v_aut record;
  v_acu record;
  v_sancion record;
  v_activos integer;
  v_pol_version text;
begin
  select per.*, t.implica_menor, t.nombre as tipo_nombre into v
    from public.personas per join public.tipos_documento t on t.codigo = per.tipo_documento
   where per.id = p_persona and per.estado <> 'anonimizada';
  if not found then
    return null;
  end if;
  v_edad := privado.edad_estimada(v.edad_declarada, v.edad_declarada_en);
  v_es_menor := v.implica_menor or v_edad < 18;

  select pt.version into v_pol_version from public.politicas_tratamiento pt where pt.vigente;
  select a.id, a.autoriza_foto into v_aut
    from public.autorizaciones_datos a join public.politicas_tratamiento pt on pt.id = a.politica_id and pt.vigente
   where a.persona_id = v.id and a.estado = 'vigente';
  select a.nombres, a.apellidos, a.telefono, a.numero_documento, a.tipo_documento into v_acu
    from public.acudientes a where a.id = v.acudiente_id;
  select s.hasta, s.motivo into v_sancion
    from public.sanciones s
   where s.persona_id = v.id and s.estado = 'vigente' and s.tipo = 'suspension'
     and current_date between s.desde and s.hasta
   order by s.hasta desc limit 1;
  select count(*)::integer into v_activos from public.prestamos pr where pr.persona_id = v.id and pr.estado = 'activo';

  return jsonb_build_object(
    'id', v.id,
    'tipo_documento', v.tipo_documento,
    'tipo_documento_nombre', v.tipo_nombre,
    'documento_enmascarado', privado.enmascarar(v.numero_documento),
    'nombres', v.nombres,
    'apellidos', v.apellidos,
    'telefono_enmascarado', privado.enmascarar(v.telefono),
    'edad_estimada', v_edad,
    'es_menor', v_es_menor,
    'estado', v.estado,
    'acudiente', case when v_acu.nombres is not null then jsonb_build_object(
        'nombres', v_acu.nombres, 'apellidos', v_acu.apellidos,
        'parentesco', v.acudiente_parentesco,
        'tipo_documento', v_acu.tipo_documento,
        'documento_enmascarado', privado.enmascarar(v_acu.numero_documento),
        'telefono_enmascarado', privado.enmascarar(v_acu.telefono)) end,
    'politica_vigente', v_pol_version,
    'autorizacion_vigente', v_aut.id is not null,
    'autoriza_foto', coalesce(v_aut.autoriza_foto, false),
    'sancion', case when v_sancion.hasta is not null then
        jsonb_build_object('hasta', v_sancion.hasta, 'motivo', v_sancion.motivo) end,
    'prestamos_activos', v_activos
  );
end $$;

-- ============================================================================
-- RPC públicas
-- ============================================================================

-- Perfil del usuario autenticado (NULL si no es personal activo).
create function public.mi_perfil() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', p.id, 'nombre', p.nombre, 'rol', p.rol, 'debe_cambiar_clave', p.debe_cambiar_clave)
    from public.personal p where p.id = (select auth.uid()) and p.activo
$$;

create function public.marcar_clave_cambiada() returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform privado.exigir_rol('operador', 'administrador');
  update public.personal set debe_cambiar_clave = false where id = auth.uid() and debe_cambiar_clave;
end $$;

-- Preinscripción pública. Solo la ejecuta la Edge Function `preinscribir`
-- (con Turnstile y límite de tasa); responde solo el resultado, sin datos.
create function public.preinscribir(p jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v jsonb;
begin
  perform privado.registrar_accion('persona.preinscribir');
  v := privado.crear_persona(p, 'web', null);
  return jsonb_build_object('resultado', v ->> 'resultado');
end $$;

create function public.registrar_persona_en_punto(p jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform privado.exigir_rol('operador', 'administrador');
  perform privado.registrar_accion('persona.inscribir_en_punto');
  return privado.crear_persona(p, 'punto', auth.uid());
end $$;

-- Búsqueda exacta por documento. Cada búsqueda queda en la bitácora.
create function public.buscar_persona(p_tipo text, p_numero text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_doc text[];
  v_id uuid;
begin
  perform privado.exigir_rol('operador', 'administrador');
  v_doc := privado.limpiar_documento(p_tipo, p_numero);
  select per.id into v_id from public.personas per
   where per.tipo_documento = v_doc[1] and per.numero_documento = v_doc[2] and per.estado <> 'anonimizada';
  insert into public.bitacora_consultas (actor_id, tipo, huella_documento, encontrada, con_datos_personales)
  values (auth.uid(), 'buscar_persona', privado.huella(v_doc[1] || ':' || v_doc[2]), v_id is not null, v_id is not null);
  if v_id is null then
    return null;
  end if;
  return privado.resumen_persona(v_id);
end $$;

-- Validación presencial (documento exhibido, nunca retenido) con correcciones
-- opcionales y, si hace falta, una nueva autorización.
create function public.validar_persona(p_persona_id uuid, p_correcciones jsonb default '{}'::jsonb,
                                       p_autorizacion jsonb default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v public.personas;
  v_c jsonb := coalesce(p_correcciones, '{}'::jsonb);
  v_tipo public.tipos_documento;
begin
  perform privado.exigir_rol('operador', 'administrador');
  select * into v from public.personas per where per.id = p_persona_id and per.estado <> 'anonimizada' for update;
  if not found then
    raise exception using message = 'persona_no_existe';
  end if;
  perform privado.registrar_accion('persona.validar');

  if v_c ? 'nombres' then v.nombres := privado.limpiar_nombre(v_c ->> 'nombres'); end if;
  if v_c ? 'apellidos' then v.apellidos := privado.limpiar_nombre(v_c ->> 'apellidos'); end if;
  if v_c ? 'telefono' then v.telefono := privado.limpiar_telefono(v_c ->> 'telefono'); end if;
  if v_c ? 'correo' then v.correo := privado.limpiar_correo(v_c ->> 'correo'); end if;
  if v_c ? 'sexo_genero' then v.sexo_genero := privado.limpiar_sexo(v_c ->> 'sexo_genero'); end if;
  if v_c ? 'edad' then
    v.edad_declarada := privado.limpiar_edad(v_c ->> 'edad');
    v.edad_declarada_en := current_date;
  end if;

  select * into v_tipo from public.tipos_documento t where t.codigo = v.tipo_documento;
  if v_tipo.codigo = 'CC' and privado.edad_estimada(v.edad_declarada, v.edad_declarada_en) < 18 then
    raise exception using message = 'edad_no_coincide_documento';
  end if;
  if (v_tipo.implica_menor or privado.edad_estimada(v.edad_declarada, v.edad_declarada_en) < 18)
     and v.acudiente_id is null then
    raise exception using message = 'falta_acudiente';
  end if;

  update public.personas per set
    nombres = v.nombres, apellidos = v.apellidos, telefono = v.telefono, correo = v.correo,
    sexo_genero = v.sexo_genero, edad_declarada = v.edad_declarada, edad_declarada_en = v.edad_declarada_en,
    estado = 'validada',
    validada_en = coalesce(per.validada_en, now()),
    validada_por = coalesce(per.validada_por, auth.uid())
  where per.id = v.id;

  if p_autorizacion is not null then
    perform privado.crear_autorizacion(v.id, p_autorizacion, 'punto', auth.uid());
  end if;
  return privado.resumen_persona(v.id);
end $$;

create function public.registrar_autorizacion(p_persona_id uuid, p_autorizacion jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform privado.exigir_rol('operador', 'administrador');
  perform privado.registrar_accion('autorizacion.registrar');
  perform privado.crear_autorizacion(p_persona_id, p_autorizacion, 'punto', auth.uid());
  return privado.resumen_persona(p_persona_id);
end $$;

-- ============================================================================
-- Préstamo y devolución
-- ============================================================================

create function privado.resultado_prestamo(p public.prestamos) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'prestamo_id', p.id,
    'codigo', (select b.codigo from public.bicicletas b where b.id = p.bicicleta_id),
    'salida_en', p.salida_en,
    'vence_en', case when privado.parametro_entero('reglas_uso.duracion_maxima_min') is not null
                     then p.salida_en + make_interval(mins => privado.parametro_entero('reglas_uso.duracion_maxima_min')) end,
    'ahora_servidor', now())
$$;

create function public.registrar_prestamo(
  p_id uuid,
  p_persona_id uuid,
  p_numero_bici integer,
  p_punto_id uuid,
  p_foto_ruta text,
  p_salida_cliente_en timestamptz default null,
  p_observaciones text default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_bici public.bicicletas;
  v_existente public.prestamos;
  v_persona public.personas;
  v_tipo public.tipos_documento;
  v_punto public.puntos;
  v_evento public.eventos;
  v_aut record;
  v_edad integer;
  v_es_menor boolean;
  v_limite integer;
  v_cuenta integer;
  v_hora time;
  v_foto_persona boolean;
  v_nuevo public.prestamos;
begin
  perform privado.exigir_rol('operador', 'administrador');
  if p_id is null then
    raise exception using message = 'id_operacion_invalido';
  end if;

  -- 1. Bloquear la bici: dos operadores no pueden prestarla a la vez.
  select * into v_bici from public.bicicletas b where b.numero = p_numero_bici for update;
  if not found then
    raise exception using message = 'bici_no_existe';
  end if;

  -- 2. Idempotencia (después del bloqueo): reintento de la misma operación.
  select * into v_existente from public.prestamos pr where pr.id = p_id;
  if found then
    if v_existente.bicicleta_id = v_bici.id and v_existente.persona_id = p_persona_id
       and v_existente.punto_salida_id = p_punto_id then
      return privado.resultado_prestamo(v_existente);
    end if;
    raise exception using message = 'id_operacion_reutilizado';
  end if;

  -- 3. Bloquear la persona (orden fijo bici → persona para evitar interbloqueos).
  select * into v_persona from public.personas per where per.id = p_persona_id for update;
  if not found or v_persona.estado = 'anonimizada' then
    raise exception using message = 'persona_no_existe';
  end if;

  -- 4. Punto y bici.
  select * into v_punto from public.puntos p where p.id = p_punto_id;
  if not found then
    raise exception using message = 'punto_no_existe';
  end if;
  if v_punto.tipo = 'taller' then
    raise exception using message = 'punto_taller';
  end if;
  if v_punto.estado <> 'activo' then
    raise exception using message = 'punto_inactivo';
  end if;
  if v_punto.tipo = 'evento' then
    select * into v_evento from public.eventos e where e.id = v_punto.evento_id;
    if v_evento.estado <> 'en_curso' then
      raise exception using message = 'evento_no_en_curso';
    end if;
  end if;
  if v_bici.disponibilidad = 'prestada' then
    raise exception using message = 'bici_ya_prestada';
  end if;
  if v_bici.disponibilidad <> 'disponible' then
    raise exception using message = 'bici_no_disponible';
  end if;
  if v_bici.punto_actual_id is distinct from p_punto_id then
    raise exception using message = 'bici_en_otro_punto';
  end if;

  -- 5. Persona: validada, con autorización vigente, acudiente si es menor, sin sanción.
  if v_persona.estado <> 'validada' then
    raise exception using message = 'persona_no_validada';
  end if;
  select a.id, a.autoriza_foto into v_aut
    from public.autorizaciones_datos a join public.politicas_tratamiento pt on pt.id = a.politica_id and pt.vigente
   where a.persona_id = v_persona.id and a.estado = 'vigente';
  if v_aut.id is null then
    raise exception using message = 'falta_autorizacion_vigente';
  end if;
  select * into v_tipo from public.tipos_documento t where t.codigo = v_persona.tipo_documento;
  v_edad := privado.edad_estimada(v_persona.edad_declarada, v_persona.edad_declarada_en);
  v_es_menor := v_tipo.implica_menor or v_edad < 18;
  if v_es_menor and v_persona.acudiente_id is null then
    raise exception using message = 'falta_acudiente';
  end if;
  if exists (select 1 from public.sanciones s
              where s.persona_id = v_persona.id and s.estado = 'vigente' and s.tipo = 'suspension'
                and current_date between s.desde and s.hasta) then
    raise exception using message = 'persona_sancionada';
  end if;

  -- 6. Reglas configurables: solo se aplican si el parámetro tiene valor.
  v_limite := privado.parametro_entero('reglas_uso.edad_minima');
  if v_limite is not null and v_edad < v_limite then
    raise exception using message = 'edad_minima';
  end if;
  v_limite := privado.parametro_entero('reglas_uso.max_prestamos_activos_persona');
  if v_limite is not null then
    select count(*) into v_cuenta from public.prestamos pr where pr.persona_id = v_persona.id and pr.estado = 'activo';
    if v_cuenta >= v_limite then
      raise exception using message = 'limite_prestamos_activos';
    end if;
  end if;
  v_limite := privado.parametro_entero('reglas_uso.max_prestamos_dia_persona');
  if v_limite is not null then
    select count(*) into v_cuenta from public.prestamos pr
     where pr.persona_id = v_persona.id and pr.estado <> 'anulado'
       and (pr.salida_en at time zone 'America/Bogota')::date = privado.ahora_local()::date;
    if v_cuenta >= v_limite then
      raise exception using message = 'limite_prestamos_dia';
    end if;
  end if;
  v_hora := privado.ahora_local()::time;
  if (privado.parametro_hora('horario.hora_inicio_prestamos') is not null and v_hora < privado.parametro_hora('horario.hora_inicio_prestamos'))
     or (privado.parametro_hora('horario.hora_limite_prestamos') is not null and v_hora > privado.parametro_hora('horario.hora_limite_prestamos')) then
    raise exception using message = 'fuera_de_horario';
  end if;

  -- 7. Foto de evidencia: debe estar subida antes de registrar el préstamo.
  v_foto_persona := coalesce(privado.parametro_booleano('evidencia.foto_persona_obligatoria'), false);
  if v_foto_persona and not v_aut.autoriza_foto then
    raise exception using message = 'falta_autorizacion_foto';
  end if;
  if p_foto_ruta is null or p_foto_ruta !~ ('^prestamos/' || p_id::text || '/salida\.(webp|jpg)$') then
    raise exception using message = 'foto_ruta_invalida';
  end if;
  if not exists (select 1 from storage.objects o where o.bucket_id = 'evidencias' and o.name = p_foto_ruta) then
    raise exception using message = 'falta_foto';
  end if;

  -- 8. Registrar.
  perform privado.registrar_accion('prestamo.registrar');
  begin
    insert into public.prestamos
      (id, bicicleta_id, persona_id, autorizacion_id, punto_salida_id, operador_salida_id,
       salida_cliente_en, edad_estimada, es_menor, acudiente_id, foto_ruta, foto_contenido, observaciones_salida)
    values
      (p_id, v_bici.id, v_persona.id, v_aut.id, p_punto_id, auth.uid(),
       p_salida_cliente_en, v_edad, v_es_menor, case when v_es_menor then v_persona.acudiente_id end,
       p_foto_ruta,
       case when v_foto_persona then 'persona_y_bici'::public.contenido_foto else 'solo_bici'::public.contenido_foto end,
       nullif(btrim(coalesce(p_observaciones, '')), ''))
    returning * into v_nuevo;
  exception when unique_violation then
    -- Última red de seguridad: índice único de un solo préstamo activo por bici.
    raise exception using message = 'bici_ya_prestada';
  end;

  update public.bicicletas b
     set disponibilidad = 'prestada', punto_actual_id = null, ultimo_movimiento_en = now()
   where b.id = v_bici.id;

  return privado.resultado_prestamo(v_nuevo);
end $$;

create function privado.resultado_devolucion(p public.prestamos) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_min integer := ceil(extract(epoch from (p.devuelto_en - p.salida_en)) / 60.0)::integer;
  v_max integer := privado.parametro_entero('reglas_uso.duracion_maxima_min');
  v_tol integer := coalesce(privado.parametro_entero('sanciones.tolerancia_retraso_min'), 0);
begin
  return jsonb_build_object(
    'prestamo_id', p.id,
    'codigo', (select b.codigo from public.bicicletas b where b.id = p.bicicleta_id),
    'persona', (select per.nombres || ' ' || left(per.apellidos, 1) || '.' from public.personas per where per.id = p.persona_id),
    'salida_en', p.salida_en,
    'devuelto_en', p.devuelto_en,
    'duracion_min', v_min,
    'excedio', case when v_max is null then null else v_min > v_max + v_tol end,
    'ahora_servidor', now());
end $$;

create function public.registrar_devolucion(
  p_id_operacion uuid,
  p_numero_bici integer,
  p_punto_id uuid,
  p_con_novedad boolean default false,
  p_incidencia jsonb default null,
  p_observaciones text default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_bici public.bicicletas;
  v_pr public.prestamos;
  v_punto public.puntos;
  v_tipo text;
  v_gravedad text;
  v_desc text;
  v_fuera boolean := false;
  v_condicion public.condicion_bici;
begin
  perform privado.exigir_rol('operador', 'administrador');
  if p_id_operacion is null then
    raise exception using message = 'id_operacion_invalido';
  end if;

  select * into v_bici from public.bicicletas b where b.numero = p_numero_bici for update;
  if not found then
    raise exception using message = 'bici_no_existe';
  end if;

  -- Idempotencia: reintento de la misma devolución.
  select * into v_pr from public.prestamos pr where pr.devolucion_id_operacion = p_id_operacion;
  if found then
    if v_pr.bicicleta_id <> v_bici.id then
      raise exception using message = 'id_operacion_reutilizado';
    end if;
    return privado.resultado_devolucion(v_pr);
  end if;

  select * into v_pr from public.prestamos pr where pr.bicicleta_id = v_bici.id and pr.estado = 'activo' for update;
  if not found then
    raise exception using message = 'bici_no_prestada';
  end if;

  select * into v_punto from public.puntos p where p.id = p_punto_id;
  if not found then
    raise exception using message = 'punto_no_existe';
  end if;
  if v_punto.estado <> 'activo' and v_punto.tipo <> 'taller' then
    raise exception using message = 'punto_inactivo';
  end if;

  if coalesce(p_con_novedad, false) then
    if p_incidencia is null or jsonb_typeof(p_incidencia) <> 'object' then
      raise exception using message = 'falta_incidencia';
    end if;
    v_tipo := p_incidencia ->> 'tipo';
    v_gravedad := p_incidencia ->> 'gravedad';
    v_desc := btrim(coalesce(p_incidencia ->> 'descripcion', ''));
    if v_tipo is null or not (v_tipo = any (enum_range(null::public.tipo_incidencia)::text[])) then
      raise exception using message = 'incidencia_tipo_invalido';
    end if;
    if v_gravedad is null or not (v_gravedad = any (enum_range(null::public.gravedad)::text[])) then
      raise exception using message = 'incidencia_gravedad_invalida';
    end if;
    if length(v_desc) < 5 then
      raise exception using message = 'incidencia_descripcion_corta';
    end if;
    v_fuera := coalesce((p_incidencia ->> 'deja_fuera_de_servicio')::boolean, false);
  end if;

  perform privado.registrar_accion('prestamo.devolver');
  update public.prestamos pr set
    estado = 'finalizado',
    devolucion_id_operacion = p_id_operacion,
    punto_devolucion_id = p_punto_id,
    operador_devolucion_id = auth.uid(),
    devuelto_en = now(),
    con_novedad = coalesce(p_con_novedad, false),
    observaciones_devolucion = nullif(btrim(coalesce(p_observaciones, '')), '')
  where pr.id = v_pr.id
  returning * into v_pr;

  if coalesce(p_con_novedad, false) then
    insert into public.incidencias
      (bicicleta_id, prestamo_id, tipo, gravedad, descripcion, deja_fuera_de_servicio, reportada_por, foto_ruta)
    values
      (v_bici.id, v_pr.id, v_tipo::public.tipo_incidencia, v_gravedad::public.gravedad, v_desc, v_fuera,
       auth.uid(), nullif(p_incidencia ->> 'foto_ruta', ''));
  end if;

  v_condicion := case when v_fuera then 'averiada'::public.condicion_bici else v_bici.condicion end;
  update public.bicicletas b set
    punto_actual_id = p_punto_id,
    condicion = v_condicion,
    disponibilidad = privado.disponibilidad_para(v_condicion, p_punto_id),
    ultimo_movimiento_en = now()
  where b.id = v_bici.id;

  return privado.resultado_devolucion(v_pr);
end $$;

create function public.prestamos_activos(p_punto_id uuid default null)
returns table (
  prestamo_id uuid, codigo text, numero integer, persona text, es_menor boolean,
  punto_salida text, salida_en timestamptz, vence_en timestamptz, ahora_servidor timestamptz
)
language plpgsql stable security definer set search_path = '' as $$
declare
  v_max integer := privado.parametro_entero('reglas_uso.duracion_maxima_min');
begin
  perform privado.exigir_rol('operador', 'administrador');
  return query
    select pr.id, b.codigo, b.numero, per.nombres || ' ' || left(per.apellidos, 1) || '.', pr.es_menor,
           pu.codigo || ' · ' || pu.nombre, pr.salida_en,
           case when v_max is not null then pr.salida_en + make_interval(mins => v_max) end,
           now()
      from public.prestamos pr
      join public.bicicletas b on b.id = pr.bicicleta_id
      join public.personas per on per.id = pr.persona_id
      join public.puntos pu on pu.id = pr.punto_salida_id
     where pr.estado = 'activo' and (p_punto_id is null or pr.punto_salida_id = p_punto_id)
     order by pr.salida_en;
end $$;

-- Mover bicis entre puntos (reubicación, taller). Siempre con motivo.
create function public.mover_bicis(p_numeros integer[], p_punto_destino uuid, p_motivo text) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_destino public.puntos;
  v_numero integer;
  v_bici public.bicicletas;
  v_movidas integer := 0;
begin
  perform privado.exigir_rol('operador', 'administrador');
  if length(btrim(coalesce(p_motivo, ''))) < 5 then
    raise exception using message = 'motivo_insuficiente';
  end if;
  if p_numeros is null or cardinality(p_numeros) = 0 then
    raise exception using message = 'sin_bicis';
  end if;
  select * into v_destino from public.puntos p where p.id = p_punto_destino;
  if not found then
    raise exception using message = 'punto_no_existe';
  end if;
  if v_destino.estado = 'cerrado' then
    raise exception using message = 'punto_cerrado';
  end if;

  perform privado.registrar_accion('bici.mover', btrim(p_motivo));
  for v_numero in select distinct n from unnest(p_numeros) n order by n loop
    select * into v_bici from public.bicicletas b where b.numero = v_numero for update;
    if not found then
      raise exception using message = 'bici_no_existe', detail = v_numero::text;
    end if;
    if v_bici.disponibilidad = 'prestada' then
      raise exception using message = 'bici_prestada', detail = v_numero::text;
    end if;
    if v_bici.condicion in ('extraviada', 'baja') then
      raise exception using message = 'bici_no_movible', detail = v_numero::text;
    end if;
    if v_bici.punto_actual_id is distinct from p_punto_destino then
      update public.bicicletas b set
        punto_actual_id = p_punto_destino,
        disponibilidad = privado.disponibilidad_para(v_bici.condicion, p_punto_destino),
        ultimo_movimiento_en = now()
      where b.id = v_bici.id;
      v_movidas := v_movidas + 1;
    end if;
  end loop;
  return v_movidas;
end $$;

-- Cambiar la condición física. El operador solo puede marcar 'averiada'.
create function public.cambiar_condicion_bici(p_numero integer, p_condicion public.condicion_bici,
                                              p_motivo text, p_punto_id uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_rol public.rol_personal;
  v_bici public.bicicletas;
  v_punto uuid;
begin
  v_rol := privado.exigir_rol('operador', 'administrador');
  if v_rol = 'operador' and p_condicion <> 'averiada' then
    raise exception using message = 'no_autorizado', errcode = '42501';
  end if;
  if length(btrim(coalesce(p_motivo, ''))) < 5 then
    raise exception using message = 'motivo_insuficiente';
  end if;
  select * into v_bici from public.bicicletas b where b.numero = p_numero for update;
  if not found then
    raise exception using message = 'bici_no_existe';
  end if;
  if v_bici.disponibilidad = 'prestada' then
    raise exception using message = 'bici_prestada';
  end if;

  v_punto := case when p_condicion = 'extraviada' then null else coalesce(p_punto_id, v_bici.punto_actual_id) end;
  if p_condicion not in ('extraviada', 'baja') and v_punto is null then
    raise exception using message = 'falta_punto';
  end if;
  if p_punto_id is not null and not exists (select 1 from public.puntos p where p.id = p_punto_id) then
    raise exception using message = 'punto_no_existe';
  end if;

  perform privado.registrar_accion('bici.cambiar_condicion', btrim(p_motivo));
  update public.bicicletas b set
    condicion = p_condicion,
    punto_actual_id = v_punto,
    disponibilidad = privado.disponibilidad_para(p_condicion, v_punto),
    ultimo_movimiento_en = now()
  where b.id = v_bici.id;
end $$;

-- ============================================================================
-- Administración
-- ============================================================================

create function public.crear_bicicletas(p_desde integer, p_hasta integer, p_punto_id uuid) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_creadas integer;
begin
  perform privado.exigir_rol('administrador');
  if p_desde is null or p_hasta is null or p_desde < 1 or p_hasta > 9999 or p_desde > p_hasta
     or p_hasta - p_desde >= 1000 then
    raise exception using message = 'rango_invalido';
  end if;
  if not exists (select 1 from public.puntos p where p.id = p_punto_id) then
    raise exception using message = 'punto_no_existe';
  end if;
  perform privado.registrar_accion('bici.crear');
  insert into public.bicicletas (numero, condicion, disponibilidad, punto_actual_id)
  select n, 'operativa', privado.disponibilidad_para('operativa', p_punto_id), p_punto_id
    from generate_series(p_desde, p_hasta) n
  on conflict (numero) do nothing;
  get diagnostics v_creadas = row_count;
  return v_creadas;
end $$;

-- Vincula una cuenta creada en Supabase Auth (Dashboard) con un rol de la app.
create function public.vincular_personal(p_correo text, p_nombre text, p_rol public.rol_personal) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  perform privado.exigir_rol('administrador');
  select u.id into v_id from auth.users u where lower(u.email) = lower(btrim(coalesce(p_correo, '')));
  if not found then
    raise exception using message = 'usuario_no_existe';
  end if;
  if exists (select 1 from public.personal p where p.id = v_id) then
    raise exception using message = 'ya_vinculado';
  end if;
  perform privado.registrar_accion('personal.vincular');
  insert into public.personal (id, nombre, rol, creado_por)
  values (v_id, btrim(p_nombre), p_rol, auth.uid());
  return v_id;
end $$;

create function public.anular_prestamo(p_prestamo_id uuid, p_motivo text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_bici_id uuid;
  v_bici public.bicicletas;
  v_pr public.prestamos;
begin
  perform privado.exigir_rol('administrador');
  if length(btrim(coalesce(p_motivo, ''))) < 10 then
    raise exception using message = 'motivo_insuficiente';
  end if;
  select pr.bicicleta_id into v_bici_id from public.prestamos pr where pr.id = p_prestamo_id;
  if not found then
    raise exception using message = 'prestamo_no_existe';
  end if;
  select * into v_bici from public.bicicletas b where b.id = v_bici_id for update;
  select * into v_pr from public.prestamos pr where pr.id = p_prestamo_id for update;
  if v_pr.estado <> 'activo' then
    raise exception using message = 'prestamo_no_activo';
  end if;

  perform privado.registrar_accion('prestamo.anular', btrim(p_motivo));
  update public.prestamos pr set
    estado = 'anulado', cerrado_en = now(), cerrado_por = auth.uid(), motivo_cierre = btrim(p_motivo)
  where pr.id = v_pr.id;
  update public.bicicletas b set
    punto_actual_id = v_pr.punto_salida_id,
    disponibilidad = privado.disponibilidad_para(v_bici.condicion, v_pr.punto_salida_id),
    ultimo_movimiento_en = now()
  where b.id = v_bici.id;
end $$;

create function public.forzar_devolucion(p_prestamo_id uuid, p_punto_id uuid, p_motivo text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_bici_id uuid;
  v_bici public.bicicletas;
  v_pr public.prestamos;
begin
  perform privado.exigir_rol('administrador');
  if length(btrim(coalesce(p_motivo, ''))) < 10 then
    raise exception using message = 'motivo_insuficiente';
  end if;
  select pr.bicicleta_id into v_bici_id from public.prestamos pr where pr.id = p_prestamo_id;
  if not found then
    raise exception using message = 'prestamo_no_existe';
  end if;
  if not exists (select 1 from public.puntos p where p.id = p_punto_id) then
    raise exception using message = 'punto_no_existe';
  end if;
  select * into v_bici from public.bicicletas b where b.id = v_bici_id for update;
  select * into v_pr from public.prestamos pr where pr.id = p_prestamo_id for update;
  if v_pr.estado <> 'activo' then
    raise exception using message = 'prestamo_no_activo';
  end if;

  perform privado.registrar_accion('prestamo.forzar_devolucion', btrim(p_motivo));
  update public.prestamos pr set
    estado = 'finalizado', devolucion_id_operacion = gen_random_uuid(), punto_devolucion_id = p_punto_id,
    operador_devolucion_id = auth.uid(), devuelto_en = now(), con_novedad = false,
    devolucion_forzada = true, observaciones_devolucion = btrim(p_motivo)
  where pr.id = v_pr.id
  returning * into v_pr;
  update public.bicicletas b set
    punto_actual_id = p_punto_id,
    disponibilidad = privado.disponibilidad_para(v_bici.condicion, p_punto_id),
    ultimo_movimiento_en = now()
  where b.id = v_bici.id;
  return privado.resultado_devolucion(v_pr);
end $$;

-- La bici no volvió: cierra el préstamo, marca la bici extraviada y abre una incidencia.
create function public.cerrar_no_devuelto(p_prestamo_id uuid, p_motivo text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_bici_id uuid;
  v_pr public.prestamos;
begin
  perform privado.exigir_rol('administrador');
  if length(btrim(coalesce(p_motivo, ''))) < 10 then
    raise exception using message = 'motivo_insuficiente';
  end if;
  select pr.bicicleta_id into v_bici_id from public.prestamos pr where pr.id = p_prestamo_id;
  if not found then
    raise exception using message = 'prestamo_no_existe';
  end if;
  perform 1 from public.bicicletas b where b.id = v_bici_id for update;
  select * into v_pr from public.prestamos pr where pr.id = p_prestamo_id for update;
  if v_pr.estado <> 'activo' then
    raise exception using message = 'prestamo_no_activo';
  end if;

  perform privado.registrar_accion('prestamo.cerrar_no_devuelto', btrim(p_motivo));
  update public.prestamos pr set
    estado = 'no_devuelto', cerrado_en = now(), cerrado_por = auth.uid(), motivo_cierre = btrim(p_motivo)
  where pr.id = v_pr.id;
  update public.bicicletas b set
    condicion = 'extraviada', disponibilidad = 'no_disponible', punto_actual_id = null, ultimo_movimiento_en = now()
  where b.id = v_bici_id;
  insert into public.incidencias (bicicleta_id, prestamo_id, tipo, gravedad, descripcion, deja_fuera_de_servicio, reportada_por)
  values (v_bici_id, v_pr.id, 'perdida', 'grave', btrim(p_motivo), true, auth.uid());
end $$;

-- Cierra un punto de evento. Exige que no le queden bicis.
create function public.cerrar_punto_evento(p_punto_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_punto public.puntos;
begin
  perform privado.exigir_rol('administrador');
  select * into v_punto from public.puntos p where p.id = p_punto_id for update;
  if not found then
    raise exception using message = 'punto_no_existe';
  end if;
  if exists (select 1 from public.bicicletas b where b.punto_actual_id = p_punto_id) then
    raise exception using message = 'punto_con_bicis';
  end if;
  perform privado.registrar_accion('punto.cerrar');
  update public.puntos p set estado = 'cerrado' where p.id = p_punto_id;
end $$;

-- Publica una nueva versión de la política (la anterior deja de estar vigente,
-- pero sus autorizaciones conservan su versión).
create function public.publicar_politica(p_version text, p_vigente_desde date, p_texto_md text,
                                         p_texto_autorizacion text, p_texto_autorizacion_foto text) returns smallint
language plpgsql security definer set search_path = '' as $$
declare
  v_id smallint;
begin
  perform privado.exigir_rol('administrador');
  perform privado.registrar_accion('politica.publicar');
  update public.politicas_tratamiento pt set vigente = false where pt.vigente;
  insert into public.politicas_tratamiento
    (version, vigente_desde, texto_md, texto_autorizacion, texto_autorizacion_foto, sha256, vigente, publicada_por)
  values (btrim(p_version), p_vigente_desde, p_texto_md, p_texto_autorizacion, p_texto_autorizacion_foto, '', true, auth.uid())
  returning id into v_id;
  return v_id;
end $$;

create function public.registrar_exportacion(p_con_datos_personales boolean, p_motivo text default null,
                                             p_detalle jsonb default null) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform privado.exigir_rol('administrador');
  if coalesce(p_con_datos_personales, false) and length(btrim(coalesce(p_motivo, ''))) < 10 then
    raise exception using message = 'motivo_insuficiente';
  end if;
  insert into public.bitacora_consultas (actor_id, tipo, con_datos_personales, motivo, detalle)
  values (auth.uid(), 'exportar', coalesce(p_con_datos_personales, false), nullif(btrim(coalesce(p_motivo, '')), ''), p_detalle);
end $$;

create function public.tablero_resumen() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_hoy date := privado.ahora_local()::date;
  v_max integer := privado.parametro_entero('reglas_uso.duracion_maxima_min');
begin
  perform privado.exigir_rol('administrador');
  return jsonb_build_object(
    'ahora_servidor', now(),
    'bicis', (select jsonb_build_object(
        'total', count(*),
        'disponible', count(*) filter (where disponibilidad = 'disponible'),
        'prestada', count(*) filter (where disponibilidad = 'prestada'),
        'no_disponible', count(*) filter (where disponibilidad = 'no_disponible'),
        'averiada', count(*) filter (where condicion = 'averiada'),
        'en_reparacion', count(*) filter (where condicion = 'en_reparacion'),
        'extraviada', count(*) filter (where condicion = 'extraviada'),
        'baja', count(*) filter (where condicion = 'baja'))
      from public.bicicletas),
    'prestamos_hoy', (select count(*) from public.prestamos pr
        where pr.estado <> 'anulado' and (pr.salida_en at time zone 'America/Bogota')::date = v_hoy),
    'prestamos_activos', (select count(*) from public.prestamos pr where pr.estado = 'activo'),
    'prestamos_vencidos', case when v_max is null then null else
        (select count(*) from public.prestamos pr
          where pr.estado = 'activo' and now() > pr.salida_en + make_interval(mins => v_max)) end,
    'por_hora_hoy', (select coalesce(jsonb_agg(jsonb_build_object('hora', h, 'prestamos', n) order by h), '[]'::jsonb)
        from (select extract(hour from pr.salida_en at time zone 'America/Bogota')::integer h, count(*) n
                from public.prestamos pr
               where pr.estado <> 'anulado' and (pr.salida_en at time zone 'America/Bogota')::date = v_hoy
               group by 1) t),
    'por_punto', (select coalesce(jsonb_agg(jsonb_build_object(
          'codigo', pu.codigo, 'nombre', pu.nombre, 'tipo', pu.tipo,
          'disponibles', (select count(*) from public.bicicletas b where b.punto_actual_id = pu.id and b.disponibilidad = 'disponible'),
          'total', (select count(*) from public.bicicletas b where b.punto_actual_id = pu.id)) order by pu.codigo), '[]'::jsonb)
        from public.puntos pu where pu.estado <> 'cerrado'),
    'incidencias_abiertas', (select count(*) from public.incidencias i where i.estado <> 'cerrada'),
    'preinscritas_sin_validar', (select count(*) from public.personas per where per.estado = 'preinscrita'),
    'retencion_fotos_dias', privado.parametro_entero('retencion.fotos_dias'),
    'storage_bytes', (select coalesce(sum((o.metadata ->> 'size')::bigint), 0) from storage.objects o where o.bucket_id = 'evidencias'),
    'bd_bytes', pg_database_size(current_database()),
    'ultimo_respaldo', (select max(e.fin) from privado.ejecuciones_tareas e where e.tarea = 'respaldo' and e.resultado = 'ok'),
    'ultima_purga', (select jsonb_build_object('fin', e.fin, 'resultado', e.resultado)
        from privado.ejecuciones_tareas e where e.tarea = 'purgar_fotos' order by e.inicio desc limit 1)
  );
end $$;

-- Historial para el administrador (respeta RLS de las tablas base).
create view public.v_prestamos_admin with (security_invoker = true) as
select pr.id,
       pr.estado,
       b.codigo as bici_codigo,
       b.numero as bici_numero,
       per.id as persona_id,
       per.tipo_documento,
       per.numero_documento,
       per.nombres,
       per.apellidos,
       per.sexo_genero,
       pr.edad_estimada,
       pr.es_menor,
       ps.codigo as punto_salida,
       pd.codigo as punto_devolucion,
       pr.salida_en,
       pr.devuelto_en,
       case when pr.devuelto_en is not null
            then ceil(extract(epoch from (pr.devuelto_en - pr.salida_en)) / 60.0)::integer end as duracion_min,
       pr.con_novedad,
       pr.devolucion_forzada,
       pr.foto_contenido,
       pr.foto_estado,
       pr.foto_ruta,
       os.nombre as operador_salida,
       od.nombre as operador_devolucion,
       pr.motivo_cierre
  from public.prestamos pr
  join public.bicicletas b on b.id = pr.bicicleta_id
  join public.personas per on per.id = pr.persona_id
  join public.puntos ps on ps.id = pr.punto_salida_id
  left join public.puntos pd on pd.id = pr.punto_devolucion_id
  join public.personal os on os.id = pr.operador_salida_id
  left join public.personal od on od.id = pr.operador_devolucion_id;
