# OAuth callback does not display error_description from provider

## Status

accepted

## Severity

low

## Scope

app

## Description

When visiting  /integrations/oauth/callback/google?error=access_denied&error_description=User+denied+access , the error result view shows a generic message "Access was denied. Please try again if you want to connect." rather than the provider's human-readable  error_description  value ("User denied access"). The  error_description  parameter is passed by OAuth providers to give users a specific explanation of why the connection failed. Ignoring it in favor of a generic message may be less helpful in cases where providers return distinct error reasons (e.g., "Account suspended", "Scope not approved"). This is a minor UX gap, not a functional failure. The user still sees a clear error state and "Try again" link.

## Source

QA Story 434 — `.code_my_spec/qa/434/result.md`
