defmodule MetricFlowSpex.UserFiltersTheDashboardSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User filters the dashboard", criterion: 748 do
    scenario "a client filters by platform and only the matching data is shown" do
      given_(:user_logged_in_as_owner)

      given_ "a client is viewing the dashboard with data from two platforms", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :quickbooks)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 42.0
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :quickbooks,
          metric_name: "revenue",
          value: 500.0
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they filter by platform, date range, or metric type", context do
        context.view
        |> element("[data-role='platform-filter'] button[phx-value-platform='quickbooks']")
        |> render_click()

        {:ok, context}
      end

      then_ "only the matching data is shown", context do
        html = render(context.view)
        assert html =~ "revenue"
        refute html =~ "clicks"
        {:ok, context}
      end
    end
  end
end
