# n8n_dev

Provision AWS infrastructure for a self-hosted n8n proof-of-concept stack. The project relies on Terraform modules (Phase 1), Docker/Ansible automation (Phase 2), and operational runbooks (Phase 3).

## Phase 1 Quickstart (Terraform + Terratest)
1. Export sandbox AWS credentials or set profile/region via Terraform variables. Never point to production accounts.
2. Copy `infra/terraform/terraform.tfvars.example` to `terraform.tfvars` and update values:
   ```hcl
   aws_profile     = "sandbox"
   aws_region      = "us-east-1"
   domain_name     = "n8n.sandbox.example.com"
   hosted_zone_name = "example.com"
   letsencrypt_email = "ops@example.com"
   ssh_key_name    = "sandbox-key"
   allowed_ssh_cidr = ["0.0.0.0/0"]
   ```
3. Initialize and validate Terraform:
   ```bash
   cd infra/terraform
   terraform init
   terraform fmt -check
   terraform validate
   ```
4. Plan/apply in the sandbox account:
   ```bash
   terraform plan -var-file=terraform.tfvars
   terraform apply -var-file=terraform.tfvars
   # Re-run apply to confirm idempotence
   terraform apply -var-file=terraform.tfvars
   ```
5. Run Terratest suite (requires temporary AWS resources). Set env vars first:
   ```bash
   export N8N_TERRATEST_ENABLED=1
   export N8N_TEST_HOSTED_ZONE_NAME=example.com
   export N8N_TEST_DOMAIN=n8n.sandbox.example.com
   export N8N_TEST_SSH_KEY_NAME=sandbox-key
   export N8N_TEST_AWS_PROFILE=sandbox
   export N8N_TEST_AWS_REGION=us-east-1
   export N8N_TEST_LETSENCRYPT_EMAIL=ops@example.com
   cd test/terraform
   go test ./...
   ```
6. Destroy when finished to avoid charges:
   ```bash
   cd infra/terraform
   terraform destroy -var-file=terraform.tfvars
   ```

`.tfstate`, `.tfvars`, and `.env` files are excluded via `.gitignore`. Keep secrets out of version control.

## Phase 2 Quickstart (Docker Stack)
1. Terraform injects `scripts/user_data.sh` via the `letsencrypt_email` variable, so newly created EC2 hosts already have Docker and `/opt/n8n` prepared:
   ```bash
   ssh ubuntu@<instance-ip> "docker --version && ls /opt/n8n"
   ```
2. Copy deployment assets (or bake them into an AMI/image):
   ```bash
   rsync -av deploy/ ubuntu@<instance-ip>:/opt/n8n/
   ```
3. Create `.env` from the template and populate secrets:
   ```bash
   ssh ubuntu@<instance-ip>
   cd /opt/n8n
   cp .env.example .env
   nano .env  # edit POSTGRES_PASSWORD, N8N_ENCRYPTION_KEY, LETSENCRYPT_EMAIL, etc.
   ```
4. Launch the stack and confirm status:
   ```bash
   docker compose --env-file .env up -d
   docker compose --env-file .env ps
   ```
5. Restart procedure (preserves Postgres/n8n volumes):
   ```bash
   docker compose --env-file .env down
   docker compose --env-file .env up -d
   ```
6. Manual certificate renewal fallback:
   ```bash
   docker compose run --rm certbot certonly \
     --webroot -w /var/www/certbot \
     --non-interactive --agree-tos \
     --email "$LETSENCRYPT_EMAIL" \
     -d "$N8N_HOST"
   docker compose kill -s HUP nginx
   ```
7. Optional integration smoke test from your workstation:
   ```bash
   export N8N_INTEGRATION_ENABLED=1
   export N8N_INTEGRATION_HOST=<instance-ip>
   export N8N_INTEGRATION_USER=ubuntu
   export N8N_INTEGRATION_SSH_KEY=~/.ssh/your-key.pem
   bash tests/integration/bootstrap.sh
   ```
