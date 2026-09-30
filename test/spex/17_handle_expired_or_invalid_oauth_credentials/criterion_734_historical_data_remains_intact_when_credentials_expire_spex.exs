defmodule MetricFlowSpex.HistoricalDataRemainsIntactWhenCredentialsExpireSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Historical data remains intact when credentials expire", criterion: 734 do
    scenario "viewing sync history for an integration with expired credentials still shows past syncs" do
      given_(:user_logged_in_as_owner)

      given_ "an integration's credentials have expired", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads,
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

        MetricFlowSpex.Fixtures.create_sync_history_for(context.owner_email, %{
          provider: :google_ads,
          status: :success,
          records_synced: 40,
          completed_at: DateTime.add(DateTime.utc_now(), -172_800, :second)
        })

        {:ok, context}
      end

      when_ "the user views its historical data", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "that data is still present and has not been deleted", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success']"
               )

        {:ok, context}
      end
    end
  end
end
