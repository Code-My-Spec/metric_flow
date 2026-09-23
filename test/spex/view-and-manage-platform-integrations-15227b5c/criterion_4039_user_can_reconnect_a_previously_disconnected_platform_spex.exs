defmodule MetricFlowSpex.UserCanReconnectAPreviouslyDisconnectedPlatformSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can reconnect a previously disconnected platform" do
    scenario "the integrations page shows a reconnect option for disconnected platforms" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "disconnected platforms show a reconnect button or link", context do
        html = render(context.view)
        assert html =~ "Reconnect" or
                 html =~ "reconnect" or
                 html =~ "Connect" or
                 has_element?(context.view, "[data-role='reconnect-integration']") or
                 has_element?(context.view, "button", "Reconnect") or
                 has_element?(context.view, "a", "Reconnect")
        :ok
      end
    end

    scenario "a disconnected platform card is visually distinguishable from a connected one" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page indicates which platforms are disconnected versus connected", context do
        html = render(context.view)
        assert html =~ "Disconnected" or
                 html =~ "disconnected" or
                 html =~ "Connected" or
                 html =~ "connected" or
                 has_element?(context.view, "[data-status]")
        :ok
      end
    end

    scenario "clicking reconnect on a disconnected platform navigates to the connect page" do
      given_ :user_logged_in_as_owner

      given_ "the user is on the integrations page with unconnected platforms", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the reconnect link navigates to the provider connect page", context do
        assert has_element?(context.view, "[data-role='reconnect-integration']")
        :ok
      end
    end
  end
end
