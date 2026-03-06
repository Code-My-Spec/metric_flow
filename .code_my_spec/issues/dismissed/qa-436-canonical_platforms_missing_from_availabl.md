# Canonical platforms missing from Available Platforms section

## Severity

medium

## Scope

app

## Description

Google Ads, Facebook Ads, and Google Analytics do not appear in the "Available Platforms" section.
Only "Google (Google OAuth)" is listed. A user has no way to connect these three canonical marketing
platforms from the integrations index page. This is a direct consequence of the platform list construction bug described above. The  @canonical_platforms
module attribute (which hardcodes these three platforms) is absent from the running module version.

## Source

QA Story 436 — `.code_my_spec/qa/436/result.md`

## Triage Notes

Dismissed — duplicate of already-fixed qa-434-integrations_index_missing_canonical_platforms. The code fix was applied but the QA server wasn't restarted, so the stale module was tested.
