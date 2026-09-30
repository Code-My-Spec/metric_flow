defmodule MetricFlowSpex.Criterion797SameTemplateRendersDifferentDataPerBindingSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Same spec template renders different data for different metric bindings", criterion: 797 do
    scenario "two visualizations built from the same chart type but bound to different metrics render their own data" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "two visualizations sharing the same spec template, bound to different metrics via the join table", context do
        {:ok, view_a, _html} = live(context.owner_conn, "/app/visualizations/new")

        view_a
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        view_a
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Impressions Series"})

        view_a
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, view_b, _html} = live(context.owner_conn, "/app/visualizations/new")

        view_b
        |> element("[phx-value-metric='clicks']")
        |> render_click()

        view_b
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Clicks Series"})

        view_b
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, index_view, _html} = live(context.owner_conn, "/app/visualizations")
        html = render(index_view)
        [id_a, id_b] = Regex.scan(~r/data-visualization-id="(\d+)"/, html) |> Enum.map(&Enum.at(&1, 1))

        {:ok, Map.merge(context, %{id_a: id_a, id_b: id_b})}
      end

      when_ "both are rendered", context do
        {:ok, view_a, _html} = live(context.owner_conn, "/app/reports/#{context.id_a}")
        {:ok, view_b, _html} = live(context.owner_conn, "/app/reports/#{context.id_b}")
        {:ok, Map.merge(context, %{view_a: view_a, view_b: view_b})}
      end

      then_ "each displays the data for its own bound metric rather than shared or embedded data", context do
        chart_a =
          context.view_a
          |> element("[data-role='vega-lite-chart']")
          |> render()

        chart_b =
          context.view_b
          |> element("[data-role='vega-lite-chart']")
          |> render()

        assert chart_a =~ "&quot;values&quot;"
        assert chart_b =~ "&quot;values&quot;"
        refute chart_a == chart_b
        {:ok, context}
      end
    end
  end
end
