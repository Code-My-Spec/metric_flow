# Schedule section does not mention Google Business Profile as a covered provider

## Status

resolved

## Severity

low

## Scope

app

## Description

The  [data-role="sync-schedule"]  static description text was written before Story 517 was implemented. It reads: "Covers marketing providers (Google Ads, Facebook Ads, Google Analytics) and financial providers (QuickBooks)." Google Business Profile is now a supported provider and should be listed. Reproduction: visit  /integrations/sync-history  — the Automated Sync Schedule section does not mention Google Business Profile.

## Source

QA Story 517 — `.code_my_spec/qa/517/result.md`

## Resolution

Updated schedule description in sync_history.ex to include Google Business Profile and Google Search Console in the provider list.
