defmodule MetricFlowSpex.Criterion968BackfillReturnsLessThan548DaysWhenAccountHasLessHistorySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Backfill returns less than 548 days of data when the account itself has less history available",
       criterion: 968 do
    scenario "a Google Ads account with a shorter history than 548 days still completes its first sync" do
      given_ :user_logged_in_as_owner

      given_ "a Google Ads account has less than 548 days of history available", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads,
          provider_metadata: %{"customer_id" => "1234567890"}
        )

        {:ok, context}
      end

      when_ "the first sync backfills it", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "only the available history is backfilled rather than erroring on the shortfall", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']",
                 "Google Ads"
               )

        {:ok, context}
      end
    end
  end
end
