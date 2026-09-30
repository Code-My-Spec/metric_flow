defmodule MetricFlowSpex.FinancialDebitsAndCreditsAreStoredAsMetricsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Financial debits and credits are stored as metrics", criterion: 613 do
    scenario "a connected financial integration's debits and credits sync in like any other metric source" do
      given_ :user_logged_in_as_owner

      given_ "a connected financial integration produces debits and credits", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :quickbooks)
        {:ok, context}
      end

      when_ "the sync stores that data", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it is stored as metrics alongside the marketing metrics", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'] [data-role='sync-provider']", "QuickBooks")
        {:ok, context}
      end
    end
  end
end
