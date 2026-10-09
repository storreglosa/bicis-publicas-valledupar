#!/usr/bin/env bash
# Vincula la PRIMERA cuenta de administrador de un proyecto (arranque). Las demás
# cuentas se vinculan desde la app con vincular_personal, que exige ser admin.
#
#   scripts/vincular_admin_inicial.sh dev <correo> "<Nombre Apellido>"
#   scripts/vincular_admin_inicial.sh prod <correo> "<Nombre Apellido>" --confirmar <ref-de-prod>
#
# La cuenta debe existir en Supabase (Authentication → Users → Add user, con
# Auto Confirm User) y tener el correo confirmado. Si ya hay administradores, no
# hace nada: a partir de ahí se usa la app.
set -euo pipefail
# PostgreSQL 17 del entorno conda «bicis» aunque la terminal esté en otro (p. ej. base):
# pg_dump debe ser de la misma versión mayor que el servidor.
BIN="$HOME/miniconda3/envs/bicis/bin"; [ -x "$BIN/psql" ] || BIN="${CONDA_PREFIX:-/usr}/bin"
PSQL="$BIN/psql"

entorno="${1:-}"; correo="${2:-}"; nombre="${3:-}"
case "$entorno" in dev|prod) ;; *) echo "uso: $0 dev|prod <correo> \"<nombre>\" [--confirmar <ref>]" >&2; exit 2 ;; esac
[ -n "$correo" ] && [ -n "$nombre" ] || { echo "faltan correo y nombre" >&2; exit 2; }

servicio="bicis_$entorno"
ref="$(awk -v s="[$servicio]" '$0==s{f=1;next} /^\[/{f=0} f && /^user=/{sub(/^user=postgres\./,""); print}' ~/.pg_service.conf)"
if [ "$entorno" = "prod" ] && [ "${4:-}" != "--confirmar" -o "${5:-}" != "$ref" ]; then
  echo "Para PROD hay que confirmar con --confirmar $ref" >&2
  exit 1
fi

"$PSQL" "service=$servicio" -X -q -v ON_ERROR_STOP=1 -v correo="$correo" -v nombre="$nombre" <<'SQL'
begin;
select set_config('app.accion', 'personal.vincular_admin_inicial', true);
do $$ begin
  if exists (select 1 from public.personal where rol = 'administrador' and activo) then
    raise notice 'Ya hay un administrador activo: no se hace nada (usa la app).';
  end if;
end $$;
insert into public.personal (id, nombre, rol, debe_cambiar_clave)
select u.id, :'nombre', 'administrador', false
  from auth.users u
 where lower(u.email) = lower(:'correo') and u.email_confirmed_at is not null
   and not exists (select 1 from public.personal where rol = 'administrador' and activo)
on conflict (id) do nothing;
select case when exists (select 1 from public.personal p join auth.users u on u.id = p.id
                          where lower(u.email) = lower(:'correo') and p.rol = 'administrador')
            then 'OK: la cuenta es administradora.'
            else 'NO se vinculó: revisa que la cuenta exista y tenga el correo confirmado.' end as resultado;
commit;
SQL
