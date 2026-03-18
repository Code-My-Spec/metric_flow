# Non-Google provider account selection pages display Google Analytics-specific help text

## Status

resolved

## Severity

medium

## Scope

app

## Description

The account selection page at  /integrations/connect/facebook_ads/accounts  renders incorrect help text for the manual property ID field. The field label is correctly "Ad Account ID" but the supplemental help text reads "Find this in Google Analytics under Admin → Property Settings" — this is Google Analytics-specific guidance that is meaningless and misleading for a Facebook Ads user. The same issue would affect  /integrations/connect/quickbooks/accounts  when a QuickBooks integration exists. Steps to reproduce: Log in with an account that has a facebook_ads integration Navigate to  /integrations/connect/facebook_ads/accounts Observe the help text below the manual entry field reads "Find this in Google Analytics under Admin → Property Settings" Expected:  Help text should say something like "Find this in your Facebook Business Manager" or similar Facebook-specific guidance. Actual:  "Find this in Google Analytics under Admin → Property Settings" Location:   lib/metric_flow_web/live/integration_live/connect.ex ,  render_account_selection/1  — the  label-text-alt  span is hardcoded to Google Analytics instructions and is not provider-aware. Screenshot:  .code_my_spec/qa/434/screenshots/05b-facebook-accounts.png

## Source

QA Story 434 — `.code_my_spec/qa/434/result.md`

## Resolution

Added help_text field to account_labels/1 with provider-specific guidance. Google: GA Admin settings, Facebook: Business Manager, QuickBooks: Account Settings. Template now uses dynamic @account_labels.help_text instead of hardcoded GA text.
