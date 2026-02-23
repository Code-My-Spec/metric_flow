# E2E and Integration Testing Strategy

## Status

Accepted

## Context

MetricFlow is a Phoenix 1.8 / LiveView 1.1 marketing analytics SaaS that needs an integration
testing approach covering:

- User story acceptance criteria (registration, login, dashboards, integrations)
- External HTTP interactions (Google Analytics, Google Ads, Facebook Ads, QuickBooks, OAuth via Assent)
- LiveView interactive behavior (forms, navigation, real-time updates)
- JavaScript hook rendering (Vega-Lite charts via vega-embed)

The project already uses:

- `sexy_spex` (BDD) for behavior-driven specs run via `mix spex`
- `Phoenix.LiveViewTest` for LiveView unit tests
- `lazy_html` for HTML assertion helpers
- `floki` for HTML parsing
- `Req ~> 0.5` as the HTTP client
- `Assent ~> 0.2` for OAuth flows

## Options Considered

### Option A: SexySpex BDD + VCR HTTP Recording (No Browser Testing)

Use SexySpex BDD specs as the primary integration test layer. All user story acceptance criteria
are tested through `Phoenix.LiveViewTest` and `Phoenix.ConnTest`. External HTTP interactions are
recorded and replayed using a VCR library for deterministic testing.

- **Pros:**
  - Fast test execution — no browser startup, no WebSocket sandbox issues
  - Deterministic — VCR cassettes replay exact API responses
  - No CI infrastructure requirements (no ChromeDriver, no headless Chrome)
  - BDD given/when/then structure maps directly to user story acceptance criteria
  - `Phoenix.LiveViewTest` handles LiveView interactions natively without flakiness

- **Cons:**
  - Cannot test JavaScript hooks (Vega-Lite chart rendering)
  - Cannot test real browser behavior (CSS rendering, responsive layout)

### Option B: Wallaby with ChromeDriver

Browser-based integration testing using Wallaby (0.30.x, 3.7M downloads) with ChromeDriver
for headless Chrome.

- **Pros:**
  - Tests real browser behavior including JavaScript hooks
  - Can verify Vega-Lite chart rendering end-to-end
  - Mature library with LiveView support via sandbox plug

- **Cons:**
  - Requires ChromeDriver + Chrome in CI (adds setup complexity)
  - `DBConnection.OwnershipError` issues with LiveView WebSocket + Ecto sandbox
  - Must run `async: false` for LiveView tests (slower)
  - Browser tests are inherently flaky — timing-dependent assertions
  - Community consensus: "keep browser tests sparse, only test happy paths"

### Option C: Playwright via phoenix_test_playwright

Cross-browser E2E testing using Playwright via Elixir bindings.

- **Pros:**
  - Cross-browser support (Chrome, Firefox, WebKit)
  - Modern auto-waiting reduces flakiness

- **Cons:**
  - `playwright` Elixir package is alpha (207 total downloads)
  - Requires Node.js in CI for Playwright CLI
  - Not production-proven in the Elixir ecosystem

### Option D: Phoenix.LiveViewTest Only (No VCR)

Rely entirely on `Phoenix.LiveViewTest` with mocked contexts.

- **Pros:**
  - Simplest setup — no additional dependencies

- **Cons:**
  - No HTTP recording means external API integration tests require manual mocks
  - Mocks can drift from real API responses over time

## Decision

**Option A: SexySpex BDD specs with VCR HTTP recording. No browser-based E2E testing.**

SexySpex BDD specs are the primary integration test layer. All user story acceptance criteria
are tested through `Phoenix.LiveViewTest` and `Phoenix.ConnTest` within the SexySpex
given/when/then structure.

External HTTP interactions (Google APIs, Facebook Marketing API, QuickBooks API, OAuth callbacks)
are recorded and replayed using a VCR approach for deterministic testing in CI.

Browser-based testing (Wallaby, Playwright) is not adopted because:

1. `Phoenix.LiveViewTest` covers all LiveView interactions without browser overhead
2. Vega-Lite chart specs are validated server-side as JSON — the rendering is a client-side
   concern handled by the well-tested `vega-embed` library
3. Browser test flakiness and CI setup complexity are not justified for the current feature set
4. If JavaScript hook testing becomes critical in the future, Wallaby can be added for a small
   set of smoke tests without changing the overall strategy

### HTTP Recording: Two-Layer Approach

Two recording tools are used because MetricFlow has two HTTP clients:

- **ReqCassette** — for providers using raw Req (Google Ads, Facebook Ads, QuickBooks, OAuth).
  Integrates via Req's `plug:` option. Cassettes stored as JSON.
- **TestRecorder** — for Google Analytics which uses the official `google_api_analytics_data`
  library (Tesla via `google_gax`). Records any function return value to `.etf` files using
  `:erlang.term_to_binary`. Works at the function level, not the HTTP transport level, so it's
  transport-agnostic.

ExVCR was rejected because it hooks into Hackney/HTTPoison, incompatible with both Req and the
goal of recording Tesla calls at a higher level. See `testing_strategy.md` for full details.

## Consequences

**Test layers:**

| Layer | Tool | Scope |
|-------|------|-------|
| BDD Specs | SexySpex (`mix spex`) | User story acceptance criteria |
| LiveView Tests | `Phoenix.LiveViewTest` | Individual LiveView behavior |
| Context Tests | ExUnit | Business logic, repository queries |
| HTTP Recording (Req) | ReqCassette | Google Ads, Facebook, QuickBooks, OAuth |
| HTTP Recording (Tesla) | TestRecorder | Google Analytics (google_api library) |

**Trade-offs accepted:**

- No visual regression testing — CSS layout issues must be caught manually
- JavaScript hooks (Vega charts) are not tested in automated tests — trusted to the
  `vega-embed` library and manual QA
- VCR cassettes must be regenerated when external API response formats change

**Follow-up actions:**

- Add `{:req_cassette, "~> 0.4", only: :test}` to `mix.exs`
- Port `TestRecorder` from CodeMySpec to `test/support/test_recorder.ex`
- Establish cassette directory structure: `test/cassettes/{provider}/` per data provider
- Record initial cassettes against real APIs during provider module development
- Commit cassettes to version control; regenerate with `:record` mode (ReqCassette) or
  `RERECORD=true` (TestRecorder) when APIs change
- Use `filter_request_headers` to strip `Authorization` headers from ReqCassette JSON cassettes
