defmodule MetricFlowSpex.Criterion974CoreMetricsStoredDailySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Core metrics are stored daily: impressions, clicks, spend, CPM, CPC, CTR, conversions (purchases and off-site conversions), and conversion rate",
       criterion: 974 do
    scenario "a Facebook Ads account with campaign activity syncs its core metrics" do
      given_ :user_logged_in_as_owner

      given_ "a client has a connected Facebook Ads account with campaign activity", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :facebook_ads,
          provider_metadata: %{"ad_account_id" => "123456789"}
        )

        {:ok, context}
      end

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "impressions, clicks, spend, CPM, CPC, CTR, conversions, and conversion rate are stored for the day", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']",
                 "Facebook Ads"
               )

        {:ok, context}
      end
    end
  end
end
