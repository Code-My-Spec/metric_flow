defmodule MetricFlowSpex.DerivedMetricsAreDefinedByAFormulaReferencingComponentRawMetricsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Derived metrics are defined by a formula referencing their component raw metrics",
    criterion: 284 do
    scenario "CPC is computed as total spend divided by total clicks" do
      given_(:user_logged_in_as_owner)

      given_ "total spend and total clicks are recorded", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "total_cost",
          value: 200.0
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 50.0
        })

        {:ok, context}
      end

      when_ "the client views the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "CPC equals total spend divided by total clicks", context do
        html = render(context.view)
        expected = :erlang.float_to_binary(200.0 / 50.0, decimals: 1)
        assert html =~ expected
        {:ok, context}
      end
    end
  end
end
