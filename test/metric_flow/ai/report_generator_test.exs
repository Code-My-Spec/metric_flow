defmodule MetricFlow.Ai.ReportGeneratorTest do
  use ExUnit.Case, async: true

  import ReqCassette

  alias MetricFlow.Ai.ReportGenerator

  @cassette_dir "test/cassettes/ai"
  @filter_headers [filter_request_headers: ["x-api-key", "authorization"]]

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp user_prompt, do: "Show me a bar chart of revenue over time"

  defp metric_names, do: ["revenue", "sessions", "ad_spend"]

  # ---------------------------------------------------------------------------
  # build_system_prompt/0 — pure function
  # ---------------------------------------------------------------------------

  describe "build_system_prompt/0" do
    test "includes base marketing analytics context" do
      prompt = ReportGenerator.build_system_prompt()

      assert String.downcase(prompt) =~ ~r/marketing|analytics|metric/
    end

    test "includes Vega-Lite task-specific instructions" do
      prompt = ReportGenerator.build_system_prompt()

      assert String.downcase(prompt) =~ ~r/vega|chart|visualization|spec/
    end

    test "returns a non-empty string" do
      prompt = ReportGenerator.build_system_prompt()

      assert is_binary(prompt)
      assert String.length(prompt) > 20
    end
  end

  # ---------------------------------------------------------------------------
  # build_user_content/2 — pure function
  # ---------------------------------------------------------------------------

  describe "build_user_content/2" do
    test "includes the user prompt" do
      content = ReportGenerator.build_user_content(user_prompt(), metric_names())

      assert String.contains?(content, user_prompt())
    end

    test "includes available metric names" do
      content = ReportGenerator.build_user_content(user_prompt(), metric_names())

      assert String.contains?(content, "revenue")
      assert String.contains?(content, "sessions")
      assert String.contains?(content, "ad_spend")
    end

    test "handles empty metric names list" do
      content = ReportGenerator.build_user_content(user_prompt(), [])

      assert is_binary(content)
      assert String.contains?(content, user_prompt())
    end
  end

  # ---------------------------------------------------------------------------
  # generate/3 — integration via ReqCassette
  # ---------------------------------------------------------------------------

  describe "generate/3" do
    test "returns ok tuple with Vega-Lite spec map on success" do
      with_cassette "report_generator_success", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        result = ReportGenerator.generate(
          user_prompt(),
          metric_names(),
          req_http_options: [plug: plug]
        )

        assert {:ok, spec} = result
        assert is_map(spec)
      end
    end

    test "returned map contains dollar-schema key" do
      with_cassette "report_generator_success", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        {:ok, spec} = ReportGenerator.generate(
          user_prompt(),
          metric_names(),
          req_http_options: [plug: plug]
        )

        assert Map.has_key?(spec, "$schema")
      end
    end

    test "returned map contains mark key" do
      with_cassette "report_generator_success", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        {:ok, spec} = ReportGenerator.generate(
          user_prompt(),
          metric_names(),
          req_http_options: [plug: plug]
        )

        assert Map.has_key?(spec, "mark")
      end
    end

    test "returned map contains encoding key" do
      with_cassette "report_generator_success", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        {:ok, spec} = ReportGenerator.generate(
          user_prompt(),
          metric_names(),
          req_http_options: [plug: plug]
        )

        assert Map.has_key?(spec, "encoding")
      end
    end

    test "dollar-schema field points to a Vega-Lite v5 URL" do
      with_cassette "report_generator_success", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        {:ok, spec} = ReportGenerator.generate(
          user_prompt(),
          metric_names(),
          req_http_options: [plug: plug]
        )

        assert String.contains?(spec["$schema"], "vega-lite")
        assert String.contains?(spec["$schema"], "v5")
      end
    end

    test "returns error tuple when API call fails" do
      with_cassette "report_generator_error", [cassette_dir: @cassette_dir, match_requests_on: [:method, :uri]] ++ @filter_headers, fn plug ->
        result = ReportGenerator.generate(
          user_prompt(),
          metric_names(),
          req_http_options: [plug: plug]
        )

        assert {:error, _reason} = result
      end
    end
  end
end
