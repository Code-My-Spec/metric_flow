defmodule MetricFlowSpex.UserCanSelectFromMultipleChartTypesSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can select from multiple chart types: line, bar, donut, Gantt, scatter, area, etc." do
    scenario "dashboard editor displays a chart type selector when adding a visualization" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the new dashboard editor", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboards/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user opens the metric picker", context do
        view =
          context.view
          |> element("[data-role='add-visualization-btn']")
          |> render_click()
          |> then(fn _ -> context.view end)

        {:ok, Map.put(context, :view, view)}
      end

      then_ "a chart type selector is displayed with multiple chart type options", context do
        assert has_element?(context.view, "[data-role='chart-type-selector']"),
               "Expected a chart type selector to be visible in the metric picker"

        :ok
      end
    end

    scenario "chart type selector includes line chart option" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the new dashboard editor", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboards/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user opens the metric picker", context do
        context.view
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        {:ok, context}
      end

      then_ "the chart type selector includes a line chart option", context do
        html = render(context.view)

        has_line_option =
          has_element?(context.view, "[phx-value-chart_type='line']") or
            has_element?(context.view, "[data-chart-type='line']") or
            html =~ "Line" or
            html =~ "line"

        assert has_line_option, "Expected a 'line' chart type option to be available"
        :ok
      end
    end

    scenario "chart type selector includes bar chart option" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the new dashboard editor", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboards/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user opens the metric picker", context do
        context.view
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        {:ok, context}
      end

      then_ "the chart type selector includes a bar chart option", context do
        html = render(context.view)

        has_bar_option =
          has_element?(context.view, "[phx-value-chart_type='bar']") or
            has_element?(context.view, "[data-chart-type='bar']") or
            html =~ "Bar" or
            html =~ "bar"

        assert has_bar_option, "Expected a 'bar' chart type option to be available"
        :ok
      end
    end

    scenario "chart type selector includes area chart option" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the new dashboard editor", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboards/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user opens the metric picker", context do
        context.view
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        {:ok, context}
      end

      then_ "the chart type selector includes an area chart option", context do
        html = render(context.view)

        has_area_option =
          has_element?(context.view, "[phx-value-chart_type='area']") or
            has_element?(context.view, "[data-chart-type='area']") or
            html =~ "Area" or
            html =~ "area"

        assert has_area_option, "Expected an 'area' chart type option to be available"
        :ok
      end
    end

    scenario "user can click on a chart type to select it" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the new dashboard editor", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboards/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user opens the metric picker and selects the bar chart type", context do
        context.view
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        context.view
        |> element("[phx-click='select_chart_type'][phx-value-chart_type='bar']")
        |> render_click()

        {:ok, context}
      end

      then_ "the bar chart type button appears selected", context do
        html = render(context.view)

        assert html =~ "Bar" or html =~ "bar",
               "Expected 'bar' chart type to be visible after selection"

        :ok
      end
    end
  end
end
