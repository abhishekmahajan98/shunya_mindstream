#!/usr/bin/env bash
# Run the app against a backend on this machine (bypasses Railway).
# Usage: ./run_local.sh [flutter run args...]
set -euo pipefail
cd "$(dirname "$0")"

IP="${LOCAL_API_IP:-$(ipconfig getifaddr en0 2>/dev/null || true)}"
if [ -z "$IP" ]; then
  echo "Could not detect LAN IP. Set LOCAL_API_IP and retry, e.g.:"
  echo "  LOCAL_API_IP=192.168.1.5 ./run_local.sh"
  exit 1
fi

API_URL="http://${IP}:8000"
echo "Using API_URL=$API_URL"
echo "Ensure backend is running: cd ../backend && .venv/bin/uvicorn main:app --reload --host 0.0.0.0 --port 8000"
echo ""

exec flutter run --dart-define=API_URL="$API_URL" "$@"
