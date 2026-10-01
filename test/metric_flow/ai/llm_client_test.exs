defmodule MetricFlow.Ai.LlmClientTest do
  use ExUnit.Case, async: true

  import ReqCassette

  alias MetricFlow.Ai.LlmClient
  alias MetricFlowTest.ClaudeCodeStub

  @cassette_dir "test/cassettes/ai"
  # Same options `ai_test.exs` already uses for its LLM cassettes, and for the
  # same two reasons.
  #
  # `mode: :replay` because ReqCassette's default is `:record` — "record if the
  # cassette or the interaction is missing, otherwise replay" — so a miss reaches
  # api.anthropic.com for real and writes whatever it answers into the cassette.
  # Measured: these tests failed with "Your credit balance is too low to access
  # the Anthropic API", which is a unit test reporting a billing problem, and a
  # `mix test` run appended 714 lines across five cassettes.
  #
  # `match_requests_on: [:method, :uri]` because the default includes `:body`,
  # and the body carries the system prompt. Both prompts have been edited since
  # these were recorded (report 829 → 1354 characters, insights 909 → 1497), so
  # every prompt refinement silently invalidated every recording. The prompts are
  # asserted directly by the `build_system_prompt/0` tests in these same files,
  # so matching on them here adds no coverage — it only couples an editable
  # string to a paid re-recording.
  @filter_headers [
    mode: :replay,
    match_requests_on: [:method, :uri],
    filter_request_headers: ["x-api-key", "authorization"]
  ]

  # ---------------------------------------------------------------------------
  # chat_model/0
  # ---------------------------------------------------------------------------

  describe "chat_model/0" do
    test "returns the Sonnet model string" do
      assert LlmClient.chat_model() == "anthropic:claude-sonnet-4-5"
    end

    test "return value is consistent across multiple calls" do
      assert LlmClient.chat_model() == LlmClient.chat_model()
    end

    test "returned string contains the anthropic provider prefix" do
      assert String.starts_with?(LlmClient.chat_model(), "anthropic:")
    end
  end

  # ---------------------------------------------------------------------------
  # insights_model/0
  # ---------------------------------------------------------------------------

  describe "insights_model/0" do
    test "returns the Haiku model string" do
      assert LlmClient.insights_model() == "anthropic:claude-haiku-4-5"
    end

    test "return value is consistent across multiple calls" do
      assert LlmClient.insights_model() == LlmClient.insights_model()
    end

    test "insights model is different from chat model" do
      refute LlmClient.insights_model() == LlmClient.chat_model()
    end
  end

  # ---------------------------------------------------------------------------
  # base_system_prompt/0
  # ---------------------------------------------------------------------------

  describe "base_system_prompt/0" do
    test "returns a non-empty string" do
      prompt = LlmClient.base_system_prompt()

      assert is_binary(prompt)
      assert String.length(prompt) > 0
    end

    test "contains marketing analytics context" do
      prompt = LlmClient.base_system_prompt()

      assert String.downcase(prompt) =~ ~r/marketing|analytics|metric/
    end

    test "return value is consistent across multiple calls" do
      assert LlmClient.base_system_prompt() == LlmClient.base_system_prompt()
    end

    test "prompt is substantive content" do
      assert String.length(LlmClient.base_system_prompt()) > 20
    end
  end

  # ---------------------------------------------------------------------------
  # generate_insights/3
  # ---------------------------------------------------------------------------

  describe "generate_insights/3" do
    @insight %{
      "summary" => "Sessions strongly predict revenue",
      "content" => "Sessions correlate with revenue at 0.85; consider increasing acquisition spend.",
      "suggestion_type" => "budget_increase",
      "confidence" => 0.85
    }

    test "returns ok tuple with structured insight data on success" do
      runner = ClaudeCodeStub.tool_call("emit_insights", %{"insights" => [@insight]})

      result =
        LlmClient.generate_insights(
          LlmClient.base_system_prompt(),
          "Analyze these correlations: sessions→revenue coefficient=0.85, optimal_lag=3 days",
          command_runner: runner
        )

      assert {:ok, data} = result
      assert is_map(data)
    end

    # Was "contains suggestions field". `@insight_schema` requires a top-level
    # `insights` key — a list of {summary, content, suggestion_type, confidence}
    # — and `InsightsGenerator` reads `"insights"`. `suggestions` was the key the
    # first schema used; nothing has produced it since.
    test "returned data contains insights field" do
      runner = ClaudeCodeStub.tool_call("emit_insights", %{"insights" => [@insight]})

      {:ok, data} =
        LlmClient.generate_insights(
          LlmClient.base_system_prompt(),
          "Analyze these correlations: sessions→revenue coefficient=0.85, optimal_lag=3 days",
          command_runner: runner
        )

      assert Map.has_key?(data, "insights") or Map.has_key?(data, :insights)
    end
  end

  # ---------------------------------------------------------------------------
  # stream_chat/3
  # ---------------------------------------------------------------------------

  describe "stream_chat/3" do
    test "returns ok tuple with StreamResponse on success" do
      with_cassette "stream_chat", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        result =
          LlmClient.stream_chat(
            LlmClient.base_system_prompt(),
            "What metrics are driving revenue growth?",
            req_http_options: [plug: plug]
          )

        assert {:ok, response} = result
        assert is_struct(response, ReqLLM.StreamResponse)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # generate_vega_spec/3
  # ---------------------------------------------------------------------------

  describe "generate_vega_spec/3" do
    @vega_spec %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "mark" => "bar",
      "encoding" => %{
        "x" => %{"field" => "month", "type" => "temporal"},
        "y" => %{"field" => "revenue", "type" => "quantitative"}
      }
    }

    test "returns ok tuple with a Vega-Lite spec map on success" do
      runner = ClaudeCodeStub.tool_call("emit_vega_spec", %{"spec" => @vega_spec})

      result =
        LlmClient.generate_vega_spec(
          LlmClient.base_system_prompt(),
          "Create a bar chart showing revenue by month",
          command_runner: runner
        )

      assert {:ok, spec} = result
      assert is_map(spec)
    end

    test "returned map contains required Vega-Lite fields" do
      runner = ClaudeCodeStub.tool_call("emit_vega_spec", %{"spec" => @vega_spec})

      {:ok, spec} =
        LlmClient.generate_vega_spec(
          LlmClient.base_system_prompt(),
          "Create a bar chart showing revenue by month",
          command_runner: runner
        )

      assert Map.has_key?(spec, "$schema")
      assert Map.has_key?(spec, "mark")
      assert Map.has_key?(spec, "encoding")
    end

    test "dollar-schema field points to a Vega-Lite v5 URL" do
      runner = ClaudeCodeStub.tool_call("emit_vega_spec", %{"spec" => @vega_spec})

      {:ok, spec} =
        LlmClient.generate_vega_spec(
          LlmClient.base_system_prompt(),
          "Create a bar chart showing revenue by month",
          command_runner: runner
        )

      assert String.contains?(spec["$schema"], "vega-lite")
      assert String.contains?(spec["$schema"], "v5")
    end
  end
end
