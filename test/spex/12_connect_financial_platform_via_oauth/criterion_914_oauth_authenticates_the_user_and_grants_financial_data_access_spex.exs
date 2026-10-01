defmodule MetricFlowSpex.OauthAuthenticatesTheUserAndGrantsFinancialDataAccessSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "OAuth authenticates the user and grants financial data access", criterion: 914 do
    scenario "completing the QuickBooks OAuth prompts grants the system access to financial data" do
      given_ :user_logged_in_as_owner
      given_ :with_oauth_stub_providers

      given_ "the user completes the QuickBooks OAuth prompts", context do
        {:ok, context}
      end

      when_ "authentication succeeds", context do
        _callback_conn =
          get(
            context.owner_conn,
            "/app/integrations/oauth/callback/quickbooks",
            MetricFlowTest.OAuthStub.valid_callback_params()
          )

        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/quickbooks")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the system is granted access to their financial data", context do
        html = render(context.view)
        assert html =~ "Connected" or html =~ "connected"
        {:ok, context}
      end
    end
  end
end
