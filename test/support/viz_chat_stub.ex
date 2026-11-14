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
  shape tests the backend mechanism in isolation -- it is not what the
  deployed model actually does for a multi-widget request. Walked live,
  the model combined both requested views into one `vconcat` spec instead,
  and on an explicit follow-up said it has no tool to create or manage
  separate dashboard elements. See `journey_result.md` Journey 6 and
  `test/journeys/build_a_screen_with_the_agent_test.exs`'s prompt-capture
  test, which asserts on the real prompt/tool text instead of a double.
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

  @doc """
  Refinement that changes an existing widget's chart type (QA journey 6,
  2026-11-14): the real model, asked to change "Impressions Over Time"
  from a line chart to an area chart, can only call `update_spec` with a
  brand new spec -- its `input_schema` has no id/index/target parameter
  to identify an existing widget by. The one signal it carries over is
  the spec's own `"title"`, which stays "Impressions Over Time" here,
  matching what a real model naming the same widget back would send.
  """
  def refine_to_area_chart do
    ClaudeCodeStub.sequence(
      ClaudeCodeStub.completed_tool_call(
        "update_spec",
        %{"vega_lite_json" => Jason.encode!(area_chart_spec())},
        completion_text: "I've changed it to an area chart."
      )
    )
  end

  @doc """
  Refinement that changes an existing widget's chart type AND rewords
  its title, passing back the widget_id the model was given for it
  (QA journey 6, criterion 1062, 2026-11-14; widget_id mechanism added
  in df2bd49). `existing_widgets_context/1` in `dashboard_live/editor.ex`
  gives each existing widget a stable `widget_id` (its 0-based
  position); `update_spec`'s own description tells the model to pass
  that same `widget_id` back to update a widget in place regardless of
  whether it renames it. In the two-widget fixture `generate_initial/0`
  builds (stat tile at position 0, line chart at position 1), the line
  chart's `widget_id` is `1`. This preset models a real model doing
  exactly what it's told: renaming \"Impressions Over Time\" to
  \"Daily Impressions\" while changing its mark to area, and passing
  `widget_id: 1` so the merge can target it despite the title no longer
  matching.
  """
  def refine_to_area_chart_with_reworded_title do
    ClaudeCodeStub.sequence(
      ClaudeCodeStub.completed_tool_call(
        "update_spec",
        %{
          "vega_lite_json" => Jason.encode!(reworded_area_chart_spec()),
          "widget_id" => 1
        },
        completion_text: "I've changed it to an area chart."
      )
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

  defp area_chart_spec do
    %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "data" => %{"name" => "impressions"},
      "mark" => "area",
      "encoding" => %{
        "x" => %{"field" => "date", "type" => "temporal", "title" => "Date"},
        "y" => %{"field" => "value", "type" => "quantitative", "title" => "Impressions"}
      },
      "title" => "Impressions Over Time",
      "width" => "container",
      "height" => 400
    }
  end

  defp reworded_area_chart_spec do
    %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "data" => %{"name" => "impressions"},
      "mark" => "area",
      "encoding" => %{
        "x" => %{"field" => "date", "type" => "temporal", "title" => "Date"},
        "y" => %{"field" => "value", "type" => "quantitative", "title" => "Impressions"}
      },
      "title" => "Daily Impressions",
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
