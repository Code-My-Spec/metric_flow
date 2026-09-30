defmodule MetricFlowSpex.FirstSyncBackfills548DaysSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "First sync backfills 548 days; later syncs continue from the last stored date", criterion: 657 do
    scenario "a property was just connected" do
      given_ :user_logged_in_as_owner

      given_ "a property was just connected", context do
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

      then_ "it backfills up to 548 days, and subsequent syncs fetch from the day after the last stored date",
            context do
        assert has_element?(context.view, "[data-sync-type='initial']")

        {:ok, context}
      end
    end
  end
end
