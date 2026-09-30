defmodule MetricFlowSpex.DailySyncJobRunsAtScheduledTimeSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  @moduledoc """
  The real 2 AM UTC cron trigger (config/runtime.exs) can't be waited for in
  a spec. This drives the dev/admin "Run Scheduled Sync Now" control on the
  Sync History page -- the same entry point the cron plugin invokes
  (MetricFlow.DataSync.Scheduler) -- standing in for the schedule firing.
  """

  spex "System runs daily sync job at scheduled time (e.g., 2 AM UTC)", criterion: 101 do
    scenario "the scheduled sync trigger runs the daily job" do
      given_ :owner_with_integrations

      when_ "the scheduled daily sync fires", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a sync history entry appears showing the job ran", context do
        assert has_element?(context.view, "[data-role='sync-history-entry']")
        {:ok, context}
      end
    end
  end
end
