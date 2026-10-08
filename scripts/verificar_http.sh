#!/usr/bin/env bash
# Verificaciones de runbook §2.1 que exigen una sesión real del personal (no se
# pueden hacer en local). Pide la clave por teclado, sin eco; nada queda en disco
# ni en el historial, y la sesión se cierra al terminar.
#
#   scripts/verificar_http.sh dev <correo-de-tu-cuenta>
#
# 1. Prefer: tx=rollback NO debe revertir la bitácora de buscar_persona.
# 2. Un error de validación por HTTP NO debe traer `details` ni `hint` (A-1).
set -euo pipefail
PSQL="${CONDA_PREFIX:-$HOME/miniconda3/envs/bicis}/bin/psql"

entorno="${1:-}"; correo="${2:-}"
case "$entorno" in dev|prod) ;; *) echo "uso: $0 dev|prod <correo>" >&2; exit 2 ;; esac
[ -n "$correo" ] || { echo "falta el correo" >&2; exit 2; }
servicio="service=bicis_$entorno"
ref="$(awk -v s="[bicis_$entorno]" '$0==s{f=1;next} /^\[/{f=0} f && /^user=/{sub(/^user=postgres\./,""); print}' ~/.pg_service.conf)"
url="https://$ref.supabase.co"
case "$entorno" in
  dev)  clave_publica="sb_publishable_5z8E4sWa1M-73UmOanuezw_JBUFGnTX" ;;
  prod) clave_publica="sb_publishable_lFBmdb53ut_MMPai4UlYgg_Tp4uAfp-" ;;
esac

read -r -s -p "Clave de $correo en $entorno (no se muestra): " clave
echo
token="$(python3 - "$url" "$clave_publica" "$correo" "$clave" <<'PY'
import json, sys, urllib.request
url, apikey, correo, clave = sys.argv[1:]
pet = urllib.request.Request(f"{url}/auth/v1/token?grant_type=password", method="POST",
    data=json.dumps({"email": correo, "password": clave}).encode(),
    headers={"apikey": apikey, "content-type": "application/json"})
try:
    print(json.load(urllib.request.urlopen(pet))["access_token"])
except Exception as e:
    sys.exit(f"No se pudo iniciar sesión ({getattr(e, 'code', e)}).")
PY
)"
unset clave
trap 'curl -s -o /dev/null -X POST "$url/auth/v1/logout" -H "apikey: $clave_publica" -H "authorization: Bearer $token"' EXIT

contar() { "$PSQL" "$servicio" -X -A -t -c "select count(*) from public.bitacora_consultas where tipo = 'buscar_persona'"; }

echo "1. Prefer: tx=rollback en buscar_persona"
antes="$(contar)"
encabezados="$(curl -s -D - -o /dev/null -X POST "$url/rest/v1/rpc/buscar_persona" \
  -H "apikey: $clave_publica" -H "authorization: Bearer $token" -H "content-type: application/json" \
  -H "Prefer: tx=rollback" -d '{"p_tipo": "CC", "p_numero": "00100777"}')"
despues="$(contar)"
aplicada="$(grep -i '^preference-applied' <<<"$encabezados" | tr -d '\r' || true)"
if [ "$despues" -gt "$antes" ]; then
  echo "   OK: la búsqueda quedó en la bitácora ($antes → $despues). ${aplicada:-(PostgREST no aplicó tx=rollback)}"
else
  echo "   FALLA: la bitácora no creció ($antes → $despues). $aplicada"; fallas=1
fi

echo "2. Error de validación por HTTP sin details ni hint"
respuesta="$(curl -s -X POST "$url/rest/v1/rpc/validar_persona" \
  -H "apikey: $clave_publica" -H "authorization: Bearer $token" -H "content-type: application/json" \
  -d '{"p_persona_id": "00000000-0000-4000-8000-000000000000"}')"
python3 - "$respuesta" <<'PY' || fallas=1
import json, sys
r = json.loads(sys.argv[1])
ok = r.get("details") in (None, "") and r.get("hint") in (None, "")
print(f"   {'OK' if ok else 'FALLA'}: message={r.get('message')!r}, details={r.get('details')!r}, hint={r.get('hint')!r}")
sys.exit(0 if ok else 1)
PY
exit "${fallas:-0}"
