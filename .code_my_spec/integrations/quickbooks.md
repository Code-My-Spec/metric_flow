# QuickBooks Online

## Auth Type

oauth2

## Required Credentials

- `QUICKBOOKS_CLIENT_ID` — OAuth Client ID from Intuit Developer portal
- `QUICKBOOKS_CLIENT_SECRET` — OAuth Client Secret from the same app
- `QUICKBOOKS_API_URL` — API base URL (default: `https://sandbox-quickbooks.api.intuit.com/v3/company` for sandbox)

### Test-only credentials

- `QUICKBOOKS_TEST_ACCESS_TOKEN` — A valid access token for testing
- `QUICKBOOKS_TEST_REALM_ID` — Company/Realm ID for the sandbox company
- `QUICKBOOKS_TEST_INCOME_ACCOUNT_ID` — Income account ID within the sandbox company

## Verify Script

`.code_my_spec/qa/scripts/verify_quickbooks.sh`

## Token Exchange Script

`.code_my_spec/qa/scripts/exchange_quickbooks_token.sh`

## Status

verified

## Notes

- Intuit Developer: https://developer.intuit.com/app/developer/dashboard
- Required scope: `com.intuit.quickbooks.accounting`
- Use sandbox environment for development: https://developer.intuit.com/app/developer/sandbox
- Access tokens expire in 1 hour; refresh tokens valid for 100 days (rotating)
- QuickBooks rotates the refresh token on each use — always persist the new one
- Callback URL to register: `https://dev.metric-flow.app/integrations/oauth/callback/quickbooks`
