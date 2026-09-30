defmodule MetricFlowSpex.UserSeesWarningIndicatorOnIntegrationInDashboardSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User sees warning indicator on integration in dashboard", criterion: 123 do
    scenario "an integration with expired credentials shows a warning indicator on the dashboard" do
      given_(:user_logged_in_as_owner)

      given_ "an integration's credentials have expired", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads,
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

        {:ok, context}
      end

      when_ "the user views the integrations dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a warning indicator is shown for that integration", context do
        assert has_element?(
                 context.view,
                 "[data-platform='google_ads'][data-status='error']"
               )

        {:ok, context}
      end
    end
  end
end
