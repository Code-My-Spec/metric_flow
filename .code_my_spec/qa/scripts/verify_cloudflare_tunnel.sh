#!/usr/bin/env bash
# Verify Cloudflare Tunnel is running and reachable
set -euo pipefail

integration="cloudflare_tunnel"

if [[ -z "${CLOUDFLARE_TUNNEL_SECRET:-}" ]]; then
  echo "{\"integration\": \"$integration\", \"status\": \"error\", \"error\": \"missing_credentials\", \"details\": \"CLOUDFLARE_TUNNEL_SECRET must be set\"}"
  exit 1
fi

# Check if cloudflared is installed
if ! command -v cloudflared &>/dev/null; then
  echo "{\"integration\": \"$integration\", \"status\": \"error\", \"error\": \"cloudflared_not_installed\", \"details\": \"Install cloudflared: brew install cloudflare/cloudflare/cloudflared\"}"
  exit 1
fi

# Check if tunnel is reachable by hitting the dev URL
response=$(curl -s -o /dev/null -w "%{http_code}" "https://dev.metric-flow.app" --max-time 5 2>/dev/null || echo "000")

if [[ "$response" == "200" || "$response" == "302" ]]; then
  echo "{\"integration\": \"$integration\", \"status\": \"ok\", \"details\": \"Tunnel reachable — dev.metric-flow.app returned HTTP $response\"}"
elif [[ "$response" == "000" ]]; then
  echo "{\"integration\": \"$integration\", \"status\": \"error\", \"error\": \"tunnel_unreachable\", \"details\": \"dev.metric-flow.app is not responding — ensure cloudflared tunnel and Phoenix server are running\"}"
  exit 1
else
  echo "{\"integration\": \"$integration\", \"status\": \"ok\", \"details\": \"Tunnel reachable — dev.metric-flow.app returned HTTP $response (may need Phoenix server running)\"}"
fi
