# Instructions for AI Agent Operating on `hl-win` (Windows / Docker Desktop)

> **Purpose**: This document specifies operational protocols, environment controls, and safety constraints for any autonomous or semi-autonomous agent operating on `hl-win` (Windows host with Docker Desktop).

---

## 1. Role and Boundary of `hl-win`

The `hl-win` host functions as the **stateful infrastructure server**:
- **Within `hl-win` scope**:
  1. Stateful backing services: PostgreSQL 14 (`immich_postgres` with `pgvector`), Redis (`immich_redis`), automated backup container (`immich_db_backup`).
  2. Physical storage of media assets (`UPLOAD_LOCATION`, e.g. `I:\library`).
  3. Production execution of `immich-server` and `immich-machine-learning` when local development is inactive.
- **OUTSIDE `hl-win` scope**:
  1. Source code modifications (all development occurs on the macOS workstation).
  2. Git branch management and upstream PRs (handled on macOS).
  3. Local container image builds (images are built centrally via GitHub Actions in `gsdstr/immich` and pulled from `ghcr.io/gsdstr/immich-server:latest`).

---

## 2. Directory Layout & Environment Files

Target deployment directory on `hl-win` (e.g. `C:\opt\immich` or `D:\immich\deployment`):
```text
deployment/
├── docker-compose.yml       # Service configuration with compose profiles
├── .env                     # Local environment variables
├── start-full.cmd           # Script to launch full production stack
├── start-infra.cmd          # Script to switch to infra-only dev mode
└── backups/                 # Directory for automated database dumps (7-day retention)
```

### `.env` Configuration on `hl-win`
```dotenv
UPLOAD_LOCATION=I:\library
DB_PASSWORD=your_secure_postgres_password
DB_USERNAME=postgres
DB_DATABASE_NAME=immich
IMMICH_SERVER_IMAGE=ghcr.io/gsdstr/immich-server:latest
```

---

## 3. Operational Modes & Commands

### Mode A: "Development Infrastructure" (Active Mac Development)
> **Critical Rule**: `immich-server` and `immich-machine-learning` containers on `hl-win` **MUST BE STOPPED** during local Mac development to prevent race conditions on Redis BullMQ job queues and database lock contention.

**To activate**:
```cmd
start-infra.cmd
```
*Or manually:*
```cmd
docker compose stop immich-server immich-machine-learning
docker compose up -d database redis db-backup
```
**Verification**:
```cmd
docker compose ps
```
Only `immich_postgres` (:5432), `immich_redis` (:6379), and `immich_db_backup` should be running.

---

### Mode B: "Full Production" (Standalone Homelab Mode)
Runs the complete stack including server and machine learning containers.

**To activate**:
```cmd
start-full.cmd
```
*Or manually:*
```cmd
docker compose --profile app up -d
```

---

### Upgrading to New Custom Build from GHCR
When new features are pushed to `deploy/hl-win`, GitHub Actions publishes an updated image. On `hl-win`, execute:
```cmd
docker compose pull immich-server
docker compose --profile app up -d
docker compose ps
```

---

## 4. Network and Windows Firewall

To allow the Mac workstation direct access to the database and queue:
1. Ports `5432` (PostgreSQL) and `6379` (Redis) are bound to `0.0.0.0` in `docker-compose.yml`.
2. Windows Defender Firewall must allow inbound TCP connections on ports 5432 and 6379 from the local subnet:
   ```powershell
   New-NetFirewallRule -DisplayName "Immich Dev Postgres" -Direction Inbound -Protocol TCP -LocalPort 5432 -Action Allow
   New-NetFirewallRule -DisplayName "Immich Dev Redis" -Direction Inbound -Protocol TCP -LocalPort 6379 -Action Allow
   ```

---

## 5. Backups and Data Safety

1. **Automated Backups**:
   - The `immich_db_backup` container creates a daily database dump at `05:00` with rolling 7-day retention (`BACKUP_KEEP_DAYS: 7`).
   - Dumps are stored in `./backups/`.
2. **On-Demand Manual Backup**:
   ```cmd
   docker exec -t immich_postgres pg_dump -U postgres immich > .\backups\manual_pre_migration_%date%.sql
   ```
3. **Disaster Recovery / Restoration**:
   ```cmd
   docker compose stop immich-server immich-machine-learning
   cat .\backups\immich-backup-YYYY-MM-DD.sql | docker exec -i immich_postgres psql -U postgres -d immich
   ```

---

## 6. Hard Rules for Agents on `hl-win`

1. ❌ **NEVER** modify or delete files inside `UPLOAD_LOCATION` ( I:\\library ). All operations against media assets are strictly read-only.
2. ❌ **NEVER** run `immich-server` on `hl-win` simultaneously with a local dev server on macOS when sharing the same Redis instance.
3. ❌ **NEVER** run `docker compose down -v` (this deletes persistent `pgdata` volume). Use `docker compose stop` or `docker compose restart`.
4. ❌ **NEVER** execute local `docker build` on `hl-win`. Image builds are managed centrally via GitHub Actions CI.
