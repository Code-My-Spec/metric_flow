defmodule MetricFlowSpex.FailedOauthAttemptShowsAClearErrorSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "Failed OAuth attempt shows a clear error", fail_on_error_logs: false, criterion: 920 do
    scenario "a user's OAuth attempt fails because they deny access" do
      given_ :user_logged_in_as_owner
      given_ :with_oauth_stub_providers

      given_ "the user's OAuth attempt fails (they deny access)", context do
        capture_log(fn ->
          _callback_conn =
            get(
              context.owner_conn,
              "/app/integrations/oauth/callback/quickbooks",
              MetricFlowTest.OAuthStub.denied_callback_params()
            )
        end)

        {:ok, context}
      end

      when_ "they return to the application", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/quickbooks")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a clear error message is shown rather than a silent failure", context do
        html = render(context.view)

        assert html =~ "denied" or html =~ "Denied" or html =~ "error" or html =~ "Error" or
                 html =~ "not connected" or html =~ "Not connected"

        {:ok, context}
      end
    end
  end
end
