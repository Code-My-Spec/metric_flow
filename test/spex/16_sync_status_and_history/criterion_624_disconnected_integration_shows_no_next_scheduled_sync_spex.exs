defmodule MetricFlowSpex.DisconnectedIntegrationShowsNoNextScheduledSyncSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Disconnected integration shows no next scheduled sync", criterion: 624 do
    scenario "an integration with an expired, unrefreshable connection shows no next sync time" do
      given_(:user_logged_in_as_owner)

      given_ "an integration has been disconnected", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")

        view
        |> element("[data-role='disconnect-integration']")
        |> render_click()

        view
        |> element("[data-role='confirm-disconnect']")
        |> render_click()

        {:ok, context}
      end

      when_ "the user views that integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no next scheduled sync time is shown", context do
        refute has_element?(
                 context.view,
                 "[data-platform='google_ads'] [data-role='next-sync-at']"
               )

        {:ok, context}
      end
    end
  end
end
