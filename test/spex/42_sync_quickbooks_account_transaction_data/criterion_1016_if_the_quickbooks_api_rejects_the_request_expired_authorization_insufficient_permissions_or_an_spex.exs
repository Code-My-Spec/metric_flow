defmodule MetricFlowSpex.Criterion1016QuickbooksApiRejectionFailsSyncWithErrorSurfacedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "If the QuickBooks API rejects the request (expired authorization, insufficient permissions, or an unrecognized company) the sync for that integration fails with the error surfaced",
       criterion: 1016 do
    scenario "the QuickBooks API rejects a sync request because the integration's authorization has expired" do
      given_ :user_logged_in_as_owner

      given_ "a QuickBooks integration's authorization has expired", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :quickbooks,
          provider_metadata: %{"realm_id" => "123456789", "income_account_id" => "79"},
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

        {:ok, context}
      end

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync fails for that integration with the API's error surfaced", context do
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
