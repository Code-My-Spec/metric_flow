defmodule MetricFlowTest.ReportGeneratorStub do
  @moduledoc """
  Named `:command_runner` scripted responses for the `/app/reports/generate`
  flow (`MetricFlow.Ai.ReportGenerator` / `LlmClient.generate_vega_spec/3`),
  replacing the Anthropic-API-shaped `report_generator_success` cassette
  recorded for the pre-Alloy ReqLLM pipeline.
  """

  alias MetricFlowTest.ClaudeCodeStub

  @doc "A bar chart of revenue over time."
  def generate_revenue_bar_chart do
    ClaudeCodeStub.tool_call("emit_vega_spec", %{"spec" => revenue_bar_chart_spec()})
  end

  @doc "A bar chart of weekly revenue — the 'refine it' response."
  def generate_weekly_revenue_bar_chart do
    ClaudeCodeStub.tool_call(
      "emit_vega_spec",
      %{"spec" => weekly_revenue_bar_chart_spec()},
      call_id: "call_2"
    )
  end

  @doc "A two-turn conversation: generate, then refine."
  def generate_then_refine do
    ClaudeCodeStub.sequence([
      ClaudeCodeStub.completed_tool_call(
        "emit_vega_spec",
        %{"spec" => revenue_bar_chart_spec()},
        completion_text: "Here's a bar chart of revenue over time."
      ),
      ClaudeCodeStub.completed_tool_call(
        "emit_vega_spec",
        %{"spec" => weekly_revenue_bar_chart_spec()},
        call_id: "call_2",
        completion_text: "Here's the revenue broken down by week instead."
      )
    ])
  end

  defp revenue_bar_chart_spec do
    %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "mark" => "bar",
      "encoding" => %{
        "x" => %{"field" => "date", "type" => "temporal", "title" => "Date"},
        "y" => %{"field" => "revenue", "type" => "quantitative", "title" => "Revenue"}
      },
      "title" => "Revenue Over Time"
    }
  end

  defp weekly_revenue_bar_chart_spec do
    %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "mark" => "bar",
      "encoding" => %{
        "x" => %{"field" => "week", "type" => "temporal", "title" => "Week"},
        "y" => %{"field" => "revenue", "type" => "quantitative", "title" => "Revenue"}
      },
      "title" => "Weekly Revenue"
    }
  end
end
