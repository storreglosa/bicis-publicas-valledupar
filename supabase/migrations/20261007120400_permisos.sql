-- Permisos explícitos + RLS. Diseño: docs/diseno-detallado.md §4 (matriz RLS).
--
-- Regla: nada queda expuesto por defecto. Primero se revoca todo a los roles de
-- la API (anon, authenticated) y después se concede, tabla por tabla y función
-- por función, solo lo que cada rol necesita. tests/bd/test_superficie.py
-- compara lo que anon puede tocar contra una lista blanca.
--
-- Roles de la app (tabla personal), no del JWT:
--   anon        → público sin cuenta
--   authenticated + personal.rol = 'operador'      → operador
--   authenticated + personal.rol = 'administrador' → administrador
--   service_role → Edge Functions (clave secreta); BYPASSRLS

-- 1. Cerrar todo -------------------------------------------------------------
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;
revoke all on schema privado from public, anon, authenticated;
revoke all on all tables in schema privado from public, anon, authenticated;
revoke execute on all functions in schema privado from public, anon, authenticated;

alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;
alter default privileges in schema privado revoke execute on functions from public, anon, authenticated;

-- Las políticas RLS del personal llaman a estas tres funciones; el esquema
-- privado no se expone por HTTP, así que no son invocables desde la API.
grant usage on schema privado to authenticated;
grant execute on function privado.rol_actual(), privado.es_admin(), privado.es_personal() to authenticated;

-- 2. RLS en todas las tablas de public ---------------------------------------
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

-- 3. Público (anon) -----------------------------------------------------------
grant select on public.disponibilidad_puntos to anon, authenticated;
create policy publico_ve_puntos_visibles on public.disponibilidad_puntos
  for select to anon using (visible);
create policy personal_ve_disponibilidad on public.disponibilidad_puntos
  for select to authenticated using (visible or (select privado.es_personal()));

grant select on public.tipos_documento to anon, authenticated;
create policy ve_tipos_activos on public.tipos_documento
  for select to anon, authenticated using (activo);

grant select on public.politicas_tratamiento to anon, authenticated;
create policy ve_politicas on public.politicas_tratamiento
  for select to anon, authenticated using (true);

grant select on public.parametros to anon, authenticated;
create policy publico_ve_parametros_publicos on public.parametros
  for select to anon using (publico);
create policy personal_ve_parametros on public.parametros
  for select to authenticated using (publico or (select privado.es_personal()));

grant select on public.eventos to anon, authenticated;
create policy publico_ve_eventos_publicados on public.eventos
  for select to anon using (publicado);
create policy personal_ve_eventos on public.eventos
  for select to authenticated using (publicado or (select privado.es_personal()));

-- 4. Personal ------------------------------------------------------------------
grant select on public.puntos to authenticated;
create policy personal_ve_puntos on public.puntos
  for select to authenticated using ((select privado.es_personal()));

grant select on public.bicicletas to authenticated;
create policy personal_ve_bicicletas on public.bicicletas
  for select to authenticated using ((select privado.es_personal()));

grant select on public.incidencias to authenticated;
create policy personal_ve_incidencias on public.incidencias
  for select to authenticated using ((select privado.es_admin()) or (estado <> 'cerrada' and (select privado.es_personal())));

grant select on public.personal to authenticated;
create policy ve_su_fila_o_admin on public.personal
  for select to authenticated using (id = (select auth.uid()) or (select privado.es_admin()));

-- 5. Administrador -------------------------------------------------------------
-- Datos personales: solo el administrador los lee directamente; el operador
-- solo a través de buscar_persona (búsqueda exacta, queda en la bitácora).
grant select on public.personas, public.acudientes, public.autorizaciones_datos, public.prestamos,
                public.sanciones, public.auditoria, public.bitacora_consultas to authenticated;
create policy admin_ve_personas on public.personas
  for select to authenticated using ((select privado.es_admin()));
create policy admin_ve_acudientes on public.acudientes
  for select to authenticated using ((select privado.es_admin()));
create policy admin_ve_autorizaciones on public.autorizaciones_datos
  for select to authenticated using ((select privado.es_admin()));
create policy admin_ve_prestamos on public.prestamos
  for select to authenticated using ((select privado.es_admin()));
create policy admin_ve_sanciones on public.sanciones
  for select to authenticated using ((select privado.es_admin()));
create policy admin_ve_auditoria on public.auditoria
  for select to authenticated using ((select privado.es_admin()));
create policy admin_ve_bitacora on public.bitacora_consultas
  for select to authenticated using ((select privado.es_admin()));
grant select on public.v_prestamos_admin to authenticated;

-- Escrituras directas del administrador (el resto pasa por funciones).
-- Disponibilidad y ubicación de una bici solo cambian por funciones: no hay
-- UPDATE sobre esas columnas para nadie.
grant insert, update on public.puntos to authenticated;
create policy admin_crea_puntos on public.puntos
  for insert to authenticated with check ((select privado.es_admin()));
create policy admin_edita_puntos on public.puntos
  for update to authenticated using ((select privado.es_admin())) with check ((select privado.es_admin()));

grant insert, update on public.eventos to authenticated;
create policy admin_crea_eventos on public.eventos
  for insert to authenticated with check ((select privado.es_admin()));
create policy admin_edita_eventos on public.eventos
  for update to authenticated using ((select privado.es_admin())) with check ((select privado.es_admin()));

grant update (marca, modelo, color, talla, numero_serie, fecha_ingreso, nota_operativa) on public.bicicletas to authenticated;
create policy admin_edita_bicicletas on public.bicicletas
  for update to authenticated using ((select privado.es_admin())) with check ((select privado.es_admin()));

grant update (valor) on public.parametros to authenticated;
create policy admin_edita_parametros on public.parametros
  for update to authenticated using ((select privado.es_admin())) with check ((select privado.es_admin()));

grant update (nombre, rol, activo) on public.personal to authenticated;
create policy admin_edita_personal on public.personal
  for update to authenticated using ((select privado.es_admin())) with check ((select privado.es_admin()));

grant update (estado, resolucion, cerrada_por, cerrada_en) on public.incidencias to authenticated;
create policy admin_edita_incidencias on public.incidencias
  for update to authenticated using ((select privado.es_admin())) with check ((select privado.es_admin()));

grant insert, update on public.sanciones to authenticated;
create policy admin_crea_sanciones on public.sanciones
  for insert to authenticated with check ((select privado.es_admin()));
create policy admin_edita_sanciones on public.sanciones
  for update to authenticated using ((select privado.es_admin())) with check ((select privado.es_admin()));

-- 6. Funciones ------------------------------------------------------------------
-- Cada función valida además el rol de la app (privado.exigir_rol).
grant execute on function public.mi_perfil() to authenticated;
grant execute on function public.marcar_clave_cambiada() to authenticated;
grant execute on function public.buscar_persona(text, text) to authenticated;
grant execute on function public.registrar_persona_en_punto(jsonb) to authenticated;
grant execute on function public.validar_persona(uuid, jsonb, jsonb) to authenticated;
grant execute on function public.registrar_autorizacion(uuid, jsonb) to authenticated;
grant execute on function public.registrar_prestamo(uuid, uuid, integer, uuid, text, timestamptz, text) to authenticated;
grant execute on function public.registrar_devolucion(uuid, integer, uuid, boolean, jsonb, text) to authenticated;
grant execute on function public.prestamos_activos(uuid) to authenticated;
grant execute on function public.mover_bicis(integer[], uuid, text) to authenticated;
grant execute on function public.cambiar_condicion_bici(integer, public.condicion_bici, text, uuid) to authenticated;
grant execute on function public.crear_bicicletas(integer, integer, uuid) to authenticated;
grant execute on function public.vincular_personal(text, text, public.rol_personal) to authenticated;
grant execute on function public.anular_prestamo(uuid, text) to authenticated;
grant execute on function public.forzar_devolucion(uuid, uuid, text) to authenticated;
grant execute on function public.cerrar_no_devuelto(uuid, text) to authenticated;
grant execute on function public.cerrar_punto_evento(uuid) to authenticated;
grant execute on function public.publicar_politica(text, date, text, text, text) to authenticated;
grant execute on function public.registrar_exportacion(boolean, text, jsonb) to authenticated;
grant execute on function public.tablero_resumen() to authenticated;

-- La preinscripción pública solo entra por la Edge Function (Turnstile + límite de tasa).
grant execute on function public.preinscribir(jsonb) to service_role;

-- 7. Storage: fotos de evidencia en un bucket privado -------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('evidencias', 'evidencias', false, 524288, array['image/webp', 'image/jpeg'])
on conflict (id) do nothing;

-- El personal sube (sin sobrescribir: no hay UPDATE ni DELETE); solo el
-- administrador lee; solo la Edge Function de purga (clave secreta) borra.
create policy evidencias_personal_sube on storage.objects
  for insert to authenticated
  with check (bucket_id = 'evidencias' and (select privado.es_personal())
              and (storage.foldername(name))[1] in ('prestamos', 'incidencias'));
create policy evidencias_admin_lee on storage.objects
  for select to authenticated
  using (bucket_id = 'evidencias' and (select privado.es_admin()));

-- 8. Tiempo real: solo la proyección pública (sin datos personales) -----------
alter publication supabase_realtime add table public.disponibilidad_puntos;
