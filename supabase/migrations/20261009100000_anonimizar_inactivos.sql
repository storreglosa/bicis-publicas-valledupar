-- Política v1.0, §8: las personas que no presten una bicicleta durante
-- `retencion.anonimizar_inactivos_meses` meses se anonimizan como las preinscripciones
-- nunca validadas. La tarea diaria `purgar-preinscripciones` (pg_cron, 03:15 en
-- Colombia) hace ahora las dos cosas; con un parámetro vacío (NULL) esa parte no hace nada.
--
-- Inactividad: desde el último préstamo o, si nunca prestó, desde su validación. No se
-- anonimiza a quien tenga un préstamo activo, una sanción vigente o una novedad abierta
-- en alguno de sus préstamos: esos casos aún pueden necesitar su identidad.

create or replace function privado.purgar_preinscripciones() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_dias integer := privado.parametro_entero('retencion.preinscripcion_sin_validar_dias');
  v_meses integer := privado.parametro_entero('retencion.anonimizar_inactivos_meses');
  v_inicio timestamptz := clock_timestamp();
  v_n integer := 0;
  v_inactivas integer := 0;
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

  insert into privado.ejecuciones_tareas (tarea, inicio, fin, resultado, detalle)
  values ('purgar_preinscripciones', v_inicio, clock_timestamp(), 'ok',
          jsonb_build_object('anonimizadas', v_n, 'plazo_dias', v_dias,
                             'inactivas_anonimizadas', v_inactivas, 'plazo_meses', v_meses));
  return v_n + v_inactivas;
end $$;
