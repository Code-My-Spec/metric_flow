defmodule MetricFlowSpex.FailedSyncsAreHighlightedWithErrorDetailsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Failed syncs are highlighted with error details", criterion: 120 do
    scenario "a failed sync history entry is visually distinguished and shows its error" do
      given_(:user_logged_in_as_owner)

      given_ "a sync attempt in the history failed", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_sync_history_for(context.owner_email, %{
          provider: :google_ads,
          status: :failed,
          records_synced: 0,
          error_message: "All data providers failed. Check your integration settings.",
          completed_at: DateTime.utc_now()
        })

        {:ok, context}
      end

      when_ "the user views the sync history", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "that entry is visually highlighted", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='failed']"
               )

        {:ok, context}
      end

      then_ "it shows its error details", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-error']",
                 "All data providers failed. Check your integration settings."
               )

        {:ok, context}
      end
    end
  end
end
