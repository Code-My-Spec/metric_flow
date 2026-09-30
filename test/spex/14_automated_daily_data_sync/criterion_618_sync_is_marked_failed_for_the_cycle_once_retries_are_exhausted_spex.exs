defmodule MetricFlowSpex.SyncIsMarkedFailedForTheCycleOnceRetriesAreExhaustedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync is marked failed for the cycle once retries are exhausted", fail_on_error_logs: false, criterion: 618 do
    scenario "an integration whose retries are exhausted is marked failed and left alone until the next cycle" do
      given_ :user_logged_in_as_owner

      given_ "a sync attempt has already failed 3 times", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads,
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync, with_recursion: true)
        {:ok, Map.put(context, :view, view)}
      end

      when_ "no further retry succeeds", context do
        {:ok, context}
      end

      then_ "that integration's sync is marked failed for this cycle", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='failed']")
        {:ok, context}
      end

      then_ "no further retries happen until the next scheduled sync", context do
        assert Oban.drain_queue(queue: :sync) == %{success: 0, cancelled: 0, discard: 0, failure: 0, snoozed: 0}
        {:ok, context}
      end
    end
  end
end
