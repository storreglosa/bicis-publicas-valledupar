-- Resumen de persona para el operador: agrega si la autorización vigente se dio
-- en persona (canal 'punto'). La vista del operador lo necesita para saber si un
-- menor puede prestar o si hay que registrar la autorización presencial del
-- acudiente (D-21). Mismo contrato: solo se añade un campo.

create or replace function privado.resumen_persona(p_persona uuid) returns jsonb
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
  select a.id, a.autoriza_foto, a.canal into v_aut
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
    -- La autorización vigente se dio en persona, en un punto. Para un menor es
    -- requisito para prestar (D-21); el operador la registra si falta.
    'autorizacion_presencial', coalesce(v_aut.canal = 'punto', false),
    'sancion', case when v_sancion.hasta is not null then
        jsonb_build_object('hasta', v_sancion.hasta, 'motivo', v_sancion.motivo) end,
    'prestamos_activos', v_activos
  );
end $$;
