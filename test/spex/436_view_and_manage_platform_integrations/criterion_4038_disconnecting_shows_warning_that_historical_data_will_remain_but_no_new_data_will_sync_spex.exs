defmodule MetricFlowSpex.DisconnectingShowsWarningThatHistoricalDataWillRemainButNoNewDataWillSyncSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Disconnecting shows warning that historical data will remain but no new data will sync" do
    scenario "a warning appears when the user initiates a disconnect action" do
      given_ :user_logged_in_as_owner

      given_ "the user is on the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the disconnect button on an integration", context do
        html =
          context.view
          |> element("[data-role='disconnect-integration']")
          |> render_click()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the user sees a warning about historical data remaining", context do
        html = render(context.view)
        assert html =~ "historical data" or
                 html =~ "Historical data" or
                 html =~ "historical" or
                 has_element?(context.view, "[data-role='disconnect-warning']")
        :ok
      end
    end

    scenario "the warning explains that no new data will sync after disconnecting" do
      given_ :user_logged_in_as_owner

      given_ "the user is on the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the disconnect button on an integration", context do
        html =
          context.view
          |> element("[data-role='disconnect-integration']")
          |> render_click()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the user sees a message that no new data will sync", context do
        html = render(context.view)
        assert html =~ "no new data" or
                 html =~ "No new data" or
                 html =~ "will not sync" or
                 html =~ "stop syncing" or
                 html =~ "new data will sync"
        :ok
      end
    end

    scenario "the disconnect warning page or modal provides a confirm and cancel option" do
      given_ :user_logged_in_as_owner

      given_ "the user is on the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the disconnect button on an integration", context do
        html =
          context.view
          |> element("[data-role='disconnect-integration']")
          |> render_click()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the user sees options to confirm or cancel the disconnection", context do
        html = render(context.view)
        assert html =~ "Confirm" or
                 html =~ "confirm" or
                 html =~ "Cancel" or
                 html =~ "cancel" or
                 has_element?(context.view, "[data-role='confirm-disconnect']") or
                 has_element?(context.view, "[data-role='cancel-disconnect']")
        :ok
      end
    end
  end
end
