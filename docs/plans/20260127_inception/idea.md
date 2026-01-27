# **n8n\_poc**

## Goal

The goal of this project is to deploy a proof of concept for n8n and postgresql as docker containers on an ec2 instance in Amazon AWS.  This is a proof of concept, I do not need any reliability (multiple AZ or multi region support)  at the end of this project, I should be able to access the n8n application via a URL and schedule a workflow run via the Web UI.

## Current State

None, this is a brand new project with no defined architecture yet.

## Idea

**Goal:** One EC2 instance hosts everything via Docker Compose:

* **n8n** (workflow automation)
* **PostgreSQL** (n8n persistence)
* **Nginx** (reverse proxy \+ TLS termination)

**Public access:**

* EC2 has an **Elastic IP (static public IP)**
* **Route53 A record** points your domain/subdomain to that Elastic IP
* Nginx receives HTTPS traffic on 443 and forwards to n8n on an internal Docker network

**Data durability:**

* Postgres uses a Docker volume (or bind mount on EBS) so restarts don’t lose data
* n8n also uses a volume for its config/state

---

## **Architecture diagram (simple)**

```
Internet
   |
   |  HTTPS :443   (HTTP :80 for redirect / ACME)
   v
Route53 (A/AAAA)
   |
   v
Elastic IP  --->  EC2 Instance (Ubuntu24.04)
                    |
                    |  Docker network: "app_net"
                    |
            +------------------+
            |   Nginx container|  listens :80/:443
            |  reverse proxy   |
            +---------+--------+
                      |
                      | proxy_pass http://n8n:5678
                      v
            +------------------+         +-------------------+
            |   n8n container  |<------->| PostgreSQL        |
            |  :5678 internal  |   SQL   | container :5432   |
            +------------------+         +-------------------+
                    |
          volumes for persistence

```

### **1\) AWS resources**

* **EC2 instance (shoudl be variables defined)**
  * Instance type: `t3.small` (or bigger if you expect heavy workflows)
  * Storage: EBS gp3 (e.g., 30–100GB depending on logs/backups)
  * OS: Ubuntu 24.04 LTS
  * Pre defined SSH Key

* **Elastic IP**
  * Allocate and associate to the EC2 instance (this is your static IP)

* **Security Group**
  * Inbound:

    * TCP 22 from 0.0.0.0/0
    * TCP 80 from 0.0.0.0/0 (for HTTP redirect \+ cert issuance)
    * TCP 443 from 0.0.0.0/0

  * Outbound: allow all (or tighten if you want)

* **Route53**
  * Existing Hosted zone for your domain
  * `A` record (e.g., `n8n.example.com`) → Elastic IP

### **2\) Host bootstrapping (user-data or manual provisioning)**

* Install Docker \+ Docker Compose plugin
* Create directories:
  * `/opt/n8n/`
  * `/opt/n8n/nginx/`
  * `/opt/n8n/postgres/` (optional for bind mounts)
* Create `.env` with secrets (do **not** hardcode in compose)
* Configure firewall (optional, UFW) to allow 80/443 only
* Enable auto-start:
  * Use `docker compose up -d` plus a `systemd` unit (or just Docker restart policies)

### **3\) Docker Compose services (3 containers)**

* **postgres**

  * Use official `postgres:16` (or 15/14) image
  * Persist data with a volume
  * Strong password from env

* **n8n**
  * Use official `n8nio/n8n`
  * Configure:
    * `DB_TYPE=postgresdb`
    * `DB_POSTGRESDB_HOST=postgres`
    * `DB_POSTGRESDB_DATABASE=n8n`
    * `DB_POSTGRESDB_USER=n8n`
    * `DB_POSTGRESDB_PASSWORD={..variable-defined..}`
    * `N8N_HOST=n8n.example.com`
    * `N8N_PROTOCOL=https`
    * `WEBHOOK_URL=https://n8n.example.com/`
    * `N8N_ENCRYPTION_KEY=...` (very important)
  * Persist n8n data with volume

* **nginx**
  * Terminates TLS and proxies to `n8n:5678`
  * Forces HTTPS redirect
  * Adds sane headers (X-Forwarded-For, X-Forwarded-Proto, etc.)

### **4\) TLS (HTTPS)**

* Let’s Encrypt via a companion container (e.g., certbot) or use a known Nginx+ACME pattern

---

## **Nginx routing behavior (what it should do)**

* `80 -> 443` redirect
* `443` server\_name `n8n.example.com`
* `location /` → proxy to `http://n8n:5678`
* Ensure websocket/upgrade headers are supported (n8n UI can need it depending on features)

---

## **Minimal “interface contract” for agents (inputs/outputs)**

**Inputs**

* Domain/subdomain (e.g., `n8n.example.com`)
* Route53 hosted zone id or zone name
* EC2 key pair name / SSH allowed CIDR
* Secrets:
  * Postgres password
  * `N8N_ENCRYPTION_KEY`

**Outputs**

* An EC2 with Elastic IP and working DNS
* `docker-compose.yml`, `.env`, and Nginx config
* HTTPS endpoint serving n8n
* Persistence verified (restart instance and data remains)

### Terraform

AWS infrastructure should be built using terraform, with compostable modules.  Each module should have unit testing using terratest.

Terraform state should be locally stored, but not checked into git repository

Settings should be configurable via variables whenever possible.

### Installation of software,

I would like Installation to be as minimal as possible, using existing docker containers when possible.  I would like to use user\_data scripts when possible, but when not possible I prefer to use ansible over things like cloudformation

Ansible playbooks should be in a separate directory from the terraform configuration, ansible inventory files should not be checked into git repository

### Documentation

Please create a [README.md](http://README.md) that describes the deployment process

## Resources to check

- [https://docs.n8n.io/hosting/installation/docker/](https://docs.n8n.io/hosting/installation/docker/)
- https://www.docker.com/blog/how-to-use-the-postgres-docker-official-image/
- https://medium.com/@mmartinmainan/running-n8n-for-free-on-aws-a-self-hosting-guide-for-n8n-lovers-4e367727f45e

