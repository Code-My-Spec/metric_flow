defmodule MetricFlow.Ai.LlmClientTest do
  use ExUnit.Case, async: true

  import ReqCassette

  alias MetricFlow.Ai.LlmClient

  @cassette_dir "test/cassettes/ai"
  @filter_headers [filter_request_headers: ["x-api-key", "authorization"]]

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
    test "returns ok tuple with structured insight data on success" do
      with_cassette "generate_insights", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        result =
          LlmClient.generate_insights(
            LlmClient.base_system_prompt(),
            "Analyze these correlations: sessions→revenue coefficient=0.85, optimal_lag=3 days",
            req_http_options: [plug: plug]
          )

        assert {:ok, data} = result
        assert is_map(data)
      end
    end

    test "returned data contains suggestions field" do
      with_cassette "generate_insights", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        {:ok, data} =
          LlmClient.generate_insights(
            LlmClient.base_system_prompt(),
            "Analyze these correlations: sessions→revenue coefficient=0.85, optimal_lag=3 days",
            req_http_options: [plug: plug]
          )

        assert Map.has_key?(data, "suggestions") or Map.has_key?(data, :suggestions)
      end
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
    test "returns ok tuple with a Vega-Lite spec map on success" do
      with_cassette "generate_vega_spec", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        result =
          LlmClient.generate_vega_spec(
            LlmClient.base_system_prompt(),
            "Create a bar chart showing revenue by month",
            req_http_options: [plug: plug]
          )

        assert {:ok, spec} = result
        assert is_map(spec)
      end
    end

    test "returned map contains required Vega-Lite fields" do
      with_cassette "generate_vega_spec", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        {:ok, spec} =
          LlmClient.generate_vega_spec(
            LlmClient.base_system_prompt(),
            "Create a bar chart showing revenue by month",
            req_http_options: [plug: plug]
          )

        assert Map.has_key?(spec, "$schema")
        assert Map.has_key?(spec, "mark")
        assert Map.has_key?(spec, "encoding")
      end
    end

    test "dollar-schema field points to a Vega-Lite v5 URL" do
      with_cassette "generate_vega_spec", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        {:ok, spec} =
          LlmClient.generate_vega_spec(
            LlmClient.base_system_prompt(),
            "Create a bar chart showing revenue by month",
            req_http_options: [plug: plug]
          )

        assert String.contains?(spec["$schema"], "vega-lite")
        assert String.contains?(spec["$schema"], "v5")
      end
    end
  end
end
