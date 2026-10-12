@echo off
echo Switching hl-win to Dev-Infrastructure Mode (stopping server & ml containers)...
docker compose stop immich-server immich-machine-learning
docker compose up -d database redis db-backup
echo Infrastructure running. Ports 5432 (Postgres) and 6379 (Redis) are ready for local Mac development.
docker compose ps
