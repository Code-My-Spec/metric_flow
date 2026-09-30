defmodule MetricFlowSpex.IntegrationShowsItsLastSuccessfulSyncTimestampSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Integration shows its last successful sync timestamp", criterion: 621 do
    scenario "an integration with a completed successful sync shows that timestamp" do
      given_(:user_logged_in_as_owner)

      given_ "an integration has completed at least one successful sync", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        completed_at = DateTime.add(DateTime.utc_now(), -3600, :second)

        MetricFlowSpex.Fixtures.create_sync_history_for(context.owner_email, %{
          provider: :google_ads,
          status: :success,
          records_synced: 42,
          completed_at: completed_at
        })

        {:ok, Map.put(context, :completed_at, completed_at)}
      end

      when_ "the user views that integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it shows the timestamp of its last successful sync", context do
        assert has_element?(
                 context.view,
                 "[data-platform='google_ads'] [data-role='last-sync-at']"
               )

        {:ok, context}
      end
    end
  end
end
