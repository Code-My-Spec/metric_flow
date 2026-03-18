# Facebook and QuickBooks accounts pages show Google Analytics-specific text

## Status

resolved

## Severity

medium

## Scope

app

## Description

Visiting  /integrations/connect/facebook_ads/accounts  renders the account selection view with the heading "Facebook — Select Accounts" but the body text says "Choose which GA4 property to sync data from." and the form field is labeled "GA4 Property ID" with the help text "Find this in Google Analytics under Admin → Property Settings". This text is incorrect for a Facebook provider. The  render_account_selection/1  function is not provider-aware — all providers show the same Google Analytics-centric UI copy. For Facebook and QuickBooks, this text is misleading and incorrect.

## Source

QA Story 434 — `.code_my_spec/qa/434/result.md`

## Resolution

Added account_labels/1 helper with provider-specific text for Google (GA4 Property), Facebook (Ad Account), QuickBooks (Company/Realm ID), and a generic fallback.
