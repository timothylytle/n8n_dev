# Phase 3 — Operationalization & Documentation

## Goal
Deliver operational readiness by documenting deployment/runbooks, adding observability guidance, and validating the full end-to-end workflow (Terraform → Docker stack → scheduled n8n workflow).

## Scope
- Comprehensive README covering prerequisites (AWS CLI, Go for Terratest, Docker), configuration (`.env`, tfvars), deployment sequence (Terraform → user_data/Ansible → Docker), verification, and teardown.
- Troubleshooting section (cert issues, Docker failures, Terraform errors) plus safety notes for sandbox vs production.
- Observability guidance: where to view logs (Docker, systemd journal, certbot), suggested CloudWatch metrics/log exports if desired.
- Runbook/checklist for executing sample workflow, validating schedule triggers, and confirming persistence across restarts.
- Re-run full suite of tests (Terratest + integration) and document results.

## Tasks
- [ ] Expand `README.md` with sections: Overview, Prereqs, Configuration (tfvars/.env), Deployment Steps, Verification, Troubleshooting, Teardown.
- [ ] Add `docs/runbook.md` (optional) or README subsection describing workflow creation, scheduling, and validation steps.
- [ ] Document log/monitoring approach (Docker logs commands, journalctl, optional CloudWatch setup guidance).
- [ ] Provide certificate renewal guidance (cron job, manual `docker compose run certbot renew`).
- [ ] Run Terratest + integration scripts end-to-end in sandbox; capture results, update plan progress.
- [ ] Compile known limitations/non-goals section referencing spec.

## Acceptance Criteria
- README is self-contained enough for a new operator to deploy the stack without external guidance.
- Observability instructions clearly state how to inspect service health/logs and validate HTTPS certs.
- Sample workflow creation and scheduling documented, with verification that it runs post-restart.
- All tests (Terratest + integration) rerun successfully and logged in plan Progress.
- Cleanup instructions prevent orphaned AWS resources/certs.

## Tests (Must be implemented in this phase)
- Rerun `go test ./test/terraform/...` and `tests/integration/bootstrap.sh` (or Molecule) with updated instructions.
- Manual workflow scheduling test with documented evidence (screenshots optional, textual confirmation acceptable).

## Edge Cases to Address
- Certificates expiring without renewal (document detection and manual renewal procedure).
- Workflow failures after EC2 reboot (ensure troubleshooting steps highlight logs/DB persistence checks).
- Misconfigured `.env` variables causing startup failures (README warnings + validation tips).
- Terraform destroy left-overs (Elastic IP/Route53) if fails mid-teardown.

## Verification Steps
1. Follow README to deploy infrastructure + Docker stack in sandbox.
2. Create & schedule sample n8n workflow; observe execution and logs.
3. Restart EC2, confirm workflow persists and re-runs.
4. Verify cert validity via `openssl s_client -connect domain:443 -servername domain`.
5. Execute Terratest & integration scripts; log results.
6. Perform teardown per README, confirming resources removed.
