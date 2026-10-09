-- Política v1.0, §3 y §8: la huella de la IP del formulario de preinscripción se borra a
-- los dos días. Hasta ahora solo se borraba cuando llegaba una preinscripción nueva
-- (verificación normativa del 2026-10-09, V-3 y a9): ahora la borra también la tarea
-- diaria `purgar-preinscripciones` (pg_cron, 03:15 en Colombia).

create or replace function privado.purgar_preinscripciones() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_dias integer := privado.parametro_entero('retencion.preinscripcion_sin_validar_dias');
  v_meses integer := privado.parametro_entero('retencion.anonimizar_inactivos_meses');
  v_inicio timestamptz := clock_timestamp();
  v_n integer := 0;
  v_inactivas integer := 0;
  v_huellas integer := 0;
  r record;
begin
  -- 1. Preinscripciones que nunca se validaron.
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

  -- 2. Personas validadas sin préstamos en el plazo.
  if v_meses is not null then
    perform privado.registrar_accion('persona.anonimizar', 'Sin préstamos por más de ' || v_meses || ' meses');
    for r in select per.id from public.personas per
              where per.estado = 'validada'
                and coalesce((select max(pr.salida_en) from public.prestamos pr where pr.persona_id = per.id),
                             per.validada_en) < now() - make_interval(months => v_meses)
                and not exists (select 1 from public.prestamos pr where pr.persona_id = per.id and pr.estado = 'activo')
                and not exists (select 1 from public.sanciones s where s.persona_id = per.id and s.estado = 'vigente')
                and not exists (select 1 from public.incidencias i join public.prestamos pr on pr.id = i.prestamo_id
                                 where pr.persona_id = per.id and i.estado <> 'cerrada')
              for update of per skip locked loop
      perform privado.anonimizar_persona(r.id);
      v_inactivas := v_inactivas + 1;
    end loop;
  end if;

  -- 3. Huellas de IP de más de dos días (límite de intentos de la preinscripción).
  delete from privado.intentos_preinscripcion i where i.en < now() - interval '2 days';
  get diagnostics v_huellas = row_count;

  insert into privado.ejecuciones_tareas (tarea, inicio, fin, resultado, detalle)
  values ('purgar_preinscripciones', v_inicio, clock_timestamp(), 'ok',
          jsonb_build_object('anonimizadas', v_n, 'plazo_dias', v_dias,
                             'inactivas_anonimizadas', v_inactivas, 'plazo_meses', v_meses,
                             'huellas_ip_borradas', v_huellas));
  return v_n + v_inactivas;
end $$;
