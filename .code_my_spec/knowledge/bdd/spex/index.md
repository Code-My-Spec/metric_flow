# BDD spex — Metric Flow specifics

The framework docs (`bdd/spex/philosophy.md`, `bdd/spex/boundaries.md`,
`bdd/spex/writing_a_spex.md`) cover the generic rules. This page is the
project-specific complement: which surfaces exist here, what the
fixtures bridge currently offers, and what a `then_` may legally read
in this codebase.

## Public surfaces a spec may drive

- **`MetricFlowWeb` LiveViews** — the primary surface. Drive with
  `Phoenix.LiveViewTest` (`live/2`, `form/2`, `render_submit/1`,
  `render_click/1`). Every `*Live` module under `lib/metric_flow_web/live/`
  is fair game: `AccountLive`, `AgencyLive`, `AiLive`, `CorrelationLive`,
  `DashboardLive`, `IntegrationLive`, `InvitationLive`, `OnboardingLive`,
  `ReportLive`, `SubscriptionLive`, `UserLive`, `VisualizationLive`.
- **`MetricFlowWeb` controllers** — `IntegrationOauthController`,
  `BillingWebhookController`, `UserSessionController`. Drive with
  `Phoenix.ConnTest` (`get/2`, `post/2`, `json_response/2`,
  `redirected_to/2`).

There is no separate harness-hook surface in this project (that pattern
belongs to CodeMySpec itself, not to an application it generates) —
Metric Flow specs only ever drive the two surfaces above.

## Fixture inventory

`MetricFlowSpex.Fixtures` (`test/support/fixtures/metric_flow_spex_fixtures.ex`)
is currently **empty by design**. All 374 existing spex drive setup
through the web layer (registration form, login form, OAuth callback,
etc.) rather than seeding rows directly, and none has yet needed a
server-originated fixture. If a new spec needs state that:

1. Can be produced by driving a LiveView or controller — do that.
2. Genuinely originates server-side (a user, an account, a synced
   integration) and driving the UI to create it is prohibitively
   expensive for the scenario under test — add a narrow
   `defdelegate` here to the matching `*_fixtures.ex` under
   `test/support/fixtures/` (`users_fixtures.ex`, `agencies_fixtures.ex`,
   `metrics_fixtures.ex`, etc.), and say why in a comment.

Do not add a fixture for state a real user would create through the UI
(an account's white-label config, a saved visualization, a dashboard) —
that's exactly the shortcut `boundaries.md`'s anti-pattern section warns
about.

## Legal observable surfaces in `then_`

- **Rendered LiveView HTML/elements** — `render(view)`,
  `has_element?(view, selector)`, `element(view, selector) |> render()`.
  Prefer `data-role`/`data-test` selectors (see existing specs under
  `test/spex/`) over class or id.
- **HTTP response body** — `json_response/2` for the OAuth/webhook
  controllers, `redirected_to/2` for redirect assertions.
- **Flash messages** — `Phoenix.Flash.get/2` against the conn or
  LiveView, since several criteria assert on flash text
  ("Welcome back!", "Logged out successfully.", etc.).

Never assert against `MetricFlow.Repo` or any context's `get_*`/`list_*`
functions in a `then_` — re-mount the LiveView or re-request the page
and assert on what it renders.

## Project-specific anti-patterns

- **Do not seed sync/integration state directly.** `MetricFlow.DataSync`
  and `MetricFlow.Integrations` rows (a completed sync, a connected
  OAuth integration) should come from driving the OAuth callback or
  triggering "Sync Now", not from a fixture — the point of those specs
  is proving the sync pipeline itself works.
- **Do not seed `MetricFlow.Ai` or `MetricFlow.Correlations` results.**
  These are computed from cassette-backed LLM/API calls (see
  `bdd/spex/environment.md` for the `ExCliVcr` cassette convention) —
  drive the real flow and let the cassette answer, don't fabricate the
  output row.
- **Do not read `MetricFlow.Billing` subscription state from the DB** to
  decide whether a feature gate should be visible; re-render the page
  and check what's shown, the same as any other gate.
