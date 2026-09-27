#!/bin/bash
set -euo pipefail
SECRET=$(grep STRIPE_WEBHOOK_SECRET .env.dev | cut -d= -f2)
EVENT_ID="evt_qa1103_retest_$(date +%s)"
PAYLOAD=$(cat <<EOF
{"id":"$EVENT_ID","type":"customer.subscription.updated","data":{"object":{"id":"sub_qa1103_seed","customer":"cus_qa1103_seed","status":"past_due","current_period_start":1700000000,"current_period_end":1702592000}}}
EOF
)
TS=$(date +%s)
SIGNED_PAYLOAD="${TS}.${PAYLOAD}"
SIG=$(printf '%s' "$SIGNED_PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" | sed 's/^.* //')
curl -sS -w '\nHTTP_STATUS:%{http_code}\n' -X POST https://preview-3d7fe72b-0b24-43bc-a0c6-7b9c1bc9d98b.codemyspec.com/billing/webhooks \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: t=${TS},v1=${SIG}" \
  -d "$PAYLOAD"
