#!/usr/bin/env bash
# Aplica las migraciones de supabase/migrations/ a un proyecto Supabase con psql
# (sin Docker ni token de la CLI). Credenciales: ~/.pg_service.conf + ~/.pgpass
# (servicios bicis_dev y bicis_prod; ver docs/runbook.md §1.2).
#
#   scripts/migrar.sh dev                       # solo muestra qué aplicaría
#   scripts/migrar.sh dev --aplicar             # aplica las pendientes en dev
#   scripts/migrar.sh prod --aplicar --confirmar <ref-de-prod>
#
# Cada archivo se aplica en UNA transacción junto con su registro en
# supabase_migrations.schema_migrations (la misma tabla que usa la CLI de
# Supabase): o entra completo o no entra nada.
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
PSQL="${CONDA_PREFIX:-$HOME/miniconda3/envs/bicis}/bin/psql"

entorno="${1:-}"
shift || true
aplicar=0
confirmacion=""
while [ $# -gt 0 ]; do
  case "$1" in
    --aplicar) aplicar=1 ;;
    --confirmar) confirmacion="${2:-}"; shift ;;
    *) echo "opción desconocida: $1" >&2; exit 2 ;;
  esac
  shift
done
case "$entorno" in
  dev|prod) ;;
  *) echo "uso: $0 dev|prod [--aplicar] [--confirmar <ref>]" >&2; exit 2 ;;
esac

servicio="bicis_$entorno"
conexion="service=$servicio"
ref="$(awk -v s="[$servicio]" '$0==s{f=1;next} /^\[/{f=0} f && /^user=/{sub(/^user=postgres\./,""); print}' ~/.pg_service.conf)"
if [ -z "$ref" ]; then
  echo "No encuentro [$servicio] con user=postgres.<ref> en ~/.pg_service.conf" >&2
  exit 1
fi

echo "Proyecto: $entorno (ref $ref)"
"$PSQL" "$conexion" -X -q -v ON_ERROR_STOP=1 <<'SQL'
create schema if not exists supabase_migrations;
create table if not exists supabase_migrations.schema_migrations (
  version text primary key,
  statements text[],
  name text
);
SQL

aplicadas="$("$PSQL" "$conexion" -X -A -t -c "select version from supabase_migrations.schema_migrations order by 1")"
pendientes=()
for archivo in "$RAIZ"/supabase/migrations/*.sql; do
  base="$(basename "$archivo" .sql)"
  version="${base%%_*}"
  if ! grep -qx "$version" <<<"$aplicadas"; then
    pendientes+=("$archivo")
  fi
done

if [ ${#pendientes[@]} -eq 0 ]; then
  echo "Sin migraciones pendientes."
  exit 0
fi
echo "Pendientes:"
for archivo in "${pendientes[@]}"; do echo "  $(basename "$archivo")"; done

if [ "$aplicar" -eq 0 ]; then
  echo "(simulación: usa --aplicar para aplicarlas)"
  exit 0
fi
if [ "$entorno" = "prod" ] && [ "$confirmacion" != "$ref" ]; then
  echo "Para aplicar en PROD hay que confirmar con --confirmar $ref" >&2
  exit 1
fi

for archivo in "${pendientes[@]}"; do
  base="$(basename "$archivo" .sql)"
  version="${base%%_*}"
  nombre="${base#*_}"
  echo "→ $base"
  "$PSQL" "$conexion" -X -q -v ON_ERROR_STOP=1 --single-transaction \
    -f "$archivo" \
    -c "insert into supabase_migrations.schema_migrations (version, name) values ('$version', '$nombre')"
done
echo "Listo: ${#pendientes[@]} migración(es) aplicada(s) en $entorno."
