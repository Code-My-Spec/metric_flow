defmodule MetricFlowSpex.Criterion762DerivedMetricsDisplayIdenticallyToRawMetricsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Derived metrics display identically to raw metrics", criterion: 762 do
    scenario "a dashboard shows both raw and derived metrics with no visible difference in how they were calculated" do
      given_(:user_logged_in_as_owner)

      given_ "a dashboard shows both raw and derived metrics", context do
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

      when_ "the user views them", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "derived metrics are displayed the same way as raw metrics, with no visible difference in how they were calculated",
            context do
        stat_cards = context.view |> element("[data-role='summary-stats']") |> render()

        assert stat_cards =~ "clicks"
        assert stat_cards =~ "cpc"
        refute stat_cards =~ "calculated"
        refute stat_cards =~ "formula"
        {:ok, context}
      end
    end
  end
end
