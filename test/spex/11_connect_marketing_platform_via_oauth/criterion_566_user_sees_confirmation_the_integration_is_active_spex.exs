defmodule MetricFlowSpex.UserSeesConfirmationTheIntegrationIsActiveSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User sees confirmation the integration is active", criterion: 566 do
    scenario "Dana completes the connect flow for Google Analytics and sees an active confirmation" do
      given_ :user_logged_in_as_owner
      given_ :with_oauth_stub_providers

      given_ "Dana completes the connect flow for Google Analytics", context do
        _callback_conn = get(context.owner_conn, "/app/integrations/oauth/callback/google",
          MetricFlowTest.OAuthStub.valid_callback_params())
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "she sees confirmation that the integration is active and ready to sync", context do
        html = render(context.view)
        assert html =~ "connected" or html =~ "Connected" or html =~ "active" or html =~ "Active"
        {:ok, context}
      end
    end
  end
end
