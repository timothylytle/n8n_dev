#!/usr/bin/env bash
set -euo pipefail

if [[ "${N8N_INTEGRATION_ENABLED:-0}" != "1" ]]; then
  echo "Skipping integration test (set N8N_INTEGRATION_ENABLED=1 to run)."
  exit 0
fi

: "${N8N_INTEGRATION_HOST:?N8N_INTEGRATION_HOST is required}"
SSH_USER="${N8N_INTEGRATION_USER:-ubuntu}"
SSH_KEY="${N8N_INTEGRATION_SSH_KEY:-}"
WORKDIR="${N8N_INTEGRATION_WORKDIR:-/opt/n8n}"

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
if [[ -n "${SSH_KEY}" ]]; then
  SSH_OPTS+=(-i "${SSH_KEY}")
fi

run_remote() {
  ssh "${SSH_OPTS[@]}" "${SSH_USER}@${N8N_INTEGRATION_HOST}" "$@"
}

echo "[integration] Verifying Docker installation"
run_remote "docker --version"
run_remote "docker compose version"

echo "[integration] Checking compose services"
run_remote "cd ${WORKDIR} && docker compose ps"

echo "[integration] Testing persistence workflow marker"
MARKER_PATH="/home/node/.n8n/tests/persistence.marker"
run_remote "cd ${WORKDIR} && docker compose exec -T n8n /bin/sh -c 'mkdir -p \$(dirname ${MARKER_PATH}) && date > ${MARKER_PATH}'"
run_remote "cd ${WORKDIR} && docker compose restart n8n"
run_remote "cd ${WORKDIR} && docker compose exec -T n8n /bin/sh -c 'test -f ${MARKER_PATH}'"

echo "[integration] Completed successfully"
