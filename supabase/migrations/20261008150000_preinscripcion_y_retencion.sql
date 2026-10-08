-- Hitos 1e (preinscripción pública) y 1f (retención de fotos y de preinscripciones).
--
-- 1e: límite de intentos por IP para la preinscripción. La IP nunca llega a la base:
--     la Edge Function `preinscribir` manda una huella HMAC con una sal diaria secreta.
-- 1f: funciones que usa la Edge Function `purgar-fotos` (solo service_role), registro
--     de tareas programadas, conservación manual de una foto (administrador),
--     conservación automática al reportar una avería, y anonimización de las
--     preinscripciones que nunca se validaron.

-- ============================================================================
-- 1e. Preinscripción con límite de intentos
-- ============================================================================
create table privado.intentos_preinscripcion (
  id bigint generated always as identity primary key,
  ip_huella text not null check (ip_huella ~ '^[0-9a-f]{64}$'),
  en timestamptz not null default now()
);
create index intentos_preinscripcion_ip on privado.intentos_preinscripcion (ip_huella, en);

drop function public.preinscribir(jsonb);

-- 5 intentos por hora y 20 por día por IP (diseño §4). Cuenta los intentos que
-- llegan a la base (ya pasaron Turnstile), incluidos los «ya inscrito»: eso es lo
-- que frena recorrer documentos. Un intento con datos inválidos se revierte con su
-- transacción y no cuenta; cada uno exige un token de Turnstile nuevo.
create function public.preinscribir(p jsonb, p_ip_huella text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v jsonb;
begin
  if p_ip_huella is null or p_ip_huella !~ '^[0-9a-f]{64}$' then
    raise exception using message = 'datos_invalidos';
  end if;
  -- Dos peticiones simultáneas de la misma IP no pasan ambas el límite.
  perform pg_advisory_xact_lock(hashtextextended(p_ip_huella, 0));
  if (select count(*) from privado.intentos_preinscripcion i
       where i.ip_huella = p_ip_huella and i.en > now() - interval '1 hour') >= 5
     or (select count(*) from privado.intentos_preinscripcion i
       where i.ip_huella = p_ip_huella and i.en > now() - interval '1 day') >= 20 then
    raise exception using message = 'demasiados_intentos';
  end if;
  insert into privado.intentos_preinscripcion (ip_huella) values (p_ip_huella);
  delete from privado.intentos_preinscripcion i where i.en < now() - interval '2 days';

  perform privado.registrar_accion('persona.preinscribir');
  v := privado.crear_persona(p, 'web', null);
  return jsonb_build_object('resultado', v ->> 'resultado');
end $$;

-- ============================================================================
-- 1f. Retención de fotos
-- ============================================================================

-- Fotos que ya cumplieron el plazo: préstamos finalizados sin novedad (o anulados,
-- I-6), sin incidencias, no marcados para conservar, cerrados hace más de
-- `retencion.fotos_dias` días. Sin plazo definido (NULL) no devuelve nada.
create function public.fotos_por_purgar(p_limite integer default 500)
returns table (prestamo_id uuid, foto_ruta text)
language plpgsql stable security definer set search_path = '' as $$
declare
  v_dias integer := privado.parametro_entero('retencion.fotos_dias');
begin
  if v_dias is null then
    return;
  end if;
  return query
  select pr.id, pr.foto_ruta
    from public.prestamos pr
   where pr.foto_estado = 'almacenada' and not pr.foto_retener
     and ((pr.estado = 'finalizado' and pr.con_novedad = false
           and pr.devuelto_en < now() - make_interval(days => v_dias))
       or (pr.estado = 'anulado' and pr.cerrado_en < now() - make_interval(days => v_dias)))
     and not exists (select 1 from public.incidencias i where i.prestamo_id = pr.id)
   order by coalesce(pr.devuelto_en, pr.cerrado_en)
   limit least(greatest(coalesce(p_limite, 500), 1), 1000);
end $$;

-- Marca las fotos como eliminadas ANTES de borrar los archivos y devuelve solo las
-- rutas que marcó: si entretanto el administrador conservó una, no se borra. Si el
-- borrado del archivo falla después, `fotos_huerfanas` lo reintenta.
create function public.marcar_fotos_eliminadas(p_rutas text[]) returns setof text
language plpgsql security definer set search_path = '' as $$
begin
  perform privado.registrar_accion('foto.purgar', 'Plazo de retención cumplido');
  return query
  update public.prestamos pr set foto_estado = 'eliminada', foto_eliminada_en = now()
   where pr.foto_ruta = any (p_rutas) and pr.foto_estado = 'almacenada' and not pr.foto_retener
     and not exists (select 1 from public.incidencias i where i.prestamo_id = pr.id)
  returning pr.foto_ruta;
end $$;

-- Archivos de préstamos que sobran en Storage: los de préstamos marcados como
-- eliminados (un borrado que falló) y los subidos para un préstamo que nunca se
-- registró (más de 24 h). No toca la carpeta de incidencias.
create function public.fotos_huerfanas(p_limite integer default 500) returns setof text
language sql stable security definer set search_path = '' as $$
  select o.name
    from storage.objects o
    left join public.prestamos pr on pr.foto_ruta = o.name
   where o.bucket_id = 'evidencias' and o.name like 'prestamos/%'
     and ((pr.id is null and o.created_at < now() - interval '24 hours')
       or pr.foto_estado = 'eliminada')
   order by o.created_at
   limit least(greatest(coalesce(p_limite, 500), 1), 1000);
$$;

-- Resultado de una tarea programada; alimenta el tablero (última purga, último respaldo).
create function public.registrar_tarea(p_tarea text, p_inicio timestamptz, p_resultado text,
                                       p_detalle jsonb default null) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if p_tarea not in ('purgar_fotos', 'respaldo', 'purgar_preinscripciones') or p_resultado not in ('ok', 'error') then
    raise exception using message = 'datos_invalidos';
  end if;
  insert into privado.ejecuciones_tareas (tarea, inicio, fin, resultado, detalle)
  values (p_tarea, coalesce(p_inicio, now()), now(), p_resultado, p_detalle);
end $$;

-- El administrador conserva la foto de un préstamo (un reclamo, un daño descubierto
-- después): la purga ya no la toca. Queda en la auditoría con su motivo.
create function public.conservar_foto(p_prestamo_id uuid, p_motivo text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_motivo text;
  v_pr public.prestamos;
begin
  perform privado.exigir_rol('administrador');
  v_motivo := privado.motivo(p_motivo, 10);
  select * into v_pr from public.prestamos pr where pr.id = p_prestamo_id for update;
  if not found then
    raise exception using message = 'prestamo_no_existe';
  end if;
  if v_pr.foto_estado <> 'almacenada' then
    raise exception using message = 'foto_ya_eliminada';
  end if;
  if v_pr.foto_retener then
    return;
  end if;
  perform privado.registrar_accion('foto.conservar', v_motivo);
  update public.prestamos pr set foto_retener = true where pr.id = p_prestamo_id;
end $$;

-- Igual que antes, más una regla: si la bici se reporta averiada o extraviada, se
-- conserva la foto de su último préstamo finalizado. Un daño descubierto después de
-- una devolución «sin novedad» no pierde su evidencia por la purga. No atribuye
-- responsabilidad a nadie: solo evita que la foto se borre antes de revisarla.
create or replace function public.cambiar_condicion_bici(p_numero integer, p_condicion public.condicion_bici,
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

  if p_condicion in ('averiada', 'extraviada') then
    update public.prestamos pr set foto_retener = true
     where pr.id = (select x.id from public.prestamos x
                     where x.bicicleta_id = v_bici.id and x.estado = 'finalizado'
                     order by x.devuelto_en desc limit 1)
       and pr.foto_estado = 'almacenada' and not pr.foto_retener;
  end if;
end $$;

-- El historial del administrador muestra si la foto está marcada para conservar.
create or replace view public.v_prestamos_admin with (security_invoker = true) as
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
       pr.motivo_cierre,
       pr.foto_retener
  from public.prestamos pr
  join public.bicicletas b on b.id = pr.bicicleta_id
  join public.personas per on per.id = pr.persona_id
  join public.puntos ps on ps.id = pr.punto_salida_id
  left join public.puntos pd on pd.id = pr.punto_devolucion_id
  join public.personal os on os.id = pr.operador_salida_id
  left join public.personal od on od.id = pr.operador_devolucion_id;

-- ============================================================================
-- 1f. Preinscripciones nunca validadas: se anonimizan (nada se borra)
-- ============================================================================

-- Tipo de documento técnico para registros anonimizados: inactivo (no aparece en
-- los formularios) y con un patrón que ningún documento real cumple.
insert into public.tipos_documento (codigo, nombre, implica_menor, patron, orden, activo)
values ('AN', 'Anonimizado', false, '^X[0-9A-F]{19}$', 99, false)
on conflict (codigo) do nothing;

-- Reemplaza los datos que identifican a la persona y su sal de huellas: las huellas
-- ya escritas en la auditoría quedan sin vínculo. Conserva edad y sexo/género (sin
-- el resto no identifican y sirven para estadísticas). El acudiente se anonimiza si
-- ya no responde por nadie vigente.
create function privado.anonimizar_persona(p_persona uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_acu uuid;
begin
  update public.personas per set
    tipo_documento = 'AN',
    numero_documento = 'X' || upper(left(md5(gen_random_uuid()::text), 19)),
    nombres = 'Anonimizada',
    apellidos = 'Anonimizada',
    telefono = '0000000',
    correo = null,
    sal_huella = encode(sha256(convert_to(gen_random_uuid()::text || clock_timestamp()::text, 'UTF8')), 'hex'),
    estado = 'anonimizada'
  where per.id = p_persona and per.estado <> 'anonimizada'
  returning per.acudiente_id into v_acu;

  if v_acu is not null and not exists (select 1 from public.personas o
                                        where o.acudiente_id = v_acu and o.estado <> 'anonimizada') then
    update public.acudientes a set
      tipo_documento = 'AN',
      numero_documento = 'X' || upper(left(md5(gen_random_uuid()::text), 19)),
      nombres = 'Anonimizado',
      apellidos = 'Anonimizado',
      telefono = '0000000',
      correo = null,
      sal_huella = encode(sha256(convert_to(gen_random_uuid()::text || clock_timestamp()::text, 'UTF8')), 'hex')
    where a.id = v_acu;
  end if;
end $$;

-- Tarea diaria (pg_cron, solo SQL): anonimiza las preinscripciones que nadie validó
-- en `retencion.preinscripcion_sin_validar_dias` días. Sin plazo definido no hace nada.
create function privado.purgar_preinscripciones() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_dias integer := privado.parametro_entero('retencion.preinscripcion_sin_validar_dias');
  v_inicio timestamptz := clock_timestamp();
  v_n integer := 0;
  r record;
begin
  if v_dias is not null then
    perform privado.registrar_accion('persona.anonimizar', 'Preinscripción sin validar por más de ' || v_dias || ' días');
    for r in select per.id from public.personas per
              where per.estado = 'preinscrita' and per.creada_en < now() - make_interval(days => v_dias)
                and not exists (select 1 from public.prestamos pr where pr.persona_id = per.id)
              for update skip locked loop
      perform privado.anonimizar_persona(r.id);
      v_n := v_n + 1;
    end loop;
  end if;
  insert into privado.ejecuciones_tareas (tarea, inicio, fin, resultado, detalle)
  values ('purgar_preinscripciones', v_inicio, clock_timestamp(), 'ok',
          jsonb_build_object('anonimizadas', v_n, 'plazo_dias', v_dias));
  return v_n;
end $$;

-- ============================================================================
-- Permisos
-- ============================================================================
grant execute on function public.preinscribir(jsonb, text) to service_role;
grant execute on function public.fotos_por_purgar(integer), public.marcar_fotos_eliminadas(text[]),
                          public.fotos_huerfanas(integer), public.registrar_tarea(text, timestamptz, text, jsonb)
  to service_role;
grant execute on function public.conservar_foto(uuid, text) to authenticated;
