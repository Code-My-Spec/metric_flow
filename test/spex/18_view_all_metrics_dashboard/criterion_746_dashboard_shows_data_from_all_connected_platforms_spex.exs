defmodule MetricFlowSpex.DashboardShowsDataFromAllConnectedPlatformsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Dashboard shows data from all connected platforms", criterion: 746 do
    scenario "a client with multiple connected platforms sees data from all of them together" do
      given_(:user_logged_in_as_owner)

      given_ "a client has multiple connected platforms", context do
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

        {:ok, context}
      end

      when_ "they open the All Metrics dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "data from all of those platforms is shown together", context do
        html = render(context.view)
        assert html =~ "clicks"
        assert html =~ "revenue"
        {:ok, context}
      end
    end
  end
end
