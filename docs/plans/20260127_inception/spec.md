# n8n_poc — Specification

## 1. Context & Goals (User/Business Perspective)
- Deploy a proof-of-concept environment where a single EC2 instance hosts n8n, PostgreSQL persistence, and Nginx reverse proxy via Docker Compose.
- Success equals accessing the n8n web UI over HTTPS at a custom domain, scheduling workflows, and persisting state across restarts.
- Infrastructure managed through Terraform modules (with Terratest coverage) so the operator can tweak instance size, storage, domain, and networking via variables.

## 2. Non-Goals / Out of Scope
- High availability, multi-AZ or multi-region deployments.
- Managed services like RDS, ALBs, or AWS ACM; ALB-based TLS termination is out.
- Provisioning paths other than Docker-based services (no CloudFormation, no manual package installs beyond Docker dependencies).
- OS hardening beyond what's required to run Docker/Nginx/Postgres/n8n.
- Terraform remote state management or storing state files in Git.

## 3. Definitions / Glossary
- **n8n**: Workflow automation platform (`n8nio/n8n` image).
- **PostgreSQL**: n8n persistence layer (`postgres:16` image) using Docker volume.
- **Nginx**: Reverse proxy + TLS termination container.
- **Terraform**: Infrastructure-as-code describing EC2, Elastic IP, security groups, Route53 record.
- **Terratest**: Testing framework ensuring Terraform modules plan/apply as expected.
- **User data**: EC2 bootstrap script installing Docker + Compose plugin, preparing `/opt/n8n` directories.
- **Ansible**: Optional automation when user_data cannot cover Docker/Nginx/Postgres/n8n provisioning (no inventory files checked into Git).

## 4. Functional Requirements
### 4.1 User Stories
- As an operator, I can configure and provision AWS resources via Terraform variables (instance type, disk size, domain, hosted zone, SSH key) so I can repeat deployments easily.
- As an operator, I can bootstrap the EC2 host via user_data so Docker, Docker Compose plugin, and the `/opt/n8n` directory structure exist without manual steps.
- As an operator, I can deploy the Docker Compose stack (n8n, PostgreSQL, Nginx, Let's Encrypt companion) using `.env` secrets stored outside Git to keep credentials secure.
- As an operator, I can optionally run Ansible playbooks located outside Terraform directories for tasks user_data cannot handle, focused on the Docker stack only.

### 4.2 Use Cases (happy path + key variants)
- **UC1: Fresh deployment** – run Terraform to create EC2 + Elastic IP + security group + Route53 record; confirm user_data completes, bring Docker Compose stack up, access n8n via HTTPS.
- **UC2: DNS/TLS configuration** – Terraform sets Route53 A record pointing to Elastic IP; Dockerized Let's Encrypt helper validates via HTTP-01 and stores certs so Nginx terminates TLS.
- **UC3: Persistence verification** – restart Docker services or the EC2 host, ensuring Postgres/n8n volumes retain workflows and automatic restarts happen via Docker policies/systemd.
- **UC4: Workflow execution** – use the n8n UI to create and schedule a workflow, demonstrating the proof-of-concept goal.

### 4.3 Edge Cases & Failure Modes
- User_data failures (e.g., Docker install failure) must be diagnosable via system logs; README should describe remediation.
- Let's Encrypt issuance failures (DNS propagation delays, rate limits) should degrade gracefully (temporary HTTP-only) with documented manual recovery.
- Storage exhaustion on Postgres or root volume should be detectable with recommended manual/CloudWatch checks.
- Terraform runs must be idempotent: repeated applies don't recreate resources unless inputs change; local state remains outside Git.
- Security group misconfiguration leading to blocked ports should be identifiable via health-check guidance.

## 5. Non-Functional Requirements
- **Performance**: Default t3.small must handle light workflows; variables allow scaling up. Containers should stay within host CPU/memory limits.
- **Security/Privacy**: HTTPS enforced; HTTP redirects to HTTPS. Ports 22/80/443 only inbound. Secrets stored in `.env` files outside Git. UFW optional but must align with security group rules.
- **Reliability**: Single-host PoC; Docker restart policies/systemd ensure services recover after reboot. Persistent volumes prevent data loss.
- **Observability**: Docker logs document service output; optional instructions for CloudWatch/log aggregation. Terraform/Terratest failures surface in CLI/CI logs.
- **Compliance**: Terraform state stored locally (gitignored). Ansible inventory never committed.

## 6. UX / API Contracts (as applicable)
- n8n web UI reachable at `https://<custom-domain>`; HTTP requests redirect to HTTPS.
- UI flow covers initial login/setup (documented default credentials or initialization steps) and scheduling workflows.
- Terraform CLI variables documented for domain, hosted zone, instance sizing, key pair, disk configuration.
- Ansible playbooks (if used) expose variables for Docker image versions, secrets path, and directories.
- Error handling expectations: Terraform validates required variables with clear messages; Ansible/Docker commands fail with actionable output.

## 7. Data & State
- **PostgreSQL volume**: Docker named volume or bind mount (e.g., `/opt/n8n/postgres`) to persist `n8n` DB across restarts.
- **n8n volume**: Stores encryption key, workflow states, and configuration.
- **Nginx/Certbot volumes**: Persist certificates and challenge files for renewal continuity.
- **Terraform state**: Stored locally (default `terraform.tfstate`), ignored by Git.

## 8. Acceptance Criteria (Top-level)
- Terraform apply provisions EC2 (Ubuntu 24.04), Elastic IP, security group (22/80/443 inbound), and Route53 A record; destroy removes them cleanly.
- User_data script installs Docker + Compose plugin, creates `/opt/n8n` directories, and can be rerun without adverse effects.
- Docker Compose stack (n8n, PostgreSQL, Nginx, Let's Encrypt companion) deploys with a single command and serves n8n UI via HTTPS.
- Restarting EC2 or Docker services retains workflows/certs and auto-starts services via Docker restart policies/systemd.
- Terratest suite validates each Terraform module's plan/apply behavior.
- README documents end-to-end deployment, secret handling, Docker stack operations, and troubleshooting.
- `.env` and Terraform state excluded from version control; Ansible inventory absent from repo.

## 9. Open Questions
- None (decisions confirmed: Dockerized Let's Encrypt, public UI access, default VPC, Ansible limited to Docker stack tasks).

## 10. Assumptions
- Operator supplies Route53 hosted zone, desired subdomain, and SSH key pair.
- Terraform/Terratest run locally with appropriate AWS credentials.
- Let's Encrypt HTTP-01 validation succeeds (public DNS).
- Minimal OS hardening acceptable for PoC purposes.

## 11. References
1. n8n Docker installation – https://docs.n8n.io/hosting/installation/docker/
2. PostgreSQL Docker image guide – https://www.docker.com/blog/how-to-use-the-postgres-docker-official-image/
3. n8n on AWS guide – https://medium.com/@mmartinmainan/running-n8n-for-free-on-aws-a-self-hosting-guide-for-n8n-lovers-4e367727f45e

## 12. Technical Notes / Implementation Hints
- Nginx: HTTP → HTTPS redirect; HTTPS server_name matches domain; proxy to `http://n8n:5678` with WebSocket headers (`Upgrade`, `Connection`, `X-Forwarded-*`).
- n8n env vars to surface in `.env`: `DB_TYPE=postgresdb`, `DB_POSTGRESDB_HOST=postgres`, `DB_POSTGRESDB_DATABASE=n8n`, `DB_POSTGRESDB_USER=n8n`, `DB_POSTGRESDB_PASSWORD=<var>`, `N8N_HOST=<domain>`, `N8N_PROTOCOL=https`, `WEBHOOK_URL=https://<domain>/`, `N8N_ENCRYPTION_KEY=<secret>`.
- Directory layout: `/opt/n8n`, `/opt/n8n/nginx`, `/opt/n8n/postgres`; `.env` stored outside Git but referenced by Docker Compose.
