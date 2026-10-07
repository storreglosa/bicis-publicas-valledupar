-- Auditoría de solo inserción y reglas de integridad que no caben en un CHECK.

-- Huella: identifica un valor sin guardarlo (sha256 con sal secreta). Sirve para
-- saber si un documento o teléfono cambió sin duplicar datos personales.
-- Las huellas de personas y acudientes usan la sal PROPIA de cada fila
-- (sal_huella): al anonimizar se reemplaza y las huellas ya escritas en la
-- auditoría inmutable dejan de poder revertirse (revisión de seguridad M-4).
-- Sin sal propia se usa la sal general de la base.
create function privado.huella(p_valor text, p_sal text default null) returns text
language sql stable security definer set search_path = '' as $$
  select case when p_valor is null then null else
    left(encode(sha256(convert_to(
      coalesce(p_sal, (select a.valor from privado.ajustes a where a.clave = 'sal_huellas')) || '|' || p_valor,
      'UTF8')), 'hex'), 24)
  end
$$;

-- Trigger genérico de auditoría. Argumentos: columnas con datos personales,
-- que se guardan como huella y no en claro.
-- Las funciones de negocio dejan en app.accion / app.motivo qué hicieron y por qué.
create function privado.auditar() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_viejo jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  v_nuevo jsonb := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end;
  v_antes jsonb := v_viejo;
  v_despues jsonb := v_nuevo;
  v_fila jsonb := coalesce(v_nuevo, v_viejo);
  v_sal_vieja text := v_viejo ->> 'sal_huella';
  v_sal_nueva text := v_nuevo ->> 'sal_huella';
  v_columna text;
begin
  -- La sal nunca se copia a la auditoría.
  v_viejo := v_viejo - 'sal_huella';
  v_nuevo := v_nuevo - 'sal_huella';
  v_antes := v_viejo;
  v_despues := v_nuevo;

  if tg_op = 'UPDATE' then
    select jsonb_object_agg(e.key, e.value) into v_antes
      from jsonb_each(v_viejo) e where v_nuevo -> e.key is distinct from e.value;
    select jsonb_object_agg(e.key, e.value) into v_despues
      from jsonb_each(v_nuevo) e where v_viejo -> e.key is distinct from e.value;
    if v_despues is null then
      return null;  -- UPDATE sin cambios reales: no se audita
    end if;
  end if;

  foreach v_columna in array coalesce(tg_argv, '{}'::text[]) loop
    if v_antes ? v_columna then
      v_antes := jsonb_set(v_antes, array[v_columna], to_jsonb('huella:' || coalesce(privado.huella(v_antes ->> v_columna, v_sal_vieja), 'null')));
    end if;
    if v_despues ? v_columna then
      v_despues := jsonb_set(v_despues, array[v_columna], to_jsonb('huella:' || coalesce(privado.huella(v_despues ->> v_columna, v_sal_nueva), 'null')));
    end if;
  end loop;

  insert into public.auditoria (actor_id, tabla, operacion, registro_id, antes, despues, accion, motivo)
  values (
    auth.uid(),
    tg_table_name,
    tg_op,
    coalesce(v_fila ->> 'id', v_fila ->> 'clave', v_fila ->> 'codigo'),
    v_antes,
    v_despues,
    nullif(current_setting('app.accion', true), ''),
    nullif(current_setting('app.motivo', true), '')
  );
  return null;
end $$;

-- Auditoría de solo inserción: nadie la modifica ni la borra.
create function privado.impedir_cambio() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception using message = 'registro_inmutable', detail = tg_table_name;
end $$;

create trigger auditoria_inmutable before update or delete on public.auditoria
  for each row execute function privado.impedir_cambio();
create trigger auditoria_sin_truncate before truncate on public.auditoria
  for each statement execute function privado.impedir_cambio();
create trigger bitacora_inmutable before update or delete on public.bitacora_consultas
  for each row execute function privado.impedir_cambio();
create trigger bitacora_sin_truncate before truncate on public.bitacora_consultas
  for each statement execute function privado.impedir_cambio();

-- Tablas auditadas (las columnas listadas se guardan como huella).
create trigger auditar after insert or update or delete on public.personal
  for each row execute function privado.auditar();
create trigger auditar after insert or update or delete on public.personas
  for each row execute function privado.auditar('numero_documento', 'nombres', 'apellidos', 'telefono', 'correo');
create trigger auditar after insert or update or delete on public.acudientes
  for each row execute function privado.auditar('numero_documento', 'nombres', 'apellidos', 'telefono', 'correo');
create trigger auditar after insert or update or delete on public.autorizaciones_datos
  for each row execute function privado.auditar();
create trigger auditar after insert or update or delete on public.politicas_tratamiento
  for each row execute function privado.auditar();
create trigger auditar after insert or update or delete on public.eventos
  for each row execute function privado.auditar();
create trigger auditar after insert or update or delete on public.puntos
  for each row execute function privado.auditar();
create trigger auditar after insert or update or delete on public.bicicletas
  for each row execute function privado.auditar();
create trigger auditar after insert or update or delete on public.prestamos
  for each row execute function privado.auditar();
create trigger auditar after insert or update or delete on public.incidencias
  for each row execute function privado.auditar();
create trigger auditar after insert or update or delete on public.sanciones
  for each row execute function privado.auditar();
create trigger auditar after insert or update or delete on public.parametros
  for each row execute function privado.auditar();
create trigger auditar after insert or update or delete on public.tipos_documento
  for each row execute function privado.auditar();

-- Personal: nunca quedarse sin administradores; nadie se degrada a sí mismo.
create function privado.proteger_personal() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and old.id = auth.uid() and old.rol = 'administrador'
     and (new.rol <> 'administrador' or not new.activo) then
    raise exception using message = 'no_puede_degradarse';
  end if;
  if not exists (select 1 from public.personal p where p.rol = 'administrador' and p.activo) then
    raise exception using message = 'sin_administradores';
  end if;
  return null;
end $$;

create trigger proteger_personal after update on public.personal
  for each row execute function privado.proteger_personal();

-- Política de tratamiento: el texto publicado no se edita (se publica otra versión).
create function privado.sellar_politica() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.sha256 := encode(sha256(convert_to(
      new.version || E'\n' || new.texto_md || E'\n' || new.texto_autorizacion || E'\n' || new.texto_autorizacion_foto, 'UTF8')), 'hex');
    return new;
  end if;
  if (new.version, new.vigente_desde, new.texto_md, new.texto_autorizacion, new.texto_autorizacion_foto, new.sha256)
     is distinct from
     (old.version, old.vigente_desde, old.texto_md, old.texto_autorizacion, old.texto_autorizacion_foto, old.sha256) then
    raise exception using message = 'politica_inmutable';
  end if;
  return new;
end $$;

create trigger sellar_politica before insert or update on public.politicas_tratamiento
  for each row execute function privado.sellar_politica();

-- Documento: el número debe cumplir el patrón de su tipo.
create function privado.validar_documento() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_patron text;
begin
  select t.patron into v_patron from public.tipos_documento t where t.codigo = new.tipo_documento;
  if new.numero_documento !~ v_patron then
    raise exception using message = 'documento_invalido';
  end if;
  return new;
end $$;

create trigger validar_documento before insert or update of tipo_documento, numero_documento on public.personas
  for each row execute function privado.validar_documento();
create trigger validar_documento before insert or update of tipo_documento, numero_documento on public.acudientes
  for each row execute function privado.validar_documento();

create function privado.marcar_actualizacion() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.actualizada_en := now();
  return new;
end $$;

create trigger marcar_actualizacion before update on public.personas
  for each row execute function privado.marcar_actualizacion();

-- Parámetros: valida mínimo y máximo y registra quién cambió el valor.
create function privado.validar_parametro() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.valor is not null and new.tipo = 'entero' then
    if (new.minimo is not null and (new.valor #>> '{}')::numeric < new.minimo)
       or (new.maximo is not null and (new.valor #>> '{}')::numeric > new.maximo) then
      raise exception using message = 'parametro_fuera_de_rango', detail = new.clave;
    end if;
  end if;
  if tg_op = 'UPDATE' and new.valor is distinct from old.valor then
    new.actualizado_en := now();
    new.actualizado_por := auth.uid();
  end if;
  return new;
end $$;

create trigger validar_parametro before insert or update on public.parametros
  for each row execute function privado.validar_parametro();

-- Una incidencia ligada a un préstamo obliga a conservar su foto de evidencia.
create function privado.retener_foto_por_incidencia() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.prestamo_id is not null then
    update public.prestamos set foto_retener = true
     where id = new.prestamo_id and not foto_retener;
  end if;
  return null;
end $$;

create trigger retener_foto after insert or update of prestamo_id on public.incidencias
  for each row execute function privado.retener_foto_por_incidencia();

-- Atribución fijada por el servidor (revisión de seguridad B-5): quién impone o
-- anula una sanción y quién cierra una incidencia no lo decide el cliente.
create function privado.atribuir_sancion() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.impuesta_por := coalesce(auth.uid(), new.impuesta_por);
    new.impuesta_en := now();
    new.estado := 'vigente';
    new.anulada_por := null;
    new.anulada_en := null;
    return new;
  end if;
  if (new.persona_id, new.tipo, new.impuesta_por, new.impuesta_en, new.prestamo_id, new.incidencia_id)
     is distinct from (old.persona_id, old.tipo, old.impuesta_por, old.impuesta_en, old.prestamo_id, old.incidencia_id) then
    raise exception using message = 'sancion_inmutable';
  end if;
  if new.estado = 'anulada' and old.estado <> 'anulada' then
    new.anulada_por := auth.uid();
    new.anulada_en := now();
  elsif new.estado <> 'anulada' then
    new.anulada_por := null;
    new.anulada_en := null;
  end if;
  return new;
end $$;

create trigger atribuir_sancion before insert or update on public.sanciones
  for each row execute function privado.atribuir_sancion();

create function privado.atribuir_incidencia() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (new.bicicleta_id, new.prestamo_id, new.tipo, new.reportada_por, new.reportada_en)
     is distinct from (old.bicicleta_id, old.prestamo_id, old.tipo, old.reportada_por, old.reportada_en) then
    raise exception using message = 'incidencia_inmutable';
  end if;
  if new.estado = 'cerrada' and old.estado <> 'cerrada' then
    new.cerrada_por := auth.uid();
    new.cerrada_en := now();
  elsif new.estado <> 'cerrada' then
    new.cerrada_por := null;
    new.cerrada_en := null;
    new.resolucion := null;
  end if;
  return new;
end $$;

create trigger atribuir_incidencia before update on public.incidencias
  for each row execute function privado.atribuir_incidencia();

-- Puntos: el tipo no cambia y un punto no se cierra con bicis adentro (B-5).
create function privado.proteger_punto() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.tipo is distinct from old.tipo then
    raise exception using message = 'tipo_punto_inmutable';
  end if;
  if new.estado = 'cerrado' and old.estado <> 'cerrado'
     and exists (select 1 from public.bicicletas b where b.punto_actual_id = new.id) then
    raise exception using message = 'punto_con_bicis';
  end if;
  return new;
end $$;

create trigger proteger_punto before update on public.puntos
  for each row execute function privado.proteger_punto();
