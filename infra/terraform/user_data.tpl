#!/bin/bash
set -euo pipefail

cat <<'N8N_BOOTSTRAP' >/tmp/n8n_user_data.sh
${bootstrap_contents}
N8N_BOOTSTRAP

chmod +x /tmp/n8n_user_data.sh

export DOMAIN_NAME="${domain_name}"
export LETSENCRYPT_EMAIL="${letsencrypt_email}"

/tmp/n8n_user_data.sh
