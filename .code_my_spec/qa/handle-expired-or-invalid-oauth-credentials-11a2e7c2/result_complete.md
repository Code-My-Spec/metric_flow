# QA Result

Story 440 — Handle Expired or Invalid OAuth Credentials

## Status

pass

## Scenarios

### Scenario 1: Unauthenticated redirect to integrations page

pass

Verified via `curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/integrations`. The server returned HTTP 302, confirming the route redirects unauthenticated users before any page content is served.

### Scenario 2: Integrations page loads with connected integration

pass

After logging in as `qa@example.com`, navigated to `http://localhost:4070/integrations`. The page loaded successfully and displayed "Google Analytics" in the "Connected Platforms" section with a "Connected" badge. The integration record shows it was connected via Google Analytics on 2026-03-18, confirming the seed data from `qa_seeds_440.exs` is in place.

Screenshot: `.code_my_spec/qa/440/screenshots/01_integrations_page_connected.png`

### Scenario 3: Sync Now on expired integration shows reconnection message

pass

Clicked the "Sync Now" button on the Google Analytics integration card. The LiveView responded with a flash error message:

> "Your Google Analytics token has expired. Please reconnect."

The message contains both "token has expired" and "reconnect" as expected. The integration card continued to display the "Connected" badge throughout — no data was deleted.

Screenshot: `.code_my_spec/qa/440/screenshots/02_sync_expired_flash_error.png`

### Scenario 4: Connect detail page shows Reconnect button

pass

Navigated to `http://localhost:4070/integrations/connect/google_analytics`. The per-provider detail card displayed:

- A "Connected" success badge
- The connected account email: "reports@andersonthefish.com"
- The GA4 property ID: "properties/396614951" (from provider_metadata)
- A "Select Accounts" button with `data-role="select-accounts-button"`
- A "Reconnect" anchor with `data-role="oauth-connect-button"` (confirmed by DOM inspection)
- A "Back to integrations" link

All elements expected by the spec are present.

Screenshot: `.code_my_spec/qa/440/screenshots/03_detail_page_reconnect_button.png`

### Scenario 5: Historical data not deleted after credentials expire

pass

After triggering the failed sync in Scenario 3, navigated back to `http://localhost:4070/integrations`. The Google Analytics integration remained in the "Connected Platforms" section with the "Connected" badge visible. The integration record was not deleted.

Screenshot: `.code_my_spec/qa/440/screenshots/04_data_preserved_after_expiry.png`

### Scenario 6: Reconnect button re-initiates OAuth flow

pass

On `/integrations/connect/google_analytics`, inspected the `href` attribute of `[data-role="oauth-connect-button"]`. The value is a full Google OAuth URL:

```
https://accounts.google.com/o/oauth2/v2/auth?access_type=offline&client_id=313342253006-fhe81vh1g5q7nd3f0kssp47jrvpuu0a5.apps.googleusercontent.com&prompt=consent&redirect_uri=http%3A%2F%2Flocalhost%3A4070%2Fintegrations%2Foauth%2Fcallback%2Fgoogle_analytics&response_type=code&scope=openid+email+profile+https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fanalytics.readonly&state=jVMvfko4xJPiurfFAUKOFBBRnOuo90aG
```

The URL is a full provider OAuth URL (not empty, not a relative path), pointing to `accounts.google.com`. It includes `access_type=offline`, `prompt=consent`, and the correct `redirect_uri` pointing back to the app's OAuth callback.

Screenshot: `.code_my_spec/qa/440/screenshots/05_reconnect_oauth_href.png`

### Scenario 7: Check for email notification

fail (expected — feature not implemented)

Navigated to `http://localhost:4070/dev/mailbox`. The mailbox shows "0 message(s)" with no emails about expired credentials, token expiry, or reconnection reminders. No email notification is sent when a sync fails due to expired tokens.

As noted in the brief, the email notification acceptance criterion is not implemented.

Screenshot: `.code_my_spec/qa/440/screenshots/06_dev_mailbox.png`

## Evidence

- `.code_my_spec/qa/440/screenshots/01_integrations_page_connected.png` — Integrations page showing Google Analytics in "Connected Platforms" after login
- `.code_my_spec/qa/440/screenshots/02_sync_expired_flash_error.png` — Flash error "Your Google Analytics token has expired. Please reconnect." after clicking Sync Now
- `.code_my_spec/qa/440/screenshots/03_detail_page_reconnect_button.png` — Provider detail page with Connected badge and Reconnect button
- `.code_my_spec/qa/440/screenshots/04_data_preserved_after_expiry.png` — Integrations page after failed sync, showing Google Analytics still listed as Connected
- `.code_my_spec/qa/440/screenshots/05_reconnect_oauth_href.png` — Detail page showing the Reconnect link (OAuth href inspected via browser_get_attribute)
- `.code_my_spec/qa/440/screenshots/06_dev_mailbox.png` — Dev mailbox showing 0 messages (no expiry notification email)

## Issues

### Email notification on token expiry not implemented

#### Severity
LOW

#### Description
When a sync fails due to an expired OAuth token, no email notification is sent to the user. The dev mailbox at `http://localhost:4070/dev/mailbox` shows 0 messages after triggering the expired-token sync error path. The acceptance criterion "user receives email notification" is not implemented. The in-app flash error "Your Google Analytics token has expired. Please reconnect." is shown immediately, but there is no asynchronous email delivery for the case where the user is not actively viewing the integrations page.
