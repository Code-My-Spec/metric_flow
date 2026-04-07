defmodule MetricFlowSpex.Criterion4076ChartTypeSelectionSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can select from multiple chart types in the visualization editor" do
    scenario "editor page displays multiple chart type options" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user navigates to the visualization editor", context do
        {:ok, view, html} = live(context.owner_conn, "/visualizations/new")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "multiple chart types are available for selection", context do
        html = render(context.view)
        assert has_element?(context.view, "[data-role='chart-type-selector']")
        assert html =~ "Line"
        assert html =~ "Bar"
        assert html =~ "Area"
        assert html =~ "Point"
        assert html =~ "Arc"
        assert html =~ "Rect"
        :ok
      end
    end

    scenario "user can select each chart type" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user is on the visualization editor", context do
        {:ok, view, _html} = live(context.owner_conn, "/visualizations/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "user clicks each chart type button", context do
        results =
          for type <- ["bar", "area", "point", "arc", "rect"] do
            html =
              context.view
              |> element("[phx-value-chart_type='#{type}']")
              |> render_click()

            {type, html}
          end

        {:ok, Map.put(context, :chart_type_results, results)}
      end

      then_ "each chart type becomes the active selection", context do
        for {type, html} <- context.chart_type_results do
          assert html =~ "btn-primary",
                 "Expected #{type} button to have active styling after click"
        end

        :ok
      end
    end
  end
end
