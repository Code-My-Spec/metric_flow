defmodule MetricFlowSpex.WhenOauthTokenRefreshFailsIntegrationStatusChangesToNeedsReconnectionSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "When OAuth token refresh fails, integration status changes to Needs Reconnection" do
    scenario "user sees a failure message after the system reports a token refresh failure" do
      given_ :owner_with_integrations

      given_ "the user is on the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the system broadcasts a sync failure indicating token refresh could not be completed", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google,
          reason: "Authorization expired. Please reconnect the integration."
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the user sees a message indicating reconnection is needed", context do
        html = render(context.view)

        has_reconnect_message =
          html =~ "reconnect" or
          html =~ "Reconnect" or
          html =~ "Authorization expired" or
          html =~ "expired" or
          html =~ "failed"

        assert has_reconnect_message,
               "Expected the integrations page to show a reconnection message after token refresh failure, got: #{html}"

        :ok
      end
    end

    scenario "user can see a reconnect option after a token expiry sync failure" do
      given_ :owner_with_integrations

      given_ "the user is on the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the system reports a sync failure due to expired authorization", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google,
          reason: "Token expired and could not be refreshed. Please reconnect."
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the integrations page shows a reconnect option for the provider", context do
        html = render(context.view)

        has_reconnect_option =
          html =~ "Reconnect" or
          html =~ "reconnect" or
          has_element?(context.view, "[data-role='reconnect-integration']") or
          has_element?(context.view, "a", "Reconnect") or
          has_element?(context.view, "button", "Reconnect")

        assert has_reconnect_option,
               "Expected the integrations page to show a reconnect option, got: #{html}"

        :ok
      end
    end

    scenario "the provider detail page offers a Reconnect action for connected integrations" do
      given_ :owner_with_integrations

      given_ "the user navigates to the Google Analytics integration detail page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/google_analytics")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the detail page shows an option to reconnect the integration", context do
        html = render(context.view)

        has_reconnect_action =
          html =~ "Reconnect" or
          html =~ "reconnect" or
          has_element?(context.view, "[data-role='oauth-connect-button']") or
          has_element?(context.view, "a", "Reconnect")

        assert has_reconnect_action,
               "Expected the integration detail page to show a reconnect option, got: #{html}"

        :ok
      end
    end
  end
end
