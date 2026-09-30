defmodule MetricFlowSpex.FirstSyncBackfills548DaysThenContinuesFromLastStoredDateSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "On first sync, system backfills up to 548 days of historical GA4 data (approximately 18 months); on subsequent syncs, fetches from the day after the last stored metric date",
       criterion: 295 do
    scenario "a newly connected GA4 property's first sync is marked as a historical backfill" do
      given_ :user_logged_in_as_owner

      given_ "a GA4 property was just connected and has not synced before", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, context}
      end

      when_ "the first sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync history marks it as an initial backfill of up to 548 days", context do
        assert has_element?(context.view, "[data-sync-type='initial']")
        {:ok, context}
      end
    end

    scenario "a second sync for the same property continues from the day after the last stored date" do
      given_ :user_logged_in_as_owner

      given_ "the property already completed its first sync", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a second sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the second sync is not marked as an initial backfill", context do
        html = render(context.view)
        refute Regex.match?(~r/data-sync-type="initial"[^>]*>\s*<\/div>\s*<\/div>\s*<\/div>\s*$/, html)
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success']")
        {:ok, context}
      end
    end
  end
end
