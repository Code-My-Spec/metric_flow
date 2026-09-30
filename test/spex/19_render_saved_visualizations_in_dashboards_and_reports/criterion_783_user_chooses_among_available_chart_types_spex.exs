defmodule MetricFlowSpex.Criterion783UserChoosesAmongAvailableChartTypesSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User chooses among available chart types", criterion: 783 do
    scenario "a user building a visualization opens the chart type picker" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      when_ "they view the chart type selector", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "they can choose from types including line, bar, donut, Gantt, scatter, and area", context do
        assert has_element?(context.view, "[phx-value-chart_type='line']")
        assert has_element?(context.view, "[phx-value-chart_type='bar']")
        assert has_element?(context.view, "[phx-value-chart_type='area']")
        assert has_element?(context.view, "[phx-value-chart_type='donut']")
        assert has_element?(context.view, "[phx-value-chart_type='gantt']")
        assert has_element?(context.view, "[phx-value-chart_type='scatter']")
        {:ok, context}
      end
    end
  end
end
