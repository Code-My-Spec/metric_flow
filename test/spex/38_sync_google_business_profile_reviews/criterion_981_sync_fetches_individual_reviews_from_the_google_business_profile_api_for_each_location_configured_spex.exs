defmodule MetricFlowSpex.Criterion981SyncFetchesIndividualReviewsForEachLocationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync fetches individual reviews from the Google Business Profile API for each configured location, via the account's Google OAuth",
       criterion: 981 do
    scenario "a client with a connected Google Business Profile location syncs its reviews" do
      given_ :user_logged_in_as_owner

      given_ "a client has a connected Google Business Profile location", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_business,
          provider_metadata: %{"included_locations" => ["locations/123456789"]}
        )

        {:ok, context}
      end

      when_ "the daily sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "reviews for that location are fetched using the account's own Google OAuth authorization", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']",
                 "Google Business Reviews"
               )

        {:ok, context}
      end
    end
  end
end
