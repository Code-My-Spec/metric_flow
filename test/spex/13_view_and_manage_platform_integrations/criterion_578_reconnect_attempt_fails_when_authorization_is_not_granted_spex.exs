defmodule MetricFlowSpex.ReconnectAttemptFailsWhenAuthorizationIsNotGrantedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "Reconnect attempt fails when authorization is not granted", fail_on_error_logs: false, criterion: 578 do
    scenario "the user starts the reconnect flow but authorization fails or is denied" do
      given_ :user_logged_in_as_owner
      given_ :with_oauth_stub_providers

      given_ "the user starts the reconnect flow for Google Analytics", context do
        {:ok, context}
      end

      when_ "authorization fails or is denied", context do
        capture_log(fn ->
          _conn =
            get(
              context.owner_conn,
              "/app/integrations/oauth/callback/google",
              MetricFlowTest.OAuthStub.denied_callback_params()
            )
        end)

        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the integration remains disconnected and no new sync begins", context do
        refute has_element?(
                 context.view,
                 "[data-platform='google_analytics'][data-status='connected']"
               )

        {:ok, context}
      end
    end
  end
end
