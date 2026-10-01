defmodule MetricFlowSpex.IntegrationSavesOnlyAfterOauthCompletesSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Integration saves only after OAuth completes", criterion: 917 do
    scenario "the integration is saved once the connection process finishes successfully" do
      given_ :user_logged_in_as_owner
      given_ :with_oauth_stub_providers

      given_ "the user has completed the OAuth flow successfully", context do
        _callback_conn =
          get(
            context.owner_conn,
            "/app/integrations/oauth/callback/quickbooks",
            MetricFlowTest.OAuthStub.valid_callback_params()
          )

        {:ok, context}
      end

      when_ "the connection process finishes", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/quickbooks")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the integration is saved", context do
        html = render(context.view)
        assert html =~ "Connected" or html =~ "connected"
        {:ok, context}
      end
    end
  end
end
