#!/usr/bin/env bash
# Deploy Lit Messenger backend on the VDS (Ubuntu/Debian).
# Run this from the `backend/` directory that contains docker-compose.yml.
set -euo pipefail

echo "== Lit Messenger backend deploy =="

# 1) Install Docker if missing
if ! command -v docker >/dev/null 2>&1; then
  echo "[*] Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
fi

# 2) Ensure compose plugin available (docker compose)
if ! docker compose version >/dev/null 2>&1; then
  echo "[!] docker compose plugin not found. Install docker-ce-cli with compose plugin."
  exit 1
fi

# 3) Make sure .env exists
if [ ! -f .env ]; then
  echo "[*] .env not found, copying from .env.example — edit it if needed."
  cp .env.example .env
fi

# 4) Build and start
echo "[*] Building image and starting container..."
docker compose build
docker compose up -d

# 5) Initialize database (creates tables; safe to re-run)
echo "[*] Initializing database schema..."
docker compose exec -T backend node src/db_init.js || echo "[!] db_init failed — check DB credentials in .env"

echo "== Done =="
echo "API:        http://157.228.137.204/api"
echo "Files:      http://157.228.137.204/files/<name>"
echo "Logs:       docker compose logs -f"
