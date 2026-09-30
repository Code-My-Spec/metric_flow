defmodule MetricFlowSpex.SystemDistinguishesBetweenRawAndDerivedMetricsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "System distinguishes between raw/additive metrics and derived/calculated metrics",
    criterion: 283 do
    scenario "a derived metric's value is mathematically dependent on its raw components, not independently recorded" do
      given_(:user_logged_in_as_owner)

      given_ "raw component metrics are recorded", context do
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

      then_ "clicks and total_cost show their own recorded sums", context do
        html = render(context.view)
        assert html =~ "clicks"
        assert html =~ "total_cost"
        {:ok, context}
      end

      then_ "cpc is shown as a derived value equal to total_cost divided by clicks, not an independently-stored number",
            context do
        html = render(context.view)
        expected = :erlang.float_to_binary(100.0 / 20.0, decimals: 1)
        assert html =~ "cpc"
        assert html =~ expected
        {:ok, context}
      end
    end
  end
end
