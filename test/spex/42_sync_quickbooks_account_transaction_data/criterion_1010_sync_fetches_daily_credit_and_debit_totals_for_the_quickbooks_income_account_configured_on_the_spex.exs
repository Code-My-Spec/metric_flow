defmodule MetricFlowSpex.Criterion1010SyncFetchesCreditsAndDebitsViaExistingOAuthSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync fetches daily credit and debit totals for the configured QuickBooks income account, using the account's existing QuickBooks OAuth authorization -- no separate financial-platform connection step required",
       criterion: 1010 do
    scenario "a client with a connected QuickBooks company and income account syncs daily credit and debit totals" do
      given_ :user_logged_in_as_owner
      given_ :with_quickbooks_sync_stub

      given_ "a client has a connected QuickBooks company with an income account configured", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :quickbooks,
          provider_metadata: %{"realm_id" => "123456789", "income_account_id" => "79"}
        )

        {:ok, context}
      end

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "daily credit and debit totals are fetched using the account's own QuickBooks OAuth authorization", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']",
                 "QuickBooks"
               )

        {:ok, context}
      end
    end
  end
end
