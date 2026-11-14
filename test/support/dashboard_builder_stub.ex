defmodule MetricFlowTest.DashboardBuilderStub do
  @moduledoc """
  Named `:command_runner` scripted responses for the dashboard builder chat
  loop (`MetricFlow.Ai.DashboardBuilder`), which replaced `MetricFlow.Ai.VizChat`
  on the dashboard editor's chat (Story 74). Every preset scripts the
  builder's one write tool, `set_dashboard_spec`, with the dashboard's
  COMPLETE A2UI spec -- there is no per-widget edit tool, so refining one
  widget means returning every other widget unchanged alongside it.

  Kept separate from `MetricFlowTest.VizChatStub`: that module scripts
  `update_spec` for `MetricFlow.Ai.VizChat`, which still backs the
  single-visualization editor (`VisualizationLive.Editor`) and is exercised
  by the spex criteria under `test/spex/29_llm-driven_visualization_authoring/`
  -- retargeting those shared helpers to `set_dashboard_spec` would break
  every one of them.
  """

  alias MetricFlowTest.ClaudeCodeStub

  @doc """
  Initial build: a headline stat tile plus a line chart, both over
  impressions -- two widgets from one request (Journey 6, Story 74 rule 2),
  via a single `set_dashboard_spec` call carrying both components, since
  the builder's one write tool always sends the complete spec rather than
  a per-widget delta.
  """
  def generate_initial do
    ClaudeCodeStub.sequence(
      ClaudeCodeStub.completed_tool_call(
        "set_dashboard_spec",
        %{"a2ui_json" => Jason.encode!(%{"components" => initial_components()})},
        completion_text: "I'll create a line chart showing impressions over time."
      )
    )
  end

  @doc """
  Follow-up refinement: adds clicks as its own chart alongside the
  existing stat tile and impressions chart. A2UI's query binds one metric
  per component (Story 74: a "query" map with a single "metric" key, no
  multi-metric layering convention), so "a second series" becomes its own
  chart widget rather than a layered encoding on the existing one.
  """
  def generate_followup do
    ClaudeCodeStub.sequence(
      ClaudeCodeStub.completed_tool_call(
        "set_dashboard_spec",
        %{"a2ui_json" => Jason.encode!(%{"components" => followup_components()})},
        completion_text: "I've added clicks as a second chart alongside impressions."
      )
    )
  end

  @doc """
  Refinement that changes an existing widget's chart type: the model's
  next `set_dashboard_spec` call carries the SAME component id
  ("widget-1") with `chartType` now `"area"`, alongside the untouched
  stat tile ("widget-0") -- `set_dashboard_spec` always replaces the whole
  canvas, so leaving an unrelated widget out of the call would delete it,
  not leave it alone.
  """
  def refine_to_area_chart do
    ClaudeCodeStub.sequence(
      ClaudeCodeStub.completed_tool_call(
        "set_dashboard_spec",
        %{"a2ui_json" => Jason.encode!(%{"components" => area_chart_components()})},
        completion_text: "I've changed it to an area chart."
      )
    )
  end

  @doc """
  Refinement that changes an existing widget's chart type AND rewords its
  title, while keeping its component id ("widget-1") -- modeling a model
  that renames a widget without losing track of which one it's editing.
  There's no title-matching merge step to fool here (the whole spec is
  just replaced positionally); the id is the one thing that has to carry
  over for "the same widget, now renamed" to be a meaningful claim at all.
  """
  def refine_to_area_chart_with_reworded_title do
    ClaudeCodeStub.sequence(
      ClaudeCodeStub.completed_tool_call(
        "set_dashboard_spec",
        %{"a2ui_json" => Jason.encode!(%{"components" => reworded_area_chart_components()})},
        completion_text: "I've changed it to an area chart."
      )
    )
  end

  @doc """
  A build whose spec carries a top-level "title" the model chose itself
  ("Daily Clicks"), worded differently from the user's own request
  ("show me a bar chart of clicks by day") -- Story 75, criterion 1068:
  the dashboard's name should come from that title, not from copying
  the request text verbatim.
  """
  def generate_titled_bar_chart do
    ClaudeCodeStub.sequence(
      ClaudeCodeStub.completed_tool_call(
        "set_dashboard_spec",
        %{
          "a2ui_json" =>
            Jason.encode!(%{
              "title" => "Daily Clicks",
              "components" => [
                %{
                  "id" => "widget-0",
                  "type" => "chart",
                  "chartType" => "bar",
                  "title" => "Clicks by Day",
                  "query" => %{"metric" => "clicks"}
                }
              ]
            })
        },
        completion_text: "I've created a bar chart of daily clicks."
      )
    )
  end

  defp initial_components do
    [
      %{
        "id" => "widget-0",
        "type" => "stat",
        "title" => "Total Impressions",
        "query" => %{"metric" => "impressions"}
      },
      %{
        "id" => "widget-1",
        "type" => "chart",
        "chartType" => "line",
        "title" => "Impressions Over Time",
        "query" => %{"metric" => "impressions"}
      }
    ]
  end

  defp followup_components do
    initial_components() ++
      [
        %{
          "id" => "widget-2",
          "type" => "chart",
          "chartType" => "line",
          "title" => "Clicks Over Time",
          "query" => %{"metric" => "clicks"}
        }
      ]
  end

  defp area_chart_components do
    [
      hd(initial_components()),
      %{
        "id" => "widget-1",
        "type" => "chart",
        "chartType" => "area",
        "title" => "Impressions Over Time",
        "query" => %{"metric" => "impressions"}
      }
    ]
  end

  defp reworded_area_chart_components do
    [
      hd(initial_components()),
      %{
        "id" => "widget-1",
        "type" => "chart",
        "chartType" => "area",
        "title" => "Daily Impressions",
        "query" => %{"metric" => "impressions"}
      }
    ]
  end
end
