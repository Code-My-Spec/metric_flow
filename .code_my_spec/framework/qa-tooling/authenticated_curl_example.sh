#!/usr/bin/env bash
#
# authenticated_curl.sh — API-authenticated curl for a Phoenix app
#
# Wraps curl with the X-Api-Key header for making authenticated API requests.
# The API key is looked up from the QA seed account in the database.
#
# IMPORTANT: This is for API endpoints (/api/*) only — NOT for session-authenticated
# browser routes. For UI/LiveView testing, use MCP browser tools.
#
# USAGE:
#   # GET a transaction
#   .code_my_spec/qa/scripts/authenticated_curl.sh http://localhost:4090/api/transactions/1
#
#   # POST a webhook
#   .code_my_spec/qa/scripts/authenticated_curl.sh -X POST -H "Content-Type: application/json" \
#     -d '{"processor_reference":"ic_test_card_001","amount":"50.00","location":"Shell, TX"}' \
#     http://localhost:4090/api/webhooks/transactions
#
# ENVIRONMENT VARIABLES:
#   APP_URL           Base URL   (default: http://localhost:4000)
#   APP_API_KEY       Override API key (skips DB lookup)
#   VERBOSE           Set to 1 for debug output
#
# HOW TO ADAPT:
#   1. Change the DB query to match your app's account/API-key schema
#   2. Change the fallback API key to match your seed data
#   3. Change the header name if your app uses Authorization: Bearer instead of X-Api-Key

set -euo pipefail

BASE_URL="${APP_URL:-http://localhost:4000}"
VERBOSE="${VERBOSE:-0}"

debug() {
  if [ "$VERBOSE" = "1" ]; then
    echo "[api] $*" >&2
  fi
}

# --- Resolve API key ---
if [ -n "${APP_API_KEY:-}" ]; then
  API_KEY="$APP_API_KEY"
  debug "Using API key from APP_API_KEY env var"
else
  # Look up the QA account's API key from the database.
  # Adapt this query to your app's schema.
  API_KEY=$(mix run -e '
    Logger.configure(level: :none)
    import Ecto.Query
    case MyApp.Repo.one(from a in MyApp.Accounts.Account, where: a.name == "QA Account", select: a.api_key) do
      nil -> IO.puts(""); System.halt(1)
      key -> IO.puts(key)
    end
  ' 2>/dev/null) || true

  if [ -z "$API_KEY" ]; then
    # Fallback: use the known seed value
    API_KEY="qa_test_key_abc123"
    debug "DB lookup failed, using default seed API key"
  else
    debug "API key from DB: ${API_KEY}"
  fi
fi

if [ -z "$API_KEY" ]; then
  echo "ERROR: Could not determine API key." >&2
  echo "Run seed scripts to create QA data." >&2
  exit 1
fi

# --- Make the request ---
if [ "$#" -eq 0 ]; then
  echo "Usage: $0 [curl-flags...] URL" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  $0 ${BASE_URL}/api/transactions/1" >&2
  echo "  $0 -X POST -d '{\"amount\":\"50.00\"}' ${BASE_URL}/api/webhooks/transactions" >&2
  echo "" >&2
  echo "API key: ${API_KEY}" >&2
  exit 0
fi

debug "curl -H 'X-Api-Key: ${API_KEY}' $*"

curl -H "X-Api-Key: ${API_KEY}" "$@" || {
  echo "ERROR: Request failed" >&2
  exit 2
}
