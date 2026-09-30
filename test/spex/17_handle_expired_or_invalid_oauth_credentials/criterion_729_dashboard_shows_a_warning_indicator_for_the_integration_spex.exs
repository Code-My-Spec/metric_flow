defmodule MetricFlowSpex.DashboardShowsAWarningIndicatorForTheIntegrationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Dashboard shows a warning indicator for the integration", criterion: 729 do
    scenario "an integration in Needs Reconnection status shows a warning indicator on the dashboard" do
      given_(:user_logged_in_as_owner)

      given_ "an integration is in Needs Reconnection status", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads,
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

        {:ok, context}
      end

      when_ "the user views the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a warning indicator is shown on that integration", context do
        assert has_element?(
                 context.view,
                 "[data-platform='google_ads'] .badge-error"
               )

        {:ok, context}
      end
    end
  end
end
