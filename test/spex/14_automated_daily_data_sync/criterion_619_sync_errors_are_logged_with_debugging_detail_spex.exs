defmodule MetricFlowSpex.SyncErrorsAreLoggedWithDebuggingDetailSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync errors are logged with debugging detail", fail_on_error_logs: false, criterion: 619 do
    scenario "a failed sync's log includes enough detail to debug it" do
      given_ :user_logged_in_as_owner

      given_ "a sync attempt fails", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads,
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

        {:ok, context}
      end

      when_ "the failure is recorded", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the entry includes the integration, timestamp, and cause needed to debug it", context do
        assert has_element?(context.view, "[data-role='sync-provider']")
        assert has_element?(context.view, "[data-role='sync-error']")
        {:ok, context}
      end
    end
  end
end
