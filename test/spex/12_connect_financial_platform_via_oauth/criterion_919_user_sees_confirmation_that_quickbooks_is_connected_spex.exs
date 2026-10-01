defmodule MetricFlowSpex.UserSeesConfirmationThatQuickbooksIsConnectedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User sees confirmation that QuickBooks is connected", criterion: 919 do
    scenario "viewing the connection status after the integration is saved shows a ready-to-sync confirmation" do
      given_ :user_logged_in_as_owner
      given_ :with_oauth_stub_providers

      given_ "the integration has just been saved", context do
        _callback_conn =
          get(
            context.owner_conn,
            "/app/integrations/oauth/callback/quickbooks",
            MetricFlowTest.OAuthStub.valid_callback_params()
          )

        {:ok, context}
      end

      when_ "the user views the connection status", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/quickbooks")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "they see confirmation that QuickBooks is connected and ready to sync", context do
        html = render(context.view)
        assert html =~ "QuickBooks"
        assert html =~ "Connected" or html =~ "connected"
        assert html =~ "sync" or html =~ "Sync"
        {:ok, context}
      end
    end
  end
end
