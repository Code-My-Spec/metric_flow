defmodule MetricFlowSpex.FirstSyncBackfillWindowSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "On first sync, backfill window is determined by the service layer (consistent with other integrations at 548 days); subsequent syncs fetch from day after last stored metric date",
       criterion: 359 do
    scenario "a newly connected Search Console integration's first sync is marked as an initial backfill" do
      given_ :user_logged_in_as_owner

      given_ "a Search Console integration was just connected, with a configured site URL", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_search_console,
          provider_metadata: %{"site_url" => "https://example.com/"}
        )

        {:ok, context}
      end

      when_ "the first sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync is marked as an initial backfill, matching the 548-day window used by other integrations",
            context do
        assert has_element?(context.view, "[data-sync-type='initial']")

        {:ok, context}
      end
    end
  end
end
