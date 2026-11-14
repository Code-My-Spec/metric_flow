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

  @doc """
  Initial chart generation: a headline stat tile followed by a line chart,
  both over impressions -- two widgets from one request (Journey 6, Story
  74 rule 2), without introducing a second metric no other caller of this
  preset has synced. `extract_spec/1`'s existing reverse-and-find-first
  still lands on the line chart (the last `update_spec` call), so every
  single-widget caller of this preset keeps seeing exactly the same final
  spec and text as before.

  Note (QA journey 6, 2026-11-14): this two-sequential-`update_spec`-calls
  shape is not what the deployed model actually does for a multi-widget
  request. Walked live, asked explicitly for "two separate widgets ...
  not one combined chart," the model replied it has no tool to create or
  manage separate dashboard elements, only `update_spec` for one spec --
  see `generate_multi_widget_combined/0` for the shape confirmed live.
  Kept as-is because the two single-widget tests below only care that the
  final spec/text is the line chart, which this still produces.
  """
  def generate_initial do
    ClaudeCodeStub.sequence([
      ClaudeCodeStub.tool_call(
        "update_spec",
        %{"vega_lite_json" => Jason.encode!(stat_tile_spec())},
        call_id: "call_1"
      ),
      ClaudeCodeStub.tool_call(
        "update_spec",
        %{"vega_lite_json" => Jason.encode!(line_chart_spec())},
        call_id: "call_2"
      ),
      ClaudeCodeStub.text("I'll create a line chart showing impressions over time.")
    ])
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

  @doc """
  Multi-widget request as the deployed model actually answers it: one
  `update_spec` call whose spec combines both requested views with a
  Vega-Lite `vconcat`, not two separate `update_spec` calls. Confirmed live
  (QA journey 6, 2026-11-14): sent "Add a headline stat of total clicks and
  a line chart of impressions over time" and, on an explicit follow-up
  asking for two independent widgets, the model said it has no tool for
  that -- only `update_spec`, which writes one spec. This preset reproduces
  that single combined-spec response so the journey test documents the
  real surface instead of the two-separate-calls shape `generate_initial/0`
  exercises on the backend path alone.
  """
  def generate_multi_widget_combined do
    ClaudeCodeStub.sequence(
      ClaudeCodeStub.completed_tool_call(
        "update_spec",
        %{"vega_lite_json" => Jason.encode!(combined_stat_and_line_spec())},
        completion_text:
          "The chart is created. It has two stacked views: a headline stat for total clicks and a line chart of impressions over time."
      )
    )
  end

  defp stat_tile_spec do
    %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "data" => %{"name" => "impressions"},
      "mark" => "text",
      "encoding" => %{
        "text" => %{"field" => "value", "type" => "quantitative", "aggregate" => "sum"}
      },
      "title" => "Total Impressions",
      "width" => "container",
      "height" => 100
    }
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

  defp combined_stat_and_line_spec do
    %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "vconcat" => [
        %{
          "data" => %{"name" => "clicks"},
          "mark" => %{
            "type" => "text",
            "align" => "center",
            "baseline" => "middle",
            "fontSize" => 48,
            "fontWeight" => "bold"
          },
          "encoding" => %{
            "text" => %{
              "field" => "value",
              "type" => "quantitative",
              "aggregate" => "sum",
              "format" => ",.0f"
            }
          },
          "title" => "Total Clicks",
          "width" => "container",
          "height" => 80
        },
        %{
          "data" => %{"name" => "impressions"},
          "mark" => %{"type" => "line", "point" => true, "tooltip" => true},
          "encoding" => %{
            "x" => %{"field" => "date", "type" => "temporal", "title" => "Date"},
            "y" => %{"field" => "value", "type" => "quantitative", "title" => "Impressions"}
          },
          "title" => "Impressions Over Time",
          "width" => "container",
          "height" => 300
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
