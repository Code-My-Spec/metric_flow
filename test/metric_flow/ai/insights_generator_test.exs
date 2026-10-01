defmodule MetricFlow.Ai.InsightsGeneratorTest do
  use ExUnit.Case, async: true

  alias MetricFlow.Ai.InsightsGenerator
  alias MetricFlowTest.ClaudeCodeStub

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

  defp insight(overrides \\ %{}) do
    Map.merge(
      %{
        "summary" => "Sessions strongly predict revenue",
        "content" => "Sessions correlate with revenue at 0.85; consider increasing acquisition spend.",
        "suggestion_type" => "budget_increase",
        "confidence" => 0.85
      },
      overrides
    )
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
  # generate/3 — integration via Alloy's ClaudeCode command_runner stub
  # ---------------------------------------------------------------------------

  describe "generate/3" do
    test "returns ok tuple with list of insight attribute maps on success" do
      runner = ClaudeCodeStub.tool_call("emit_insights", %{"insights" => [insight()]})

      result =
        InsightsGenerator.generate(
          correlation_data_with_multiple_results(),
          available_metric_names(),
          command_runner: runner
        )

      assert {:ok, insights} = result
      assert is_list(insights)
      assert insights != []
    end

    test "each map in the list contains required insight field: content" do
      runner = ClaudeCodeStub.tool_call("emit_insights", %{"insights" => [insight()]})

      {:ok, insights} =
        InsightsGenerator.generate(
          correlation_data_with_multiple_results(),
          available_metric_names(),
          command_runner: runner
        )

      assert insights != []

      assert Enum.all?(insights, fn insight ->
               Map.has_key?(insight, :content) and is_binary(insight.content) and
                 String.length(insight.content) > 0
             end)
    end

    test "each map in the list contains required insight field: summary" do
      runner = ClaudeCodeStub.tool_call("emit_insights", %{"insights" => [insight()]})

      {:ok, insights} =
        InsightsGenerator.generate(
          correlation_data_with_multiple_results(),
          available_metric_names(),
          command_runner: runner
        )

      assert insights != []
      assert Enum.all?(insights, &Map.has_key?(&1, :summary))
    end

    test "each map in the list contains required insight field: suggestion_type" do
      runner = ClaudeCodeStub.tool_call("emit_insights", %{"insights" => [insight()]})

      {:ok, insights} =
        InsightsGenerator.generate(
          correlation_data_with_multiple_results(),
          available_metric_names(),
          command_runner: runner
        )

      assert insights != []
      assert Enum.all?(insights, &Map.has_key?(&1, :suggestion_type))
    end

    test "each map in the list contains required insight field: confidence" do
      runner = ClaudeCodeStub.tool_call("emit_insights", %{"insights" => [insight()]})

      {:ok, insights} =
        InsightsGenerator.generate(
          correlation_data_with_multiple_results(),
          available_metric_names(),
          command_runner: runner
        )

      assert insights != []

      assert Enum.all?(insights, fn insight ->
               Map.has_key?(insight, :confidence) and is_float(insight.confidence)
             end)
    end

    test "handles single correlation result" do
      runner = ClaudeCodeStub.tool_call("emit_insights", %{"insights" => [insight(%{"summary" => "Sessions predict revenue"})]})

      result =
        InsightsGenerator.generate(
          correlation_data_with_single_result(),
          available_metric_names(),
          command_runner: runner
        )

      assert {:ok, insights} = result
      assert is_list(insights)
    end

    test "returns empty list when LLM returns empty suggestions" do
      runner = ClaudeCodeStub.tool_call("emit_insights", %{"insights" => []})

      {:ok, insights} =
        InsightsGenerator.generate(
          correlation_data_with_multiple_results(),
          available_metric_names(),
          command_runner: runner
        )

      assert insights == []
    end

    test "returns error tuple when API call fails" do
      runner = ClaudeCodeStub.error("simulated provider failure")

      result =
        InsightsGenerator.generate(
          correlation_data_with_multiple_results(),
          available_metric_names(),
          command_runner: runner
        )

      assert {:error, _reason} = result
    end
  end
end
