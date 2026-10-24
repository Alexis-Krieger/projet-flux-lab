#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

env="${1:?usage : scripts/run.sh <test|prod>}"
config="config/${env}.env"
[ -f "$config" ] || { echo "environnement inconnu : $env" >&2; exit 1; }

set -a
source "$config"
set +a

mkdir -p "$(dirname "$FLUX_LAB_DB")"
exec uv run uvicorn flux_lab.api:app --port "$PORT"
