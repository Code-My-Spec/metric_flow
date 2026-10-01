defmodule MetricFlowSpex.FailedOauthAttemptShowsAClearErrorSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "Failed OAuth attempt shows a clear error", fail_on_error_logs: false, criterion: 953 do
    scenario "denying access during the OAuth flow leaves the integration visibly not connected" do
      given_ :user_logged_in_as_owner

      when_ "the user's OAuth attempt fails because they deny access", context do
        capture_log(fn ->
          get(
            context.owner_conn,
            "/app/integrations/oauth/callback/google_business",
            %{"error" => "access_denied", "state" => "any-state"}
          )
        end)

        {:ok, context}
      end

      then_ "a clear error message is shown rather than a silent failure", context do
        {:ok, _view, html} = live(context.owner_conn, "/app/integrations/connect/google_business")
        assert html =~ "Not connected"
        refute html =~ "badge-success"
        {:ok, context}
      end
    end
  end
end
