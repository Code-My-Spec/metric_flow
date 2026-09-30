defmodule MetricFlowSpex.DerivedMetricIsDefinedByItsFormulaOverComponentMetricsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Derived metric is defined by its formula over component metrics", criterion: 756 do
    scenario "CPC uses the formula total spend divided by total clicks" do
      given_(:user_logged_in_as_owner)

      given_ "CPC is defined as total spend divided by total clicks", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "total_cost",
          value: 300.0
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 60.0
        })

        {:ok, context}
      end

      when_ "the system evaluates CPC", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it uses that formula referencing the spend and clicks component metrics", context do
        html = render(context.view)
        expected = :erlang.float_to_binary(300.0 / 60.0, decimals: 1)
        assert html =~ expected
        {:ok, context}
      end
    end
  end
end
