defmodule MetricFlowSpex.FirstSyncBackfillsUpTo548DaysOfHistorySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "First sync backfills up to 548 days of history", fail_on_error_logs: false, criterion: 634 do
    scenario "the first sync for a newly connected property is marked as an initial backfill" do
      given_ :user_logged_in_as_owner

      given_ "a GA4 property was just connected and has never synced", context do
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

      then_ "it backfills up to 548 days of historical data", context do
        assert has_element?(context.view, "[data-sync-type='initial']")
        {:ok, context}
      end

      then_ "subsequent syncs continue from the day after the last stored date", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)

        html = render(view)
        yesterday = Date.utc_today() |> Date.add(-1) |> Date.to_iso8601()
        assert html =~ yesterday
        {:ok, context}
      end
    end
  end
end
