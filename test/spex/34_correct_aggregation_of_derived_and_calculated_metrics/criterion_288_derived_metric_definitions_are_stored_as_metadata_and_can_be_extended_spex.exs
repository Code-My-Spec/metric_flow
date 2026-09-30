defmodule MetricFlowSpex.DerivedMetricDefinitionsAreStoredAsMetadataAndCanBeExtendedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Derived metric definitions are stored as metadata and can be extended for new metric types",
    criterion: 288 do
    scenario "an agency admin can define a new derived metric type without an engineer changing the aggregation code" do
      given_(:user_logged_in_as_owner)

      given_ "a client has raw cost and conversions data", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "total_cost",
          value: 100.0
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "conversions",
          value: 20.0
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they attempt to define a new derived metric type, e.g. CPA = total_cost / conversions",
            context do
        context.view |> element("[data-role='define-derived-metric']") |> render_click()

        context.view
        |> form("#define-derived-metric-form", %{
          "name" => "cpa",
          "numerator" => "total_cost",
          "denominator" => "conversions"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "a way to define and extend derived metrics exists without code changes", context do
        assert has_element?(
                 context.view,
                 "[data-role='stat-card'][data-metric-scope='derived']",
                 "cpa"
               )

        assert render(context.view) =~ "5.0"

        {:ok, context}
      end
    end
  end
end
