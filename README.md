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
   cd test/terraform
   go test ./...
   ```
6. Destroy when finished to avoid charges:
   ```bash
   cd infra/terraform
   terraform destroy -var-file=terraform.tfvars
   ```

`.tfstate`, `.tfvars`, and `.env` files are excluded via `.gitignore`. Keep secrets out of version control.
