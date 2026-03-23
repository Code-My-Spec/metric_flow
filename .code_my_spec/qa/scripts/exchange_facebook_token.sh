#!/usr/bin/env bash
# Exchange a short-lived Facebook token for a long-lived token (60 days)
# Usage: FACEBOOK_APP_ID=... FACEBOOK_APP_SECRET=... ./exchange_facebook_token.sh <short_lived_token>
set -euo pipefail

if [[ -z "${FACEBOOK_APP_ID:-}" || -z "${FACEBOOK_APP_SECRET:-}" ]]; then
  echo "Error: FACEBOOK_APP_ID and FACEBOOK_APP_SECRET must be set"
  exit 1
fi

SHORT_TOKEN="${1:-}"

if [[ -z "$SHORT_TOKEN" ]]; then
  echo "Usage: $0 <short_lived_token>"
  echo ""
  echo "Get a short-lived token from the Facebook Graph API Explorer:"
  echo "https://developers.facebook.com/tools/explorer/"
  echo "Select your app, add 'ads_read' permission, and generate a token."
  exit 1
fi

response=$(curl -s "https://graph.facebook.com/v20.0/oauth/access_token?grant_type=fb_exchange_token&client_id=${FACEBOOK_APP_ID}&client_secret=${FACEBOOK_APP_SECRET}&fb_exchange_token=${SHORT_TOKEN}" 2>/dev/null)

echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"

long_token=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || echo "")

if [[ -n "$long_token" ]]; then
  echo ""
  echo "Add to your .env:"
  echo "FACEBOOK_TEST_ACCESS_TOKEN=$long_token"
fi
