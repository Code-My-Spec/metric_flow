defmodule MetricFlowSpex.Criterion973DataQueriedPerCampaignByDefaultAdsetBreakdownAvailableSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Data is queried per day and, by default, per campaign; an ad-set-level breakdown is also available",
       criterion: 973 do
    scenario "a user opts into ad-set-level breakdown when syncing a Facebook Ads account" do
      given_ :user_logged_in_as_owner

      given_ "a client has a connected Facebook Ads account", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :facebook_ads,
          provider_metadata: %{"ad_account_id" => "123456789"}
        )

        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they choose to sync with an ad-set-level breakdown instead of the campaign-level default", context do
        assert has_element?(context.view, "[data-role='facebook-adset-breakdown-toggle']"),
               "Expected a control to opt into ad-set-level breakdown for Facebook Ads syncs"

        context.view |> element("[data-role='facebook-adset-breakdown-toggle']") |> render_click()
        context.view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, context}
      end

      then_ "the sync completes using the ad-set-level breakdown rather than the campaign-level default", context do
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
