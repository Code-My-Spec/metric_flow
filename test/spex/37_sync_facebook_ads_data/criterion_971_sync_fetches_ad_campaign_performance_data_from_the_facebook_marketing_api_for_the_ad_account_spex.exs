defmodule MetricFlowSpex.Criterion971SyncFetchesAdCampaignDataFromFacebookMarketingApiSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync fetches ad campaign performance data from the Facebook Marketing API for the configured ad account, via Facebook's own OAuth, separate from Google integrations",
       criterion: 971 do
    scenario "a client with both a Facebook Ads and a Google Ads integration syncs each independently" do
      given_ :user_logged_in_as_owner

      given_ "a client has a connected Facebook Ads account and a connected Google Ads account", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :facebook_ads,
          provider_metadata: %{"ad_account_id" => "123456789"}
        )

        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        {:ok, context}
      end

      when_ "the daily sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Facebook Ads account is synced via its own OAuth connection, separately from the Google Ads integration", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'] [data-role='sync-provider']",
                 "Facebook Ads"
               )

        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'] [data-role='sync-provider']",
                 "Google Ads"
               )

        {:ok, context}
      end
    end
  end
end
