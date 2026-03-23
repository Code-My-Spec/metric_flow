# Facebook Ads

## Auth Type

oauth2

## Required Credentials

- `FACEBOOK_APP_ID` — Facebook App ID from Meta for Developers console
- `FACEBOOK_APP_SECRET` — Facebook App Secret from the same app

### Test-only credentials

- `FACEBOOK_TEST_ACCESS_TOKEN` — A long-lived user access token with `ads_read` scope
- `FACEBOOK_TEST_AD_ACCOUNT_ID` — Ad account ID to test against (digits only, without `act_` prefix)

## Verify Script

`.code_my_spec/qa/scripts/verify_facebook_ads.sh`

## Token Exchange Script

`.code_my_spec/qa/scripts/exchange_facebook_token.sh`

## Status

verified

## Notes

- Meta for Developers: https://developers.facebook.com/apps/
- Required permissions: `ads_read`, `ads_management`
- Facebook tokens are long-lived (60 days), not refreshable via standard OAuth refresh
- The token exchange script converts a short-lived token to a long-lived token
- Callback URL to register: `https://dev.metric-flow.app/integrations/oauth/callback/facebook_ads`
