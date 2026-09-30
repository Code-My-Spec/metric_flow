defmodule MetricFlowSpex.Criterion977ResultsArePaginatedAutomaticallySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Results are paginated automatically until all rows for the requested period have been retrieved",
       criterion: 977 do
    scenario "a sync runs for an ad account whose period spans more rows than a single API page" do
      given_ :user_logged_in_as_owner

      given_ "a client has a connected Facebook Ads account with more rows than fit on a single API page", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :facebook_ads,
          provider_metadata: %{"ad_account_id" => "123456789"}
        )

        {:ok, context}
      end

      given_ :with_facebook_ads_sync_stub

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "all pages are retrieved automatically and the sync completes successfully", context do
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
