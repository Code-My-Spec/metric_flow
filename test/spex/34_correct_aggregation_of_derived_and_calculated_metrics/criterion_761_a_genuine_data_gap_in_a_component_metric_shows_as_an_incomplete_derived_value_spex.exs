defmodule MetricFlowSpex.AGenuineDataGapInAComponentMetricShowsAsAnIncompleteDerivedValueSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "A genuine data gap in a component metric shows as an incomplete derived value",
    criterion: 761 do
    scenario "a sync gap in clicks data is reflected as incomplete rather than silently computed as if clicks were zero" do
      given_(:user_logged_in_as_owner)

      given_ "a day within an aggregated period is missing its clicks data due to a sync gap, not a true zero-activity day",
             context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "total_cost",
          value: 50.0
        })

        {:ok, context}
      end

      when_ "the derived metric for that period is computed", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it reflects that the period is incomplete rather than silently computing as if the missing day contributed zero",
            context do
        html = render(context.view)

        assert html =~ "incomplete" or html =~ "missing data" or html =~ "data gap",
               "Expected an indication that the derived metric is incomplete due to a data gap, got: #{html}"

        {:ok, context}
      end
    end
  end
end
