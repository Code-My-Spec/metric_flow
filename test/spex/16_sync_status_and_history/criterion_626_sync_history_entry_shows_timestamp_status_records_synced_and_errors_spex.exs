defmodule MetricFlowSpex.SyncHistoryEntryShowsTimestampStatusRecordsSyncedAndErrorsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync history entry shows timestamp, status, records synced, and errors", criterion: 626 do
    scenario "a sync history entry shows its timestamp, status, records synced, and error message" do
      given_(:user_logged_in_as_owner)

      given_ "a sync history entry for an integration", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_sync_history_for(context.owner_email, %{
          provider: :google_ads,
          status: :failed,
          records_synced: 0,
          error_message: "Token expired and could not be refreshed",
          completed_at: DateTime.utc_now()
        })

        {:ok, context}
      end

      when_ "the user views it", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it shows the timestamp, status, number of records synced, and any error messages",
            context do
        html = render(context.view)
        assert html =~ "Failed"
        assert html =~ "0 records synced"
        assert html =~ "Token expired and could not be refreshed"

        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='failed']"
               )

        {:ok, context}
      end
    end
  end
end
