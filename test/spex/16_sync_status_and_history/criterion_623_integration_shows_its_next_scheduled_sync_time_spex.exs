defmodule MetricFlowSpex.IntegrationShowsItsNextScheduledSyncTimeSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Integration shows its next scheduled sync time", criterion: 623 do
    scenario "a connected active integration shows its next scheduled sync time" do
      given_(:user_logged_in_as_owner)

      given_ "an integration is connected and active", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)
        {:ok, context}
      end

      when_ "the user views that integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it shows the next scheduled sync time", context do
        assert has_element?(
                 context.view,
                 "[data-platform='google_ads'] [data-role='next-sync-at']"
               )

        {:ok, context}
      end
    end
  end
end
