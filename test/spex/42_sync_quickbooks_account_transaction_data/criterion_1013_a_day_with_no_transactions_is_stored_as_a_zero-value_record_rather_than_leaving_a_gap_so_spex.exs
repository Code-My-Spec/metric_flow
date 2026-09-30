defmodule MetricFlowSpex.Criterion1013NoTransactionDayStoredAsZeroValueRecordSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "A day with no transactions is stored as a zero-value record rather than leaving a gap, so correlation calculations have continuous daily data",
       criterion: 1013 do
    scenario "a QuickBooks account had no transactions on a given day" do
      given_ :user_logged_in_as_owner

      given_ "a QuickBooks income account had no transactions on a given day", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :quickbooks,
          provider_metadata: %{"realm_id" => "123456789", "income_account_id" => "79"}
        )

        {:ok, context}
      end

      when_ "the sync processes that day", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a zero-value record is stored for that day rather than leaving a gap", context do
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
