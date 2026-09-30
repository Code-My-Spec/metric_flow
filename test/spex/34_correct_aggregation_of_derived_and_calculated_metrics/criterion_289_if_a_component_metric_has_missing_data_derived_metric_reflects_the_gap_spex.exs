defmodule MetricFlowSpex.IfAComponentMetricHasMissingDataDerivedMetricReflectsTheGapSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "If a component metric has missing data for a time period, the derived metric for that period reflects the gap rather than silently producing incorrect values",
    criterion: 289 do
    scenario "a day missing clicks data (a sync gap, not a true zero) is reflected as incomplete rather than silently computing CPC as if clicks were zero" do
      given_(:user_logged_in_as_owner)

      given_ "total_cost is recorded for a day but clicks failed to sync for that same day",
             context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "total_cost",
          value: 50.0
        })

        {:ok, context}
      end

      when_ "the derived CPC metric for that period is computed", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it reflects that the period is incomplete rather than silently computing as if clicks were zero",
            context do
        html = render(context.view)

        assert html =~ "incomplete" or html =~ "missing data" or html =~ "data gap",
               "Expected an indication that CPC is incomplete due to missing clicks data, got: #{html}"

        {:ok, context}
      end
    end
  end
end
