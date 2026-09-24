# The remaining test and spex failures, grouped by cause

Working inventory for getting metric_flow's suites to green, so the in-app
agents inherit a baseline where a red test means *their* regression.

Baseline at the time of writing: `mix test` **2801/2931** (83 failing, after the
4 fixed in `5db7838`), `mix spex` **360/374** (14 failing). Measured from a full
run; per-file re-runs since.

Three things to know before working this list:

- **`mix test` dirties five cassettes on every run** — the same 714 lines
  against `api.anthropic.com` and `api.stripe.com`. `git checkout -- test/cassettes/`
  after every run, and never stage them. See STATUS.md.
- **The harness now serves this checkout** (working copy
  `3d7fe72b-0b24-43bc-a0c6-7b9c1bc9d98b`), so it runs its own analyzer sweeps.
  Don't start a full suite beside one — scope to the file you are changing and
  spend the full run once at the end.
- **LazyHTML replaced Floki** in LiveViewTest and is stricter about selectors.
  An unquoted attribute value that starts with a digit now *raises* instead of
  not matching. If a selector error looks like a missing element, read it again.

## Certain: test or environment defects, not the application

| where | n | what |
|---|---|---|
| `smoke_test.exs:37,41` | 2 | Asserts `Sentry` and `MetricFlowWeb.PromEx` load. Both superseded — `mix.exs` says the AppSignal ADR "supersedes the 2026-02-21 Sentry+PromEx ADR after the move off Fly.io", neither is a dep any more, and `lib/metric_flow_web/prom_ex.ex` does not exist. `mix.lock` still carries both; `mix deps.unlock --unused` is in the `precommit` alias. Replace the assertions with AppSignal. |

## Probable: one cause per cluster, worth one investigation each

| where | n | shape | first thing to check |
|---|---|---|---|
| `dashboard_live/editor_test.exs`, `visualization_live/editor_test.exs` | 9 | `selector "[data-role='metric-list'] button" did not return any element` | One missing element in two editors. Does either template render `data-role="metric-list"` at all, and does the list populate without metrics in the account? |
| `ai/insights_generator_test.exs`, `ai/report_generator_test.exs`, `ai_live/report_generator_test.exs` | 16 | `MatchError` on the generator's return, plus `Expected truthy` | These are the tests whose cassettes get rewritten on every run. Suspect cassette replay before suspecting the generators — a miss falls through to a live call, so a replayed run and a recorded run are different tests. |
| `dashboards_test.exs` | 10 | `Assertion with in failed` ×5, `BadMapError` ×2, `==` ×2, `!=` ×1 | One shape mismatch in what `get_dashboard_data/2` returns. `BadMapError: expected a map` says a list is arriving where a map is expected. |
| `billing_test.exs:9,26,43,76,92` | 5 | `Assertion with =~ failed`, all five in `process_webhook_event/1` | Every webhook case at once, so one thing about the event fixture or the return string. `billing_webhook_controller_test.exs:182` raising `Plug.Parsers.ParseError` (a `Jason.DecodeError`) may be the same payload problem seen from the HTTP side. |
| Google provider tests | 6 | `match (=) failed` on error tuples | `google_search_console_sites_test.exs:198` expects `{:error, :malformed_response}` and gets `{:error, {:network_error, "unexpected byte at position 0..."}}`. Error normalization is not collapsing a decode failure. `.code_my_spec/knowledge/data_provider_apis/error_normalization.md` is the spec. Same file also covers `google_business_test.exs:1013,1038`, `google_ads_accounts_test.exs:430`, `google_business_locations_test.exs:330,341`. |

## Feature not built — story work, not repair

| where | n | what |
|---|---|---|
| `agency_live/settings_test.exs` | 9 | `form#auto-enrollment-form` (2), `form#white-label-form` (3), `[data-role='reset-white-label']` (1), truthy (3) |
| spex: agency auto-enrollment | 6 | domain-based auto-enrollment, default access level, member management, disable, inherited client access |
| spex: agency white-label | 7 | logo upload, colour scheme, custom subdomain + DNS verification, live preview, reset to default, stored at agency level |

These 13 spex and 9 tests are the same two features. They are the clearest
candidates to hand to an agent as stories rather than to fix by hand — the tests
and spex already state the acceptance criteria.

## Singles, each its own investigation

`account_repository_test.exs:342` · `accounts_test.exs:366` ·
`ai/insight_test.exs:167` · `ai/llm_client_test.exs:93` ·
`integration_oauth_controller_test.exs:34,41,102` ·
`integration_live/account_edit_test.exs:96` ·
`account_live/settings_test.exs:300` · `onboarding_live/index_test.exs:27` ·
`ai_live/report_generator_test.exs:209` ·
`integration_live/connect_test.exs:210` · `ai_live/insights_test.exs:48` ·
`correlation_live/goals_test.exs:129` (wants an `a[href='/integrations']` the
empty state does not render) · `report_live/index_test.exs:34,94,180` ·
`integration_live/index_test.exs:97,112,145` ·
`dashboard_live/index_test.exs:44,100` · `dashboard_live/show_test.exs:66` ·
`visualization_live/editor_test.exs:66,151` ·
`subscription_live/checkout_test.exs:82` · `billing_webhook_controller_test.exs:182`

The `Expected truthy, got false` ones on index and show LiveViews are almost all
"this `data-role` is not in the template" and will read as a group once one is
opened.

## Already fixed (for the record)

| commit | n | what |
|---|---|---|
| `5db7838` | 4 | 3 invalid CSS selectors in `plans_test.exs`; `list_all_plans/1` so the agency's management screen shows a deactivated plan |
