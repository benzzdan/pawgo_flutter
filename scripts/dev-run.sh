#!/usr/bin/env bash
# Run the Flutter app pointed at the local Pawgo-api Supabase stack on this
# Mac's current LAN IP. Auto-detects the IP so it works after WiFi/network
# changes without editing lib/config/env.dart.
#
# Usage:
#   ./scripts/dev-run.sh                    # flutter run on default device
#   ./scripts/dev-run.sh -d chrome          # extra args forwarded to flutter
#   PORT=8000 ./scripts/dev-run.sh          # override the Kong port
set -euo pipefail

PORT="${PORT:-8000}"

# Pick the first non-loopback IPv4 address. Prefer 192.168.* or 10.* (LAN
# subnets) over anything else like Docker bridges (172.17.*) or link-local.
detect_lan_ip() {
  ifconfig 2>/dev/null \
    | awk '/inet / && $2 != "127.0.0.1" { print $2 }' \
    | grep -E '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' \
    | grep -vE '^172\.1[78]\.' \
    | head -1
}

LAN_IP="$(detect_lan_ip || true)"
if [[ -z "${LAN_IP}" ]]; then
  echo "ERROR: could not auto-detect a LAN IPv4 address on this Mac." >&2
  echo "       Connect to a network, or set SUPABASE_URL manually:" >&2
  echo "         flutter run --dart-define=SUPABASE_URL=http://<host>:${PORT}" >&2
  exit 1
fi

SUPABASE_URL="http://${LAN_IP}:${PORT}"

# Sanity check: make sure Kong is actually answering on that IP.
if ! curl -sf --max-time 3 -o /dev/null "${SUPABASE_URL}/auth/v1/health"; then
  # /auth/v1/health requires apikey; a 401 still proves Kong is reachable.
  HTTP_CODE="$(curl -s --max-time 3 -o /dev/null -w '%{http_code}' "${SUPABASE_URL}/auth/v1/health" || echo 000)"
  if [[ "${HTTP_CODE}" == "000" ]]; then
    echo "WARN: ${SUPABASE_URL} did not respond. Is Colima + docker-compose up?" >&2
    echo "      Continuing anyway in case the device is on a different network." >&2
  fi
fi

cd "$(dirname "$0")/.."
echo "→ SUPABASE_URL=${SUPABASE_URL}"
exec flutter run --dart-define=SUPABASE_URL="${SUPABASE_URL}" "$@"
