defmodule MetricFlowSpex.SystemClassifiesMetricsAsRawOrDerivedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "System classifies metrics as raw or derived", criterion: 755 do
    scenario "clicks, spend, and impressions are treated as raw while CPC, CTR, and ROAS are treated as derived" do
      given_(:user_logged_in_as_owner)

      given_ "clicks, spend, and impressions alongside CPC, CTR, conversion rate, and ROAS",
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

      when_ "the system classifies them", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "clicks/spend/impressions are treated as raw and cpc/ctr/roas are treated as derived",
            context do
        html = render(context.view)
        expected_cpc = :erlang.float_to_binary(100.0 / 20.0, decimals: 1)

        assert html =~ "clicks"
        assert html =~ "total_cost"
        assert html =~ "cpc"
        assert html =~ expected_cpc
        {:ok, context}
      end
    end
  end
end
