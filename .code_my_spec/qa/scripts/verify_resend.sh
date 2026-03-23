#!/usr/bin/env bash
# Verify Resend API key by listing domains
set -euo pipefail

integration="resend"

if [[ -z "${RESEND_API_KEY:-}" ]]; then
  echo "{\"integration\": \"$integration\", \"status\": \"error\", \"error\": \"missing_credentials\", \"details\": \"RESEND_API_KEY must be set\"}"
  exit 1
fi

response=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer ${RESEND_API_KEY}" \
  "https://api.resend.com/domains" \
  2>/dev/null || echo -e "\n000")

http_code=$(echo "$response" | tail -1)

if [[ "$http_code" == "200" ]]; then
  echo "{\"integration\": \"$integration\", \"status\": \"ok\", \"details\": \"API key valid — domains endpoint returned HTTP 200\"}"
elif [[ "$http_code" == "401" || "$http_code" == "403" ]]; then
  echo "{\"integration\": \"$integration\", \"status\": \"error\", \"error\": \"invalid_api_key\", \"details\": \"HTTP $http_code — check RESEND_API_KEY\"}"
  exit 1
else
  echo "{\"integration\": \"$integration\", \"status\": \"error\", \"error\": \"unexpected_response\", \"details\": \"Domains endpoint returned HTTP $http_code\"}"
  exit 1
fi
