#!/usr/bin/env bash
# Verify Anthropic API key by listing available models
set -euo pipefail

integration="anthropic"

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "{\"integration\": \"$integration\", \"status\": \"error\", \"error\": \"missing_credentials\", \"details\": \"ANTHROPIC_API_KEY must be set\"}"
  exit 1
fi

# Send a minimal message to verify the key works
response=$(curl -s -w "\n%{http_code}" \
  -X POST "https://api.anthropic.com/v1/messages" \
  -H "x-api-key: ${ANTHROPIC_API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-haiku-4-5-20251001","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}' \
  2>/dev/null || echo -e "\n000")

http_code=$(echo "$response" | tail -1)
body=$(echo "$response" | sed '$d')

if [[ "$http_code" == "200" ]]; then
  echo "{\"integration\": \"$integration\", \"status\": \"ok\", \"details\": \"API key valid — Haiku 4.5 responded successfully\"}"
elif [[ "$http_code" == "401" ]]; then
  echo "{\"integration\": \"$integration\", \"status\": \"error\", \"error\": \"invalid_api_key\", \"details\": \"HTTP 401 — check ANTHROPIC_API_KEY\"}"
  exit 1
else
  error_msg=$(echo "$body" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error',{}).get('message','unknown'))" 2>/dev/null || echo "HTTP $http_code")
  echo "{\"integration\": \"$integration\", \"status\": \"error\", \"error\": \"api_error\", \"details\": \"$error_msg\"}"
  exit 1
fi
