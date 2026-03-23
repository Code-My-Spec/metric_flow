#!/usr/bin/env bash
# Exchange QuickBooks OAuth authorization code for access + refresh tokens
# Usage: QUICKBOOKS_CLIENT_ID=... QUICKBOOKS_CLIENT_SECRET=... ./exchange_quickbooks_token.sh <auth_code> [redirect_uri]
set -euo pipefail

if [[ -z "${QUICKBOOKS_CLIENT_ID:-}" || -z "${QUICKBOOKS_CLIENT_SECRET:-}" ]]; then
  echo "Error: QUICKBOOKS_CLIENT_ID and QUICKBOOKS_CLIENT_SECRET must be set"
  exit 1
fi

AUTH_CODE="${1:-}"
REDIRECT_URI="${2:-https://dev.metric-flow.app/integrations/oauth/callback/quickbooks}"

if [[ -z "$AUTH_CODE" ]]; then
  echo "Usage: $0 <authorization_code> [redirect_uri]"
  echo ""
  echo "To get an authorization code, visit the Intuit OAuth playground:"
  echo "https://developer.intuit.com/app/developer/playground"
  echo "Or use the authorization URL directly with your app."
  exit 1
fi

response=$(curl -s -X POST "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${QUICKBOOKS_CLIENT_ID}:${QUICKBOOKS_CLIENT_SECRET}" \
  -d "grant_type=authorization_code&code=${AUTH_CODE}&redirect_uri=${REDIRECT_URI}")

echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"

access_token=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || echo "")
refresh_token=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('refresh_token',''))" 2>/dev/null || echo "")
realm_id=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('realmId',''))" 2>/dev/null || echo "")

if [[ -n "$access_token" ]]; then
  echo ""
  echo "Add to your .env:"
  echo "QUICKBOOKS_TEST_ACCESS_TOKEN=$access_token"
  if [[ -n "$refresh_token" ]]; then
    echo "QUICKBOOKS_TEST_REFRESH_TOKEN=$refresh_token"
  fi
fi
