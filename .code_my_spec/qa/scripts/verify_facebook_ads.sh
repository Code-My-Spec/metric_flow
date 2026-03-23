#!/usr/bin/env bash
# Verify Facebook Ads credentials (App ID/Secret + optional access token)
set -euo pipefail

integration="facebook_ads"

if [[ -z "${FACEBOOK_APP_ID:-}" || -z "${FACEBOOK_APP_SECRET:-}" ]]; then
  echo "{\"integration\": \"$integration\", \"status\": \"error\", \"error\": \"missing_credentials\", \"details\": \"FACEBOOK_APP_ID and FACEBOOK_APP_SECRET must be set\"}"
  exit 1
fi

# Verify app credentials by requesting an app access token
response=$(curl -s "https://graph.facebook.com/oauth/access_token?client_id=${FACEBOOK_APP_ID}&client_secret=${FACEBOOK_APP_SECRET}&grant_type=client_credentials" 2>/dev/null)

app_token=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || echo "")
error_msg=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error',{}).get('message',''))" 2>/dev/null || echo "")

if [[ -n "$app_token" ]]; then
  details="App access token obtained successfully."

  if [[ -n "${FACEBOOK_TEST_ACCESS_TOKEN:-}" ]]; then
    # Verify user token by checking debug endpoint
    debug_response=$(curl -s "https://graph.facebook.com/debug_token?input_token=${FACEBOOK_TEST_ACCESS_TOKEN}&access_token=${app_token}" 2>/dev/null)
    is_valid=$(echo "$debug_response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('is_valid',False))" 2>/dev/null || echo "False")

    if [[ "$is_valid" == "True" ]]; then
      details="$details User access token is valid."
    else
      details="$details WARNING: FACEBOOK_TEST_ACCESS_TOKEN is invalid or expired."
    fi
  else
    details="$details FACEBOOK_TEST_ACCESS_TOKEN not set (needed for API testing)."
  fi

  echo "{\"integration\": \"$integration\", \"status\": \"ok\", \"details\": \"$details\"}"
else
  echo "{\"integration\": \"$integration\", \"status\": \"error\", \"error\": \"invalid_credentials\", \"details\": \"$error_msg\"}"
  exit 1
fi
