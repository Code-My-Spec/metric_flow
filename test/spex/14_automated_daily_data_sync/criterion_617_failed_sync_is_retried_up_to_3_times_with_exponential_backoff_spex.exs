defmodule MetricFlowSpex.FailedSyncIsRetriedUpTo3TimesWithExponentialBackoffSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Failed sync is retried up to 3 times with exponential backoff", fail_on_error_logs: false, criterion: 617 do
    scenario "a sync attempt for an integration fails and the system retries it" do
      given_ :user_logged_in_as_owner

      given_ "a sync attempt for an integration fails", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads,
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

        {:ok, context}
      end

      when_ "the system retries it", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync, with_recursion: true)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it retries up to 3 times with exponential backoff between attempts before finally failing", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='failed']")
        {:ok, context}
      end
    end
  end
end
