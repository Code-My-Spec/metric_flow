# Per-platform detail OAuth connect button falls back to phx-click when no credentials configured

## Severity

low

## Scope

app

## Description

The per-platform detail view (e.g., `/integrations/connect/google_ads`) falls back to a `phx-click` button when `Integrations.authorize_url/1` returns an error (no OAuth credentials configured in dev). The expected `data-role="oauth-connect-button"` anchor with `target="_blank"` is only rendered when valid credentials produce an authorize URL. This means the OAuth flow cannot be verified in environments without real provider credentials. The fallback button approach may also confuse users since it triggers an error flash rather than redirecting to the OAuth provider.

## Source

QA Story 434 — `.code_my_spec/qa/434/result.md`

## Triage Notes

Dismissed — severity is low, below the medium+ triage threshold. The fallback behavior is by design for environments without OAuth credentials configured.
