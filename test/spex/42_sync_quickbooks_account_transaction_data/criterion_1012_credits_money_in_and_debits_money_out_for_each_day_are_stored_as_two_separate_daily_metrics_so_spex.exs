defmodule MetricFlowSpex.Criterion1012CreditsAndDebitsStoredAsTwoSeparateDailyMetricsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Credits (money in) and debits (money out) for each day are stored as two separate daily metrics, so revenue and spend can each be correlated independently",
       criterion: 1012 do
    scenario "a QuickBooks account with both credit and debit transactions completes its sync" do
      given_ :user_logged_in_as_owner

      given_ "a client has a connected QuickBooks account with both credit and debit transactions", context do
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

      then_ "credits and debits are stored as two separate daily metrics rather than a single net figure", context do
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
