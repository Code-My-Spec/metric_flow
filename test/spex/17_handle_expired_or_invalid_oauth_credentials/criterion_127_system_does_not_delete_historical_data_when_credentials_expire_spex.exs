defmodule MetricFlowSpex.SystemDoesNotDeleteHistoricalDataWhenCredentialsExpireSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "System does not delete historical data when credentials expire", criterion: 127 do
    scenario "past sync history for an integration remains visible after its credentials expire" do
      given_(:user_logged_in_as_owner)

      given_ "an integration has past successful syncs recorded", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_sync_history_for(context.owner_email, %{
          provider: :google_ads,
          status: :success,
          records_synced: 25,
          completed_at: DateTime.add(DateTime.utc_now(), -86_400, :second)
        })

        {:ok, context}
      end

      when_ "the integration's credentials expire", context do
        MetricFlowSpex.Fixtures.expire_integration_for(context.owner_email, :google_ads)

        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "its historical sync data is still shown, not deleted", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success']"
               )

        {:ok, context}
      end
    end
  end
end
