defmodule MetricFlowSpex.FilterCombinationWithNoMatchingDataShowsAnEmptyStateSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Filter combination with no matching data shows an empty state", criterion: 749 do
    scenario "a client toggles off all metrics and sees an empty state rather than an error" do
      given_(:user_logged_in_as_owner)

      given_ "a client is viewing the dashboard with a single visible metric", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 42.0
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they apply a filter combination that matches no data", context do
        context.view
        |> element("[data-role='metric-toggles'] button[phx-value-metric='clicks']")
        |> render_click()

        {:ok, context}
      end

      then_ "it shows an empty state rather than an error", context do
        html = render(context.view)

        assert html =~ "No metric data available for the selected filters." or
                 html =~ "No data to display." or
                 html =~ "No metrics match the selected filters.",
               "Expected an empty-state message, got: #{html}"

        {:ok, context}
      end
    end
  end
end
