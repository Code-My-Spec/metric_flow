defmodule MetricFlowSpex.Criterion965DataQueriedPerCampaignByDefaultAdGroupBreakdownAvailableSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Data is queried per day and, by default, per campaign; an ad-group-level breakdown is also available",
       criterion: 965 do
    scenario "a user opts into ad-group-level breakdown when syncing a Google Ads account" do
      given_ :user_logged_in_as_owner

      given_ "a client has a connected Google Ads customer account", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads,
          provider_metadata: %{"customer_id" => "1234567890"}
        )

        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      given_ :with_google_ads_sync_stub

      when_ "they choose to sync with an ad-group-level breakdown instead of the campaign-level default", context do
        assert has_element?(context.view, "[data-role='google-ads-adgroup-breakdown-toggle']"),
               "Expected a control to opt into ad-group-level breakdown for Google Ads syncs"

        context.view |> element("[data-role='google-ads-adgroup-breakdown-toggle']") |> render_click()
        context.view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, context}
      end

      then_ "the sync completes using the ad-group-level breakdown rather than the campaign-level default", context do
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
