defmodule MetricFlowSpex.UserCanDisconnectOrRemoveAnIntegrationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can disconnect or remove an integration" do
    scenario "integrations page shows a disconnect or remove action for each integration" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows a disconnect or remove button for integrations", context do
        html = render(context.view)
        assert html =~ "Disconnect" or
                 html =~ "disconnect" or
                 html =~ "Remove" or
                 has_element?(context.view, "[data-role='disconnect-integration']") or
                 has_element?(context.view, "button", "Disconnect") or
                 has_element?(context.view, "button", "Remove")
        :ok
      end
    end

    scenario "clicking disconnect on an integration initiates the disconnection flow" do
      given_ :owner_with_integrations

      given_ "the user is on the integrations page with a connected integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the disconnect button on an integration", context do
        html =
          context.view
          |> element("[data-platform='google_analytics'] [data-role='disconnect-integration']")
          |> render_click()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the user sees a response confirming the disconnect action was triggered", context do
        html = render(context.view)
        assert html =~ "disconnect" or
                 html =~ "Disconnect" or
                 html =~ "removed" or
                 html =~ "Removed" or
                 html =~ "confirm"
        :ok
      end
    end

    scenario "after disconnecting an integration the integration no longer appears as connected" do
      given_ :owner_with_integrations

      given_ "the user is on the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user completes the disconnect action for an integration", context do
        html =
          context.view
          |> element("[data-platform='google_analytics'] [data-role='disconnect-integration']")
          |> render_click()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the page reflects the integration is no longer active", context do
        html = render(context.view)
        assert html =~ "Disconnected" or
                 html =~ "disconnected" or
                 html =~ "Reconnect" or
                 html =~ "reconnect" or
                 has_element?(context.view, "[data-status='disconnected']")
        :ok
      end
    end
  end
end
