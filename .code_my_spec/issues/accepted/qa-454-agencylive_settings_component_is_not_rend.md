# AgencyLive.Settings component is not rendered by AccountLive.Settings

## Severity

high

## Scope

app

## Description

MetricFlowWeb.AgencyLive.Settings  is a fully-implemented function component module with auto-enrollment and white-label branding sections, but  MetricFlowWeb.AccountLive.Settings  never calls  AgencyLive.Settings.auto_enrollment_section/1  or  AgencyLive.Settings.white_label_section/1 . The agency settings cards ( data-role="agency-auto-enrollment" ,  data-role="agency-white-label" ) are therefore never visible on  /accounts/settings , regardless of account type or user role. Fix:  AccountLive.Settings  should conditionally render both  AgencyLive.Settings  sections (inside a  :if={@account.type == "team" and @current_user_role in [:owner, :admin]}  guard) and the mount/event handlers for saving white-label config and auto-enrollment rules need to be added.

## Source

QA Story 454 — `.code_my_spec/qa/454/result.md`

## Resolution

Updated `MetricFlowWeb.AccountLive.Settings` to:
- Alias `MetricFlow.Agencies` and `MetricFlowWeb.AgencyLive`
- Load `auto_enrollment_rule` and `agency_white_label_config` from the Agencies context on mount for team accounts
- Conditionally render `<AgencyLive.Settings.auto_enrollment_section>` and `<AgencyLive.Settings.white_label_section>` when `@account.type == "team"` and role is owner/admin
- Handle events: `save_auto_enrollment`, `disable_auto_enrollment`, `validate_white_label`, `save_white_label`, `reset_white_label`, `verify_dns`

**Files changed:** `lib/metric_flow_web/live/account_live/settings.ex`
**Verified:** `mix test` — all account and dashboard tests pass (116/116).
