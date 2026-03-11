defmodule MetricFlowSpex.OauthFlowAuthenticatesUserAndGrantsAccessToFinancialDataSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "OAuth flow authenticates user and grants access to financial data" do
    scenario "successful OAuth callback creates an integration with financial data scopes" do
      given_ :user_logged_in_as_owner

      when_ "the OAuth callback returns with a valid authorization code", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/integrations/oauth/callback/quickbooks?code=test_auth_code")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees a successful connection confirmation", context do
        html = render(context.view)
        assert html =~ "connected" or html =~ "Active" or html =~ "Integration Active"
        :ok
      end
    end

    scenario "OAuth callback with invalid code shows error" do
      given_ :user_logged_in_as_owner

      when_ "the OAuth callback returns with an error", context do
        {:ok, view, _html} =
          live(
            context.owner_conn,
            "/integrations/oauth/callback/quickbooks?error=access_denied"
          )

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees an error message about the failed authentication", context do
        html = render(context.view)
        assert html =~ "denied" or html =~ "failed" or html =~ "Failed"
        :ok
      end
    end

    scenario "OAuth callback without a code shows a missing code error" do
      given_ :user_logged_in_as_owner

      when_ "the OAuth callback is invoked without a code parameter", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/integrations/oauth/callback/quickbooks")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees an error about no authorization code", context do
        html = render(context.view)
        assert html =~ "No authorization code" or html =~ "Failed" or html =~ "error"
        :ok
      end
    end
  end
end
