# Google OAuth (GA4 + Ads)

## Auth Type

oauth2

## Required Credentials

- `GOOGLE_CLIENT_ID` — OAuth 2.0 Client ID from Google Cloud Console (APIs & Services > Credentials)
- `GOOGLE_CLIENT_SECRET` — OAuth 2.0 Client Secret from the same credential
- `GOOGLE_ADS_DEVELOPER_TOKEN` — Developer token from Google Ads API Center (requires approved app)
- `GOOGLE_ADS_LOGIN_CUSTOMER_ID` — Manager (MCC) account ID for Google Ads API access (digits only, no dashes)

### Test-only credentials

- `GOOGLE_TEST_ACCESS_TOKEN` — A valid OAuth access token for testing (obtain via token exchange script)
- `GOOGLE_TEST_REFRESH_TOKEN` — A valid refresh token for testing
- `GA4_TEST_PROPERTY_ID` — GA4 property ID to test against (e.g., `123456789`)
- `GOOGLE_ADS_TEST_CUSTOMER_ID` — Google Ads customer ID to test against (digits only)

## Verify Script

`.code_my_spec/qa/scripts/verify_google_oauth.sh`

## Token Exchange Script

`.code_my_spec/qa/scripts/exchange_google_token.sh`

## Status

verified

## Notes

- Google Cloud Console: https://console.cloud.google.com/apis/credentials
- Google Ads API Center: https://ads.google.com/aw/apicenter
- Required OAuth scopes: `https://www.googleapis.com/auth/analytics.readonly`, `https://www.googleapis.com/auth/adwords`
- Callback URL to register: `https://dev.metric-flow.app/integrations/oauth/callback/google_analytics` and `/callback/google_ads`
- Apps in "Testing" mode have refresh tokens that expire after 7 days — move to production for persistent tokens
