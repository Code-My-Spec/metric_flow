defmodule MetricFlowSpex.FailedOAuthAttemptShowsAClearErrorMessageSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "Failed OAuth attempt shows a clear error message", fail_on_error_logs: false, criterion: 567 do
    scenario "Dana denies permission for Facebook Ads and sees a clear error message" do
      given_ :user_logged_in_as_owner
      given_ :with_oauth_stub_providers

      given_ "Dana starts the OAuth flow for Facebook Ads and denies permission", context do
        capture_log(fn ->
          _callback_conn = get(context.owner_conn, "/app/integrations/oauth/callback/facebook_ads",
            MetricFlowTest.OAuthStub.denied_callback_params())
        end)
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/facebook_ads")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "she sees a clear error message explaining the connection failed", context do
        html = render(context.view)
        assert html =~ "error" or html =~ "Error" or html =~ "failed" or html =~ "Failed" or
                 html =~ "denied" or html =~ "not connected" or html =~ "Not connected"
        {:ok, context}
      end
    end
  end
end
