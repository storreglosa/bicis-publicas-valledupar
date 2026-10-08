#!/usr/bin/env bash
# Simulacro de restauración (diseño §10): abre un respaldo cifrado, lo restaura en una
# base LOCAL nueva (Postgres de conda, scripts/pg_local.sh start) y compara los
# conteos de filas con los del momento del respaldo. Nunca restaura sobre Supabase.
#
#   scripts/restaurar_prueba.sh ~/Claude_code/respaldos-bicis/AAAA-MM-DD_bicis_prod.tar.gpg
#
# gpg pide la frase de paso de tu clave privada. Al terminar borra la base local
# restaurada (tiene datos personales), salvo con --conservar.
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${CONDA_PREFIX:-$HOME/miniconda3/envs/bicis}/bin"
LOCAL="host=$RAIZ/.pg_local port=54329 user=postgres"
BD=bicis_restauracion

archivo="${1:?uso: $0 <respaldo.tar.gpg> [--conservar]}"
conservar="${2:-}"
trabajo="$(mktemp -d)"
chmod 700 "$trabajo"
limpiar() {
  rm -rf "$trabajo"
  if [ "$conservar" != "--conservar" ]; then
    "$BIN/psql" "$LOCAL dbname=postgres" -X -q -c "drop database if exists $BD with (force)" 2>/dev/null || true
  fi
}
trap limpiar EXIT

echo "→ Descifrando"
gpg --quiet --decrypt "$archivo" | tar -C "$trabajo" -xf -

echo "→ Base local nueva con el reemplazo mínimo de Supabase (roles, auth, storage)"
"$BIN/psql" "$LOCAL dbname=postgres" -X -q -v ON_ERROR_STOP=1 \
  -c "drop database if exists $BD with (force)" -c "create database $BD"
"$BIN/psql" "$LOCAL dbname=$BD" -X -q -v ON_ERROR_STOP=1 -f "$RAIZ/tests/bd/stub_supabase.sql" >/dev/null
"$BIN/psql" "$LOCAL dbname=$BD" -X -q -v ON_ERROR_STOP=1 \
  -c "drop schema public cascade" \
  -c "\\copy auth.users (id, email, email_confirmed_at, created_at) from '$trabajo/auth_usuarios.csv' csv header"

# Roles internos de Supabase que nombran los permisos del volcado (supabase_admin…): se
# crean sin login en el Postgres local para restaurar también los permisos.
"$BIN/pg_restore" -f - "$trabajo/bicis.dump" \
  | grep -E '^(GRANT|REVOKE|ALTER DEFAULT PRIVILEGES) ' \
  | grep -oE '\b(FOR ROLE|TO|FROM) [a-z_][a-z0-9_]*' | awk '{print $NF}' | sort -u \
  | while read -r rol; do
      "$BIN/psql" "$LOCAL dbname=postgres" -X -q -v rol="$rol" >/dev/null <<<"select format('create role %I nologin', :'rol') where not exists (select from pg_roles where rolname = :'rol') \\gexec"
    done

echo "→ Restaurando"
"$BIN/pg_restore" -d "$LOCAL dbname=$BD" --no-owner --exit-on-error "$trabajo/bicis.dump"

echo "→ Comparando conteos"
fallas=0
while IFS=$'\t' read -r tabla esperado; do
  obtenido="$("$BIN/psql" "$LOCAL dbname=$BD" -X -A -t -c "select count(*) from $tabla")"
  if [ "$obtenido" = "$esperado" ]; then
    printf '  ok     %-40s %s\n' "$tabla" "$obtenido"
  else
    printf '  FALLA  %-40s respaldo=%s restaurado=%s\n' "$tabla" "$esperado" "$obtenido"
    fallas=$((fallas + 1))
  fi
done < "$trabajo/conteos.tsv"
if [ "$fallas" -gt 0 ]; then
  echo "La restauración NO coincide en $fallas tabla(s)." >&2
  exit 1
fi
echo "Restauración verificada: todas las tablas coinciden."
