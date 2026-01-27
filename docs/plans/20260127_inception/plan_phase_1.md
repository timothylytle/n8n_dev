# Phase 1 — Terraform Infrastructure Baseline

## Goal
Establish modular Terraform infrastructure (EC2, Elastic IP, security group, Route53) with Terratest validation and idempotent apply/destroy behavior.

## Scope
- Terraform root module and submodules: networking (security group rules), compute (EC2 + IAM role/policy + user_data wiring), DNS (Elastic IP + Route53 A record).
- Explicit segregation of AWS accounts/profiles: all Terraform/Terratest actions must target a sandbox/test account via dedicated `AWS_PROFILE`/`AWS_REGION` variables or short-lived credentials captured in `terraform.tfvars.example`. Production account IDs must never appear in defaults.
- Local Terraform backend configuration; `.gitignore` updates to exclude state.
- Terratest Go suite covering each module (plan/apply tests, variable validation).
- No Docker/Ansible work in this phase.

## Tasks
- [ ] Scaffold Terraform directories (`infra/terraform/modules/{network,compute,dns}` + root).
- [ ] Define module variables/outputs (instance type, volume size, hosted zone ID, domain name, SSH key, allowed CIDRs).
- [ ] Implement security group module enforcing inbound 22/80/443 and open egress.
- [ ] Implement compute module provisioning Ubuntu 24.04 EC2 with Elastic IP association option, user_data template input, tags.
- [ ] Implement DNS module creating Route53 A record pointing to Elastic IP.
- [ ] Wire modules in root `main.tf`, include provider config, remote-exec outputs (public IP, URL).
- [ ] Add sample `terraform.tfvars.example` documenting sandbox AWS profile/region variables and `.gitignore` entries for `terraform.tfstate*`.
- [ ] Add Terratest suite (`test/terraform/*`) with Go tests invoking each module (scoped to `t.Run`).
- [ ] Document commands in README snippet or phase notes (terraform init/plan/apply, go test).

## Acceptance Criteria
- `terraform fmt -check`, `terraform validate` succeed.
- `terraform apply` using sandbox credentials/sample tfvars provisions EC2 + security group + Elastic IP + DNS record; rerunning apply reports no changes and does not touch prod accounts.
- Terratest suite passes, exercising module creation/destruction (or mock validation) and checking expected attributes.
- Sensitive files (`terraform.tfstate`, `.tfvars`) are gitignored.

## Tests (Must be implemented in this phase)
- `go test ./test/terraform/...` (Terratest verifying network/compute/dns modules).
- Manual `terraform plan` (documented) ensuring zero diff after second apply.

## Edge Cases to Address
- Missing/invalid hosted zone ID or domain name inputs.
- User_data template path errors.
- Failure to associate Elastic IP (ensure dependency order).
- Destroy safety to release Elastic IP and DNS record.

## Verification Steps
1. `cd infra/terraform && terraform init`.
2. `terraform fmt -check && terraform validate`.
3. `terraform plan -var-file=example.tfvars` (documented path) to inspect resources.
4. `go test ./test/terraform/...`.
5. `terraform apply -auto-approve` (if permissible) and re-run to confirm idempotence.
