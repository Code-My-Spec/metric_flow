# What is still red, and why

`mix test` **2904/2917** (13 failing, 10 excluded) · `mix spex` **360/374** (14 failing)

Started the day at 2175/2931 and 0/374. Everything mechanical is done. **All 27
remaining failures are two features that were never built**, and both already have
their acceptance criteria written as tests and spex — which makes them the right
thing to hand to an agent as stories rather than to repair.

## The two features

### Agency domain-based auto-enrollment — 9 tests + 6 spex

`agency_live/settings_test.exs:119,142,161` and the `agency-admin-team-members`
spex. The screen has no `form#auto-enrollment-form`. `AutoEnrollmentRule` exists
as a schema (`lib/metric_flow/agencies/auto_enrollment_rule.ex`, unique on
`[:agency_id, :email_domain]`, with `default_access_level` and `enabled`) and
`AgenciesRepository` can upsert it — what is missing is the LiveView.

Criteria, from the spex titles: configure a rule for an email domain; users who
register with a matching domain are added automatically; auto-enrolled users get
the default access level the admin set; the admin can view and manage
auto-enrolled members; the admin can disable it; team members inherit access to
all the agency's client accounts.

### Agency white-label — 7 spex (+ the rest of those 9 tests)

`agency_live/settings_test.exs:69,187,217,241,265,283`. No `form#white-label-form`
and no `[data-role='reset-white-label']`. `MetricFlowWeb.WhiteLabelHook` is wired
into the `/app` live_session already, so the read path exists; the settings form
does not.

Criteria: upload a logo (PNG, JPG, SVG); set primary/secondary/accent colours;
configure a custom subdomain, with DNS verification before activation; preview
changes before saving; reset to default; stored at agency account level; no
Anderson Analytics branding on white-labelled instances; a client reaching the
system through the agency subdomain sees agency branding, through the main domain
sees default branding; white-labelling is visual only.

### Visualization preview — 4 tests

`visualization_live/editor_test.exs:133,151,179,198`. There is no
`preview-chart-btn` and no `preview_chart` event in
`lib/metric_flow_web/live/visualization_live/editor.ex`. The module also carries
unused `fetch_metric_data/2`, `page_title_for/1` and `build_template_spec/3`
defaults — the shape of an editor someone stopped halfway through. The matching
spex is "Changes preview in real-time before saving".

## Excluded, not failing: 10 tests waiting on a recording

Tagged `:needs_cassette`, excluded by `ExUnit.start/1`, visible with
`mix test --include needs_cassette`.

| where | what it needs |
|---|---|
| `ai/insights_generator_test.exs` `generate/3` (8) | `insights_generator_success.json` and `insights_generator_single.json` hold `{"confidence", "suggestions"}`, the schema before `{"insights": [{summary, content, suggestion_type, confidence}]}`. Re-record — and since Anthropic is being replaced with alloy and local Claude Code, record against whatever replaces it. |
| `data_providers/google_business_test.exs` `fetch_metrics/2 with cassette` (2) | No `gbp_fetch_metrics` or `gbp_unauthorized` cassette, and no `GOOGLE_BUSINESS_TEST_ACCOUNT_IDS` / `GOOGLE_BUSINESS_TEST_LOCATION_IDS` in `.env.test`. |

A recorded response is never rewritten to make one of these pass — that records
something the provider never said.

## Things to know before working this suite

- **The suite makes no network calls.** Every cassette surface is `mode: :replay`
  now — LLM, data_sync and Stripe. `git status -- test/cassettes/` is clean after
  a full run; if it ever is not, a `:replay` was dropped somewhere.
- **LazyHTML replaced Floki** in LiveViewTest and is stricter. An unquoted
  attribute value that starts with a digit *raises* rather than not matching, so
  `[phx-value-id=#{id}]` must be `[phx-value-id='#{id}']`.
- **`Enum.all?([], _)` is true.** Several tests were green on an empty list and
  proved nothing. When a list-returning call is under test, assert it is non-empty
  first.
- **Application config is global.** The five Google provider test modules and
  `billing_test.exs` are `async: false` because they mutate `:google_client_id`,
  `:oauth_providers` or the Logger level. Anything new that does the same has to
  join them.
- **`String.to_existing_atom/1` does not raise for the atoms you expect.** Atoms
  are never collected, so once any code has mentioned one the lookup succeeds.
  Two places used the raise as a control-flow signal; both now match on a reason
  instead.
