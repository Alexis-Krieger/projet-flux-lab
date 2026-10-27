#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get upgrade -y
apt-get install -y docker.io curl ca-certificates

id deploy >/dev/null 2>&1 || useradd --create-home --shell /bin/bash deploy

