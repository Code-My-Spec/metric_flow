defmodule MetricFlowSpex.Criterion1017SyncFailuresLoggedAndVisibleInSyncHistorySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync failures are logged with enough detail to diagnose them and are visible in Sync History",
       criterion: 1017 do
    scenario "a QuickBooks sync fails because no income account is configured" do
      given_ :user_logged_in_as_owner

      given_ "a QuickBooks integration has no income account configured", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :quickbooks,
          provider_metadata: %{"realm_id" => "123456789"}
        )

        {:ok, context}
      end

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the failure is logged with enough detail to diagnose it and is visible in Sync History", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='failed'] [data-role='sync-provider']",
                 "QuickBooks"
               )

        assert has_element?(context.view, "[data-role='sync-error']")
        {:ok, context}
      end
    end
  end
end
