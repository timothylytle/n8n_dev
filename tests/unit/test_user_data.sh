#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

SCRIPT_PATH="scripts/user_data.sh"

if [[ ! -f "${SCRIPT_PATH}" ]]; then
  echo "ERROR: ${SCRIPT_PATH} is missing"
  exit 1
fi

bash -n "${SCRIPT_PATH}"
grep -q "set -euo pipefail" "${SCRIPT_PATH}"
