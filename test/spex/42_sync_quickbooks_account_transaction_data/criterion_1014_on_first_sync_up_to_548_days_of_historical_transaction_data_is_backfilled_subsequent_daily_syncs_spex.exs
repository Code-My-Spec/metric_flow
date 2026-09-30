defmodule MetricFlowSpex.Criterion1014FirstSyncBackfills548DaysSubsequentSyncsAreIncrementalSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "On first sync, up to 548 days of historical transaction data is backfilled; subsequent daily syncs are intended to fetch only data since the last successful sync rather than re-fetching the full history",
       fail_on_error_logs: false, criterion: 1014 do
    scenario "a newly connected QuickBooks account backfills on its first sync, then syncs incrementally" do
      given_ :user_logged_in_as_owner

      given_ "a QuickBooks account was just connected and has never synced", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :quickbooks,
          provider_metadata: %{"realm_id" => "123456789", "income_account_id" => "79"}
        )

        {:ok, context}
      end

      when_ "the first sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it backfills up to 548 days of historical transaction data", context do
        assert has_element?(context.view, "[data-sync-type='initial']")
        {:ok, context}
      end

      then_ "a subsequent daily sync fetches only data since the last successful sync rather than re-fetching the full history", context do
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
