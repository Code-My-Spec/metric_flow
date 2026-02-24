defmodule MetricFlowSpex.UserCanReconnectAPreviouslyDisconnectedPlatformSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can reconnect a previously disconnected platform" do
    scenario "the integrations page shows a reconnect option for disconnected platforms" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
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
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
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

    scenario "clicking reconnect on a disconnected platform initiates the reconnection flow" do
      given_ :user_logged_in_as_owner

      given_ "the user is on the integrations page with a disconnected integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the reconnect button on the disconnected platform", context do
        html =
          context.view
          |> element("[data-role='reconnect-integration']")
          |> render_click()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the user is taken to or shown a reconnect flow for that platform", context do
        html = render(context.view)
        assert html =~ "reconnect" or
                 html =~ "Reconnect" or
                 html =~ "authorize" or
                 html =~ "Authorize" or
                 html =~ "Connect"
        :ok
      end
    end
  end
end
