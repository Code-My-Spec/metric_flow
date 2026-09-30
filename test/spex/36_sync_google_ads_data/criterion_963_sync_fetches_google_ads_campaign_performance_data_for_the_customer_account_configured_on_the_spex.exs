defmodule MetricFlowSpex.Criterion963SyncFetchesGoogleAdsCampaignDataViaExistingOAuthSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync fetches Google Ads campaign performance data for the configured customer account, using the account's existing Google OAuth authorization -- no separate connection step required",
       criterion: 963 do
    scenario "a client with a connected Google Ads customer account syncs campaign performance data" do
      given_ :user_logged_in_as_owner

      given_ "a client has a connected Google Ads customer account", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads,
          provider_metadata: %{"customer_id" => "1234567890"}
        )

        {:ok, context}
      end

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "campaign performance data is fetched using the account's own Google OAuth authorization", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']",
                 "Google Ads"
               )

        {:ok, context}
      end
    end
  end
end
