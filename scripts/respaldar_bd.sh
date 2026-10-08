#!/usr/bin/env bash
# Respaldo cifrado de la base (el plan Free de Supabase no trae respaldos; diseño §10).
#
#   BICIS_RESPALDO_GPG=<correo o huella de tu clave pública> scripts/respaldar_bd.sh prod
#
# Qué guarda: los esquemas public y privado (estructura y datos), el id, correo y
# fecha de las cuentas de auth.users (lo demás de Auth lo maneja Supabase) y los
# conteos de filas para comprobar la restauración. Las fotos de Storage NO van.
# Dónde: ~/Claude_code/respaldos-bicis/AAAA-MM-DD_bicis_<entorno>.tar.gpg, fuera del
# repositorio (cámbialo con BICIS_RESPALDOS). Se cifra con la clave PÚBLICA: el script
# no necesita frase de paso; para abrirlo hace falta la privada (scripts/restaurar_prueba.sh).
# Conserva los 8 más recientes y el primero de cada mes de los últimos 12 meses.
# Registra el resultado con registrar_tarea('respaldo'): «Último respaldo» del tablero.
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${CONDA_PREFIX:-$HOME/miniconda3/envs/bicis}/bin"

entorno="${1:-}"
case "$entorno" in dev|prod) ;; *) echo "uso: BICIS_RESPALDO_GPG=<clave> $0 dev|prod" >&2; exit 2 ;; esac
destinatario="${BICIS_RESPALDO_GPG:?Define BICIS_RESPALDO_GPG con el correo o la huella de tu clave pública de gpg}"
servicio="service=bicis_$entorno"
carpeta="${BICIS_RESPALDOS:-$HOME/Claude_code/respaldos-bicis}"
case "$(cd "$(dirname "$carpeta")" 2>/dev/null && pwd)/$(basename "$carpeta")/" in
  "$RAIZ"/*) echo "Los respaldos no van dentro del repositorio ($RAIZ)." >&2; exit 1 ;;
esac
mkdir -p "$carpeta" && chmod 700 "$carpeta"

trabajo="$(mktemp -d)"
chmod 700 "$trabajo"
trap 'rm -rf "$trabajo"' EXIT
inicio="$(date -u +%FT%TZ)"
fecha="$(TZ=America/Bogota date +%F)"
archivo="$carpeta/${fecha}_bicis_${entorno}.tar.gpg"

registrar() {   # registrar <ok|error> <detalle-json>   (BICIS_RESPALDO_REGISTRAR=0: simulacro del script, no se registra)
  [ "${BICIS_RESPALDO_REGISTRAR:-1}" = "1" ] || return 0
  "$BIN/psql" "$servicio" -X -q -v ON_ERROR_STOP=1 -v inicio="$inicio" -v resultado="$1" -v detalle="$2" >/dev/null \
    <<<"select public.registrar_tarea('respaldo', :'inicio'::timestamptz, :'resultado', :'detalle'::jsonb);"
}
trap 'registrar error "{\"paso\": \"fallo antes de terminar\"}" || true; rm -rf "$trabajo"' ERR

echo "→ Volcado de $entorno"
"$BIN/pg_dump" "$servicio" -Fc -n public -n privado -f "$trabajo/bicis.dump"
"$BIN/psql" "$servicio" -X -q -v ON_ERROR_STOP=1 \
  -c "\\copy (select id, email, email_confirmed_at, created_at from auth.users order by created_at) to '$trabajo/auth_usuarios.csv' csv header"
"$BIN/psql" "$servicio" -X -q -A -t -F $'\t' -v ON_ERROR_STOP=1 > "$trabajo/conteos.tsv" <<'SQL'
select t.table_schema || '.' || t.table_name,
       (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from %I.%I', t.table_schema, t.table_name), false, true, '')))[1]::text
  from information_schema.tables t
 where t.table_schema in ('public', 'privado') and t.table_type = 'BASE TABLE'
 order by 1;
SQL

echo "→ Cifrado para $destinatario"
tar -C "$trabajo" -cf - bicis.dump auth_usuarios.csv conteos.tsv \
  | gpg --batch --yes --trust-model always --encrypt --recipient "$destinatario" --output "$archivo"
chmod 600 "$archivo"
bytes="$(stat -c %s "$archivo")"

# Rotación: los 8 más recientes + el primero de cada mes (12 meses).
mapfile -t todos < <(ls -1 "$carpeta"/*_bicis_"$entorno".tar.gpg 2>/dev/null | sort -r)
declare -A conservar=()
for f in "${todos[@]:0:8}"; do conservar["$f"]=1; done
declare -A meses=()
for f in $(printf '%s\n' "${todos[@]}" | sort); do
  mes="$(basename "$f" | cut -c1-7)"
  if [ -z "${meses[$mes]:-}" ]; then meses["$mes"]="$f"; fi
done
for mes in $(printf '%s\n' "${!meses[@]}" | sort -r | head -12); do conservar["${meses[$mes]}"]=1; done
for f in "${todos[@]}"; do [ -n "${conservar[$f]:-}" ] || rm -f "$f"; done

registrar ok "{\"archivo\": \"$(basename "$archivo")\", \"bytes\": $bytes}"
echo "Listo: $archivo ($bytes bytes)"
