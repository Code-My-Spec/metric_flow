defmodule MetricFlowSpex.SubsequentDailySyncsFetchDataForYesterdayOnlySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Subsequent daily syncs fetch data for yesterday only (avoids incomplete current-day data)",
       fail_on_error_logs: false, criterion: 296 do
    scenario "a property that already completed its first sync only fetches yesterday's data on the next sync" do
      given_ :user_logged_in_as_owner

      given_ "a GA4 property has already completed its first sync", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a subsequent daily sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync entry's date is yesterday, not today", context do
        yesterday = Date.utc_today() |> Date.add(-1) |> Date.to_iso8601()
        html = render(context.view)
        assert html =~ yesterday
        {:ok, context}
      end
    end
  end
end
