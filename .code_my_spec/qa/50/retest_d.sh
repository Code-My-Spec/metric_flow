#!/bin/bash
set -uo pipefail
BASE=https://preview-3d7fe72b-0b24-43bc-a0c6-7b9c1bc9d98b.codemyspec.com
SECRET=$(grep STRIPE_WEBHOOK_SECRET .env.dev | cut -d= -f2)

sign_and_post() {
  local payload="$1"
  local sig_override="${2:-}"
  local ts=$(date +%s)
  local sig
  if [ -n "$sig_override" ]; then
    sig="$sig_override"
  else
    sig=$(printf '%s.%s' "$ts" "$payload" | openssl dgst -sha256 -hmac "$SECRET" | sed 's/^.* //')
  fi
  echo "--- POST (ts=$ts) ---"
  curl -sS -w '\nHTTP_STATUS:%{http_code}\n' -X POST "$BASE/billing/webhooks" \
    -H 'Content-Type: application/json' \
    -H "Stripe-Signature: t=${ts},v1=${sig}" \
    -d "$payload"
  echo
}

NOW=$(date +%s)

echo "### 1. Fresh created WITH metadata.account_id=23"
EVT1="evt_qa1103d_created_meta_${NOW}"
SUB1="sub_qa1103d_created_meta_${NOW}"
P1=$(cat <<EOF
{"id":"$EVT1","type":"customer.subscription.created","data":{"object":{"id":"$SUB1","customer":"cus_qa1103d_1","status":"active","metadata":{"account_id":"23"},"current_period_start":1700000000,"current_period_end":1702592000}}}
EOF
)
sign_and_post "$P1"

echo "### 2. Fresh created WITHOUT any account context (edge case)"
EVT2="evt_qa1103d_noctx_${NOW}"
SUB2="sub_qa1103d_noctx_${NOW}"
P2=$(cat <<EOF
{"id":"$EVT2","type":"customer.subscription.created","data":{"object":{"id":"$SUB2","customer":"cus_qa1103d_2","status":"active","current_period_start":1700000000,"current_period_end":1702592000}}}
EOF
)
sign_and_post "$P2"

echo "### 3. Recognized event updates existing row (sub_qa1103_seed -> trialing)"
EVT3="evt_qa1103d_update_${NOW}"
P3=$(cat <<EOF
{"id":"$EVT3","type":"customer.subscription.updated","data":{"object":{"id":"sub_qa1103_seed","customer":"cus_qa1103_seed","status":"trialing","current_period_start":1700000000,"current_period_end":1702592000}}}
EOF
)
sign_and_post "$P3"

echo "### 4. Payment failure on sub_qa1103_seed"
EVT4="evt_qa1103d_payfail_${NOW}"
P4=$(cat <<EOF
{"id":"$EVT4","type":"invoice.payment_failed","data":{"object":{"id":"in_qa1103d_1","subscription":"sub_qa1103_seed","customer":"cus_qa1103_seed"}}}
EOF
)
sign_and_post "$P4"

echo "### 5. Cancellation downgrades to free (plan cleared) on sub_qa1103_seed"
EVT5="evt_qa1103d_cancel_${NOW}"
P5=$(cat <<EOF
{"id":"$EVT5","type":"customer.subscription.deleted","data":{"object":{"id":"sub_qa1103_seed","customer":"cus_qa1103_seed","status":"canceled","current_period_start":1700000000,"current_period_end":1702592000}}}
EOF
)
sign_and_post "$P5"

echo "### 6. Duplicate delivery is a no-op (post fresh event twice)"
EVT6="evt_qa1103d_dup_${NOW}"
SUB6="sub_qa1103d_dup_${NOW}"
P6=$(cat <<EOF
{"id":"$EVT6","type":"customer.subscription.updated","data":{"object":{"id":"$SUB6","customer":"cus_qa1103d_dup","status":"active","current_period_start":1700000000,"current_period_end":1702592000}}}
EOF
)
echo '-- first delivery --'
sign_and_post "$P6"
echo '-- second (duplicate) delivery --'
sign_and_post "$P6"

echo "### 7. Processing failure logged, retry succeeds (bad sig then correct sig, identical payload)"
EVT7="evt_qa1103d_retry_${NOW}"
P7=$(cat <<EOF
{"id":"$EVT7","type":"customer.subscription.updated","data":{"object":{"id":"sub_qa1103_seed","customer":"cus_qa1103_seed","status":"active","current_period_start":1700000000,"current_period_end":1702592000}}}
EOF
)
echo '-- bad signature --'
sign_and_post "$P7" "$(printf '0%.0s' {1..64})"
echo '-- correct signature retry --'
sign_and_post "$P7"

echo "### 9. Connected-account event attributed to agency (account 30, acct_qa1103d_connected)"
EVT9="evt_qa1103d_connattr_${NOW}"
SUB9="sub_qa1103d_connattr_${NOW}"
P9=$(cat <<EOF
{"id":"$EVT9","account":"acct_qa1103d_connected","type":"customer.subscription.updated","data":{"object":{"id":"$SUB9","customer":"cus_qa1103d_conn","status":"active","current_period_start":1700000000,"current_period_end":1702592000}}}
EOF
)
sign_and_post "$P9"

echo "### 10. Unrecognized account context rejected"
EVT10="evt_qa1103d_unrecacct_${NOW}"
P10=$(cat <<EOF
{"id":"$EVT10","account":"acct_never_registered_qa1103d","type":"customer.subscription.updated","data":{"object":{"id":"sub_qa1103d_unrec_${NOW}","customer":"cus_qa1103d_unrec","status":"active","current_period_start":1700000000,"current_period_end":1702592000}}}
EOF
)
sign_and_post "$P10"

echo "DONE. EVT_IDS: $EVT1 $EVT2 $EVT3 $EVT4 $EVT5 $EVT6 $EVT7 $EVT9 $EVT10"
echo "SUB_IDS: $SUB1 $SUB2 $SUB6 $SUB9"
