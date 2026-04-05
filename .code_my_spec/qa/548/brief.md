# QA Story Brief: Stripe Webhook Handler (Story 548)

## Tool

curl

## Auth

No authentication required. The webhook endpoint is secured by Stripe signature verification, not user sessions. The `STRIPE_WEBHOOK_SECRET` environment variable must be set for signature verification to pass.

For testing without real Stripe signatures, ensure the app is running in dev/test mode where signature verification may be relaxed.

## Seeds

```
.code_my_spec/qa/scripts/start-qa.sh
```

No additional seeds required — webhook testing uses synthetic payloads sent via curl.

## Setup Notes

The webhook endpoint is at `POST /billing/webhooks`. It must be added to the router under the `:api` pipeline (no CSRF protection). Ensure the app is running on `http://localhost:4070` before testing.

## What To Test

### 1. Webhook endpoint exists and responds (criterion 5021)
```bash
curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:4070/billing/webhooks \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: test_signature" \
  -d '{"id":"evt_test_1","type":"ping","data":{"object":{}}}'
```
- Expected: HTTP status is NOT 404 (endpoint exists)

### 2. Missing Stripe-Signature header rejected (criterion 5022)
```bash
curl -s -w '\n%{http_code}' -X POST http://localhost:4070/billing/webhooks \
  -H "Content-Type: application/json" \
  -d '{"id":"evt_test_2","type":"customer.subscription.created","data":{"object":{"id":"sub_test"}}}'
```
- Expected: HTTP 400

### 3. Subscription lifecycle events accepted (criterion 5023)
Test each event type:
```bash
# subscription.created
curl -s -w '\n%{http_code}' -X POST http://localhost:4070/billing/webhooks \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: test_signature" \
  -d '{"id":"evt_c1","type":"customer.subscription.created","data":{"object":{"id":"sub_1","customer":"cus_1","status":"active","items":{"data":[{"price":{"id":"price_1"}}]},"current_period_start":1700000000,"current_period_end":1702592000}}}'

# invoice.payment_failed
curl -s -w '\n%{http_code}' -X POST http://localhost:4070/billing/webhooks \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: test_signature" \
  -d '{"id":"evt_pf1","type":"invoice.payment_failed","data":{"object":{"id":"in_1","customer":"cus_1","subscription":"sub_1","status":"open"}}}'
```
- Expected: HTTP 200 for each

### 4. payment_failed marks subscription past_due (criterion 5024)
- Send invoice.payment_failed event via curl (as above)
- Expected: HTTP 200 and event logged

### 5. subscription.deleted processes cancellation (criterion 5025)
```bash
curl -s -w '\n%{http_code}' -X POST http://localhost:4070/billing/webhooks \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: test_signature" \
  -d '{"id":"evt_del1","type":"customer.subscription.deleted","data":{"object":{"id":"sub_del","customer":"cus_del","status":"canceled","canceled_at":1700100000,"current_period_end":1702592000,"items":{"data":[{"price":{"id":"price_1"}}]}}}}'
```
- Expected: HTTP 200

### 6. Idempotent duplicate delivery (criterion 5026)
- Send the same event ID twice in a row
- Expected: Both return HTTP 200

### 7. Event logging (criterion 5027)
- Send any valid event and check app logs for the Stripe event ID and type
- Expected: Log line contains event ID and type

### 8. Graceful failure handling (criterion 5028)
```bash
# Malformed JSON
curl -s -w '\n%{http_code}' -X POST http://localhost:4070/billing/webhooks \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: test_signature" \
  -d 'not valid json'

# Unknown event type
curl -s -w '\n%{http_code}' -X POST http://localhost:4070/billing/webhooks \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: test_signature" \
  -d '{"id":"evt_unk","type":"unknown.event","data":{"object":{}}}'
```
- Expected: Malformed JSON returns 400, unknown event returns 200

## Result Path

`.code_my_spec/qa/548/result.md`
