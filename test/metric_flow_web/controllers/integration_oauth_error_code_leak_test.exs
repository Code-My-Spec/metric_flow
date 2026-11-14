defmodule MetricFlowWeb.IntegrationOauthErrorCodeLeakTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog

  @moduledoc """
  Reproduces issue 2d562431: the OAuth callback error flash shows the
  provider's description correctly, but also appends the raw OAuth error
  code in parentheses (e.g. "(access_denied)"), which should not be
  user-visible.
  """

  setup :register_and_log_in_user

  test "does not show the raw OAuth error code alongside the provider's description", %{
    conn: conn
  } do
    MetricFlowTest.OAuthStub.setup_oauth_providers()

    conn =
      capture_log(fn ->
        conn =
          get(conn, ~p"/app/integrations/oauth/callback/google_ads", %{
            "error" => "access_denied",
            "error_description" => "User denied access",
            "state" => MetricFlowTest.OAuthStub.state_token()
          })

        send(self(), {:conn, conn})
      end)
      |> then(fn _log ->
        receive do
          {:conn, conn} -> conn
        end
      end)

    message = Phoenix.Flash.get(conn.assigns.flash, :error)

    assert message =~ "User denied access"
    refute message =~ "access_denied"
  end
end
