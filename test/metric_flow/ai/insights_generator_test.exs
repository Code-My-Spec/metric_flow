defmodule MetricFlow.Ai.InsightsGeneratorTest do
  use ExUnit.Case, async: true

  import ReqCassette

  alias MetricFlow.Ai.InsightsGenerator

  @cassette_dir "test/cassettes/ai"

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp correlation_data_with_multiple_results do
    %{
      results: [
        %{
          metric_name: "sessions",
          goal_metric_name: "revenue",
          coefficient: 0.85,
          optimal_lag: 3
        },
        %{
          metric_name: "ad_spend",
          goal_metric_name: "revenue",
          coefficient: 0.72,
          optimal_lag: 7
        }
      ],
      data_window: %{
        start_date: ~D[2025-11-01],
        end_date: ~D[2026-01-31]
      }
    }
  end

  defp correlation_data_with_single_result do
    %{
      results: [
        %{
          metric_name: "sessions",
          goal_metric_name: "revenue",
          coefficient: 0.91,
          optimal_lag: 1
        }
      ],
      data_window: %{
        start_date: ~D[2025-12-01],
        end_date: ~D[2026-01-31]
      }
    }
  end

  defp available_metric_names do
    ["sessions", "ad_spend", "pageviews", "revenue", "conversions"]
  end

  # ---------------------------------------------------------------------------
  # build_system_prompt/0 — pure function
  # ---------------------------------------------------------------------------

  describe "build_system_prompt/0" do
    test "includes base marketing analytics context" do
      prompt = InsightsGenerator.build_system_prompt()

      assert String.downcase(prompt) =~ ~r/marketing|analytics|metric/
    end

    test "includes task-specific insight instructions" do
      prompt = InsightsGenerator.build_system_prompt()

      assert String.downcase(prompt) =~ ~r/insight|correlation|recommendation|suggest/
    end

    test "returns a non-empty string" do
      prompt = InsightsGenerator.build_system_prompt()

      assert is_binary(prompt)
      assert String.length(prompt) > 20
    end
  end

  # ---------------------------------------------------------------------------
  # build_user_content/2 — pure function
  # ---------------------------------------------------------------------------

  describe "build_user_content/2" do
    test "includes metric names from correlation results" do
      content = InsightsGenerator.build_user_content(
        correlation_data_with_multiple_results(),
        available_metric_names()
      )

      assert String.contains?(content, "sessions")
      assert String.contains?(content, "ad_spend")
    end

    test "includes correlation coefficients" do
      content = InsightsGenerator.build_user_content(
        correlation_data_with_multiple_results(),
        available_metric_names()
      )

      assert String.contains?(content, "0.85")
      assert String.contains?(content, "0.72")
    end

    test "includes optimal lag values" do
      content = InsightsGenerator.build_user_content(
        correlation_data_with_multiple_results(),
        available_metric_names()
      )

      assert String.contains?(content, "3")
      assert String.contains?(content, "7")
    end

    test "includes data window dates" do
      content = InsightsGenerator.build_user_content(
        correlation_data_with_multiple_results(),
        available_metric_names()
      )

      assert String.contains?(content, "2025-11-01")
      assert String.contains?(content, "2026-01-31")
    end

    test "includes available metric names" do
      content = InsightsGenerator.build_user_content(
        correlation_data_with_multiple_results(),
        ["sessions", "revenue", "pageviews"]
      )

      assert String.contains?(content, "sessions")
      assert String.contains?(content, "revenue")
      assert String.contains?(content, "pageviews")
    end

    test "handles single correlation result" do
      content = InsightsGenerator.build_user_content(
        correlation_data_with_single_result(),
        available_metric_names()
      )

      assert String.contains?(content, "sessions")
      assert String.contains?(content, "0.91")
    end
  end

  # ---------------------------------------------------------------------------
  # generate/3 — integration via ReqCassette
  # ---------------------------------------------------------------------------

  describe "generate/3" do
    test "returns ok tuple with list of insight attribute maps on success" do
      with_cassette "insights_generator_success", [cassette_dir: @cassette_dir], fn plug ->
        result = InsightsGenerator.generate(
          correlation_data_with_multiple_results(),
          available_metric_names(),
          req_http_options: [plug: plug]
        )

        assert {:ok, insights} = result
        assert is_list(insights)
        assert insights != []
      end
    end

    test "each map in the list contains required insight field: content" do
      with_cassette "insights_generator_success", [cassette_dir: @cassette_dir], fn plug ->
        {:ok, insights} = InsightsGenerator.generate(
          correlation_data_with_multiple_results(),
          available_metric_names(),
          req_http_options: [plug: plug]
        )

        assert Enum.all?(insights, fn insight ->
          Map.has_key?(insight, :content) and is_binary(insight.content) and
            String.length(insight.content) > 0
        end)
      end
    end

    test "each map in the list contains required insight field: summary" do
      with_cassette "insights_generator_success", [cassette_dir: @cassette_dir], fn plug ->
        {:ok, insights} = InsightsGenerator.generate(
          correlation_data_with_multiple_results(),
          available_metric_names(),
          req_http_options: [plug: plug]
        )

        assert Enum.all?(insights, &Map.has_key?(&1, :summary))
      end
    end

    test "each map in the list contains required insight field: suggestion_type" do
      with_cassette "insights_generator_success", [cassette_dir: @cassette_dir], fn plug ->
        {:ok, insights} = InsightsGenerator.generate(
          correlation_data_with_multiple_results(),
          available_metric_names(),
          req_http_options: [plug: plug]
        )

        assert Enum.all?(insights, &Map.has_key?(&1, :suggestion_type))
      end
    end

    test "each map in the list contains required insight field: confidence" do
      with_cassette "insights_generator_success", [cassette_dir: @cassette_dir], fn plug ->
        {:ok, insights} = InsightsGenerator.generate(
          correlation_data_with_multiple_results(),
          available_metric_names(),
          req_http_options: [plug: plug]
        )

        assert Enum.all?(insights, fn insight ->
          Map.has_key?(insight, :confidence) and is_float(insight.confidence)
        end)
      end
    end

    test "handles single correlation result" do
      with_cassette "insights_generator_single", [cassette_dir: @cassette_dir], fn plug ->
        result = InsightsGenerator.generate(
          correlation_data_with_single_result(),
          available_metric_names(),
          req_http_options: [plug: plug]
        )

        assert {:ok, insights} = result
        assert is_list(insights)
      end
    end

    test "returns empty list when LLM returns empty suggestions" do
      with_cassette "insights_generator_empty", [cassette_dir: @cassette_dir, match_requests_on: [:method, :uri]], fn plug ->
        {:ok, insights} = InsightsGenerator.generate(
          correlation_data_with_multiple_results(),
          available_metric_names(),
          req_http_options: [plug: plug]
        )

        assert insights == []
      end
    end

    test "returns error tuple when API call fails" do
      with_cassette "insights_generator_error", [cassette_dir: @cassette_dir, match_requests_on: [:method, :uri]], fn plug ->
        result = InsightsGenerator.generate(
          correlation_data_with_multiple_results(),
          available_metric_names(),
          req_http_options: [plug: plug]
        )

        assert {:error, _reason} = result
      end
    end
  end
end
