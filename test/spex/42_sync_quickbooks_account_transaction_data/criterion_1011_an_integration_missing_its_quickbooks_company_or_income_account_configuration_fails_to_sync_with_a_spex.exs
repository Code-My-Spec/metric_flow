defmodule MetricFlowSpex.Criterion1011MissingCompanyOrIncomeAccountConfigFailsClearErrorSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "An integration missing its QuickBooks company or income account configuration fails to sync with a clear error",
       criterion: 1011 do
    scenario "a QuickBooks integration has no income account configured" do
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

      then_ "the sync fails with a clear error", context do
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
