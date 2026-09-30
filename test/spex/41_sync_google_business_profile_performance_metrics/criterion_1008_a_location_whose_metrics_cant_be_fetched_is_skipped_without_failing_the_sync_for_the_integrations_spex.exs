defmodule MetricFlowSpex.Criterion1008FailingLocationSkippedWithoutFailingOtherLocationsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "A location whose metrics can't be fetched is skipped without failing the sync for the integration's other locations",
       criterion: 1008 do
    scenario "one of two configured locations fails to fetch while the other succeeds" do
      given_ :user_logged_in_as_owner

      given_ "a Google Business Profile integration has two locations, one of which cannot be fetched", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_business,
          provider_metadata: %{"included_locations" => ["locations/111", "locations/does-not-exist"]}
        )

        {:ok, context}
      end

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the failing location is skipped and the sync still succeeds for the integration's other location", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']",
                 "Google Business Profile"
               )

        {:ok, context}
      end
    end
  end
end
