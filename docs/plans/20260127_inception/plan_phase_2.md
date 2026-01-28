# Phase 2 — Host Bootstrapping & Docker Stack

## Goal
Provision the EC2 host runtime environment via user_data/Ansible and deploy the Docker Compose stack (n8n, PostgreSQL, Nginx, Let's Encrypt companion) with persistent volumes and secrets stored outside Git.

## Scope
- User_data script (cloud-init compatible) that installs Docker Engine, Docker Compose plugin, and dependencies (curl, git, ufw optional) using Ubuntu package manager.
- Directory scaffolding under `/opt/n8n`, `/opt/n8n/nginx`, `/opt/n8n/postgres`, plus permissions/ownership adjustments.
- Docker Compose bundle defining services `postgres`, `n8n`, `nginx`, `certbot` (or supported ACME helper) with explicit networks, volumes, and restart policies.
- `.env` template documenting required variables (DB credentials, domain, webhook URL, encryption key). File is gitignored.
- Nginx configuration files (syntax: standard server blocks) implementing HTTP→HTTPS redirect, proxy headers, and TLS certificate mounting.
- Optional Ansible playbook (separate directory) for tasks user_data cannot cover (idempotent Docker stack deployment). Inventory excluded from repo.
- Integration test script (bash or Molecule) verifying Docker installed, containers run, and persistence across restarts.

## Tasks
- [ ] Author `infra/terraform/files/user_data.sh` (or similar) using `#!/bin/bash` + `set -euo pipefail`, installing Docker + compose, enabling services, creating directories.
- [ ] Template user_data via Terraform `templatefile` to inject domain/email variables.
- [ ] Create Docker Compose file `deploy/docker-compose.yml` with services, volumes, network `app_net`, and `depends_on` ordering.
- [ ] Provide `.env.example` at root or `deploy/.env.example`, listing required variables (`POSTGRES_PASSWORD`, `N8N_HOST`, `N8N_ENCRYPTION_KEY`, etc.).
- [ ] Write `deploy/nginx/conf.d/n8n.conf` (or similar) with listener configs; include comment referencing cert paths (`/etc/letsencrypt/live/<domain>` mounted read-only).
- [ ] Add certbot container definition (e.g., `certbot/certbot`) with command to obtain/renew certs using HTTP-01; schedule via cron or Docker `restart: unless-stopped` + manual hook.
- [ ] Document restart procedures (`docker compose down/up`).
- [ ] Implement integration test script under `tests/integration/bootstrap.sh` (or using Molecule) verifying Docker version, container health, and persistence by creating workflow via API (or placeholder file) then restarting containers.
- [ ] Update README snippet describing `.env` handling, user_data usage, Docker commands.

## Acceptance Criteria
- Running user_data on a fresh Ubuntu instance results in Docker + compose installed, directories created, and compose bundle ready (verified via logs/test script).
- `docker compose up -d` successfully starts all services; `docker compose ps` shows healthy states; HTTPS endpoint serves n8n via domain (certbot obtains certs).
- Removing/stopping containers and restarting preserves workflows (verified by via API or n8n DB check).
- `.env` stays untracked; `.env.example` documents every required variable.
- Integration test script passes against sandbox EC2 host.

## Tests (Must be implemented in this phase)
- `tests/integration/bootstrap.sh` (or Molecule scenario) covering Docker install verification and stack health.
- Manual validation of certificate issuance (documented steps) or automated check in script (curl HTTPS endpoint verifying cert issuer).
- Optional n8n API smoke test (create workflow, restart, confirm persistence via API).

## Edge Cases to Address
- User_data re-run safety (script should detect existing Docker installation and skip gracefully).
- Missing `.env` secrets: compose should fail fast with clear error; README instructs generating keys.
- Certbot rate limits or DNS propagation delays—document fallback and manual rerun instructions.
- Docker network name conflicts (use unique prefix or include `${COMPOSE_PROJECT_NAME}`).
- UFW interplay with security groups (document consistent approach; default disabled).

## Verification Steps
1. Launch sandbox EC2 with Phase 1 infrastructure; ensure user_data attached.
2. SSH in (sandbox account) and run `docker --version`, `docker compose version`.
3. Populate `.env` from `.env.example`; run `docker compose up -d` within `/opt/n8n`.
4. Visit `https://<domain>` and confirm n8n UI loads with valid cert.
5. Create sample workflow, restart stack (`docker compose down && docker compose up -d`), confirm workflow persists.
6. Execute `tests/integration/bootstrap.sh` (or `molecule test`) from local machine targeting sandbox host.
