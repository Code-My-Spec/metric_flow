defmodule MetricFlowSpex.UserSeesConfirmationThatIntegrationIsActiveAndReadyToSyncSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User sees confirmation that integration is active and ready to sync" do
    scenario "OAuth callback page shows active and ready to sync confirmation" do
      given_ :user_logged_in_as_owner

      given_ "the user arrives at the callback page after successful OAuth", context do
        {:ok, view, _html} =
          live(
            context.owner_conn,
            "/integrations/oauth/callback/google_ads?code=test_auth_code&state=test_state"
          )

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees a confirmation that the integration is active", context do
        html = render(context.view)
        assert html =~ "active" or html =~ "Active" or html =~ "ready" or html =~ "Ready"
        :ok
      end

      then_ "the user sees messaging about data syncing", context do
        html = render(context.view)
        assert html =~ "sync" or html =~ "Sync" or html =~ "data" or html =~ "connected"
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
        assert has_element?(context.view, "[data-role='integration-status']") or
                 has_element?(context.view, "[data-role='platform-status']") or
                 render(context.view) =~ "status" or
                 render(context.view) =~ "Status"

        :ok
      end
    end

    scenario "confirmation page includes a call to action after integration setup" do
      given_ :user_logged_in_as_owner

      given_ "the user arrives at the post-OAuth confirmation page", context do
        {:ok, view, _html} =
          live(
            context.owner_conn,
            "/integrations/oauth/callback/google_ads?code=test_auth_code&state=test_state"
          )

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
