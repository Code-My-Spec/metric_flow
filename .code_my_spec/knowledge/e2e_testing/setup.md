# E2E Testing Setup: ReqCassette and TestRecorder

This document covers how MetricFlow records and replays external API interactions
in its integration test suite. The approach is described in the architecture decision
at `docs/architecture/decisions/e2e_testing.md`.

The short version: MetricFlow has two HTTP clients and therefore two recording tools.

| HTTP Client | Used By | Recording Tool | Cassette Format |
|---|---|---|---|
| `Req ~> 0.5` | Google Ads, Facebook Ads, QuickBooks, OAuth (Assent) | ReqCassette | `.json` |
| Tesla (via `google_gax`) | Google Analytics (`google_api_analytics_data`) | TestRecorder | `.etf` |

---

## 1. ReqCassette

### What It Is

ReqCassette is a VCR-style record-and-replay library that integrates natively with the
Req HTTP client via Req's `plug:` option. It intercepts outgoing HTTP requests, records
the real response to a JSON cassette file on the first run, and replays the recorded
response on every subsequent run without touching the network.

Unlike ExVCR (which hooks into Hackney), ReqCassette is async-safe and works with
`async: true` in ExUnit.

Current version on Hex: **0.5.2**. Source: [hex.pm/packages/req_cassette](https://hex.pm/packages/req_cassette).

### Installation

Add to `mix.exs` — test-only dependency:

```elixir
defp deps do
  [
    # ... existing deps ...
    {:req_cassette, "~> 0.5", only: :test}
  ]
end
```

Run `mix deps.get`.

### Cassette Directory Structure

Store cassettes under `test/cassettes/`, organized by provider:

```
test/
  cassettes/
    google_ads/
      fetch_campaigns.json
      fetch_metrics_date_range.json
    facebook_ads/
      fetch_insights.json
      fetch_insights_pagination.json
    quickbooks/
      profit_and_loss.json
      balance_sheet.json
    oauth/
      google_token_exchange.json
      google_token_refresh.json
```

Each file is a pretty-printed JSON array of recorded HTTP interactions. Commit
cassettes to version control — they are the source of truth for what external APIs
return during CI runs.

### Basic Usage in Tests

```elixir
defmodule MetricFlow.DataSync.Providers.GoogleAdsTest do
  use ExUnit.Case, async: true
  import ReqCassette

  @cassette_dir "test/cassettes/google_ads"

  test "fetch_metrics/2 returns campaign data for the given date range" do
    with_cassette "fetch_metrics_date_range", [cassette_dir: @cassette_dir], fn plug ->
      req = Req.new(plug: plug)
      result = GoogleAds.fetch_metrics(integration_fixture(), req: req)
      assert {:ok, metrics} = result
      assert length(metrics) > 0
    end
  end
end
```

The `with_cassette` function receives a `plug` value you inject into `Req.new(plug: plug)`.
Pass that Req struct (or the plug option) down to the function under test.

Provider modules should accept an optional `:req` option in `fetch_metrics/2` for this
purpose:

```elixir
defmodule MetricFlow.DataSync.Providers.GoogleAds do
  def fetch_metrics(integration, opts \\ []) do
    req = Keyword.get(opts, :req, build_req(integration.access_token))
    # ... make HTTP calls using req ...
  end

  defp build_req(access_token) do
    Req.new(
      auth: {:bearer, access_token},
      retry: :safe_transient,
      max_retries: 3
    )
  end
end
```

### Recording Modes

The `mode:` option controls when the network is hit:

| Mode | Behaviour |
|---|---|
| `:record` | Default. Record if cassette/interaction is missing, otherwise replay. Safe for all environments. |
| `:replay` | Only replay from cassette. Raise if cassette or matching interaction is missing. Use in CI to prevent unexpected network calls. |
| `:bypass` | Ignore cassettes entirely. Always hit the real network. Useful when regenerating all cassettes. |

Example: enforce replay mode in CI by reading an environment variable.

```elixir
@cassette_mode if System.get_env("CI"), do: :replay, else: :record

test "fetches profit and loss report" do
  with_cassette "profit_and_loss", [cassette_dir: @cassette_dir, mode: @cassette_mode], fn plug ->
    req = Req.new(plug: plug)
    result = QuickBooks.fetch_profit_and_loss(integration, req: req)
    assert {:ok, report} = result
  end
end
```

### Filtering Sensitive Headers

Always strip the `Authorization` header before writing cassettes to disk. Bearer
tokens and API keys must never be committed to version control.

```elixir
with_cassette "fetch_campaigns",
  [
    cassette_dir: @cassette_dir,
    filter_request_headers: ["authorization", "developer-token"]
  ],
  fn plug ->
    req = Req.new(plug: plug)
    GoogleAds.fetch_metrics(integration, req: req)
  end
```

For Google Ads, filter both `authorization` and `developer-token`. For Facebook Ads,
the access token travels as a query parameter, not a header — use `filter_sensitive_data`
instead:

```elixir
with_cassette "fetch_insights",
  [
    cassette_dir: @cassette_dir,
    filter_sensitive_data: [{~r/access_token=[^&"]+/, "access_token=FILTERED"}]
  ],
  fn plug ->
    req = Req.new(plug: plug, params: [access_token: integration.access_token])
    FacebookAds.fetch_metrics(integration, req: req)
  end
```

Full list of `with_cassette` options:

| Option | Type | Default | Description |
|---|---|---|---|
| `:cassette_dir` | `string` | `"cassettes"` | Directory to read/write cassette files |
| `:mode` | `:record \| :replay \| :bypass` | `:record` | Recording mode |
| `:filter_request_headers` | `[string]` | `[]` | Header names to strip from recorded requests (case-insensitive) |
| `:filter_response_headers` | `[string]` | `[]` | Header names to strip from recorded responses |
| `:filter_sensitive_data` | `[{regex, replacement}]` | `[]` | Regex replacements applied to the raw cassette JSON |
| `:match_requests_on` | `[atom]` | `[:method, :uri, :query, :headers, :body]` | Criteria used to match a request against a recorded interaction |
| `:before_record` | `fun` | `nil` | Custom callback receiving and returning the interaction map before it is written |

### Regenerating Cassettes

Delete the cassette file and run the test against the real API. The `:record` mode
will create a fresh cassette:

```bash
# Delete a single cassette
rm test/cassettes/google_ads/fetch_metrics_date_range.json

# Run the specific test with real credentials set in environment
GOOGLE_ADS_ACCESS_TOKEN=... mix test test/metric_flow/data_sync/providers/google_ads_test.exs
```

To regenerate all cassettes at once, set `mode: :bypass` globally and run the full
test suite with real credentials available.

### ReqCassette with Assent OAuth Callbacks

The Assent library (used for OAuth token exchange) accepts a `:http_adapter` option.
Assent's `Req` adapter can be injected in tests to route OAuth calls through
a cassette:

```elixir
test "exchanges authorization code for tokens" do
  with_cassette "google_token_exchange", [cassette_dir: "test/cassettes/oauth",
                                          filter_request_headers: ["authorization"]], fn plug ->
    req = Req.new(plug: plug)
    config = Google.config() ++ [http_adapter: {Assent.HTTPAdapter.Req, [req: req]}]

    result = Assent.Strategy.Google.callback(config, %{"code" => "test_code", "state" => "x"})
    assert {:ok, %{token: token, user: user}} = result
  end
end
```

---

## 2. TestRecorder

### What It Is and Why It Exists

The `google_api_analytics_data` library (official Google Elixir client) uses Tesla as
its HTTP transport, routed through `google_gax`. ReqCassette cannot intercept Tesla
calls because it only integrates with Req.

TestRecorder solves this at a higher level: it records the **return value** of any
function call rather than the underlying HTTP interaction. On the first run it calls
the real function and serializes the result to a `.etf` file using
`:erlang.term_to_binary/1`. On subsequent runs it deserializes the saved term and
returns it directly, bypassing the function entirely.

This approach is transport-agnostic — it does not care whether the underlying
implementation uses Tesla, Req, gRPC, or anything else.

### File Location

Port `TestRecorder` from the CodeMySpec project into the MetricFlow test support tree:

```
test/support/test_recorder.ex
```

### Implementation

```elixir
defmodule MetricFlowTest.TestRecorder do
  @moduledoc """
  Function-level record-and-replay for external client calls.

  Records the return value of a function to an ETF file on the first run,
  then replays the saved value on all subsequent runs without calling the
  real function.

  Use this for providers that do NOT use Req (i.e. the Google Analytics
  official client library which uses Tesla via google_gax), where
  ReqCassette cannot intercept calls at the HTTP level.

  ## Usage

      import MetricFlowTest.TestRecorder

      test "returns sessions by date" do
        result =
          record("test/cassettes/google_analytics/run_report.etf", fn ->
            GoogleAnalyticsProvider.fetch_metrics(integration)
          end)

        assert {:ok, metrics} = result
        assert length(metrics) > 0
      end

  ## Re-recording

  Delete the cassette file and run the test against the real API:

      rm test/cassettes/google_analytics/run_report.etf

  Or set the RERECORD=true environment variable to force re-recording
  regardless of whether the cassette exists:

      RERECORD=true mix test test/metric_flow/data_sync/providers/google_analytics_test.exs
  """

  @doc """
  Records or replays the result of `fun`.

  If `path` exists and `RERECORD` env var is not set, deserializes and returns
  the stored term. Otherwise calls `fun`, serializes the result to `path`, and
  returns it.
  """
  @spec record(Path.t(), (-> term())) :: term()
  def record(path, fun) when is_function(fun, 0) do
    if File.exists?(path) and not rerecord?() do
      path |> File.read!() |> :erlang.binary_to_term()
    else
      result = fun.()
      path |> Path.dirname() |> File.mkdir_p!()
      File.write!(path, :erlang.term_to_binary(result))
      result
    end
  end

  defp rerecord? do
    System.get_env("RERECORD") in ["true", "1", "yes"]
  end
end
```

### Cassette Directory for TestRecorder

Store `.etf` files alongside ReqCassette's `.json` files, under the same provider
subdirectory:

```
test/
  cassettes/
    google_analytics/
      run_report_sessions.etf
      run_report_conversions.etf
      run_report_empty_response.etf
```

### Usage in Tests

```elixir
defmodule MetricFlow.DataSync.Providers.GoogleAnalyticsTest do
  use ExUnit.Case, async: true
  import MetricFlowTest.TestRecorder

  @cassette_dir "test/cassettes/google_analytics"

  test "fetch_metrics/1 returns parsed session data" do
    result =
      record("#{@cassette_dir}/run_report_sessions.etf", fn ->
        integration = google_analytics_integration_fixture()
        GoogleAnalytics.fetch_metrics(integration)
      end)

    assert {:ok, metrics} = result
    assert Enum.any?(metrics, &(&1.name == "sessions"))
  end

  test "fetch_metrics/1 handles empty response" do
    result =
      record("#{@cassette_dir}/run_report_empty_response.etf", fn ->
        integration = google_analytics_integration_fixture()
        GoogleAnalytics.fetch_metrics(integration, date_range: {~D[2020-01-01], ~D[2020-01-02]})
      end)

    assert {:ok, []} = result
  end
end
```

### ETF Format Notes

`.etf` files are binary Erlang External Term Format. They are not human-readable
but are safe to commit to version control. The files are deterministic for the same
input data and typically small (a few KB for a typical API response).

Advantages over JSON for this use case:
- Preserves Elixir structs, atoms, tuples, and DateTimes without extra serialization logic
- Records the exact return value of the function, including error tuples like `{:error, :rate_limited}`
- No schema needed — any Elixir term can be recorded

Limitation: `.etf` files are not cross-node portable between different Erlang/OTP
versions. Regenerate cassettes after major OTP upgrades.

---

## 3. Two-Layer Architecture Summary

```
SexySpex BDD Spec
      |
      | calls via Phoenix.LiveViewTest / ConnTest
      v
LiveView / Controller
      |
      | calls
      v
DataSync Context
      |
      +--- GoogleAds.fetch_metrics/2 ------> Req HTTP call <------- ReqCassette (.json)
      +--- FacebookAds.fetch_metrics/2 ----> Req HTTP call <------- ReqCassette (.json)
      +--- QuickBooks.fetch_metrics/2 -----> Req HTTP call <------- ReqCassette (.json)
      +--- GoogleAnalytics.fetch_metrics/1 -> Tesla/google_gax call <- TestRecorder (.etf)
```

BDD specs test the full stack from the UI layer down. They do not invoke recording
tools directly — recording happens in lower-level ExUnit context tests that exercise
provider modules in isolation.

---

## 4. Integration with SexySpex BDD Specs

BDD specs live in `test/spex/` and use `Phoenix.LiveViewTest` / `Phoenix.ConnTest`.
They do not call provider modules directly, so they do not use cassettes directly.

For BDD specs that trigger data sync flows (e.g., "User triggers a manual sync for
Google Ads"), the sync runs synchronously in test mode (Oban is configured with
`testing: :manual` in `config/test.exs`). Use `Oban.Testing.perform_job/2` to execute
the worker inline, which then calls the provider module. The provider module's `req:`
option must be injectable for this to work with cassettes.

```elixir
# In a spex that tests the manual sync flow:
when_ "the user clicks Sync Now for their Google Ads integration", context do
  {:ok, view, _html} = live(context.conn, ~p"/integrations")
  view |> element("#sync-google-ads") |> render_click()
  {:ok, context}
end

then_ "the sync completes and a success message is shown", context do
  # Oban in :manual mode: drive the job execution
  assert_enqueued worker: MetricFlow.DataSync.SyncWorker,
                  args: %{integration_id: context.integration.id}

  # Execute the job — uses the cassette via the injected req
  Oban.Testing.perform_job(MetricFlow.DataSync.SyncWorker, %{
    integration_id: context.integration.id,
    req: Req.new(plug: cassette_plug("test/cassettes/google_ads/fetch_metrics.json"))
  })

  assert has_element?(context.view, "#sync-success-flash")
  :ok
end
```

For most BDD specs testing integration management UI (listing, connecting,
disconnecting), no HTTP recording is needed — these specs interact only with the
database-backed `Integrations` context, not the data provider HTTP calls.

---

## 5. Cassette Management Checklist

**Before committing new provider code:**

- [ ] Record initial cassettes against the real API with valid credentials
- [ ] Verify `Authorization` (and `developer-token` for Google Ads) headers are stripped
- [ ] Verify no access tokens appear in query params in Facebook Ads cassettes
- [ ] Confirm cassette files are under 1 MB (flag unexpectedly large payloads)
- [ ] Run `mix test` with cassettes in place to confirm replay works

**When an external API changes its response format:**

```bash
# Delete affected cassettes
rm test/cassettes/google_ads/fetch_metrics_date_range.json

# Re-record with real credentials
GOOGLE_ADS_ACCESS_TOKEN=... GOOGLE_ADS_DEVELOPER_TOKEN=... \
  mix test test/metric_flow/data_sync/providers/google_ads_test.exs
```

**In CI:**

The CI environment should not have real API credentials. Set cassette mode to
`:replay` via an environment variable to ensure tests fail loudly if a cassette
is missing rather than silently attempting network calls:

```elixir
# test/support/cassette_helpers.ex
defmodule MetricFlowTest.CassetteHelpers do
  @cassette_mode if System.get_env("CI"), do: :replay, else: :record

  def cassette_mode, do: @cassette_mode
end
```

**For TestRecorder in CI:**

Because TestRecorder uses `RERECORD` as its re-record flag and defaults to replay
when the file exists, no special CI configuration is needed. If a `.etf` file is
missing from the repository, the test will fail because `File.read!/1` raises
`File.Error` — which is the correct behavior.

---

## 6. What Is Not Covered

The following are explicitly out of scope based on the architecture decision:

- **Browser-based E2E tests** — Wallaby and Playwright are not used. LiveView
  interactions are tested via `Phoenix.LiveViewTest` without a browser.
- **Vega-Lite chart rendering** — Chart specs are validated server-side as JSON.
  The actual browser rendering by `vega-embed` is trusted to the upstream library.
- **CSS and responsive layout** — No visual regression tooling is in place.

Sources consulted during research:
- [ReqCassette on Hex.pm](https://hex.pm/packages/req_cassette)
- [ReqCassette GitHub (lostbean/req_cassette)](https://github.com/lostbean/req_cassette)
- [ReqCassette.Plug HexDocs v0.5.2](https://hexdocs.pm/req_cassette/ReqCassette.Plug.html)
- [ReqCassette Elixir Forum announcement](https://elixirforum.com/t/reqcassette-vcr-style-testing-for-req-with-async-support/72869)
- [ExVCR rejection rationale](../../../architecture/decisions/exvcr.md)
- [E2E Testing architecture decision](../../../architecture/decisions/e2e_testing.md)
