defmodule MetricFlowTest.VizChatStub do
  @moduledoc """
  Named `:command_runner` scripted responses for the visualization chat tool
  loop (`MetricFlow.Ai.VizChat`), replacing the Anthropic-API-shaped cassettes
  recorded for the pre-Alloy ReqLLM pipeline (`test/cassettes/ai/visualization_chat_generate.json`
  and `visualization_chat_unresolvable_metric.json`). Each preset calls
  `update_spec` with the same spec those cassettes carried, JSON-encoded into
  the `vega_lite_json` string field `MetricFlow.Ai.VizTools.UpdateSpec` expects.
  """

  alias MetricFlowTest.ClaudeCodeStub

  @doc "Initial chart generation: a line chart of impressions over time."
  def generate_initial do
    ClaudeCodeStub.tool_call(
      "update_spec",
      %{"vega_lite_json" => Jason.encode!(line_chart_spec())},
      text: "I'll create a line chart showing impressions over time."
    )
  end

  @doc "Follow-up refinement: adds clicks as a second layered series."
  def generate_followup do
    ClaudeCodeStub.tool_call(
      "update_spec",
      %{"vega_lite_json" => Jason.encode!(layered_chart_spec())},
      text: "I've added clicks as a second series in a layered chart.",
      call_id: "call_2"
    )
  end

  @doc "A two-turn conversation: generate, then refine."
  def generate_then_followup do
    ClaudeCodeStub.sequence([
      ClaudeCodeStub.completed_tool_call(
        "update_spec",
        %{"vega_lite_json" => Jason.encode!(line_chart_spec())},
        text: "I'll create a line chart showing impressions over time.",
        completion_text: "I've created the line chart showing impressions over time."
      ),
      ClaudeCodeStub.completed_tool_call(
        "update_spec",
        %{"vega_lite_json" => Jason.encode!(layered_chart_spec())},
        text: "I've added clicks as a second series in a layered chart.",
        call_id: "call_2",
        completion_text: "Done — clicks are now layered alongside impressions."
      )
    ])
  end

  @doc "The model names a metric that doesn't exist for this account."
  def unresolvable_metric do
    ClaudeCodeStub.tool_call(
      "update_spec",
      %{"vega_lite_json" => Jason.encode!(unresolvable_metric_spec())},
      text: "I'll create a chart for the discontinued_metric field."
    )
  end

  defp line_chart_spec do
    %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "data" => %{"name" => "impressions"},
      "mark" => "line",
      "encoding" => %{
        "x" => %{"field" => "date", "type" => "temporal", "title" => "Date"},
        "y" => %{"field" => "value", "type" => "quantitative", "title" => "Impressions"}
      },
      "title" => "Impressions Over Time",
      "width" => "container",
      "height" => 400
    }
  end

  defp layered_chart_spec do
    %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "title" => "Impressions & Clicks Over Time",
      "width" => "container",
      "height" => 400,
      "layer" => [
        %{
          "data" => %{"name" => "impressions"},
          "mark" => %{"type" => "line", "point" => true},
          "encoding" => %{
            "x" => %{"field" => "date", "type" => "temporal"},
            "y" => %{"field" => "value", "type" => "quantitative"},
            "color" => %{"datum" => "impressions"}
          }
        },
        %{
          "data" => %{"name" => "clicks"},
          "mark" => %{"type" => "line", "point" => true},
          "encoding" => %{
            "x" => %{"field" => "date", "type" => "temporal"},
            "y" => %{"field" => "value", "type" => "quantitative"},
            "color" => %{"datum" => "clicks"}
          }
        }
      ]
    }
  end

  defp unresolvable_metric_spec do
    %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "data" => %{"name" => "discontinued_metric"},
      "mark" => "line",
      "encoding" => %{
        "x" => %{"field" => "date", "type" => "temporal", "title" => "Date"},
        "y" => %{"field" => "value", "type" => "quantitative", "title" => "Discontinued Metric"}
      },
      "title" => "Discontinued Metric Over Time",
      "width" => "container",
      "height" => 400
    }
  end
end
