-- Eliminar puntos y eventos creados por error o de prueba (D-32). Solo si nunca se
-- usaron: un punto sin préstamos (ni de salida ni de devolución) y sin bicis hoy; un
-- evento cuyos puntos cumplen lo mismo (se borran con él). Lo que tuvo préstamos no se
-- borra —el historial depende de él—: se cierra, se oculta o se cancela, como antes.
-- La auditoría (solo de inserción) guarda la fila borrada completa, la acción y el motivo.

create function privado.verificar_punto_eliminable(p_punto uuid) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if exists (select 1 from public.prestamos pr where p_punto in (pr.punto_salida_id, pr.punto_devolucion_id)) then
    raise exception using message = 'punto_con_historial';
  end if;
  if exists (select 1 from public.bicicletas b where b.punto_actual_id = p_punto) then
    raise exception using message = 'punto_con_bicis';
  end if;
end $$;

-- Borra un punto que nunca se usó; su fila del mapa público se va en cascada.
create function privado.borrar_punto(p_punto uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_codigo text;
begin
  select p.codigo into v_codigo from public.puntos p where p.id = p_punto for update;
  if not found then
    raise exception using message = 'punto_no_existe';
  end if;
  perform privado.verificar_punto_eliminable(p_punto);
  delete from public.puntos p where p.id = p_punto;
  return v_codigo;
end $$;

-- Borra un evento y sus puntos, si ninguno se usó. Devuelve cuántos puntos borró.
create function privado.borrar_evento(p_evento uuid) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_n integer := 0;
  r record;
begin
  perform 1 from public.eventos e where e.id = p_evento for update;
  if not found then
    raise exception using message = 'evento_no_existe';
  end if;
  if exists (select 1 from public.prestamos pr join public.puntos p on p.id in (pr.punto_salida_id, pr.punto_devolucion_id)
              where p.evento_id = p_evento) then
    raise exception using message = 'evento_con_historial';
  end if;
  if exists (select 1 from public.bicicletas b join public.puntos p on p.id = b.punto_actual_id
              where p.evento_id = p_evento) then
    raise exception using message = 'evento_con_bicis';
  end if;
  for r in select p.id from public.puntos p where p.evento_id = p_evento order by p.id loop
    perform privado.borrar_punto(r.id);
    v_n := v_n + 1;
  end loop;
  delete from public.eventos e where e.id = p_evento;
  return v_n;
end $$;

create function public.eliminar_punto(p_punto_id uuid, p_motivo text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_motivo text;
begin
  perform privado.exigir_rol('administrador');
  v_motivo := privado.motivo(p_motivo, 10);
  perform privado.registrar_accion('punto.eliminar', v_motivo);
  perform privado.borrar_punto(p_punto_id);
end $$;

create function public.eliminar_evento(p_evento_id uuid, p_motivo text) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_motivo text;
begin
  perform privado.exigir_rol('administrador');
  v_motivo := privado.motivo(p_motivo, 10);
  perform privado.registrar_accion('evento.eliminar', v_motivo);
  return privado.borrar_evento(p_evento_id);
end $$;

grant execute on function public.eliminar_punto(uuid, text), public.eliminar_evento(uuid, text) to authenticated;
