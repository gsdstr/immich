@echo off
echo Starting Immich in Full Production Mode on hl-win...
docker compose --profile app up -d
docker compose ps
