#!/usr/bin/env bash
# Exchange or refresh Google OAuth tokens for QA/testing.
#
# Usage:
#   # Exchange an authorization code for tokens:
#   ./exchange_google_token.sh <auth_code> [redirect_uri]
#
#   # Refresh an existing token (uses GOOGLE_TEST_REFRESH_TOKEN from env):
#   ./exchange_google_token.sh --refresh
#
#   # Extract live tokens from the dev database (requires running app or Vault):
#   ./exchange_google_token.sh --from-db [provider]
#
# Requires: GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET in env (source .env first)
set -euo pipefail

# Load .env files if they exist
[[ -f .env ]] && source .env
[[ -f .env.test ]] && source .env.test

if [[ -z "${GOOGLE_CLIENT_ID:-}" || -z "${GOOGLE_CLIENT_SECRET:-}" ]]; then
  echo "Error: GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET must be set"
  echo "Run: source .env"
  exit 1
fi

# --- Refresh mode ---
if [[ "${1:-}" == "--refresh" ]]; then
  REFRESH_TOKEN="${GOOGLE_TEST_REFRESH_TOKEN:-}"
  if [[ -z "$REFRESH_TOKEN" ]]; then
    echo "Error: GOOGLE_TEST_REFRESH_TOKEN not set. Run with an auth code first, or use --from-db."
    exit 1
  fi

  echo "Refreshing Google access token..."
  response=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
    -d "client_id=${GOOGLE_CLIENT_ID}&client_secret=${GOOGLE_CLIENT_SECRET}&refresh_token=${REFRESH_TOKEN}&grant_type=refresh_token")

  error=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error',''))" 2>/dev/null || echo "")
  if [[ -n "$error" ]]; then
    echo "Refresh failed: $error"
    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
    echo ""
    echo "The refresh token is likely expired. Get a new one:"
    echo "  1. Run: $0  (no args, prints auth URL)"
    echo "  2. Visit the URL, authorize, copy the code"
    echo "  3. Run: $0 <code>"
    exit 1
  fi

  access_token=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || echo "")
  expires_in=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('expires_in',''))" 2>/dev/null || echo "")

  echo "Success! Token expires in ${expires_in}s"
  echo ""
  echo "Update .env.test:"
  echo "GOOGLE_TEST_ACCESS_TOKEN=$access_token"
  exit 0
fi

# --- Extract from dev DB mode ---
if [[ "${1:-}" == "--from-db" ]]; then
  PROVIDER="${2:-google_business}"
  echo "Extracting ${PROVIDER} tokens from dev database..."
  echo "(Requires MetricFlow.Vault to decrypt — starting app briefly)"

  tokens=$(mix run --no-halt -e "
    integration =
      MetricFlow.Repo.one!(
        import(Ecto.Query),
        from(i in MetricFlow.Integrations.Integration,
          where: i.provider == ^:\"${PROVIDER}\",
          limit: 1
        )
      )
    IO.puts(\"ACCESS_TOKEN=#{integration.access_token}\")
    IO.puts(\"REFRESH_TOKEN=#{integration.refresh_token}\")
    IO.puts(\"EXPIRES_AT=#{integration.expires_at}\")
    System.halt(0)
  " 2>/dev/null) || {
    echo "Failed to extract tokens. Is the dev database running?"
    exit 1
  }

  echo "$tokens"
  echo ""

  # Extract and offer to update .env.test
  access=$(echo "$tokens" | grep "ACCESS_TOKEN=" | cut -d= -f2-)
  refresh=$(echo "$tokens" | grep "REFRESH_TOKEN=" | cut -d= -f2-)

  if [[ -n "$access" ]]; then
    echo "Update .env.test with:"
    echo "GOOGLE_TEST_ACCESS_TOKEN=$access"
    [[ -n "$refresh" ]] && echo "GOOGLE_TEST_REFRESH_TOKEN=$refresh"
  fi
  exit 0
fi

# --- Auth code exchange mode ---
AUTH_CODE="${1:-}"
REDIRECT_URI="${2:-https://dev.metric-flow.app/integrations/oauth/callback/google_analytics}"

if [[ -z "$AUTH_CODE" ]]; then
  echo "Google OAuth Token Exchange"
  echo ""
  echo "Usage:"
  echo "  $0 <auth_code> [redirect_uri]   Exchange code for tokens"
  echo "  $0 --refresh                     Refresh existing access token"
  echo "  $0 --from-db [provider]          Extract tokens from dev database"
  echo ""
  echo "To get an authorization code, visit this URL and authorize:"
  echo ""
  echo "https://accounts.google.com/o/oauth2/v2/auth?client_id=${GOOGLE_CLIENT_ID}&redirect_uri=${REDIRECT_URI}&response_type=code&scope=https://www.googleapis.com/auth/analytics.readonly%20https://www.googleapis.com/auth/adwords%20https://www.googleapis.com/auth/business.manage&access_type=offline&prompt=consent"
  echo ""
  echo "Then run: $0 <the_code_from_redirect>"
  exit 0
fi

echo "Exchanging authorization code..."
response=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "code=${AUTH_CODE}&client_id=${GOOGLE_CLIENT_ID}&client_secret=${GOOGLE_CLIENT_SECRET}&redirect_uri=${REDIRECT_URI}&grant_type=authorization_code")

echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"

access_token=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || echo "")
refresh_token=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('refresh_token',''))" 2>/dev/null || echo "")

if [[ -n "$access_token" ]]; then
  echo ""
  echo "Update .env.test with:"
  echo "GOOGLE_TEST_ACCESS_TOKEN=$access_token"
  if [[ -n "$refresh_token" ]]; then
    echo "GOOGLE_TEST_REFRESH_TOKEN=$refresh_token"
  fi
else
  echo ""
  echo "Token exchange failed. Check the error above."
fi
