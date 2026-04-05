#!/bin/bash
# Start Stripe CLI webhook listener for local development/QA
# Forwards webhook events to the local billing endpoint.
#
# Usage: .code_my_spec/qa/scripts/start-stripe-listener.sh
#
# The webhook signing secret is printed on startup — it changes each session.
# Update STRIPE_WEBHOOK_SECRET in .env.dev if the secret changes.

set -euo pipefail

STRIPE_SK=$(grep STRIPE_SECRET_KEY .env.dev | head -1 | cut -d= -f2)
ENDPOINT="localhost:4070/billing/webhooks"

if [ -z "$STRIPE_SK" ]; then
  echo "ERROR: STRIPE_SECRET_KEY not found in .env.dev"
  exit 1
fi

echo "Starting Stripe listener → $ENDPOINT"
echo "Copy the whsec_ secret into .env.dev as STRIPE_WEBHOOK_SECRET"
echo ""

exec stripe listen --forward-to "$ENDPOINT" --api-key "$STRIPE_SK"
