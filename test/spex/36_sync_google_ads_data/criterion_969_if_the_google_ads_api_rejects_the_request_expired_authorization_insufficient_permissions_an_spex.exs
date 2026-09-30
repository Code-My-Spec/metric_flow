defmodule MetricFlowSpex.Criterion969GoogleAdsApiRejectionFailsSyncWithErrorSurfacedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "If the Google Ads API rejects the request (expired authorization, insufficient permissions, an unrecognized customer, or a rate limit) the sync for that integration fails with the API's error surfaced",
       fail_on_error_logs: false, criterion: 969 do
    scenario "the Google Ads API rejects a sync request because the customer account is unrecognized" do
      given_ :user_logged_in_as_owner

      given_ "a Google Ads integration is configured with a customer ID the API does not recognize", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads,
          provider_metadata: %{"customer_id" => "0000000000"}
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
                 "Google Ads"
               )

        assert has_element?(context.view, "[data-role='sync-error']")
        {:ok, context}
      end
    end
  end
end
