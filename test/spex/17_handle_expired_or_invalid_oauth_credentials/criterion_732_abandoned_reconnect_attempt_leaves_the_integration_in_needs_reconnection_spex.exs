defmodule MetricFlowSpex.AbandonedReconnectAttemptLeavesTheIntegrationInNeedsReconnectionSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Abandoned reconnect attempt leaves the integration in Needs Reconnection",
    criterion: 732 do
    scenario "visiting the Reconnect link without completing OAuth leaves the integration unchanged" do
      given_(:user_logged_in_as_owner)

      given_ "the user clicks Reconnect and starts the OAuth flow", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads,
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_ads")

        assert has_element?(view, "[data-role='oauth-connect-button']")

        {:ok, context}
      end

      when_ "they abandon the flow before completing it", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the integration remains in Needs Reconnection status", context do
        assert has_element?(
                 context.view,
                 "[data-platform='google_ads'][data-status='error']"
               )

        {:ok, context}
      end
    end
  end
end
