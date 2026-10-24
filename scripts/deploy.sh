#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
env="${1:?usage : deploy.sh <test|prod> <tag>}"
tag="${2:?usage : deploy.sh <test|prod> <tag>}"

git -C "$root" rev-parse --verify --quiet "refs/tags/$tag" >/dev/null \
  || { echo "tag inconnu : $tag" >&2; exit 1; }

release="$root/.deploy/$env/releases/$tag"
if [ -d "$release" ]; then
  echo "version déjà installée : $tag"
else
  mkdir -p "$release"
  git -C "$root" archive "$tag" | tar -x -C "$release"
  (cd "$release" && uv sync --locked --no-dev)
fi

echo "$tag" > "$root/.deploy/$env/current"
echo "$env : version active = $tag"

