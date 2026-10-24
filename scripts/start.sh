#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
env="${1:?usage : start.sh <test|prod>}"
dir="$root/.deploy/$env"

[ -f "$dir/current" ] || { echo "rien de déployé en $env" >&2; exit 1; }
tag="$(cat "$dir/current")"
release="$dir/releases/$tag"

set -a
source "$release/config/$env.env"
set +a

mkdir -p "$dir/data"
export FLUX_LAB_DB="$dir/data/flux_lab.db"

echo "démarrage de $env, version $tag, port $PORT"
cd "$release"
exec uv run --no-dev uvicorn flux_lab.api:app --port "$PORT"

