defmodule MetricFlowSpex.Criterion979FacebookApiRejectionFailsSyncWithErrorSurfacedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "If the Facebook API rejects the request (expired or invalid authorization, insufficient permissions, an unrecognized ad account, or a rate limit) the sync for that integration fails with the API's error surfaced",
       criterion: 979 do
    scenario "the Facebook API rejects a sync request because the integration's authorization is invalid" do
      given_ :user_logged_in_as_owner

      given_ "a Facebook Ads account is connected with credentials the Facebook API does not recognize", context do
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

      then_ "the sync fails for that integration with the API's error surfaced", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='failed'] [data-role='sync-provider']",
                 "Facebook Ads"
               )

        assert has_element?(context.view, "[data-role='sync-error']")
        {:ok, context}
      end
    end
  end
end
