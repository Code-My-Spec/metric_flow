defmodule MetricFlowSpex.DerivedMetricsDisplayIdenticallyToRawMetricsInDashboardsAndReportsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Derived metrics display identically to raw metrics in dashboards and reports - the aggregation logic is transparent to the user",
    criterion: 290 do
    scenario "a raw metric and a derived metric render through the same stat card markup" do
      given_(:user_logged_in_as_owner)

      given_ "raw component metrics are recorded, producing both raw and derived stats",
             context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "total_cost",
          value: 100.0
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 20.0
        })

        {:ok, context}
      end

      when_ "the client views the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "both the raw metric and the derived metric render through the same stat-card markup with no visible distinction",
            context do
        stat_cards = context.view |> element("[data-role='summary-stats']") |> render()

        assert stat_cards =~ "clicks"
        assert stat_cards =~ "cpc"

        card_count =
          stat_cards
          |> String.split("data-role=\"stat-card\"")
          |> length()

        assert card_count > 2, "Expected multiple stat cards rendered through the same markup"
        {:ok, context}
      end
    end
  end
end
