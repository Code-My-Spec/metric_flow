#!/usr/bin/env bash
# Exchange Google OAuth authorization code for access + refresh tokens
# Usage: GOOGLE_CLIENT_ID=... GOOGLE_CLIENT_SECRET=... ./exchange_google_token.sh <auth_code> <redirect_uri>
set -euo pipefail

if [[ -z "${GOOGLE_CLIENT_ID:-}" || -z "${GOOGLE_CLIENT_SECRET:-}" ]]; then
  echo "Error: GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET must be set"
  exit 1
fi

AUTH_CODE="${1:-}"
REDIRECT_URI="${2:-https://dev.metric-flow.app/integrations/oauth/callback/google_analytics}"

if [[ -z "$AUTH_CODE" ]]; then
  echo "Usage: $0 <authorization_code> [redirect_uri]"
  echo ""
  echo "To get an authorization code, visit:"
  echo "https://accounts.google.com/o/oauth2/v2/auth?client_id=${GOOGLE_CLIENT_ID}&redirect_uri=${REDIRECT_URI}&response_type=code&scope=https://www.googleapis.com/auth/analytics.readonly%20https://www.googleapis.com/auth/adwords&access_type=offline&prompt=consent"
  exit 1
fi

response=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "code=${AUTH_CODE}&client_id=${GOOGLE_CLIENT_ID}&client_secret=${GOOGLE_CLIENT_SECRET}&redirect_uri=${REDIRECT_URI}&grant_type=authorization_code")

echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"

# Extract tokens for convenience
access_token=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || echo "")
refresh_token=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('refresh_token',''))" 2>/dev/null || echo "")

if [[ -n "$access_token" ]]; then
  echo ""
  echo "Add to your .env:"
  echo "GOOGLE_TEST_ACCESS_TOKEN=$access_token"
  if [[ -n "$refresh_token" ]]; then
    echo "GOOGLE_TEST_REFRESH_TOKEN=$refresh_token"
  fi
fi
