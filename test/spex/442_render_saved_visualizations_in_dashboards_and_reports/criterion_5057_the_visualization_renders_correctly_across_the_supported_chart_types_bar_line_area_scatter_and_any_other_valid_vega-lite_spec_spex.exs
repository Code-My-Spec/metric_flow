defmodule MetricFlowSpex.Criterion5057VizRendersAcrossChartTypesSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Visualization renders correctly across supported chart types" do
    scenario "editing the vega-lite spec directly updates the chart preview" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user has a chart in the editor with spec editor open", context do
        {:ok, view, _html} = live(context.owner_conn, "/visualizations/new")

        # Select metric to generate initial spec
        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        # Open spec editor
        view
        |> element("[data-role='toggle-spec-editor']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "user edits the spec to a scatter (point) chart via the textarea", context do
        custom_spec =
          Jason.encode!(%{
            "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
            "mark" => "point",
            "encoding" => %{
              "x" => %{"field" => "date", "type" => "temporal"},
              "y" => %{"field" => "value", "type" => "quantitative"}
            },
            "data" => %{
              "values" => [
                %{"date" => "2026-01-01", "value" => 10},
                %{"date" => "2026-01-02", "value" => 20}
              ]
            },
            "title" => "impressions"
          })

        html =
          context.view
          |> element("[data-role='vega-spec-textarea']")
          |> render_blur(%{"value" => custom_spec})

        {:ok, Map.merge(context, %{html: html})}
      end

      then_ "the chart preview updates with the new spec", context do
        html = render(context.view)
        assert has_element?(context.view, "[data-role='vega-lite-chart']")
        assert html =~ "data-spec="
        # No spec error shown
        refute has_element?(context.view, ".text-error")
        :ok
      end
    end

    scenario "invalid JSON in the spec editor shows an error" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user has the spec editor open", context do
        {:ok, view, _html} = live(context.owner_conn, "/visualizations/new")

        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        view
        |> element("[data-role='toggle-spec-editor']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "user enters invalid JSON", context do
        html =
          context.view
          |> element("[data-role='vega-spec-textarea']")
          |> render_blur(%{"value" => "{invalid json"})

        {:ok, Map.merge(context, %{html: html})}
      end

      then_ "an error message is displayed", context do
        html = render(context.view)
        assert html =~ "Invalid JSON"
        :ok
      end
    end
  end
end
