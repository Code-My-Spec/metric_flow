# Integration Index

| Integration | Auth Type | Status | Spec | Verify Script |
|---|---|---|---|---|
| Google OAuth (GA4 + Ads) | oauth2 | verified | [google_oauth.md](integrations/google_oauth.md) | [verify_google_oauth.sh](qa/scripts/verify_google_oauth.sh) |
| Facebook Ads | oauth2 | verified | [facebook_ads.md](integrations/facebook_ads.md) | [verify_facebook_ads.sh](qa/scripts/verify_facebook_ads.sh) |
| QuickBooks Online | oauth2 | verified | [quickbooks.md](integrations/quickbooks.md) | [verify_quickbooks.sh](qa/scripts/verify_quickbooks.sh) |
| Anthropic Claude | api_token | verified | [anthropic.md](integrations/anthropic.md) | [verify_anthropic.sh](qa/scripts/verify_anthropic.sh) |
| Resend (Email) | api_token | verified | [resend.md](integrations/resend.md) | [verify_resend.sh](qa/scripts/verify_resend.sh) |
| Cloudflare Tunnel | api_token | verified | [cloudflare_tunnel.md](integrations/cloudflare_tunnel.md) | [verify_cloudflare_tunnel.sh](qa/scripts/verify_cloudflare_tunnel.sh) |

## Environment Variables Required

### Core OAuth Providers (needed for data sync features)

```bash
# Google OAuth (GA4 + Ads)
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_ADS_DEVELOPER_TOKEN=
GOOGLE_ADS_LOGIN_CUSTOMER_ID=

# Facebook Ads
FACEBOOK_APP_ID=
FACEBOOK_APP_SECRET=

# QuickBooks Online
QUICKBOOKS_CLIENT_ID=
QUICKBOOKS_CLIENT_SECRET=
```

### API Services

```bash
# Anthropic (AI features)
ANTHROPIC_API_KEY=

# Resend (production email)
RESEND_API_KEY=
```

### Dev Infrastructure

```bash
# Cloudflare Tunnel (dev tunneling)
CLOUDFLARE_TUNNEL_SECRET=
```

### Test-only Credentials

```bash
# Google test tokens
GOOGLE_TEST_ACCESS_TOKEN=
GOOGLE_TEST_REFRESH_TOKEN=
GA4_TEST_PROPERTY_ID=
GOOGLE_ADS_TEST_CUSTOMER_ID=

# Facebook test tokens
FACEBOOK_TEST_ACCESS_TOKEN=
FACEBOOK_TEST_AD_ACCOUNT_ID=

# QuickBooks test tokens
QUICKBOOKS_TEST_ACCESS_TOKEN=
QUICKBOOKS_TEST_REALM_ID=
QUICKBOOKS_TEST_INCOME_ACCOUNT_ID=
```
