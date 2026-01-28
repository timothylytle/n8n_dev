#!/bin/bash
set -euo pipefail

LOG_TAG="[n8n-user-data]"

log() {
  echo "${LOG_TAG} $*"
}

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "${LOG_TAG} This script must run as root." >&2
    exit 1
  fi
}

configure_apt() {
  log "Preparing apt repositories"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  UBUNTU_CODENAME="$(lsb_release -cs)"
  cat >/etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable
EOF

  apt-get update -y
  apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    git
}

configure_docker() {
  systemctl enable docker
  systemctl start docker

  if id ubuntu >/dev/null 2>&1; then
    usermod -aG docker ubuntu
  fi
}

setup_directories() {
  log "Creating /opt/n8n directory tree"
  install -d -m 755 /opt/n8n
  install -d -m 755 /opt/n8n/nginx
  install -d -m 755 /opt/n8n/postgres
  install -d -m 755 /opt/n8n/certs

  if id ubuntu >/dev/null 2>&1; then
    chown -R ubuntu:ubuntu /opt/n8n
  fi
}

persist_metadata() {
  local domain="${DOMAIN_NAME:-example.com}"
  local email="${LETSENCRYPT_EMAIL:-admin@example.com}"

  cat >/opt/n8n/.bootstrap_env <<EOF
DOMAIN_NAME=${domain}
LETSENCRYPT_EMAIL=${email}
EOF

  chmod 600 /opt/n8n/.bootstrap_env
}

main() {
  require_root
  configure_apt
  configure_docker
  setup_directories
  persist_metadata
  log "Bootstrap completed"
}

main "$@"
