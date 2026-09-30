defmodule MetricFlowSpex.TokenRefreshFailureMarksTheIntegrationNeedsReconnectionSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Token refresh failure marks the integration Needs Reconnection", criterion: 728 do
    scenario "an integration whose token has expired and cannot be refreshed shows Needs Reconnection" do
      given_(:user_logged_in_as_owner)

      given_ "an integration's OAuth token has expired", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads,
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

        {:ok, context}
      end

      when_ "the user views the integrations dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the integration's status shows as needing reconnection", context do
        assert has_element?(
                 context.view,
                 "[data-platform='google_ads'][data-status='error']"
               )

        assert has_element?(context.view, "[data-status='error']", "reconnect")

        {:ok, context}
      end
    end
  end
end
