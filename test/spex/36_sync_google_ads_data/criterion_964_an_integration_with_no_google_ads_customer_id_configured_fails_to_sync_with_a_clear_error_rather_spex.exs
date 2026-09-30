defmodule MetricFlowSpex.Criterion964NoCustomerIdConfiguredFailsRatherThanSilentlySkippedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "An integration with no Google Ads customer ID configured fails to sync with a clear error rather than being silently skipped",
       fail_on_error_logs: false, criterion: 964 do
    scenario "a Google Ads integration has no customer ID configured" do
      given_ :user_logged_in_as_owner

      given_ "a Google Ads integration has no customer ID configured", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)
        {:ok, context}
      end

      when_ "the daily sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync fails with a clear error rather than being silently skipped", context do
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
