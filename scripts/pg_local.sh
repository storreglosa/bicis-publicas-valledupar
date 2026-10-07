#!/usr/bin/env bash
# Postgres 17 local para probar las migraciones sin Docker (entorno conda `bicis`).
#   scripts/pg_local.sh start | stop | status
# Datos en .pg_local/ (ignorado por git). Escucha solo por socket en .pg_local/ y en el puerto 54329.
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${CONDA_PREFIX:-$HOME/miniconda3/envs/bicis}/bin"
DATOS="$RAIZ/.pg_local/datos"
SOCKET="$RAIZ/.pg_local"
PUERTO=54329

case "${1:-status}" in
  start)
    if [ ! -d "$DATOS" ]; then
      mkdir -p "$DATOS"
      "$BIN/initdb" -D "$DATOS" -U postgres --auth=trust --encoding=UTF8 --locale=C.UTF-8 >/dev/null
    fi
    "$BIN/pg_ctl" -D "$DATOS" -l "$RAIZ/.pg_local/servidor.log" \
      -o "-p $PUERTO -k $SOCKET -c listen_addresses=''" -w start
    echo "conexión: host=$SOCKET port=$PUERTO user=postgres dbname=postgres"
    ;;
  stop)   "$BIN/pg_ctl" -D "$DATOS" -m fast stop ;;
  status) "$BIN/pg_ctl" -D "$DATOS" status ;;
  *) echo "uso: $0 start|stop|status" >&2; exit 2 ;;
esac
