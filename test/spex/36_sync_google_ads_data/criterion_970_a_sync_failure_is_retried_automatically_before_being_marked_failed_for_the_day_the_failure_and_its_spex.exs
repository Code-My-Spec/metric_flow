defmodule MetricFlowSpex.Criterion970SyncFailureRetriedBeforeMarkedFailedAndLoggedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "A sync failure is retried automatically before being marked failed for the day; the failure and its cause are logged with enough detail to diagnose and are visible in Sync History",
       fail_on_error_logs: false, criterion: 970 do
    scenario "a Google Ads sync that keeps failing is retried before ultimately being marked failed" do
      given_ :user_logged_in_as_owner

      given_ "a Google Ads account will keep failing to sync", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)
        {:ok, context}
      end

      when_ "the sync is attempted and retried automatically", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync, with_recursion: true)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "once retries are exhausted it is marked failed for the day, with the failure and its cause logged and visible in Sync History", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='failed'] [data-role='sync-provider']",
                 "Google Ads"
               )

        assert has_element?(context.view, "[data-role='sync-error']")
        {:ok, context}
      end
    end
  end
end
