#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

require_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    echo "ERROR: missing ${path}"
    exit 1
  fi
}

require_file "deploy/docker-compose.yml"
require_file "deploy/.env.example"
require_file "deploy/nginx/templates/n8n.conf.template"

grep -q "certbot" deploy/docker-compose.yml
grep -q "LETSENCRYPT_EMAIL" deploy/.env.example
