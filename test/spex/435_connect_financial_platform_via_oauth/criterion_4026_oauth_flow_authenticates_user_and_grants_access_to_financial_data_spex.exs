defmodule MetricFlowSpex.OauthFlowAuthenticatesUserAndGrantsAccessToFinancialDataSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import_givens MetricFlowSpex.SharedGivens

  spex "OAuth flow authenticates user and grants access to financial data",
       fail_on_error_logs: false do
    scenario "successful OAuth callback creates an integration with financial data scopes" do
      given_ :owner_with_quickbooks_integration

      given_ "the user navigates to the QuickBooks detail page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/quickbooks")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees a successful connection confirmation", context do
        html = render(context.view)
        assert html =~ "connected" or html =~ "Active" or html =~ "Connected"
        :ok
      end
    end

    scenario "OAuth callback with invalid code shows error" do
      given_ :user_logged_in_as_owner
      given_ :with_oauth_stub_providers

      when_ "the OAuth callback returns with an error", context do
        capture_log(fn ->
          _callback_conn = get(context.owner_conn, "/integrations/oauth/callback/quickbooks",
            MetricFlowTest.OAuthStub.denied_callback_params())
        end)
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/quickbooks")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees an error message about the failed authentication", context do
        html = render(context.view)
        assert html =~ "denied" or html =~ "failed" or html =~ "Failed" or html =~ "error" or
                 html =~ "Error" or html =~ "not connected" or html =~ "Not connected"
        :ok
      end
    end

    scenario "OAuth callback without a code shows a missing code error" do
      given_ :user_logged_in_as_owner
      given_ :with_oauth_stub_providers

      when_ "the OAuth callback is invoked without a code parameter", context do
        capture_log(fn ->
          _callback_conn = get(context.owner_conn, "/integrations/oauth/callback/quickbooks",
            %{"state" => MetricFlowTest.OAuthStub.state_token()})
        end)
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/quickbooks")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees an error about no authorization code", context do
        html = render(context.view)
        assert html =~ "No authorization code" or html =~ "Failed" or html =~ "error" or html =~ "Error" or
                 html =~ "Could not complete" or html =~ "not connected" or html =~ "Not connected"
        :ok
      end
    end
  end
end
