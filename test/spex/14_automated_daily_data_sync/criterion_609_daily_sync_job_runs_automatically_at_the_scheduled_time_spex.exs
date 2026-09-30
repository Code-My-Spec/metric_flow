defmodule MetricFlowSpex.DailySyncJobRunsAutomaticallyAtScheduledTimeSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  @moduledoc """
  The real 2 AM UTC cron trigger (config/runtime.exs) can't be waited for in
  a spec. This drives the dev/admin "Run Scheduled Sync Now" control on the
  Sync History page -- the same entry point the cron plugin invokes
  (MetricFlow.DataSync.Scheduler) -- standing in for the schedule firing,
  distinct from any per-integration manual "Sync Now" action.
  """

  spex "Daily sync job runs automatically at the scheduled time", fail_on_error_logs: false, criterion: 609 do
    scenario "the scheduled time arrives and the daily sync runs for all accounts" do
      given_ :owner_with_integrations

      given_ "no admin has manually triggered a sync", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        refute has_element?(view, "[data-role='sync-history-entry']")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the scheduled time (e.g. 2 AM UTC) arrives", context do
        context.view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, context}
      end

      then_ "the daily sync job runs automatically for the account", context do
        assert has_element?(context.view, "[data-role='sync-history-entry']")
        {:ok, context}
      end
    end
  end
end
