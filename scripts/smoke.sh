#!/usr/bin/env bash
set -euo pipefail

wheel="${1:?usage : smoke.sh <fichier.whl> [port]}"
port="${2:-8765}"
work="$(mktemp -d)"
pid=""
trap '[ -n "$pid" ] && kill "$pid" 2>/dev/null || true; rm -rf "$work"' EXIT

uv venv --quiet "$work/venv"
py="$work/venv/bin/python"
[ -x "$py" ] || py="$work/venv/Scripts/python.exe"
uv pip install --quiet --python "$py" "$wheel"

export FLUX_LAB_DB="$work/smoke.db"
"$py" -m uvicorn flux_lab.api:app --port "$port" &
pid=$!

reponse=""
for _ in $(seq 1 30); do
  if reponse="$(curl -sf "http://127.0.0.1:$port/health")"; then break; fi
  sleep 1
done

echo "réponse : ${reponse:-aucune}"
case "$reponse" in
  *'"status":"ok"'*) echo "SMOKE OK" ;;
  *) echo "SMOKE KO" >&2; exit 1 ;;
esac

