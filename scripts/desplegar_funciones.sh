#!/usr/bin/env bash
# Publica las Edge Functions (preinscribir, purgar-fotos), fija sus secretos y
# programa las tareas diarias (pg_cron + Vault) en un proyecto Supabase.
#
#   scripts/desplegar_funciones.sh dev
#   scripts/desplegar_funciones.sh prod --confirmar <ref-de-prod>
#
# Requisitos: haber iniciado sesión una vez con `npx supabase@2.117.0 login` (el token
# lo guarda la CLI; este script no lo lee) y ~/.pg_service.conf con [bicis_dev] /
# [bicis_prod] (docs/runbook.md §1.2).
#
# Secretos: SAL_IP y CLAVE_CRON se generan al azar en cada corrida y nunca se
# muestran (viajan en un archivo temporal 600 y por la entrada estándar de psql).
# TURNSTILE_SECRET_KEY: en dev, la clave de PRUEBA pública de Cloudflare (siempre
# aprueba); en prod se pide por teclado, sin eco, y no queda en el historial.
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
PSQL="${CONDA_PREFIX:-$HOME/miniconda3/envs/bicis}/bin/psql"
CLI=(npx --yes supabase@2.117.0)

entorno="${1:-}"
shift || true
confirmacion=""
while [ $# -gt 0 ]; do
  case "$1" in
    --confirmar) confirmacion="${2:-}"; shift ;;
    *) echo "opción desconocida: $1" >&2; exit 2 ;;
  esac
  shift
done
case "$entorno" in
  dev|prod) ;;
  *) echo "uso: $0 dev|prod [--confirmar <ref>]" >&2; exit 2 ;;
esac

servicio="bicis_$entorno"
ref="$(awk -v s="[$servicio]" '$0==s{f=1;next} /^\[/{f=0} f && /^user=/{sub(/^user=postgres\./,""); print}' ~/.pg_service.conf)"
if [ -z "$ref" ]; then
  echo "No encuentro [$servicio] con user=postgres.<ref> en ~/.pg_service.conf" >&2
  exit 1
fi
if [ "$entorno" = "prod" ] && [ "$confirmacion" != "$ref" ]; then
  echo "Para publicar en PROD hay que confirmar con --confirmar $ref" >&2
  exit 1
fi
echo "Proyecto: $entorno (ref $ref)"

if [ "$entorno" = "dev" ]; then
  turnstile="1x0000000000000000000000000000000AA"     # clave de prueba de Cloudflare
  origenes="https://storreglosa.github.io,http://localhost:5173,http://localhost:4174"
else
  read -r -s -p "Clave SECRETA del widget Turnstile de prod (no se muestra): " turnstile
  echo
  [ -n "$turnstile" ] || { echo "Sin clave de Turnstile no se publica." >&2; exit 1; }
  origenes="https://storreglosa.github.io"
fi
clave_cron="$(openssl rand -hex 32)"
sal_ip="$(openssl rand -hex 32)"

temporal="$(mktemp)"
chmod 600 "$temporal"
trap 'rm -f "$temporal"' EXIT
printf 'TURNSTILE_SECRET_KEY=%s\nSAL_IP=%s\nCLAVE_CRON=%s\nORIGENES_PERMITIDOS=%s\n' \
  "$turnstile" "$sal_ip" "$clave_cron" "$origenes" > "$temporal"

cd "$RAIZ"
echo "→ Funciones"
"${CLI[@]}" functions deploy preinscribir purgar-fotos --project-ref "$ref" --use-api --no-verify-jwt
echo "→ Secretos de las funciones"
"${CLI[@]}" secrets set --env-file "$temporal" --project-ref "$ref"
echo "→ Tareas programadas (pg_cron) y Vault"
{
  printf "\\set clave_cron '%s'\n\\set url_purga '%s'\n" "$clave_cron" "https://$ref.supabase.co/functions/v1/purgar-fotos"
  cat "$RAIZ/supabase/tareas_programadas.sql"
} | "$PSQL" "service=$servicio" -X -q
echo "Listo en $entorno."
