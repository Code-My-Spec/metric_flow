defmodule MetricFlowSpex.Criterion4852FailedOAuthAttemptsShowClearErrorMessagesSpex do
  use SexySpex
  use MetricFlowTest.ConnCase, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import_givens MetricFlowSpex.SharedGivens

  spex "Failed OAuth attempts show clear error messages", fail_on_error_logs: false do
    scenario "OAuth callback with access_denied error shows not-connected state on the detail page" do
      given_ :user_logged_in_as_owner

      when_ "the user arrives at the callback with an access_denied error", context do
        capture_log(fn ->
          get(
            context.owner_conn,
            "/integrations/oauth/callback/google_business",
            %{"error" => "access_denied", "state" => "any-state"}
          )
        end)

        {:ok, context}
      end

      then_ "the detail page shows the integration is not connected after the failed attempt",
            context do
        {:ok, _view, html} = live(context.owner_conn, "/integrations/connect/google_business")
        assert html =~ "Not connected"
        :ok
      end

      then_ "the detail page does not show a Connected badge after a failed attempt", context do
        {:ok, _view, html} = live(context.owner_conn, "/integrations/connect/google_business")
        refute html =~ "badge-success"
        :ok
      end
    end

    scenario "OAuth callback with invalid state token results in not-connected state" do
      given_ :user_logged_in_as_owner

      when_ "the user arrives at the callback with an invalid CSRF state token", context do
        capture_log(fn ->
          get(context.owner_conn, "/integrations/oauth/callback/google_business", %{
            "code" => "some-code",
            "state" => "invalid-state-xyz-999"
          })
        end)

        {:ok, context}
      end

      then_ "the detail page shows the integration is not connected after the invalid state",
            context do
        {:ok, _view, html} = live(context.owner_conn, "/integrations/connect/google_business")
        assert html =~ "Not connected"
        :ok
      end
    end

    scenario "Google Business detail page always shows an entry point to re-attempt OAuth" do
      given_ :user_logged_in_as_owner

      then_ "the detail page renders an OAuth entry point or a not-configured notice", context do
        {:ok, view, html} = live(context.owner_conn, "/integrations/connect/google_business")

        # Either a real connect button (when Google credentials are configured)
        # or an explicit not-configured notice — both indicate the page surfaces
        # the OAuth flow correctly.
        has_connect_button = has_element?(view, "[data-role='oauth-connect-button']")
        has_not_configured = html =~ "OAuth is not configured for this provider"

        assert has_connect_button or has_not_configured
        :ok
      end
    end
  end
end
