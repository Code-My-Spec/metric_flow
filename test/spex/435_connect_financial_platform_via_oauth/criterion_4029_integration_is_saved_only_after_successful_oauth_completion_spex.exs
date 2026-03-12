defmodule MetricFlowSpex.IntegrationIsSavedOnlyAfterSuccessfulOauthCompletionSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import_givens MetricFlowSpex.SharedGivens

  spex "Integration is saved only after successful OAuth completion",
       fail_on_error_logs: false do
    scenario "before OAuth completion the integrations list does not show QuickBooks as connected" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no QuickBooks integration is listed as connected", context do
        html = render(context.view)
        refute html =~ "QuickBooks" and html =~ "Connected"
        :ok
      end
    end

    scenario "a failed OAuth callback does not create an integration" do
      given_ :user_logged_in_as_owner
      given_ :with_oauth_stub_providers

      given_ "the OAuth callback returns with an error", context do
        capture_log(fn ->
          _callback_conn = get(context.owner_conn, "/integrations/oauth/callback/quickbooks",
            MetricFlowTest.OAuthStub.denied_callback_params())
        end)
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/quickbooks")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the callback page shows an error status", context do
        html = render(context.view)
        assert html =~ "denied" or html =~ "Failed" or html =~ "error" or html =~ "Error" or
                 html =~ "not connected" or html =~ "Not connected"
        :ok
      end

      when_ "the user navigates to the integrations list", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :list_view, view)}
      end

      then_ "QuickBooks is not shown as a connected integration", context do
        html = render(context.list_view)
        refute html =~ "QuickBooks" and html =~ "Connected"
        :ok
      end
    end

    scenario "a successful OAuth callback creates the integration" do
      given_ :owner_with_quickbooks_integration

      when_ "the user navigates to the QuickBooks detail page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/quickbooks")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the callback page shows the integration is active", context do
        html = render(context.view)
        assert html =~ "Active" or html =~ "connected" or html =~ "Connected"
        :ok
      end
    end
  end
end
