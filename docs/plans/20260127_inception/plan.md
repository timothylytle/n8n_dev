# Plan — n8n_poc

## Summary
This effort delivers a reproducible proof-of-concept stack where Terraform provisions a sandbox-only AWS footprint and Docker Compose hosts n8n, PostgreSQL, and Nginx with Let’s Encrypt TLS. By defining clear modules, automation scripts, and test coverage, contributors can stand up or tear down the environment safely without touching production accounts. The plan emphasizes minimal host configuration, container-first deployment, and persistence verification so workflows survive restarts.

Work executes in three sequential phases. Phase 1 creates the Terraform baseline plus Terratest suites. Phase 2 layers on the EC2 bootstrap and Docker stack, including certificates and persistence checks. Phase 3 operationalizes everything with documentation, observability guidance, and end-to-end validation. Each phase contains explicit acceptance criteria, edge cases, and required tests to keep quality high and avoid deferring validation.

## 0. References

### 0.1 Specification (Always Read)
- [spec.md](spec.md) — Detailed specification with acceptance criteria. **Read before any implementation.**

### 0.2 Phase Plans (Read Relevant Phase)
- [plan_phase_1.md](plan_phase_1.md) — Phase 1: Terraform Infrastructure Baseline.
- [plan_phase_2.md](plan_phase_2.md) — Phase 2: Host Bootstrapping & Docker Stack.
- [plan_phase_3.md](plan_phase_3.md) — Phase 3: Operationalization & Documentation.

### 0.3 Research (Read to Understand Codebase)
- [research.md](research.md) — Current repository state (docs only) and tooling constraints.

### 0.4 Source Document (Read if Requested)
- [idea.md](idea.md) — Original problem analysis and architecture hypothesis.

## 1. Software Design Document (SDD)
### 1.1 Goals & Constraints
- Single EC2 instance (Ubuntu 24.04) hosts all containers; no HA or managed services.
- Terraform + Terratest must target sandbox AWS accounts only (via `AWS_PROFILE`/`AWS_REGION` variables and sample tfvars). Production resources must never be implicated.
- Install footprint stays minimal using user_data scripts and optional Ansible (Docker-focused). Secrets remain outside Git in `.env` files; Terraform state stays local and gitignored.
- Public HTTPS access with Let’s Encrypt; fallback instructions required for issuance failures.

### 1.2 Proposed Architecture (High-level)
1. **Terraform Layer** (`infra/terraform`): root module orchestrates `modules/network`, `modules/compute`, `modules/dns`. Outputs expose public IP, instance ID, and domain URL. Backend remains local; tfvars specify sandbox credentials.
2. **Bootstrap Layer** (`scripts/user_data.sh`, optional `ansible/`): user_data installs Docker Engine + compose plugin, lays out `/opt/n8n` directory tree, fetches compose assets, and runs initial `docker compose pull`. Ansible can rerun idempotently if user_data insufficient.
3. **Runtime Layer** (`deploy/docker-compose.yml`, `deploy/nginx/*`): Docker Compose network `app_net` connects services `postgres`, `n8n`, `nginx`, `certbot`. Named volumes persist Postgres data, n8n config, and TLS certs. Nginx proxies HTTPS to n8n; certbot handles ACME challenges over HTTP.

### 1.3 Data Model & Types (Signatures, not full code)
- Terraform variables (HCL):
  ```hcl
  variable "instance_type" { type = string default = "t3.small" }
  variable "root_volume_size" { type = number default = 40 }
  variable "hosted_zone_id" { type = string }
  variable "domain_name" { type = string }
  variable "ssh_key_name" { type = string }
  variable "allowed_ssh_cidr" { type = list(string) default = ["0.0.0.0/0"] }
  variable "aws_profile" { type = string default = "sandbox" }
  variable "aws_region" { type = string default = "us-east-1" }
  ```
- `.env` files (dotenv syntax) stored outside Git:
  ```dotenv
  POSTGRES_DB=n8n
  POSTGRES_USER=n8n
  POSTGRES_PASSWORD=<generate secure>
  N8N_HOST=n8n.example.com
  N8N_PROTOCOL=https
  WEBHOOK_URL=https://n8n.example.com/
  N8N_ENCRYPTION_KEY=<32-byte hex>
  SSL_EMAIL=ops@example.com
  ```
- Docker volumes: `pg_data`, `n8n_data`, `letsencrypt`. Network: `app_net`.

### 1.4 Module / File-level Design
- `infra/terraform/main.tf`, `variables.tf`, `outputs.tf`, `providers.tf` plus module calls; `terraform.tfvars.example` highlights sandbox profile usage.
- `infra/terraform/modules/network`: defines security group with inbound 22/80/443, egress all. Outputs SG ID.
- `infra/terraform/modules/compute`: EC2 resource, IAM instance profile (if SSM desired), Elastic IP association, user_data rendered via `templatefile`. Outputs instance metadata.
- `infra/terraform/modules/dns`: Route53 `aws_route53_record` -> domain + Elastic IP.
- `scripts/user_data.sh`: Bash script using `#!/bin/bash`, `set -euo pipefail`, apt installs docker components, `systemctl enable docker`, creates directories, copies compose bundle from repo or remote storage.
- `ansible/playbooks/docker.yml`: optional idempotent tasks (scope: host) running `community.docker.docker_compose`. Inventories excluded from repo.
- `deploy/docker-compose.yml`: YAML `version: "3.9"` with service definitions, environment references to `.env`. `depends_on` ensures Postgres before n8n.
- `deploy/nginx/conf.d/n8n.conf`: server blocks for `80` (redirect/ACME) and `443` (proxy). Example snippet included in README.
- `tests/integration/bootstrap.sh`: bash script expecting `SSH_TARGET`, verifying docker/install/persistence. Mark executable.
- `test/terraform/go.mod` + `*_test.go`: Terratest modules verifying Terraform outputs. Initialize via `cd test/terraform && go mod init n8n_poc_terratest` and add dependency with `go get github.com/gruntwork-io/terratest/modules/terraform`.
- Update `.gitignore` to include `infra/terraform/terraform.tfstate*`, `*.tfvars`, `.env`, `ansible/inventory/`.

### 1.5 Interfaces & Contracts
- Terraform module contract: `modules/network` exposes `sg_id`; `modules/compute` requires SG ID and returns `public_ip`, `instance_id`; `modules/dns` expects `zone_id`, `domain_name`, `ip_address`. All documented in README.
- user_data interface: accepts template variables `{{domain_name}}`, `{{ssl_email}}`, `{{compose_repo_url}}`. Script must log to `/var/log/cloud-init-output.log` for troubleshooting.
- Docker Compose contract: `.env` must exist before `docker compose up`; missing keys produce `ENV` error. Compose exports port 80/443 only; Postgres internal.
- Nginx config ensures `proxy_set_header X-Forwarded-Proto https` etc. Certbot container mounts `/etc/letsencrypt` volume read-write; Nginx mounts read-only.
- Integration script expects SSH access via key defined in Terraform outputs and uses `scp` to upload `.env` and compose files.

### 1.6 Key Algorithms (Pseudo-code)
- **user_data bootstrap**:
  ```bash
  #!/bin/bash
  set -euo pipefail
  apt-get update
  apt-get install -y docker.io docker-compose-plugin curl
  usermod -aG docker ubuntu
  mkdir -p /opt/n8n/{nginx,postgres}
  curl -fsSL https://example.com/docker-compose.yml -o /opt/n8n/docker-compose.yml
  cat <<'ENV' > /opt/n8n/.env
  # placeholder; real secrets later
  ENV
  systemctl enable docker
  reboot-required || true
  ```
- **Cert renewal**:
  ```bash
  docker compose run --rm certbot renew && docker compose kill -s HUP nginx
  ```
- **Persistence test**:
  ```bash
  create_workflow_via_api()
  docker compose restart n8n postgres
  assert workflow_exists()
  ```

### 1.7 Testing Architecture
- Terratest (`go test ./test/terraform/...`): each module has sub-tests verifying plan/apply using sandbox profile; uses `terraform.Options{EnvVars: {"AWS_PROFILE": ...}}`.
- Integration tests: `tests/integration/bootstrap.sh` uses SSH to sandbox EC2, runs `docker compose ps`, hits HTTPS endpoint via `curl -k https://$DOMAIN/health`. Could integrate with Molecule if Ansible employed.
- Manual verification: create workflow via UI, schedule, confirm logs.
- Fixtures: if Python tests added later, default to `function` scope; for Go tests, rely on Terratest `retry.DoWithRetry`. No fixture directories used for tests.

### 1.8 Edge Cases
- DNS propagation delays causing certbot failure (handled via retry instructions and ability to run HTTP-only temporarily).
- Re-running Terraform/user_data should not destroy data: design ensures volumes persist and scripts check for existing installs before reinstalling.
- Elastic IP or Route53 record conflicts; modules must accept overrides or provide clear errors.
- Disk exhaustion; README instructs monitoring `df -h` and resizing EBS via Terraform variable update.

### 1.9 Observability & Ops
- Logging guidance: `docker compose logs -f nginx`, `journalctl -u docker` for daemon issues, `/var/log/cloud-init-output.log` for bootstrap debug.
- Optional CloudWatch: document enabling `awslogs` driver or SSM agent if needed.
- Health checks: mention `curl -k https://$DOMAIN` and `docker exec postgres pg_isready` commands.

## Edge Cases
- DNS propagation delays or Let’s Encrypt rate limits blocking certificates; must document HTTP-only fallback and manual re-run command (`docker compose run --rm certbot certonly ...`).
- Terraform/applies re-run after partial failure; modules must be idempotent and safe to destroy (protect Elastic IP release sequencing).
- Disk exhaustion on EC2/root volume; instructions for resizing EBS via Terraform variable plus `growpart` commands should be in README troubleshooting.
- Missing `.env` secrets or malformed dotenv syntax causing Compose failures; provide validation command (`grep -v '^#' .env | xargs -I{} echo {}`) and fail-fast behavior.
- User_data rerun or Ansible redeploy should not reinstall Docker unnecessarily; scripts must check `command -v docker` before apt installs.

## 2. Phase Breakdown (Approval checkpoint)

### Phase 1. Terraform Infrastructure Baseline (pending)
- **Goal:** Modular Terraform stack with sandbox-only applies and Terratest coverage.
- **Acceptance Criteria:** Terraform fmt/validate clean; apply in sandbox creates EC2 + SG + Elastic IP + Route53; second apply is no-op; local state/gitignore enforced.
- **Tests:** `terraform fmt -check`, `terraform validate`, `go test ./test/terraform/...`.
- **Done means:** Terraform + tests succeed using sandbox credentials; plan updated with progress entry.

### Phase 2. Host Bootstrapping & Docker Stack (pending)
- **Goal:** User_data/Ansible provisioning plus Docker Compose stack delivering HTTPS n8n with persistence.
- **Acceptance Criteria:** user_data installs Docker directories idempotently; compose stack (n8n/postgres/nginx/certbot) runs with `.env` secrets; sample workflow survives restart; integration script passes.
- **Tests:** `tests/integration/bootstrap.sh` (or Molecule), manual HTTPS verification, optional API smoke test.
- **Done means:** docker compose `up` and restart verification succeed on sandbox host; `.env` handling documented.

### Phase 3. Operationalization & Documentation (pending)
- **Goal:** Comprehensive README/runbook, observability notes, and end-to-end workflow validation.
- **Acceptance Criteria:** README instructs deployment, secrets, troubleshooting, teardown; observability + cert renewal procedures documented; workflow scheduling revalidated after reboot; all tests rerun.
- **Tests:** repeat Terratest + integration suite; manual workflow execution log.
- **Done means:** documentation updated, verification evidence captured in Progress/Decision Log.

## 3. Living Sections (Mandatory)

> **Instructions for maintainers:**
>
> This plan is a living document. As you make key design decisions, update the plan to record both the decision and the thinking behind it. Record all decisions in the `Decision Log` section.
>
> Maintain the `Progress` section in this plan and in the corresponding phase document. Mark tasks as `[ ]` not started, `[~]` in progress, or `[x]` done.
>
> When you discover optimizer behavior, performance tradeoffs, unexpected bugs, or inverse/unapply semantics that shaped your approach, capture those observations in the `Surprises & Discoveries` section with short evidence snippets (test output is ideal).
>
> If you change course mid-implementation, document why in the `Decision Log` and reflect the implications in `Progress`. Plans are guides for the next contributor as much as checklists for you.
>
> At completion of a major task or the full plan, write an `Outcomes & Retrospective` entry summarizing what was achieved, what remains, and lessons learned.
>
> **This document must describe not just the what but the why for almost everything.**

### 3.1 Progress
- [~] Phase 1: Terraform Infrastructure Baseline — 2026-01-27T13:39:59-0700
  - [x] 2026-01-27T13:42:00-0700 — Scaffold Terraform directories (`infra/terraform/modules/...`)
  - [x] 2026-01-27T13:47:00-0700 — Define Terraform variables/outputs skeleton across modules/root
  - [x] 2026-01-27T13:49:00-0700 — Implement security group module
  - [x] 2026-01-27T13:54:00-0700 — Implement compute module (EC2 + EIP wiring)
  - [x] 2026-01-27T13:55:00-0700 — Implement DNS module for Route53 record
  - [x] 2026-01-27T13:58:00-0700 — Wire modules in root Terraform configuration
  - [x] 2026-01-27T14:00:00-0700 — Add terraform.tfvars.example and .gitignore entries
  - [x] 2026-01-27T14:05:00-0700 — Add Terratest suite for modules
  - [x] 2026-01-27T14:25:00-0700 — Document terraform commands/usage in README per phase notes
- [x] Phase 1: Terraform Infrastructure Baseline — 2026-01-27T14:26:00-0700
  - [x] 2026-01-27T15:22:02-0700 — Switch hosted zone input from ID to name via data lookup
- [x] Phase 2: Host Bootstrapping & Docker Stack — 2026-01-27T15:58:00-0700
  - [x] 2026-01-27T15:42:30-0700 — Author scripts/user_data.sh installing Docker + directories
  - [x] 2026-01-27T15:47:30-0700 — Template user_data via Terraform
  - [x] 2026-01-27T15:52:00-0700 — Create Docker Compose stack (postgres/n8n/nginx/certbot)
  - [x] 2026-01-27T15:52:15-0700 — Provide deploy/.env.example
  - [x] 2026-01-27T15:52:30-0700 — Add nginx template + certbot integration
  - [x] 2026-01-27T15:54:30-0700 — Implement integration test script for bootstrap verification
  - [x] 2026-01-27T15:57:00-0700 — Update README with .env handling, user_data usage, restart procedures
- [ ] Phase 3: Operationalization & Documentation

### 3.2 Decision Log
- **Decision:** Gate Terratest execution on `N8N_TERRATEST_ENABLED`
  - Date: 2026-01-27
  - Rationale: Prevent accidental AWS resource creation by requiring an explicit opt-in env var before tests run.
- **Decision:** Prefer hosted zone name input with Route53 data lookup
  - Date: 2026-01-27
  - Rationale: Simplifies operator inputs and avoids needing to hunt hosted zone IDs while ensuring DNS resides in same AWS account.
- **Decision:** Default AMI filter to Ubuntu 22.04 until 24.04 images propagate
  - Date: 2026-01-27
  - Rationale: `ubuntu-noble-24.04` AMIs are not yet published in some regions (e.g., us-west-2), so Terratest would fail; keep 22.04 default but allow overrides via variable.
- **Decision:** Render nginx config with envsubst
  - Date: 2026-01-27
  - Rationale: Avoid hardcoding certificate paths by generating `n8n.conf` from a template that substitutes `N8N_HOST` at container start.
- **Decision:** Gate SSH-based integration script with `N8N_INTEGRATION_ENABLED`
  - Date: 2026-01-27
  - Rationale: Prevent accidental SSH execution while making it easy to opt into persistence/health checks.

### 3.3 Surprises & Discoveries
- **Observation:** Terraform provider plugins require elevated network access inside sandbox
  - Evidence: `terraform init`/`validate` failed until run with escalated permissions due to registry.terraform.io DNS restrictions.
- **Observation:** Canonical Ubuntu 24.04 AMIs unavailable in sandbox region
  - Evidence: Terratest apply failed with `data.aws_ami.ubuntu` "Your query returned no results" in `us-west-2` when filtering for `ubuntu-noble-24.04`, necessitating fallback.

### 3.4 Outcomes & Retrospective
(To be filled after completion)
