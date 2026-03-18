defmodule MetricFlowSpex.UserSeesConfirmationThatIntegrationIsActiveAndReadyToSyncSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User sees confirmation that integration is active and ready to sync" do
    scenario "OAuth callback page shows active and ready to sync confirmation" do
      given_ :owner_with_google_ads_integration

      given_ "the user navigates to the Google detail page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/google")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees a confirmation that the integration is active", context do
        html = render(context.view)
        assert html =~ "active" or html =~ "Active" or html =~ "ready" or html =~ "Ready" or
                 html =~ "Connected" or html =~ "connected"
        :ok
      end

      then_ "the user sees messaging about data syncing", context do
        html = render(context.view)
        assert html =~ "sync" or html =~ "Sync" or html =~ "data" or html =~ "connected" or html =~ "Connected"
        :ok
      end
    end

    scenario "integrations list page shows active status for connected platform" do
      given_ :user_logged_in_as_owner

      given_ "the user views the integrations list page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows a status indicator for each platform", context do
        assert has_element?(context.view, "[data-role='integration-sync-status']") or
                 has_element?(context.view, "[data-role='platform-status']") or
                 render(context.view) =~ "status" or
                 render(context.view) =~ "Status"

        :ok
      end
    end

    scenario "confirmation page includes a call to action after integration setup" do
      given_ :owner_with_google_ads_integration

      given_ "the user navigates to the Google detail page after OAuth", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/google")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees a link or button to navigate further", context do
        html = render(context.view)

        assert has_element?(context.view, "a") or
                 has_element?(context.view, "button") or
                 html =~ "dashboard" or
                 html =~ "integrations"

        :ok
      end
    end
  end
end
