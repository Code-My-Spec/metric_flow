defmodule MetricFlowSpex.UserReconnectsViaTheReconnectButtonSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User reconnects via the Reconnect button", criterion: 731 do
    scenario "clicking Reconnect on an expired integration's detail page re-initiates OAuth" do
      given_(:user_logged_in_as_owner)

      given_ "an integration is in Needs Reconnection status", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/connect/google_analytics")

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks Reconnect", context do
        reconnect_html =
          context.view
          |> element("[data-role='oauth-connect-button']")
          |> render()

        {:ok, Map.put(context, :reconnect_html, reconnect_html)}
      end

      then_ "the OAuth flow is re-initiated for that integration", context do
        assert context.reconnect_html =~ "Reconnect"
        assert context.reconnect_html =~ "href="
        refute context.reconnect_html =~ "href=\"\""
        {:ok, context}
      end
    end
  end
end
