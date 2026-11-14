defmodule MetricFlowWeb.IntegrationOauthErrorDescriptionTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog

  @moduledoc """
  Reproduces issue c1043f5d: when a provider's OAuth error callback carries
  both "error" and "error_description", the callback shows the generic
  access_denied message instead of the provider's error_description.
  """

  setup :register_and_log_in_user

  test "shows the provider's error_description, not the generic access_denied message", %{
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

    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "User denied access"
  end
end
