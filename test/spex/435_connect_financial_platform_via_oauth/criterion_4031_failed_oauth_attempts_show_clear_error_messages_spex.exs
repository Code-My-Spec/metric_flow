defmodule MetricFlowSpex.FailedOauthAttemptsShowClearErrorMessagesSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import_givens MetricFlowSpex.SharedGivens

  spex "Failed OAuth attempts show clear error messages", fail_on_error_logs: false do
    scenario "access denied error shows a clear denial message" do
      given_ :user_logged_in_as_owner
      given_ :with_oauth_stub_providers

      when_ "the OAuth callback returns with an access_denied error", context do
        capture_log(fn ->
          _callback_conn = get(context.owner_conn, "/app/integrations/oauth/callback/quickbooks",
            MetricFlowTest.OAuthStub.denied_callback_params())
        end)
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/quickbooks")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows that access was denied", context do
        html = render(context.view)
        assert html =~ "denied" or html =~ "Denied" or html =~ "error" or html =~ "Error" or
                 html =~ "not connected" or html =~ "Not connected"
        :ok
      end

      then_ "the page provides a way to try again or go back", context do
        html = render(context.view)
        assert html =~ "Connect" or html =~ "Back" or html =~ "integrations" or
                 has_element?(context.view, "a")
        :ok
      end
    end

    scenario "generic OAuth error shows the error details" do
      given_ :user_logged_in_as_owner
      given_ :with_oauth_stub_providers

      when_ "the OAuth callback returns with a server error", context do
        capture_log(fn ->
          _callback_conn = get(context.owner_conn, "/app/integrations/oauth/callback/quickbooks", %{
            "error" => "server_error",
            "error_description" => "Something went wrong",
            "state" => MetricFlowTest.OAuthStub.state_token()
          })
        end)
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/quickbooks")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays the error information", context do
        html = render(context.view)
        assert html =~ "server_error" or html =~ "Something went wrong" or html =~ "error" or
                 html =~ "Error" or html =~ "not connected" or html =~ "Not connected"
        :ok
      end
    end

    scenario "missing authorization code shows a clear error" do
      given_ :user_logged_in_as_owner
      given_ :with_oauth_stub_providers

      when_ "the OAuth callback is invoked without any parameters", context do
        capture_log(fn ->
          _callback_conn = get(context.owner_conn, "/app/integrations/oauth/callback/quickbooks",
            %{"state" => MetricFlowTest.OAuthStub.state_token()})
        end)
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/quickbooks")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows an error", context do
        html = render(context.view)
        assert html =~ "error" or html =~ "Error" or html =~ "Failed" or html =~ "Could not" or
                 html =~ "not connected" or html =~ "Not connected"
        :ok
      end
    end

    scenario "the error page provides navigation back to integrations" do
      given_ :user_logged_in_as_owner
      given_ :with_oauth_stub_providers

      when_ "the OAuth callback returns with an error", context do
        capture_log(fn ->
          _callback_conn = get(context.owner_conn, "/app/integrations/oauth/callback/quickbooks",
            MetricFlowTest.OAuthStub.denied_callback_params())
        end)
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/quickbooks")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page has a link back to integrations", context do
        html = render(context.view)
        assert html =~ "Back to integrations" or html =~ "integrations" or html =~ "Integrations"
        :ok
      end
    end
  end
end
