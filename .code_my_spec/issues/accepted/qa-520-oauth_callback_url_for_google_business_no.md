# OAuth callback URL for google_business not registered in Google Cloud Console

## Status

accepted

## Severity

low

## Scope

docs

## Description

Clicking "Reconnect" for Google Business on the connect grid redirects to Google OAuth but fails with  redirect_uri_mismatch  — the callback URL  http://localhost:4070/integrations/oauth/callback/google_business  is not registered as an authorized redirect URI in the Google Cloud Console project. This is expected for localhost testing. The production/UAT environment needs this URI added to the OAuth client configuration before the Google Business OAuth flow can complete end-to-end.

## Source

QA Story 520 — `.code_my_spec/qa/520/result.md`
