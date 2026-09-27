# BDD spec plan — MetricFlow

How the generic `bdd/spex` framework docs (philosophy, boundaries, writing_a_spex)
apply to this project specifically.

## Public surfaces a spec may drive

MetricFlow has one user — the account holder (owner/admin/account_manager/
read_only, personal or via an agency grant) — and one surface: the Phoenix
web app. There is no coding-agent/harness surface here (no `Environments`,
no `McpServers`); every `when_` is a LiveView interaction or an HTTP request
against `MetricFlowWeb`.

Concrete modules a spec may act through (see `.code_my_spec/architecture/proposal.md`
for the full inventory):

- `MetricFlowWeb.AccountLive.*`, `AgencyLive.Settings`, `IntegrationLive.*`,
  `DashboardLive.*`, `CorrelationLive.*`, `AiLive.*`, `VisualizationLive.Editor`,
  `ReportLive.*`, `InvitationLive.*`, `SubscriptionLive.Checkout`,
  `AgencyLive.Plans`, `AgencyLive.StripeConnect`, `AgencyLive.Subscriptions` —
  driven via `Phoenix.LiveViewTest` (`live/2`, `form/2`, `render_submit/1`,
  `render_click/1`).
- `MetricFlowWeb.BillingWebhookController` and any OAuth callback controllers —
  driven via `Phoenix.ConnTest` (`post/2`, `get/2`).

## Fixture inventory

`MetricFlowSpex.Fixtures` (`test/support/fixtures/metric_flow_spex_fixtures.ex`)
is currently **empty by design**. All 374 existing specs establish state by
driving the real flow — registering/logging in a user, connecting an
integration through the OAuth UI, syncing via cassette-backed provider calls —
rather than seeding rows. Before adding a function here, check whether the
state can instead be produced by:

1. Driving the relevant LiveView or controller action.
2. Writing through an existing shared given in `MetricFlowSpex.SharedGivens`
   (formerly `SharedGivens`) — check there first; a new fixture is for state
   that only originates server-side (e.g. a synced integration token) and
   cannot reasonably be produced through the UI in a scenario's setup.

## Legal observable surfaces in `then_`

- **Rendered LiveView HTML** — `has_element?/2`, `render(view)`,
  `element/2 |> render()`. Prefer `data-test` selectors.
- **HTTP response body** — `json_response/2`, `response/2`,
  `redirected_to/2` (webhook controller, OAuth callback responses).
- Never read `MetricFlow.Repo` or a context function to prove an outcome —
  re-mount the LiveView and assert on what renders instead. The project-local
  Credo check (`MetricFlow.Check.Warning.MetricFlowSpexDenies`) enforces this
  for whole-module references; it does not catch every workaround, so this is
  a review-time rule too.

## Project-specific anti-patterns

- **Do not seed correlation, sync, or insight rows directly.** e.g. do not
  call `MetricFlow.Correlations.CorrelationsRepository` or
  `MetricFlow.Ai.AiRepository` from a `given_` to fast-forward to "a
  correlation result exists" — the user action that produces one is a
  completed sync (`DataSync.SyncWorker`) followed by the correlation job
  running. If seeding is unavoidable because the upstream production is
  covered by a separate end-to-end spec, leave a module-level comment saying
  so (see `bdd/spex/boundaries.md`'s anti-pattern section).
- **Do not read `MetricFlow.Metrics` or `MetricFlow.Reviews` query functions
  in a `then_`** to check that a dashboard or chart is correct — assert on
  the rendered Vega-Lite spec or table markup instead.
- **OAuth and provider API calls are cassette-backed** (`ExCliVcr`), not
  denied outright — a spec exercising a real sync still goes through
  `DataSync.SyncWorker`/the provider modules, it just replays a recorded
  HTTP cassette rather than hitting Google/Facebook/QuickBooks. This is a
  `when_`, not a fixture shortcut.
