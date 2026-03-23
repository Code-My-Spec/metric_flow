#!/usr/bin/env bash
# Verify QuickBooks credentials (Client ID/Secret + optional access token)
set -euo pipefail

integration="quickbooks"

if [[ -z "${QUICKBOOKS_CLIENT_ID:-}" || -z "${QUICKBOOKS_CLIENT_SECRET:-}" ]]; then
  echo "{\"integration\": \"$integration\", \"status\": \"error\", \"error\": \"missing_credentials\", \"details\": \"QUICKBOOKS_CLIENT_ID and QUICKBOOKS_CLIENT_SECRET must be set\"}"
  exit 1
fi

# QuickBooks doesn't have a simple credential check endpoint — verify by testing the token endpoint
# with a dummy request (will return 400 but not 401 if client creds are valid format)
response=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${QUICKBOOKS_CLIENT_ID}:${QUICKBOOKS_CLIENT_SECRET}" \
  -d "grant_type=authorization_code&code=dummy&redirect_uri=https://dev.metric-flow.app/integrations/oauth/callback/quickbooks" \
  2>/dev/null || echo "000")

if [[ "$response" == "400" ]]; then
  # 400 = "invalid grant" which means credentials were accepted but code is invalid — credentials work
  details="QuickBooks client credentials accepted by token endpoint (HTTP 400 = invalid code, credentials valid)."

  if [[ -n "${QUICKBOOKS_TEST_ACCESS_TOKEN:-}" && -n "${QUICKBOOKS_TEST_REALM_ID:-}" ]]; then
    api_url="${QUICKBOOKS_API_URL:-https://sandbox-quickbooks.api.intuit.com/v3/company}"
    api_response=$(curl -s -o /dev/null -w "%{http_code}" \
      -H "Authorization: Bearer ${QUICKBOOKS_TEST_ACCESS_TOKEN}" \
      -H "Accept: application/json" \
      "${api_url}/${QUICKBOOKS_TEST_REALM_ID}/companyinfo/${QUICKBOOKS_TEST_REALM_ID}" \
      2>/dev/null || echo "000")

    if [[ "$api_response" == "200" ]]; then
      details="$details API access token valid (company info returned HTTP 200)."
    else
      details="$details WARNING: API access token returned HTTP $api_response — may be expired."
    fi
  else
    details="$details QUICKBOOKS_TEST_ACCESS_TOKEN/QUICKBOOKS_TEST_REALM_ID not set (needed for API testing)."
  fi

  echo "{\"integration\": \"$integration\", \"status\": \"ok\", \"details\": \"$details\"}"
elif [[ "$response" == "401" ]]; then
  echo "{\"integration\": \"$integration\", \"status\": \"error\", \"error\": \"invalid_credentials\", \"details\": \"Token endpoint returned HTTP 401 — check QUICKBOOKS_CLIENT_ID and QUICKBOOKS_CLIENT_SECRET\"}"
  exit 1
else
  echo "{\"integration\": \"$integration\", \"status\": \"error\", \"error\": \"unexpected_response\", \"details\": \"Token endpoint returned HTTP $response\"}"
  exit 1
fi
