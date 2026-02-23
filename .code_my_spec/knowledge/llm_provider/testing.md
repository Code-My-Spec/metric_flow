# Testing LLM Calls in MetricFlow

ReqLLM is built on Finch for HTTP. ReqCassette is a VCR-style record-and-replay library
specifically designed for Req-compatible HTTP stacks, and it integrates directly with ReqLLM.
No live API calls are made in CI.

## Two Testing Approaches

| Approach | Best For | Key Benefit |
|---|---|---|
| ReqCassette | Integration tests of `LlmClient`, `InsightsGenerator`, `ReportGenerator` | Real API shapes; cassettes survive model changes automatically |
| `Req.Test` mock | Unit tests of modules that call `LlmClient` | No cassette files; fully in-memory |

## Approach 1: ReqCassette

### Dependency

```elixir
# mix.exs
{:req_cassette, "~> 0.5", only: :test}
```

### How It Works

On the first test run (recording mode), ReqCassette makes the actual Anthropic API call and
saves the response to a JSON cassette file under `test/cassettes/`. Subsequent runs replay
from the file — no network, no API key needed in CI.

### Basic Test

```elixir
defmodule MetricFlow.Ai.InsightsGeneratorTest do
  use ExUnit.Case, async: true

  alias MetricFlow.Ai.InsightsGenerator

  test "generates a structured insight from correlation data" do
    correlation_data = %{
      metric_a: "google_analytics:sessions",
      metric_b: "google_ads:spend",
      correlation: 0.82,
      period: "2025-10-01/2025-12-31"
    }

    ReqCassette.with_cassette("insights_generator/basic_insight", fn ->
      assert {:ok, insight} = InsightsGenerator.generate(correlation_data)

      assert is_binary(insight.title)
      assert is_binary(insight.summary)
      assert insight.significance in [:high, :medium, :low]
      assert is_binary(insight.recommended_action)
      assert is_float(insight.confidence)
      assert insight.confidence >= 0.0 and insight.confidence <= 1.0
    end)
  end
end
```

The cassette file is written to `test/cassettes/insights_generator/basic_insight.json` on the
first real run.

### Cassette Storage Convention

```
test/cassettes/
  insights_generator/
    basic_insight.json
  report_generator/
    bar_chart_spec.json
    line_chart_spec.json
  llm_client/
    stream_text_basic.json
```

Commit cassettes to version control. They are plain JSON and diff cleanly.

### Recording Mode

To record a new cassette (or re-record after a prompt change), set the environment variable:

```sh
REQCASSETTE_MODE=record mix test test/metric_flow/ai/insights_generator_test.exs
```

This requires a real `ANTHROPIC_API_KEY` in the environment. After recording, remove the env
var — subsequent runs replay without a key.

### ReqCassette Streaming Limitation

ReqCassette records full response bodies. For streaming responses (SSE), it captures the
complete stream and replays it as a single response body. This means streaming tests via
cassette confirm that the API response shape is correct but do not test incremental token
delivery timing.

Test the LiveView token-delivery path separately using Approach 2 below.

## Approach 2: Req.Test Mock

For testing LiveView `handle_info` behaviour and modules that call `LlmClient` functions,
use `Req.Test` to return a canned response without cassette files.

This is the right approach for:
- Testing `ChatLive` token accumulation logic
- Testing error handling (API errors, network timeouts)
- Testing Oban worker retry behaviour

### Mock Setup in test/support

```elixir
# test/support/llm_mock.ex
defmodule MetricFlowTest.LlmMock do
  @moduledoc """
  Helpers for mocking ReqLLM calls in LiveView and worker tests.
  """

  @doc """
  Stubs the next ReqLLM call to return a static text response.
  """
  def stub_generate_text(text \\ "Mocked AI response") do
    Req.Test.stub(ReqLLM, fn conn ->
      Req.Test.json(conn, %{
        "content" => [%{"type" => "text", "text" => text}],
        "usage" => %{"input_tokens" => 100, "output_tokens" => 20},
        "stop_reason" => "end_turn"
      })
    end)
  end

  @doc """
  Stubs the next generate_object call to return a specific map.
  """
  def stub_generate_object(object_map) do
    Req.Test.stub(ReqLLM, fn conn ->
      Req.Test.json(conn, %{
        "content" => [%{
          "type" => "tool_use",
          "name" => "structured_output",
          "input" => object_map
        }],
        "usage" => %{"input_tokens" => 150, "output_tokens" => 80},
        "stop_reason" => "tool_use"
      })
    end)
  end

  @doc """
  Stubs the next ReqLLM call to return an API error.
  """
  def stub_api_error(status \\ 529) do
    Req.Test.stub(ReqLLM, fn conn ->
      conn
      |> Plug.Conn.put_status(status)
      |> Req.Test.json(%{"error" => %{"type" => "overloaded_error", "message" => "API overloaded"}})
    end)
  end
end
```

### Using the Mock in LiveView Tests

```elixir
defmodule MetricFlowWeb.ChatLiveTest do
  use MetricFlowWeb.ConnCase, async: false  # Req.Test stubs are process-local

  import Phoenix.LiveViewTest
  import MetricFlowTest.LlmMock

  setup :register_and_log_in_user

  test "chat message streams tokens and updates the display", %{conn: conn} do
    stub_generate_text("Your sessions increased 12% last month.")

    {:ok, lv, _html} = live(conn, ~p"/chat")

    lv
    |> form("#chat-form", %{message: "How are my sessions trending?"})
    |> render_submit()

    # The response arrives via handle_info after the task completes
    assert render(lv) =~ "sessions increased 12%"
  end

  test "displays an error message when the API fails", %{conn: conn} do
    stub_api_error(529)

    {:ok, lv, _html} = live(conn, ~p"/chat")

    lv
    |> form("#chat-form", %{message: "Analyse my revenue"})
    |> render_submit()

    assert render(lv) =~ "AI response failed"
  end
end
```

### Oban Worker Test

```elixir
defmodule MetricFlow.Ai.Workers.InsightsWorkerTest do
  use MetricFlow.DataCase, async: false
  use Oban.Testing, repo: MetricFlow.Infrastructure.Repo

  import MetricFlowTest.LlmMock

  test "saves generated insight on success" do
    stub_generate_object(%{
      "title" => "Ad spend efficiency dropped",
      "summary" => "CPA rose 18% in January.",
      "significance" => "high",
      "recommended_action" => "Review Facebook ad sets.",
      "confidence" => 0.87
    })

    correlation = insert(:correlation, results: %{correlation: 0.82})

    assert :ok = perform_job(MetricFlow.Ai.Workers.InsightsWorker, %{
      "correlation_id" => correlation.id
    })

    insight = MetricFlow.Ai.get_insight_by_correlation!(correlation.id)
    assert insight.significance == :high
  end
end
```

## config/test.exs Additions

Ensure Oban is in manual testing mode (already set) and add a placeholder API key so ReqLLM
does not attempt to load from environment during test setup:

```elixir
# config/test.exs — add to existing test config
config :req_llm, anthropic_api_key: "test-key-not-used"
```

## CI Checklist

- Cassette files are committed to `test/cassettes/` and checked in CI
- `ANTHROPIC_API_KEY` is NOT required in CI environment variables
- To update a cassette after a prompt or schema change: run locally with
  `REQCASSETTE_MODE=record mix test <path>`, review the diff, commit the new cassette
