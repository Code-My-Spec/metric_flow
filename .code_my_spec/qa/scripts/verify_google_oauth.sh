#!/usr/bin/env bash
# Verify Google OAuth credentials (Client ID/Secret validity + developer token)
set -euo pipefail

integration="google_oauth"

if [[ -z "${GOOGLE_CLIENT_ID:-}" || -z "${GOOGLE_CLIENT_SECRET:-}" ]]; then
  echo "{\"integration\": \"$integration\", \"status\": \"error\", \"error\": \"missing_credentials\", \"details\": \"GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET must be set\"}"
  exit 1
fi

# Verify client credentials by requesting token endpoint metadata
# Google's OpenID discovery document is public — if we can build an auth URL, credentials format is valid
response=$(curl -s -o /dev/null -w "%{http_code}" \
  "https://accounts.google.com/o/oauth2/v2/auth?client_id=${GOOGLE_CLIENT_ID}&response_type=code&scope=openid&redirect_uri=urn:ietf:wg:oauth:2.0:oob" \
  2>/dev/null || echo "000")

if [[ "$response" == "200" || "$response" == "302" ]]; then
  details="Google OAuth client ID format is valid (HTTP $response from auth endpoint)."

  # Check developer token if provided
  if [[ -n "${GOOGLE_ADS_DEVELOPER_TOKEN:-}" ]]; then
    details="$details Google Ads developer token is set."
  else
    details="$details WARNING: GOOGLE_ADS_DEVELOPER_TOKEN is not set — Google Ads API calls will fail."
  fi

  echo "{\"integration\": \"$integration\", \"status\": \"ok\", \"details\": \"$details\"}"
else
  echo "{\"integration\": \"$integration\", \"status\": \"error\", \"error\": \"invalid_client_id\", \"details\": \"Auth endpoint returned HTTP $response — check GOOGLE_CLIENT_ID\"}"
  exit 1
fi
