-- Proyección pública de disponibilidad por punto (lo que ve el mapa en vivo).
-- La mantienen triggers sobre bicicletas, puntos y eventos. Solo escribe si algo
-- cambió, para no generar ruido en Realtime.
--
-- visible: el punto aparece en el mapa público (no taller, no oculto ni cerrado;
--          si es de evento, el evento está publicado y no ha terminado).
-- abierto: se puede prestar ahí ahora (punto activo; si es de evento, evento en curso).

create function privado.refrescar_disponibilidad(p_punto uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  r record;
begin
  if p_punto is null then
    return;
  end if;

  select p.id, p.codigo, p.nombre, p.tipo, p.latitud, p.longitud, p.direccion, p.horario_texto,
         e.nombre as evento_nombre, e.inicia_en as evento_inicia_en, e.termina_en as evento_termina_en,
         (p.tipo <> 'taller' and p.estado in ('activo', 'inactivo')
           and (p.tipo = 'fijo' or (e.publicado and e.estado in ('planeado', 'en_curso')))) as visible,
         (p.estado = 'activo' and (p.tipo = 'fijo' or e.estado = 'en_curso')) as abierto,
         (select count(*)::int from public.bicicletas b
           where b.punto_actual_id = p.id and b.disponibilidad = 'disponible') as bicis_disponibles
    into r
    from public.puntos p
    left join public.eventos e on e.id = p.evento_id
   where p.id = p_punto;

  if not found then
    delete from public.disponibilidad_puntos where punto_id = p_punto;
    return;
  end if;

  insert into public.disponibilidad_puntos as d
    (punto_id, codigo, nombre, tipo, latitud, longitud, direccion, horario_texto,
     evento_nombre, evento_inicia_en, evento_termina_en, abierto, visible, bicis_disponibles, actualizado_en)
  values
    (r.id, r.codigo, r.nombre, r.tipo, r.latitud, r.longitud, r.direccion, r.horario_texto,
     r.evento_nombre, r.evento_inicia_en, r.evento_termina_en, coalesce(r.abierto, false),
     coalesce(r.visible, false), r.bicis_disponibles, now())
  on conflict (punto_id) do update set
    codigo = excluded.codigo, nombre = excluded.nombre, tipo = excluded.tipo,
    latitud = excluded.latitud, longitud = excluded.longitud, direccion = excluded.direccion,
    horario_texto = excluded.horario_texto, evento_nombre = excluded.evento_nombre,
    evento_inicia_en = excluded.evento_inicia_en, evento_termina_en = excluded.evento_termina_en,
    abierto = excluded.abierto, visible = excluded.visible,
    bicis_disponibles = excluded.bicis_disponibles, actualizado_en = now()
  where (d.codigo, d.nombre, d.tipo, d.latitud, d.longitud, d.direccion, d.horario_texto,
         d.evento_nombre, d.evento_inicia_en, d.evento_termina_en, d.abierto, d.visible, d.bicis_disponibles)
        is distinct from
        (excluded.codigo, excluded.nombre, excluded.tipo, excluded.latitud, excluded.longitud,
         excluded.direccion, excluded.horario_texto, excluded.evento_nombre, excluded.evento_inicia_en,
         excluded.evento_termina_en, excluded.abierto, excluded.visible, excluded.bicis_disponibles);
end $$;

create function privado.disponibilidad_por_bici() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and old.punto_actual_id is distinct from new.punto_actual_id then
    perform privado.refrescar_disponibilidad(old.punto_actual_id);
  end if;
  perform privado.refrescar_disponibilidad(new.punto_actual_id);
  return null;
end $$;

create trigger disponibilidad after insert or update of disponibilidad, condicion, punto_actual_id
  on public.bicicletas for each row execute function privado.disponibilidad_por_bici();

create function privado.disponibilidad_por_punto() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform privado.refrescar_disponibilidad(new.id);
  return null;
end $$;

create trigger disponibilidad after insert or update on public.puntos
  for each row execute function privado.disponibilidad_por_punto();

create function privado.disponibilidad_por_evento() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_punto uuid;
begin
  for v_punto in select p.id from public.puntos p where p.evento_id = new.id loop
    perform privado.refrescar_disponibilidad(v_punto);
  end loop;
  return null;
end $$;

create trigger disponibilidad after update on public.eventos
  for each row execute function privado.disponibilidad_por_evento();
