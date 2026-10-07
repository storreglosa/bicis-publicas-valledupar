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

-- Espacios en blanco de cualquier tipo: los de la clase POSIX más los Unicode que
-- algunas configuraciones regionales no incluyen (U+00A0, U+2000-U+200B, U+3000...).
create function privado.espacios(p_valor text) returns text
language sql immutable set search_path = '' as $$
  select btrim(regexp_replace(coalesce(p_valor, ''),
    '[[:space:]\u00a0\u1680\u2000-\u200b\u2028\u2029\u202f\u205f\u3000\ufeff]+', ' ', 'g'))
$$;

-- Se normaliza ANTES de medir, con la misma regla del CHECK de la tabla. Si la
-- función aceptara algo que el CHECK rechaza, el error de Postgres traería en su
-- DETAIL la fila completa (revisión de seguridad A-1).
create function privado.limpiar_nombre(p_valor text) returns text
language plpgsql immutable set search_path = '' as $$
declare
  v text := privado.espacios(p_valor);
begin
  if length(v) < 1 or length(v) > 80 or v ~ '[0-9<>{}@[:cntrl:]]' then
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

create function privado.texto_libre(p_valor text, p_maximo integer default 500) returns text
language plpgsql immutable set search_path = '' as $$
declare
  v text := nullif(privado.espacios(p_valor), '');
begin
  if length(v) > p_maximo then
    raise exception using message = 'texto_demasiado_largo';
  end if;
  return v;
end $$;

create function privado.motivo(p_valor text, p_minimo integer) returns text
language plpgsql immutable set search_path = '' as $$
declare
  v text := privado.texto_libre(p_valor, 500);
begin
  if coalesce(length(v), 0) < p_minimo then
    raise exception using message = 'motivo_insuficiente';
  end if;
  return v;
end $$;

-- Un consentimiento solo vale si es el booleano true, no 'yes', 'on' ni '1'.
create function privado.booleano(p jsonb, p_clave text) returns boolean
language plpgsql immutable set search_path = '' as $$
begin
  if p is null or not (p ? p_clave) or jsonb_typeof(p -> p_clave) = 'null' then
    return null;
  end if;
  if jsonb_typeof(p -> p_clave) <> 'boolean' then
    raise exception using message = 'datos_invalidos';
  end if;
  return (p -> p_clave)::boolean;
end $$;

-- Toda lectura de datos personales por el personal queda en la bitácora. La
-- huella del documento usa la sal de la persona (se pierde al anonimizarla); de
-- un documento NO inscrito no se guarda nada más que el intento (M-1, M-4).
create function privado.registrar_consulta(p_tipo text, p_persona uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.bitacora_consultas (actor_id, tipo, huella_documento, encontrada, con_datos_personales)
  select auth.uid(), p_tipo,
         (select privado.huella(per.tipo_documento || ':' || per.numero_documento, per.sal_huella)
            from public.personas per where per.id = p_persona),
         p_persona is not null, p_persona is not null;
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
  v_dueno uuid;
begin
  if p_aut is null or jsonb_typeof(p_aut) <> 'object' then
    raise exception using message = 'falta_autorizacion';
  end if;

  select per.*, t.implica_menor into v_per
    from public.personas per join public.tipos_documento t on t.codigo = per.tipo_documento
   where per.id = p_persona and per.estado <> 'anonimizada';
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
  if privado.booleano(p_aut, 'autoriza_tratamiento') is not true then
    raise exception using message = 'falta_autorizacion';
  end if;
  if v_es_menor then
    if v_per.acudiente_id is null then
      raise exception using message = 'falta_acudiente';
    end if;
    if privado.booleano(p_aut, 'menor_escuchado') is not true then
      raise exception using message = 'falta_menor_escuchado';
    end if;
  end if;

  v_id := coalesce(privado.a_uuid(nullif(p_aut ->> 'id', ''), 'id_operacion_invalido'), gen_random_uuid());
  select a.persona_id into v_dueno from public.autorizaciones_datos a where a.id = v_id;
  if found then
    if v_dueno = p_persona then
      return v_id;  -- reintento de la misma operación
    end if;
    raise exception using message = 'id_operacion_reutilizado';
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
     coalesce(privado.booleano(p_aut, 'autoriza_foto'), false),
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
    -- No se devuelve el id ni se modifica nada. En el punto, la respuesta revela
    -- que la persona existe: queda en la bitácora como una búsqueda (M-1).
    if p_canal = 'punto' then
      perform privado.registrar_consulta('buscar_persona', v_existente);
    end if;
    return jsonb_build_object('resultado', 'ya_inscrito');
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
    -- Un acudiente ya registrado se vincula por su documento. Que de verdad sea
    -- él quien autoriza se comprueba en persona: un menor no presta sin una
    -- autorización registrada en un punto (M-2).
    select a.id into v_acu_id from public.acudientes a
     where a.tipo_documento = v_acu_doc[1] and a.numero_documento = v_acu_doc[2];
    if not found then
      begin
        insert into public.acudientes (tipo_documento, numero_documento, nombres, apellidos, telefono, correo)
        values (v_acu_doc[1], v_acu_doc[2],
                privado.limpiar_nombre(v_acu ->> 'nombres'), privado.limpiar_nombre(v_acu ->> 'apellidos'),
                privado.limpiar_telefono(v_acu ->> 'telefono'), privado.limpiar_correo(v_acu ->> 'correo'))
        returning id into v_acu_id;
      exception
        when unique_violation then
          select a.id into v_acu_id from public.acudientes a
           where a.tipo_documento = v_acu_doc[1] and a.numero_documento = v_acu_doc[2];
        when check_violation or not_null_violation then
          -- Se relanza SIN el DETAIL de Postgres, que traería la fila completa (A-1).
          raise exception using message = 'datos_invalidos';
      end;
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
  exception
    when unique_violation then
      -- Otra solicitud inscribió el mismo documento al mismo tiempo.
      return jsonb_build_object('resultado', 'ya_inscrito');
    when check_violation or not_null_violation or foreign_key_violation then
      raise exception using message = 'datos_invalidos';  -- sin DETAIL (A-1)
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
  -- Límite por persona del personal: una cuenta comprometida no puede recorrer
  -- documentos en masa (B-10). 120 búsquedas en 10 minutos sobra para un punto.
  if (select count(*) from public.bitacora_consultas b
       where b.actor_id = auth.uid() and b.tipo = 'buscar_persona' and b.en > now() - interval '10 minutes') >= 120 then
    raise exception using message = 'demasiadas_busquedas';
  end if;
  v_doc := privado.limpiar_documento(p_tipo, p_numero);
  select per.id into v_id from public.personas per
   where per.tipo_documento = v_doc[1] and per.numero_documento = v_doc[2] and per.estado <> 'anonimizada';
  perform privado.registrar_consulta('buscar_persona', v_id);
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
  v_es_menor boolean;
begin
  perform privado.exigir_rol('operador', 'administrador');
  select * into v from public.personas per where per.id = p_persona_id and per.estado <> 'anonimizada' for update;
  if not found then
    raise exception using message = 'persona_no_existe';
  end if;
  perform privado.registrar_accion('persona.validar');
  perform privado.registrar_consulta('ver_persona', v.id);

  if v_c ? 'nombres' then v.nombres := privado.limpiar_nombre(v_c ->> 'nombres'); end if;
  if v_c ? 'apellidos' then v.apellidos := privado.limpiar_nombre(v_c ->> 'apellidos'); end if;
  if v_c ? 'telefono' then v.telefono := privado.limpiar_telefono(v_c ->> 'telefono'); end if;
  if v_c ? 'correo' then v.correo := privado.limpiar_correo(v_c ->> 'correo'); end if;
  if v_c ? 'sexo_genero' then v.sexo_genero := privado.limpiar_sexo(v_c ->> 'sexo_genero'); end if;
  if v_c ? 'edad' then
    v.edad_declarada := privado.limpiar_edad(v_c ->> 'edad');
    v.edad_declarada_en := current_date;
  end if;
  if v_c ? 'acudiente_parentesco' then
    if v.acudiente_id is null or coalesce(v_c ->> 'acudiente_parentesco', '') not in ('madre', 'padre', 'representante_legal') then
      raise exception using message = 'parentesco_invalido';
    end if;
    v.acudiente_parentesco := v_c ->> 'acudiente_parentesco';
  end if;

  select * into v_tipo from public.tipos_documento t where t.codigo = v.tipo_documento;
  if v_tipo.codigo = 'CC' and privado.edad_estimada(v.edad_declarada, v.edad_declarada_en) < 18 then
    raise exception using message = 'edad_no_coincide_documento';
  end if;
  v_es_menor := v_tipo.implica_menor or privado.edad_estimada(v.edad_declarada, v.edad_declarada_en) < 18;
  if v_es_menor and v.acudiente_id is null then
    raise exception using message = 'falta_acudiente';
  end if;

  begin
    update public.personas per set
      nombres = v.nombres, apellidos = v.apellidos, telefono = v.telefono, correo = v.correo,
      sexo_genero = v.sexo_genero, edad_declarada = v.edad_declarada, edad_declarada_en = v.edad_declarada_en,
      acudiente_parentesco = v.acudiente_parentesco,
      estado = 'validada',
      validada_en = coalesce(per.validada_en, now()),
      validada_por = coalesce(per.validada_por, auth.uid())
    where per.id = v.id;
  exception when check_violation or not_null_violation then
    raise exception using message = 'datos_invalidos';  -- sin DETAIL (A-1)
  end;

  if p_autorizacion is not null then
    perform privado.crear_autorizacion(v.id, p_autorizacion, 'punto', auth.uid());
  end if;

  -- Un menor solo queda validado si su acudiente autorizó EN PERSONA, en un
  -- punto, sobre la política vigente (M-2).
  if v_es_menor and not exists (
      select 1 from public.autorizaciones_datos a
        join public.politicas_tratamiento pt on pt.id = a.politica_id and pt.vigente
       where a.persona_id = v.id and a.estado = 'vigente' and a.canal = 'punto') then
    raise exception using message = 'falta_autorizacion_presencial';
  end if;
  return privado.resumen_persona(v.id);
end $$;

create function public.registrar_autorizacion(p_persona_id uuid, p_autorizacion jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform privado.exigir_rol('operador', 'administrador');
  perform privado.registrar_accion('autorizacion.registrar');
  perform privado.crear_autorizacion(p_persona_id, p_autorizacion, 'punto', auth.uid());
  perform privado.registrar_consulta('ver_persona', p_persona_id);
  return privado.resumen_persona(p_persona_id);
end $$;

-- ============================================================================
-- Préstamo y devolución
-- ============================================================================

create function privado.resultado_prestamo(p public.prestamos) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'prestamo_id', p.id,
    'estado', p.estado,
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
  v_observaciones text;
  v_nuevo public.prestamos;
begin
  perform privado.exigir_rol('operador', 'administrador');
  if p_id is null then
    raise exception using message = 'id_operacion_invalido';
  end if;
  v_observaciones := privado.texto_libre(p_observaciones, 500);

  -- Orden de bloqueo en todo el sistema: bici → persona → punto (compartido) → proyección.
  -- 1. Bloquear la bici: dos operadores no pueden prestarla a la vez.
  select * into v_bici from public.bicicletas b where b.numero = p_numero_bici for update;
  if not found then
    raise exception using message = 'bici_no_existe';
  end if;

  -- 2. Idempotencia (después del bloqueo): reintento de la misma operación.
  --    El resultado incluye el estado actual del préstamo (B-1).
  select * into v_existente from public.prestamos pr where pr.id = p_id;
  if found then
    if v_existente.bicicleta_id = v_bici.id and v_existente.persona_id = p_persona_id
       and v_existente.punto_salida_id = p_punto_id then
      return privado.resultado_prestamo(v_existente);
    end if;
    raise exception using message = 'id_operacion_reutilizado';
  end if;

  -- 3. Bloquear la persona.
  select * into v_persona from public.personas per where per.id = p_persona_id for update;
  if not found or v_persona.estado = 'anonimizada' then
    raise exception using message = 'persona_no_existe';
  end if;

  -- 4. Punto (bloqueo compartido: choca con el cierre del punto, B-4) y bici.
  select * into v_punto from public.puntos p where p.id = p_punto_id for share;
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
  select a.id, a.autoriza_foto, a.canal into v_aut
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
  -- Un menor presta solo si su acudiente autorizó en persona, en un punto (M-2).
  if v_es_menor and v_aut.canal <> 'punto' then
    raise exception using message = 'falta_autorizacion_presencial';
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

  -- 7. Foto de evidencia: subida antes de registrar, atada al id del préstamo y
  --    con un tamaño mínimo de foto real (B-2).
  v_foto_persona := coalesce(privado.parametro_booleano('evidencia.foto_persona_obligatoria'), false);
  if v_foto_persona and not v_aut.autoriza_foto then
    raise exception using message = 'falta_autorizacion_foto';
  end if;
  if p_foto_ruta is null or p_foto_ruta !~ ('^prestamos/' || p_id::text || '/salida\.(webp|jpg)$') then
    raise exception using message = 'foto_ruta_invalida';
  end if;
  if not exists (select 1 from storage.objects o
                  where o.bucket_id = 'evidencias' and o.name = p_foto_ruta
                    and coalesce((o.metadata ->> 'size')::bigint, 0) >= 4096) then
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
       v_observaciones)
    returning * into v_nuevo;
  exception
    when unique_violation then
      -- Última red de seguridad: índice único de un solo préstamo activo por bici.
      raise exception using message = 'bici_ya_prestada';
    when check_violation or not_null_violation then
      raise exception using message = 'datos_invalidos';
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
    'estado', p.estado,
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
  v_foto text;
  v_fuera boolean := false;
  v_observaciones text;
  v_condicion public.condicion_bici;
begin
  perform privado.exigir_rol('operador', 'administrador');
  if p_id_operacion is null then
    raise exception using message = 'id_operacion_invalido';
  end if;
  v_observaciones := privado.texto_libre(p_observaciones, 500);

  select * into v_bici from public.bicicletas b where b.numero = p_numero_bici for update;
  if not found then
    raise exception using message = 'bici_no_existe';
  end if;

  -- Idempotencia: solo es un reintento si coinciden la bici y el punto, y ese
  -- préstamo sigue siendo el último de la bici: si se volvió a prestar, el id es
  -- viejo y responder «éxito» engañaría al operador (B-1).
  select * into v_pr from public.prestamos pr where pr.devolucion_id_operacion = p_id_operacion;
  if found then
    if v_pr.bicicleta_id <> v_bici.id or v_pr.punto_devolucion_id is distinct from p_punto_id
       or exists (select 1 from public.prestamos pr
                   where pr.bicicleta_id = v_bici.id and pr.id <> v_pr.id and pr.estado <> 'anulado'
                     and pr.salida_en >= v_pr.salida_en) then
      raise exception using message = 'id_operacion_reutilizado';
    end if;
    return privado.resultado_devolucion(v_pr);
  end if;

  select * into v_pr from public.prestamos pr where pr.bicicleta_id = v_bici.id and pr.estado = 'activo' for update;
  if not found then
    raise exception using message = 'bici_no_prestada';
  end if;

  select * into v_punto from public.puntos p where p.id = p_punto_id for share;
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
    if v_tipo is null or not (v_tipo = any (enum_range(null::public.tipo_incidencia)::text[])) then
      raise exception using message = 'incidencia_tipo_invalido';
    end if;
    if v_gravedad is null or not (v_gravedad = any (enum_range(null::public.gravedad)::text[])) then
      raise exception using message = 'incidencia_gravedad_invalida';
    end if;
    v_desc := privado.texto_libre(p_incidencia ->> 'descripcion', 1000);
    if coalesce(length(v_desc), 0) < 5 then
      raise exception using message = 'incidencia_descripcion_corta';
    end if;
    v_fuera := coalesce(privado.booleano(p_incidencia, 'deja_fuera_de_servicio'), false);
    -- Foto opcional de la novedad: solo una ruta propia de incidencias y ya subida (B-2).
    v_foto := nullif(p_incidencia ->> 'foto_ruta', '');
    if v_foto is not null then
      if v_foto !~ '^incidencias/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[a-z_]{1,30}\.(webp|jpg)$' then
        raise exception using message = 'foto_ruta_invalida';
      end if;
      if not exists (select 1 from storage.objects o where o.bucket_id = 'evidencias' and o.name = v_foto) then
        raise exception using message = 'falta_foto';
      end if;
    end if;
  end if;

  perform privado.registrar_accion('prestamo.devolver');
  update public.prestamos pr set
    estado = 'finalizado',
    devolucion_id_operacion = p_id_operacion,
    punto_devolucion_id = p_punto_id,
    operador_devolucion_id = auth.uid(),
    devuelto_en = now(),
    con_novedad = coalesce(p_con_novedad, false),
    observaciones_devolucion = v_observaciones
  where pr.id = v_pr.id
  returning * into v_pr;

  if coalesce(p_con_novedad, false) then
    insert into public.incidencias
      (bicicleta_id, prestamo_id, tipo, gravedad, descripcion, deja_fuera_de_servicio, reportada_por, foto_ruta)
    values
      (v_bici.id, v_pr.id, v_tipo::public.tipo_incidencia, v_gravedad::public.gravedad, v_desc, v_fuera,
       auth.uid(), v_foto);
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
  v_rol public.rol_personal;
  v_max integer := privado.parametro_entero('reglas_uso.duracion_maxima_min');
begin
  v_rol := privado.exigir_rol('operador', 'administrador');
  -- El operador ve solo los préstamos que salieron de su punto (I-3).
  if v_rol = 'operador' and p_punto_id is null then
    raise exception using message = 'falta_punto';
  end if;
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
  v_motivo text;
  v_destino public.puntos;
  v_bici public.bicicletas;
  v_bloqueadas integer := 0;
  v_movidas integer;
begin
  perform privado.exigir_rol('operador', 'administrador');
  v_motivo := privado.motivo(p_motivo, 5);
  if p_numeros is null or cardinality(p_numeros) = 0 then
    raise exception using message = 'sin_bicis';
  end if;
  if cardinality(p_numeros) > 200 then
    raise exception using message = 'rango_invalido';
  end if;

  -- Orden de bloqueo único en todo el sistema (B-3): primero las bicis por número,
  -- luego el punto destino (compartido, choca con su cierre: B-4) y al final las
  -- filas de la proyección pública por punto_id.
  for v_bici in select * from public.bicicletas b where b.numero = any (p_numeros) order by b.numero for update loop
    v_bloqueadas := v_bloqueadas + 1;
    if v_bici.disponibilidad = 'prestada' then
      raise exception using message = 'bici_prestada', detail = v_bici.numero::text;
    end if;
    if v_bici.condicion in ('extraviada', 'baja') then
      raise exception using message = 'bici_no_movible', detail = v_bici.numero::text;
    end if;
  end loop;
  if v_bloqueadas <> (select count(distinct n) from unnest(p_numeros) n) then
    raise exception using message = 'bici_no_existe';
  end if;

  select * into v_destino from public.puntos p where p.id = p_punto_destino for share;
  if not found then
    raise exception using message = 'punto_no_existe';
  end if;
  if v_destino.estado = 'cerrado' then
    raise exception using message = 'punto_cerrado';
  end if;

  perform 1 from public.disponibilidad_puntos d
   where d.punto_id in (select b.punto_actual_id from public.bicicletas b where b.numero = any (p_numeros)
                        union select p_punto_destino)
   order by d.punto_id
   for update;

  perform privado.registrar_accion('bici.mover', v_motivo);
  update public.bicicletas b set
    punto_actual_id = p_punto_destino,
    disponibilidad = privado.disponibilidad_para(b.condicion, p_punto_destino),
    ultimo_movimiento_en = now()
  where b.numero = any (p_numeros) and b.punto_actual_id is distinct from p_punto_destino;
  get diagnostics v_movidas = row_count;
  return v_movidas;
end $$;

-- Cambiar la condición física. El operador solo puede marcar 'averiada'.
create function public.cambiar_condicion_bici(p_numero integer, p_condicion public.condicion_bici,
                                              p_motivo text, p_punto_id uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_rol public.rol_personal;
  v_motivo text;
  v_bici public.bicicletas;
  v_punto uuid;
begin
  v_rol := privado.exigir_rol('operador', 'administrador');
  v_motivo := privado.motivo(p_motivo, 5);
  select * into v_bici from public.bicicletas b where b.numero = p_numero for update;
  if not found then
    raise exception using message = 'bici_no_existe';
  end if;
  -- El operador solo reporta una bici operativa como averiada; no puede «revivir»
  -- bicis extraviadas o dadas de baja (B-5).
  if v_rol = 'operador' and (p_condicion <> 'averiada' or v_bici.condicion <> 'operativa') then
    raise exception using message = 'no_autorizado', errcode = '42501';
  end if;
  if v_bici.disponibilidad = 'prestada' then
    raise exception using message = 'bici_prestada';
  end if;
  if p_punto_id is not null then
    perform 1 from public.puntos p where p.id = p_punto_id and p.estado <> 'cerrado' for share;
    if not found then
      raise exception using message = 'punto_no_existe';
    end if;
  end if;

  v_punto := case when p_condicion = 'extraviada' then null else coalesce(p_punto_id, v_bici.punto_actual_id) end;
  if p_condicion not in ('extraviada', 'baja') and v_punto is null then
    raise exception using message = 'falta_punto';
  end if;

  perform privado.registrar_accion('bici.cambiar_condicion', v_motivo);
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
  perform 1 from public.puntos p where p.id = p_punto_id and p.estado <> 'cerrado' for share;
  if not found then
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
  v_confirmado timestamptz;
  v_nombre text := privado.espacios(p_nombre);
begin
  perform privado.exigir_rol('administrador');
  if length(v_nombre) not between 3 and 120 then
    raise exception using message = 'nombre_invalido';
  end if;
  select u.id, u.email_confirmed_at into v_id, v_confirmado
    from auth.users u where lower(u.email) = lower(btrim(coalesce(p_correo, '')));
  if v_id is null then
    raise exception using message = 'usuario_no_existe';
  end if;
  -- Solo cuentas con correo confirmado (B-9): si el registro abierto quedara
  -- activo por error, nadie podría reservar el correo de un futuro operador.
  if v_confirmado is null then
    raise exception using message = 'usuario_no_confirmado';
  end if;
  if exists (select 1 from public.personal p where p.id = v_id) then
    raise exception using message = 'ya_vinculado';
  end if;
  perform privado.registrar_accion('personal.vincular');
  insert into public.personal (id, nombre, rol, creado_por)
  values (v_id, v_nombre, p_rol, auth.uid());
  return v_id;
end $$;

create function public.anular_prestamo(p_prestamo_id uuid, p_motivo text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_motivo text;
  v_bici_id uuid;
  v_bici public.bicicletas;
  v_pr public.prestamos;
begin
  perform privado.exigir_rol('administrador');
  v_motivo := privado.motivo(p_motivo, 10);
  select pr.bicicleta_id into v_bici_id from public.prestamos pr where pr.id = p_prestamo_id;
  if not found then
    raise exception using message = 'prestamo_no_existe';
  end if;
  select * into v_bici from public.bicicletas b where b.id = v_bici_id for update;
  select * into v_pr from public.prestamos pr where pr.id = p_prestamo_id for update;
  if v_pr.estado <> 'activo' then
    raise exception using message = 'prestamo_no_activo';
  end if;
  -- La bici vuelve al punto de salida: no puede ser un punto ya cerrado.
  perform 1 from public.puntos p where p.id = v_pr.punto_salida_id and p.estado <> 'cerrado' for share;
  if not found then
    raise exception using message = 'punto_cerrado';
  end if;

  perform privado.registrar_accion('prestamo.anular', v_motivo);
  update public.prestamos pr set
    estado = 'anulado', cerrado_en = now(), cerrado_por = auth.uid(), motivo_cierre = v_motivo
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
  v_motivo text;
  v_bici_id uuid;
  v_bici public.bicicletas;
  v_pr public.prestamos;
begin
  perform privado.exigir_rol('administrador');
  v_motivo := privado.motivo(p_motivo, 10);
  select pr.bicicleta_id into v_bici_id from public.prestamos pr where pr.id = p_prestamo_id;
  if not found then
    raise exception using message = 'prestamo_no_existe';
  end if;
  select * into v_bici from public.bicicletas b where b.id = v_bici_id for update;
  select * into v_pr from public.prestamos pr where pr.id = p_prestamo_id for update;
  if v_pr.estado <> 'activo' then
    raise exception using message = 'prestamo_no_activo';
  end if;
  perform 1 from public.puntos p where p.id = p_punto_id for share;
  if not found then
    raise exception using message = 'punto_no_existe';
  end if;
  if exists (select 1 from public.puntos p where p.id = p_punto_id and p.estado = 'cerrado') then
    raise exception using message = 'punto_cerrado';
  end if;

  perform privado.registrar_accion('prestamo.forzar_devolucion', v_motivo);
  update public.prestamos pr set
    estado = 'finalizado', devolucion_id_operacion = gen_random_uuid(), punto_devolucion_id = p_punto_id,
    operador_devolucion_id = auth.uid(), devuelto_en = now(), con_novedad = false,
    devolucion_forzada = true, observaciones_devolucion = v_motivo
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
  v_motivo text;
  v_bici_id uuid;
  v_pr public.prestamos;
begin
  perform privado.exigir_rol('administrador');
  v_motivo := privado.motivo(p_motivo, 10);
  select pr.bicicleta_id into v_bici_id from public.prestamos pr where pr.id = p_prestamo_id;
  if not found then
    raise exception using message = 'prestamo_no_existe';
  end if;
  perform 1 from public.bicicletas b where b.id = v_bici_id for update;
  select * into v_pr from public.prestamos pr where pr.id = p_prestamo_id for update;
  if v_pr.estado <> 'activo' then
    raise exception using message = 'prestamo_no_activo';
  end if;

  perform privado.registrar_accion('prestamo.cerrar_no_devuelto', v_motivo);
  update public.prestamos pr set
    estado = 'no_devuelto', cerrado_en = now(), cerrado_por = auth.uid(), motivo_cierre = v_motivo
  where pr.id = v_pr.id;
  update public.bicicletas b set
    condicion = 'extraviada', disponibilidad = 'no_disponible', punto_actual_id = null, ultimo_movimiento_en = now()
  where b.id = v_bici_id;
  insert into public.incidencias (bicicleta_id, prestamo_id, tipo, gravedad, descripcion, deja_fuera_de_servicio, reportada_por)
  values (v_bici_id, v_pr.id, 'perdida', 'grave', v_motivo, true, auth.uid());
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
declare
  v_motivo text;
begin
  perform privado.exigir_rol('administrador');
  v_motivo := case when coalesce(p_con_datos_personales, false) then privado.motivo(p_motivo, 10)
                   else privado.texto_libre(p_motivo, 500) end;
  insert into public.bitacora_consultas (actor_id, tipo, con_datos_personales, motivo, detalle)
  values (auth.uid(), 'exportar', coalesce(p_con_datos_personales, false), v_motivo, p_detalle);
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
