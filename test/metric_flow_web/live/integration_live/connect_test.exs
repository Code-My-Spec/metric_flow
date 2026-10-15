defmodule MetricFlowWeb.IntegrationLive.ConnectTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Stub providers
  # ---------------------------------------------------------------------------

  defmodule StubStrategy do
    @moduledoc false

    @state "liveview-csrf-state-token"
    @auth_url "https://stub.example.com/oauth/authorize?response_type=code&state=#{@state}"

    def authorize_url(_config) do
      {:ok, %{url: @auth_url, session_params: %{state: @state}}}
    end

    def callback(_config, _params) do
      {:ok,
       %{
         token: %{
           "access_token" => "stub-access-token",
           "refresh_token" => "stub-refresh-token",
           "expires_in" => 3600,
           "scope" => "email profile"
         },
         user: %{"sub" => "stub-user-id", "email" => "stub@example.com"}
       }}
    end

    def state, do: @state
    def auth_url, do: @auth_url
  end

  defmodule StubProvider do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "https://localhost/auth/stub/callback"
      ]
    end

    @impl true
    def strategy, do: MetricFlowWeb.IntegrationLive.ConnectTest.StubStrategy

    @impl true
    def normalize_user(%{"sub" => sub}) when is_binary(sub) do
      {:ok,
       %{
         provider_user_id: sub,
         email: "stub@example.com",
         name: "Stub User",
         username: "stub@example.com",
         avatar_url: nil
       }}
    end

    def normalize_user(_), do: {:error, :missing_provider_user_id}
  end

  @stub_providers %{
    stub: MetricFlowWeb.IntegrationLive.ConnectTest.StubProvider
  }

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp future_expires_at do
    DateTime.add(DateTime.utc_now(), 3_600, :second)
  end

  defp insert_integration!(user_id, provider, overrides \\ %{}) do
    defaults = %{
      user_id: user_id,
      provider: provider,
      access_token: "access-token-#{System.unique_integer([:positive])}",
      refresh_token: "refresh-token-#{System.unique_integer([:positive])}",
      expires_at: future_expires_at(),
      granted_scopes: ["email", "profile"],
      provider_metadata: %{"provider_user_id" => "stub-user-id", "email" => "stub@example.com"}
    }

    attrs = Map.merge(defaults, overrides)

    %Integration{}
    |> Integration.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  setup do
    original = Application.get_env(:metric_flow, :oauth_providers)
    Application.put_env(:metric_flow, :oauth_providers, @stub_providers)

    on_exit(fn ->
      if original do
        Application.put_env(:metric_flow, :oauth_providers, original)
      else
        Application.delete_env(:metric_flow, :oauth_providers)
      end
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "Google Business account access recovery" do
    setup %{conn: conn} do
      user = user_fixture()

      account =
        %MetricFlow.Accounts.Account{}
        |> MetricFlow.Accounts.Account.creation_changeset(%{
          name: "GBP Test Account",
          slug: "gbp-recovery-#{System.unique_integer([:positive])}",
          type: "client",
          originator_user_id: user.id
        })
        |> Repo.insert!()

      %MetricFlow.Accounts.AccountMember{}
      |> MetricFlow.Accounts.AccountMember.changeset(%{
        account_id: account.id,
        user_id: user.id,
        role: :owner
      })
      |> Repo.insert!()

      integration = insert_integration!(user.id, :google_business)
      original = Application.get_env(:metric_flow, :req_http_options)

      on_exit(fn ->
        if original do
          Application.put_env(:metric_flow, :req_http_options, original)
        else
          Application.delete_env(:metric_flow, :req_http_options)
        end
      end)

      %{conn: log_in_user(conn, user), integration: integration}
    end

    test "403 provides access guidance and a reconnect path without changing configuration", %{
      conn: conn,
      integration: integration
    } do
      Application.put_env(:metric_flow, :req_http_options,
        plug: fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            403,
            Jason.encode!(%{"error" => %{"status" => "PERMISSION_DENIED"}})
          )
        end
      )

      capture_log(fn ->
        {:ok, view, _html} = live(conn, ~p"/app/integrations/connect/google_business/accounts")

        assert has_element?(
                 view,
                 "#gbp-account-access-error[role='alert']",
                 "Google denied access"
               )

        assert has_element?(
                 view,
                 "#gbp-account-access-error",
                 "owns or manages a Business Profile"
               )

        assert has_element?(view, "#gbp-account-access-error", "contact support")
        assert has_element?(view, "#gbp-account-access-error", "does not confirm")
        assert has_element?(view, "[data-role='save-accounts-btn'][disabled]")

        assert has_element?(
                 view,
                 "#gbp-account-reconnect[href='/app/integrations/connect/google_business']"
               )

        view |> element("#gbp-account-reconnect") |> render_click()
        assert_redirect(view, ~p"/app/integrations/connect/google_business")
      end)

      assert Repo.get!(Integration, integration.id).provider_metadata ==
               integration.provider_metadata
    end

    for {reason, category, guidance} <- [
          {"SERVICE_DISABLED", "service_disabled", "Contact support to enable the API"},
          {"ACCESS_TOKEN_SCOPE_INSUFFICIENT", "insufficient_scope",
           "Reconnect your Google account"}
        ] do
      @reason reason
      @category category
      @guidance guidance

      test "shows specific recovery guidance for #{@reason}", %{
        conn: conn,
        integration: integration
      } do
        body = %{
          "error" => %{
            "status" => "PERMISSION_DENIED",
            "details" => [
              %{
                "@type" => "type.googleapis.com/google.rpc.ErrorInfo",
                "domain" => "googleapis.com",
                "reason" => @reason
              }
            ]
          }
        }

        Application.put_env(:metric_flow, :req_http_options,
          plug: fn conn ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(403, Jason.encode!(body))
          end
        )

        capture_log(fn ->
          {:ok, view, _html} = live(conn, ~p"/app/integrations/connect/google_business/accounts")

          assert has_element?(
                   view,
                   "#gbp-account-classified-error[data-reason='#{@category}']",
                   @guidance
                 )

          refute has_element?(view, "#gbp-account-access-error")

          refute has_element?(
                   view,
                   "[data-role='account-selection']",
                   "No Google Business Profile accounts found."
                 )

          assert has_element?(view, "[data-role='save-accounts-btn'][disabled]")

          if @category == "insufficient_scope" do
            view |> element("#gbp-scope-reconnect") |> render_click()
            assert_redirect(view, ~p"/app/integrations/connect/google_business")
          end
        end)

        assert Repo.get!(Integration, integration.id).provider_metadata ==
                 integration.provider_metadata
      end
    end

    test "successful empty account response remains distinct from denied access", %{conn: conn} do
      Application.put_env(:metric_flow, :req_http_options,
        plug: fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{"accounts" => []}))
        end
      )

      {:ok, view, _html} = live(conn, ~p"/app/integrations/connect/google_business/accounts")
      refute has_element?(view, "#gbp-account-access-error")

      assert has_element?(
               view,
               "[data-role='account-selection']",
               "No Google Business Profile accounts found."
             )

      assert has_element?(view, "[data-role='save-accounts-btn'][disabled]")
    end
  end

  describe "renders connect page with provider cards in a grid" do
    test "renders connect page with provider cards in a grid", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/app/integrations/connect")

        assert html =~ "Connect a Provider"
        assert html =~ "data-platform"
      end)
    end
  end

  describe "shows Connected badge for providers with active integrations" do
    test "shows Connected badge for providers with active integrations", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :stub)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/app/integrations/connect")

        assert html =~ "Connected"
      end)
    end
  end

  describe "shows Not connected badge for providers without integrations" do
    test "shows Not connected badge for providers without integrations", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/app/integrations/connect")

        assert html =~ "Not connected"
      end)
    end
  end

  describe "shows Connect button for each provider card" do
    test "shows Connect button for each provider card", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/integrations/connect")

        assert has_element?(lv, "[data-role='connect-button']")
      end)
    end
  end

  describe "renders per-provider detail view with OAuth connect button" do
    test "renders per-provider detail view with OAuth connect button", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/app/integrations/connect/stub")

        assert is_binary(html)
        assert has_element?(lv, "[data-role='oauth-connect-button']")
      end)
    end
  end

  describe "shows connected status and account email on per-provider view when connected" do
    test "shows connected status and account email on per-provider view when connected", %{
      conn: conn
    } do
      user = user_fixture()
      insert_integration!(user.id, :stub)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/app/integrations/connect/stub")

        assert html =~ "Connected"
        assert html =~ "stub@example.com"
      end)
    end
  end

  describe "shows back to integrations link on per-provider view" do
    test "shows back to integrations link on per-provider view", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/integrations/connect/stub")

        assert has_element?(lv, "a[href='/app/integrations']")
      end)
    end
  end

  describe "redirects unauthenticated users to login" do
    test "redirects unauthenticated users to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/app/integrations/connect")
    end
  end
end
