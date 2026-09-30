defmodule MetricFlowSpex.MarketingAndFinancialMetricsAppearTogetherSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Marketing and financial metrics appear together", criterion: 747 do
    scenario "a client with both marketing and financial integrations sees both kinds of metrics with no separation" do
      given_(:user_logged_in_as_owner)

      given_ "a client has both marketing and financial integrations connected", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :quickbooks)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_type: "marketing",
          metric_name: "clicks",
          value: 42.0
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :quickbooks,
          metric_type: "financial",
          metric_name: "revenue",
          value: 500.0
        })

        {:ok, context}
      end

      when_ "they view the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "both kinds of metrics are displayed together with no separate section or distinction",
            context do
        html = render(context.view)
        assert html =~ "clicks"
        assert html =~ "revenue"
        refute html =~ "Marketing"
        refute html =~ "Financial"
        {:ok, context}
      end
    end
  end
end
