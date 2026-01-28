# Research Notes — n8n_poc

## Repo Layout
- `docs/plans/20260127_inception/idea.md` — initial architecture concept (single EC2 + Docker Compose stack).
- `docs/plans/20260127_inception/spec.md` — finalized specification generated earlier.
- No infrastructure or application code exists yet; repo currently documentation-only.

## Tooling & Constraints Observed
- No Terraform, Docker, or Ansible files checked in yet; plan must define directory structure from scratch.
- No CI configuration present; contributors likely run Terraform/Terratest locally.
- README currently minimal; will need expansion in Phase 3.

## Existing Patterns to Reuse or Avoid
- Since codebase is empty, there are no established Terraform module conventions. Plan should define consistent layout (`infra/terraform/...`).
- No pytest/Go modules yet; Terratest introduction will require `go mod init` in `test/terraform` and referencing `github.com/gruntwork-io/terratest`.

## Potential Risks / Unknowns
- Need to ensure AWS sandbox account usage is enforced to avoid production impact.
- Certificate automation reliant on outbound HTTPS; confirm security groups/OS packages permit outbound traffic.

