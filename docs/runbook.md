# n8n PoC Runbook

## Prerequisites
- Sandbox AWS account provisioned via Phase 1 Terraform.
- EC2 instance reachable over SSH (default user `ubuntu`).
- Docker stack deployed per README (Phase 2).

## Create & Schedule a Workflow
1. Log into `https://<domain>` using your n8n credentials.
2. Click **Workflows → New** and add:
   - **Cron node:** Every 5 minutes.
   - **HTTP Request node:** `GET https://httpbin.org/get`.
3. Connect nodes, save the workflow as “heartbeat”, and toggle **Activate**.
4. Confirm executions under **Executions** after at least one interval.

## Persistence Check
1. SSH into the host and run:
   ```bash
   docker compose exec -T n8n /bin/sh -c 'mkdir -p ~/.n8n/tests && date > ~/.n8n/tests/marker'
   docker compose restart n8n
   docker compose exec -T n8n /bin/sh -c 'cat ~/.n8n/tests/marker'
   ```
2. Ensure the marker file persists after restart; otherwise inspect volumes (`docker volume ls`).

## Logs & Monitoring
- Tail workflow logs: `docker compose logs -f n8n`.
- Death/health events: `docker compose ps` shows healthchecks; `docker events` for detailed stream.
- Host logs: `journalctl -u docker`, `dmesg` for kernel issues.
- Certbot status: `docker compose logs -f certbot`.

## Troubleshooting
| Symptom | Checks | Resolution |
| --- | --- | --- |
| HTTPS returns default Nginx page | `ls /etc/letsencrypt/live/<domain>` inside nginx | Rerun certbot container; ensure DNS resolves and port 80 open. |
| Workflow missing after reboot | `docker volume inspect n8n_n8n_data` | Make sure compose uses named volumes, not bind to ephemeral paths; verify user_data didn’t wipe directories. |
| Cron jobs not running | Check workflow is “Active”; inspect `Executions` tab | Restart n8n container and ensure timezone in `.env` is correct. |

## Teardown
1. Export workflow backups (`Settings → Export`) before destroying.
2. Run `docker compose --env-file .env down -v` to remove containers/volumes if desired.
3. `terraform destroy -var-file=terraform.tfvars` to remove AWS resources.
