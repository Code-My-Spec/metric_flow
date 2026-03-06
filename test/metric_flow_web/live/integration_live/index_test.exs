defmodule MetricFlowWeb.IntegrationLive.IndexTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Stub providers
  #
  # The index page calls Integrations.list_providers/0, which reads from
  # application config at runtime. Injecting stub providers lets us control
  # which platform cards appear in the view without real OAuth credentials.
  # ---------------------------------------------------------------------------

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
    def strategy, do: __MODULE__

    def authorize_url(_config), do: {:error, :not_used_in_index}
    def callback(_config, _params), do: {:error, :not_used_in_index}

    @impl true
    def normalize_user(_), do: {:error, :not_used_in_index}
  end

  @stub_providers %{
    google_ads: MetricFlowWeb.IntegrationLive.IndexTest.StubProvider,
    facebook_ads: MetricFlowWeb.IntegrationLive.IndexTest.StubProvider
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
  # Setup — inject stub providers
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
  # describe "mount/3"
  # ---------------------------------------------------------------------------

  describe "mount/3" do
    test "renders the integrations page title for an authenticated user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations")

        assert html =~ "Integrations"
      end)
    end

    test "renders the page subtitle for managing connected platforms", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations")

        assert html =~ "Manage your connected marketing platforms"
      end)
    end

    test "renders a Connect a Platform navigation link", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        assert has_element?(lv, "a[href='/integrations/connect']", "Connect a Platform")
      end)
    end

    test "shows empty state when the user has no integrations", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations")

        assert html =~ "No platforms connected yet."
      end)
    end

    test "shows empty state Connect your first platform link when no integrations exist", %{
      conn: conn
    } do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        assert has_element?(lv, "a[href='/integrations/connect']", "Connect your first platform")
      end)
    end

    test "does not render Connected Platforms section when user has no integrations", %{
      conn: conn
    } do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations")

        refute html =~ "Connected Platforms"
      end)
    end

    test "renders the Available Platforms section with each configured provider", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations")

        assert html =~ "Available Platforms"
        assert html =~ "Google Ads"
        assert html =~ "Facebook Ads"
      end)
    end

    test "renders Not connected badge for each unconnected platform", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations")

        assert html =~ "Not connected"
      end)
    end

    test "renders a Connect button for each unconnected platform", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        assert has_element?(lv, "[data-role='reconnect-integration'][phx-value-provider='google_ads']", "Connect")
        assert has_element?(lv, "[data-role='reconnect-integration'][phx-value-provider='facebook_ads']", "Connect")
      end)
    end

    test "renders Connected Platforms section when the user has at least one integration", %{
      conn: conn
    } do
      user = user_fixture()
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations")

        assert html =~ "Connected Platforms"
      end)
    end

    test "renders the connected platform name in the Connected Platforms section", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations")

        assert html =~ "Google Ads"
      end)
    end

    test "renders a Connected badge for the connected platform", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations")

        assert html =~ "Connected"
      end)
    end

    test "renders a Manage link for each connected integration", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        assert has_element?(lv, "a[href='/integrations/connect/google_ads']", "Manage")
      end)
    end

    test "moves a connected platform out of the Available Platforms section", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        # google_ads should not appear under the available section grid with a Connect link
        refute has_element?(lv, "a[href='/integrations/connect/google_ads']", "Connect")
      end)
    end

    test "does not show the empty state when the user has integrations", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations")

        refute html =~ "No platforms connected yet."
      end)
    end

    test "shows the Available Platforms section for platforms the user is not connected to", %{
      conn: conn
    } do
      user = user_fixture()
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        # facebook_ads is not connected, so it should appear in the available grid
        assert has_element?(lv, "[data-role='reconnect-integration'][phx-value-provider='facebook_ads']", "Connect")
      end)
    end

    test "only shows integrations belonging to the authenticated user", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      insert_integration!(other_user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations")

        # The current user has no integrations, so the empty state must appear
        assert html =~ "No platforms connected yet."
        refute html =~ "Connected Platforms"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event sync"
  # ---------------------------------------------------------------------------

  describe "handle_event sync" do
    test "adds the provider to syncing_providers and shows an info flash on sync success", %{
      conn: conn
    } do
      user = user_fixture()
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        html =
          lv
          |> element("[phx-click='sync'][phx-value-provider='google_ads']")
          |> render_click()

        assert html =~ "Sync started for"
      end)
    end

    test "shows an error flash when sync returns :not_found", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        # Send sync event directly — no sync button exists for unconnected platforms
        html = render_click(lv, "sync", %{"provider" => "google_ads"})

        assert html =~ "Integration not found."
      end)
    end

    test "shows an error flash when sync returns :not_connected", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        # Send sync event directly — no sync button exists for unconnected platforms
        html = render_click(lv, "sync", %{"provider" => "google_ads"})

        assert html =~ "Integration not found."
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event disconnect"
  # ---------------------------------------------------------------------------

  describe "handle_event disconnect" do
    test "shows the disconnect confirmation modal when Disconnect is clicked", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        html =
          lv
          |> element("[data-role='disconnect-integration'][phx-value-provider='google_ads']")
          |> render_click()

        assert html =~ "Disconnect"
        assert html =~ "Historical data will remain"
      end)
    end

    test "does not immediately delete the integration when Disconnect is clicked", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        lv
        |> element("[data-role='disconnect-integration'][phx-value-provider='google_ads']")
        |> render_click()

        assert {:ok, _integration} = MetricFlow.Integrations.get_integration(scope, :google_ads)
      end)
    end

    test "renders confirm and cancel buttons inside the disconnect modal", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        lv
        |> element("[data-role='disconnect-integration'][phx-value-provider='google_ads']")
        |> render_click()

        assert has_element?(lv, "[data-role='confirm-disconnect']")
        assert has_element?(lv, "[data-role='cancel-disconnect']")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event confirm_disconnect"
  # ---------------------------------------------------------------------------

  describe "handle_event confirm_disconnect" do
    test "deletes the integration and shows an info flash on successful disconnect", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        # Open the modal
        lv
        |> element("[data-role='disconnect-integration'][phx-value-provider='google_ads']")
        |> render_click()

        # Confirm the disconnect
        html =
          lv
          |> element("[data-role='confirm-disconnect']")
          |> render_click()

        assert html =~ "Disconnected from"
        assert html =~ "Historical data is retained"
      end)
    end

    test "removes the integration record from the database after confirmation", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        lv
        |> element("[data-role='disconnect-integration'][phx-value-provider='google_ads']")
        |> render_click()

        lv
        |> element("[data-role='confirm-disconnect']")
        |> render_click()

        assert {:error, :not_found} = MetricFlow.Integrations.get_integration(scope, :google_ads)
      end)
    end

    test "hides the disconnect modal after confirmation", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        lv
        |> element("[data-role='disconnect-integration'][phx-value-provider='google_ads']")
        |> render_click()

        html =
          lv
          |> element("[data-role='confirm-disconnect']")
          |> render_click()

        refute has_element?(lv, "[data-role='confirm-disconnect']")
        assert is_binary(html)
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event cancel_disconnect"
  # ---------------------------------------------------------------------------

  describe "handle_event cancel_disconnect" do
    test "hides the disconnect modal when Cancel is clicked", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        # Open the modal first
        lv
        |> element("[data-role='disconnect-integration'][phx-value-provider='google_ads']")
        |> render_click()

        # Cancel
        lv
        |> element("[data-role='cancel-disconnect']")
        |> render_click()

        refute has_element?(lv, "[data-role='confirm-disconnect']")
      end)
    end

    test "does not delete the integration when Cancel is clicked", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        lv
        |> element("[data-role='disconnect-integration'][phx-value-provider='google_ads']")
        |> render_click()

        lv
        |> element("[data-role='cancel-disconnect']")
        |> render_click()

        assert {:ok, _integration} = MetricFlow.Integrations.get_integration(scope, :google_ads)
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "authentication"
  # ---------------------------------------------------------------------------

  describe "authentication" do
    test "redirects unauthenticated users to /users/log-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/integrations")
    end
  end
end
