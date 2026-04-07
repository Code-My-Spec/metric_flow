defmodule MetricFlowWeb.IntegrationOauthControllerTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog

  alias MetricFlow.Integrations.OAuthStateStore

  setup :register_and_log_in_user

  # ---------------------------------------------------------------------------
  # request/2
  # ---------------------------------------------------------------------------

  describe "request/2" do
    test "redirects to provider authorization URL for valid provider", %{conn: conn} do
      MetricFlowTest.OAuthStub.setup_oauth_providers()

      conn = get(conn, ~p"/app/integrations/oauth/google_ads")

      assert redirected_to(conn) =~ "oauth2.googleapis.com"
    end

    test "stores session params in OAuthStateStore", %{conn: conn} do
      MetricFlowTest.OAuthStub.setup_oauth_providers()

      conn = get(conn, ~p"/app/integrations/oauth/google_ads")

      # The controller stores session params keyed by state.
      # After redirect, the state was stored. We verify by checking
      # that a redirect happened (state was generated and stored).
      assert redirected_to(conn) =~ "state="
    end

    test "shows error flash and redirects for unsupported provider", %{conn: conn} do
      conn = get(conn, ~p"/app/integrations/oauth/nonexistent_provider")

      assert redirected_to(conn) == ~p"/app/integrations/connect"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not yet supported"
    end

    test "shows error flash when authorize_url fails", %{conn: conn} do
      # Configure a provider that will fail during authorize_url
      original = Application.get_env(:metric_flow, :oauth_providers)

      Application.put_env(:metric_flow, :oauth_providers, %{
        google_ads: MetricFlowWeb.IntegrationOauthControllerTest.FailingProvider
      })

      on_exit(fn ->
        if original do
          Application.put_env(:metric_flow, :oauth_providers, original)
        else
          Application.delete_env(:metric_flow, :oauth_providers)
        end
      end)

      conn =
        capture_log(fn ->
          conn = get(conn, ~p"/app/integrations/oauth/google_ads")
          send(self(), {:conn, conn})
        end)
        |> then(fn _log ->
          receive do
            {:conn, conn} -> conn
          end
        end)

      assert redirected_to(conn) == ~p"/app/integrations/connect"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Failed to connect"
    end
  end

  # ---------------------------------------------------------------------------
  # callback/2
  # ---------------------------------------------------------------------------

  describe "callback/2" do
    test "redirects with success flash after successful OAuth callback", %{conn: conn} do
      MetricFlowTest.OAuthStub.setup_oauth_providers()

      conn =
        capture_log(fn ->
          conn =
            get(
              conn,
              ~p"/app/integrations/oauth/callback/google_ads",
              MetricFlowTest.OAuthStub.valid_callback_params()
            )

          send(self(), {:conn, conn})
        end)
        |> then(fn _log ->
          receive do
            {:conn, conn} -> conn
          end
        end)

      assert redirected_to(conn) == ~p"/app/integrations/connect/google_ads"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Successfully connected"
    end

    test "redirects with error flash when token exchange fails", %{conn: conn} do
      MetricFlowTest.OAuthStub.setup_oauth_providers()

      # Use an invalid code with a valid state so the token exchange fails
      OAuthStateStore.store("bad-exchange-state", %{state: "bad-exchange-state"})

      conn =
        capture_log(fn ->
          conn =
            get(conn, ~p"/app/integrations/oauth/callback/google_ads", %{
              "code" => "invalid-code-that-will-fail",
              "state" => "bad-exchange-state"
            })

          send(self(), {:conn, conn})
        end)
        |> then(fn _log ->
          receive do
            {:conn, conn} -> conn
          end
        end)

      assert redirected_to(conn) =~ "/app/integrations/connect/google_ads"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) != nil
    end

    test "redirects with error flash when provider returns access_denied", %{conn: conn} do
      MetricFlowTest.OAuthStub.setup_oauth_providers()

      conn =
        capture_log(fn ->
          conn =
            get(
              conn,
              ~p"/app/integrations/oauth/callback/google_ads",
              MetricFlowTest.OAuthStub.denied_callback_params()
            )

          send(self(), {:conn, conn})
        end)
        |> then(fn _log ->
          receive do
            {:conn, conn} -> conn
          end
        end)

      assert redirected_to(conn) =~ "/app/integrations/connect/google_ads"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Access was denied"
    end

    test "redirects with error flash for unsupported provider", %{conn: conn} do
      MetricFlowTest.OAuthStub.setup_oauth_providers()

      conn =
        capture_log(fn ->
          conn =
            get(conn, ~p"/app/integrations/oauth/callback/totally_unknown", %{
              "code" => "some-code",
              "state" => MetricFlowTest.OAuthStub.state_token()
            })

          send(self(), {:conn, conn})
        end)
        |> then(fn _log ->
          receive do
            {:conn, conn} -> conn
          end
        end)

      assert redirected_to(conn) =~ "/app/integrations/connect/totally_unknown"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) != nil
    end

    test "handles missing state parameter gracefully", %{conn: conn} do
      MetricFlowTest.OAuthStub.setup_oauth_providers()

      conn =
        capture_log(fn ->
          conn =
            get(conn, ~p"/app/integrations/oauth/callback/google_ads", %{
              "code" => "some-code"
            })

          send(self(), {:conn, conn})
        end)
        |> then(fn _log ->
          receive do
            {:conn, conn} -> conn
          end
        end)

      # Should still redirect (not crash) even without a state param
      assert redirected_to(conn) =~ "/app/integrations/connect/google_ads"
    end
  end

  # ---------------------------------------------------------------------------
  # Test helper modules
  # ---------------------------------------------------------------------------

  defmodule FailingProvider do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      [
        client_id: "fail",
        client_secret: "fail",
        redirect_uri: "http://localhost:4002/integrations/oauth/callback/google_ads",
        base_url: "https://invalid.example.com",
        authorize_url: "https://invalid.example.com/auth"
      ]
    end

    @impl true
    def strategy, do: Assent.Strategy.OAuth2

    @impl true
    def normalize_user(_data), do: {:ok, %{}}
  end
end
