defmodule MetricFlowSpex.UserCanClickReconnectButtonToReinitiateOAuthFlowSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can click Reconnect button to re-initiate OAuth flow", criterion: 125 do
    scenario "an expired integration's detail page offers a Reconnect link that re-initiates OAuth" do
      given_(:user_logged_in_as_owner)

      given_ "an integration's credentials have expired", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

        {:ok, context}
      end

      when_ "the user views that integration's detail page", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/connect/google_analytics")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "a Reconnect action is available that leads back into the OAuth flow", context do
        assert has_element?(context.view, "[data-role='oauth-connect-button']", "Reconnect")

        href =
          context.view
          |> element("[data-role='oauth-connect-button']")
          |> render()

        assert href =~ "href="
        refute href =~ "href=\"\""
        {:ok, context}
      end
    end
  end
end
