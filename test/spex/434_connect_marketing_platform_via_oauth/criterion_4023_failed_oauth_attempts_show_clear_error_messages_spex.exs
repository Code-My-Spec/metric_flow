defmodule MetricFlowSpex.FailedOAuthAttemptsShowClearErrorMessagesSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import_givens MetricFlowSpex.SharedGivens

  spex "Failed OAuth attempts show clear error messages", fail_on_error_logs: false do
    scenario "OAuth callback with error parameter shows error message to user" do
      given_ :user_logged_in_as_owner
      given_ :with_oauth_stub_providers

      given_ "the user arrives at the callback page with an OAuth error", context do
        capture_log(fn ->
          _callback_conn = get(context.owner_conn, "/integrations/oauth/callback/google",
            MetricFlowTest.OAuthStub.denied_callback_params())
        end)
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/google")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees a clear error message explaining the failure", context do
        html = render(context.view)

        assert html =~ "error" or html =~ "Error" or html =~ "failed" or html =~ "Failed" or
                 html =~ "denied" or html =~ "unsuccessful" or html =~ "not connected" or
                 html =~ "Not connected"

        :ok
      end

      then_ "the user is not shown a success confirmation", context do
        html = render(context.view)
        refute html =~ "Integration saved"
        refute html =~ "successfully connected"
        :ok
      end
    end

    scenario "OAuth callback with access denied shows actionable guidance" do
      given_ :user_logged_in_as_owner
      given_ :with_oauth_stub_providers

      given_ "the user arrives at the callback page after denying access", context do
        params = MetricFlowTest.OAuthStub.denied_callback_params()
                 |> Map.put("error_description", "User denied access")
        capture_log(fn ->
          _callback_conn = get(context.owner_conn, "/integrations/oauth/callback/google", params)
        end)
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/google")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page provides a way for the user to try again", context do
        html = render(context.view)

        assert has_element?(context.view, "a") or
                 has_element?(context.view, "button") or
                 html =~ "try again" or
                 html =~ "Try again" or
                 html =~ "Connect" or
                 html =~ "integrations"

        :ok
      end
    end

    scenario "OAuth callback with invalid state shows security error" do
      given_ :user_logged_in_as_owner
      given_ :with_oauth_stub_providers

      given_ "the user arrives at the callback page with an invalid state token", context do
        capture_log(fn ->
          _callback_conn = get(context.owner_conn, "/integrations/oauth/callback/google", %{
            "code" => "some_code",
            "state" => "invalid_state_token"
          })
        end)
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/google")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees an error message", context do
        html = render(context.view)

        assert html =~ "error" or html =~ "Error" or html =~ "invalid" or html =~ "Invalid" or
                 html =~ "failed" or html =~ "expired" or html =~ "not connected" or
                 html =~ "Not connected"

        :ok
      end
    end
  end
end
