# Resend (Email Delivery)

## Auth Type

api_token

## Required Credentials

- `RESEND_API_KEY` — API key from Resend dashboard

## Verify Script

`.code_my_spec/qa/scripts/verify_resend.sh`

## Status

verified

## Notes

- Resend Dashboard: https://resend.com/api-keys
- Production email adapter (Swoosh.Adapters.Resend)
- Dev/test uses Swoosh.Adapters.Local — no Resend key needed for local development
- ADR selected Mailgun but runtime.exs uses Resend — follow the code
