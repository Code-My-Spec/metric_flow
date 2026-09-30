defmodule MetricFlowSpex.NewDerivedMetricTypesCanBeAddedViaMetadataSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "New derived metric types can be added via metadata", criterion: 760 do
    scenario "a new derived metric type defined as metadata becomes available for aggregation without engine code changes" do
      given_(:user_logged_in_as_owner)

      given_ "the client is on the dashboard where derived metrics are computed", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "total_cost",
          value: 50.0
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "conversions",
          value: 10.0
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a new derived metric type with its own formula is defined as metadata and added to the system",
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

      then_ "it is available for aggregation without changing the aggregation engine's code",
            context do
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
