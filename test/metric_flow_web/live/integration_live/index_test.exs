defmodule MetricFlowWeb.IntegrationLive.IndexTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import Swoosh.TestAssertions

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Stub providers
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
    google_analytics: MetricFlowWeb.IntegrationLive.IndexTest.StubProvider,
    google_ads: MetricFlowWeb.IntegrationLive.IndexTest.StubProvider,
    google_search_console: MetricFlowWeb.IntegrationLive.IndexTest.StubProvider,
    facebook_ads: MetricFlowWeb.IntegrationLive.IndexTest.StubProvider,
    quickbooks: MetricFlowWeb.IntegrationLive.IndexTest.StubProvider
  }

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp future_expires_at do
    DateTime.add(DateTime.utc_now(), 3_600, :second)
  end

  defp past_expires_at do
    DateTime.add(DateTime.utc_now(), -3_600, :second)
  end

  defp insert_integration!(user_id, provider, overrides \\ %{}) do
    defaults = %{
      user_id: user_id,
      account_id: MetricFlowTest.UsersFixtures.default_account_id(user_id),
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

  describe "renders integrations page with header and Connect a Platform link" do
    test "renders integrations page with header and Connect a Platform link", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/app/integrations")

        assert html =~ "Integrations"
        assert has_element?(lv, "#setup-data-sources[href='/app/onboarding/connect']")
        assert has_element?(lv, "a[href='/app/integrations/connect']", "Connect a Platform")
      end)
    end
  end

  describe "shows empty state when no integrations are connected" do
    test "shows empty state when no integrations are connected", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/app/integrations")

        assert html =~ "No platforms connected yet."

        # Each sign-in's connect button opens its step of the setup wizard.
        assert has_element?(
                 lv,
                 "#connection-group-google a[href='/app/onboarding/connect?step=google']",
                 "Connect Google"
               )

        assert has_element?(
                 lv,
                 "#connection-group-quickbooks a[href='/app/onboarding/connect?step=quickbooks']",
                 "Connect QuickBooks"
               )

        refute has_element?(lv, "[data-role='integrations-list']")
      end)
    end
  end

  describe "does not send a reconnection email for a non-platform integration like codemyspec" do
    test "does not email the user when the unrelated codemyspec integration expires", %{
      conn: conn
    } do
      user = user_fixture()

      insert_integration!(user.id, :codemyspec, %{
        expires_at: past_expires_at(),
        reconnection_notified_at: nil
      })

      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, _html} = live(conn, ~p"/app/integrations")

        refute_email_sent(subject: "Reconnect your Codemyspec integration")
      end)
    end
  end

  describe "displays connected platforms with name, description, and Connected badge" do
    test "displays connected platforms with name, description, and Connected badge", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/app/integrations")

        assert has_element?(
                 lv,
                 "#connection-group-google [data-role='integrations-list'] [data-platform='google_ads']"
               )

        assert html =~ "Google Ads"
        assert has_element?(lv, "[data-platform='google_ads'][data-status='connected']")
        assert html =~ "Connected"
      end)
    end
  end

  describe "shows Sync Now, Edit Accounts, Manage, and Disconnect buttons for connected platforms" do
    test "shows Sync Now, Edit Accounts, Manage, and Disconnect buttons for connected platforms",
         %{conn: conn} do
      user = user_fixture()
      MetricFlowTest.AgenciesFixtures.account_with_member_fixture(user, :owner)

      insert_integration!(user.id, :google_ads, %{
        provider_metadata: %{"email" => "stub@example.com", "customer_id" => "1234567890"}
      })

      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/integrations")

        assert has_element?(lv, "[phx-click='sync'][phx-value-platform='google_ads']")
        assert has_element?(lv, "[data-role='edit-integration-accounts']")
        assert has_element?(lv, "a[href='/app/integrations/connect/google_ads']", "Manage")
        assert has_element?(lv, "[data-role='disconnect-integration']")
      end)
    end
  end

  describe "connected product with nothing selected" do
    test "offers choosing what to sync in the wizard instead of a sync it can't run", %{
      conn: conn
    } do
      user = user_fixture()
      MetricFlowTest.AgenciesFixtures.account_with_member_fixture(user, :owner)
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/integrations")

        assert has_element?(
                 lv,
                 "[data-platform='google_ads'] [data-role='edit-integration-accounts'][href='/app/onboarding/connect?step=google']",
                 "Choose ad account"
               )

        refute has_element?(lv, "[phx-click='sync'][phx-value-platform='google_ads']")
      end)
    end
  end

  describe "displays available platforms section for unconnected providers" do
    test "displays available platforms section for unconnected providers", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/app/integrations")

        assert html =~ "Not connected"
        assert has_element?(lv, "[data-platform='google_analytics'][data-status='available']")
        assert has_element?(lv, "[data-role='reconnect-integration']", "Connect Facebook")
      end)
    end
  end

  describe "triggers sync and shows success flash on Sync Now click" do
    test "triggers sync and shows success flash on Sync Now click", %{conn: conn} do
      user = user_fixture()
      MetricFlowTest.AgenciesFixtures.account_with_member_fixture(user, :owner)

      insert_integration!(user.id, :google_ads, %{
        provider_metadata: %{
          "provider_user_id" => "stub-user-id",
          "email" => "stub@example.com",
          "customer_id" => "1234567890"
        }
      })

      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/integrations")

        html =
          lv
          |> element("[phx-click='sync'][phx-value-platform='google_ads']")
          |> render_click()

        assert html =~ "Sync started for"
      end)
    end
  end

  describe "shows error flash when syncing a non-existent integration" do
    test "shows error flash when syncing a non-existent integration", %{conn: conn} do
      user = user_fixture()
      MetricFlowTest.AgenciesFixtures.account_with_member_fixture(user, :owner)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/integrations")

        html = render_click(lv, "sync", %{"provider" => "google_ads", "platform" => "google_ads"})

        assert html =~ "integration not found"
      end)
    end
  end

  describe "opens disconnect confirmation modal on Disconnect click" do
    test "opens disconnect confirmation modal on Disconnect click", %{conn: conn} do
      user = user_fixture()
      MetricFlowTest.AgenciesFixtures.account_with_member_fixture(user, :owner)
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/integrations")

        html =
          lv
          |> element("[data-platform='google_ads'] [data-role='disconnect-integration']")
          |> render_click()

        assert html =~ "Disconnect"
        assert html =~ "Historical data will remain"
        assert has_element?(lv, "[data-role='confirm-disconnect']")
        assert has_element?(lv, "[data-role='cancel-disconnect']")
      end)
    end
  end

  describe "disconnects provider and shows success flash on confirm" do
    test "disconnects provider and shows success flash on confirm", %{conn: conn} do
      user = user_fixture()
      MetricFlowTest.AgenciesFixtures.account_with_member_fixture(user, :owner)
      scope = MetricFlowTest.UsersFixtures.account_scope_fixture(user)
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/integrations")

        lv
        |> element("[data-platform='google_ads'] [data-role='disconnect-integration']")
        |> render_click()

        html =
          lv
          |> element("[data-role='confirm-disconnect']")
          |> render_click()

        assert html =~ "Disconnected from"
        assert html =~ "Historical data is retained"
        refute has_element?(lv, "[data-role='confirm-disconnect']")
        assert {:error, :not_found} = MetricFlow.Integrations.get_integration(scope, :google_ads)
      end)
    end
  end

  describe "cancels disconnect modal without modifying data" do
    test "cancels disconnect modal without modifying data", %{conn: conn} do
      user = user_fixture()
      MetricFlowTest.AgenciesFixtures.account_with_member_fixture(user, :owner)
      scope = MetricFlowTest.UsersFixtures.account_scope_fixture(user)
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/integrations")

        lv
        |> element("[data-platform='google_ads'] [data-role='disconnect-integration']")
        |> render_click()

        lv
        |> element("[data-role='cancel-disconnect']")
        |> render_click()

        refute has_element?(lv, "[data-role='confirm-disconnect']")
        assert {:ok, _integration} = MetricFlow.Integrations.get_integration(scope, :google_ads)
      end)
    end
  end

  describe "account-owned integrations" do
    defp member!(account_id, user, role) do
      %MetricFlow.Accounts.AccountMember{}
      |> MetricFlow.Accounts.AccountMember.changeset(%{
        account_id: account_id,
        user_id: user.id,
        role: role
      })
      |> Repo.insert!()

      user
    end

    test "an agency member switched into a client account sees the client's connections", %{
      conn: conn
    } do
      client_owner = user_fixture()
      client_id = default_account_id(client_owner)
      insert_integration!(client_owner.id, :google_ads)

      agency = MetricFlowTest.AgenciesFixtures.account_fixture(%{type: "agency"})
      agency_user = member!(agency.id, user_fixture(), :admin)

      {:ok, _} =
        MetricFlow.Agencies.grant_client_account_access(
          Scope.for_user(agency_user),
          agency.id,
          client_id,
          :account_manager,
          false
        )

      MetricFlow.Accounts.touch_membership(Scope.for_user(agency_user), client_id)
      conn = log_in_user(conn, agency_user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/integrations")
        assert has_element?(lv, "[data-platform='google_ads'][data-status='connected']")
      end)

      # Back in their own agency account, the client's connection is not shown.
      MetricFlow.Accounts.touch_membership(Scope.for_user(agency_user), agency.id)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/app/integrations")
        refute has_element?(lv, "[data-platform='google_ads'][data-status='connected']")
      end)
    end

    test "expired credentials email the account's owners and admins, not the viewing member", %{
      conn: conn
    } do
      owner = user_fixture()
      account_id = default_account_id(owner)
      admin = member!(account_id, user_fixture(), :admin)
      viewer = member!(account_id, user_fixture(), :read_only)

      insert_integration!(owner.id, :google_ads, %{
        expires_at: past_expires_at(),
        refresh_token: nil
      })

      MetricFlow.Accounts.touch_membership(Scope.for_user(viewer), account_id)
      conn = log_in_user(conn, viewer)

      capture_log(fn ->
        {:ok, _lv, _html} = live(conn, ~p"/app/integrations")
      end)

      recipients = reconnect_email_recipients()
      assert owner.email in recipients
      assert admin.email in recipients
      refute viewer.email in recipients
    end

    defp reconnect_email_recipients(acc \\ []) do
      receive do
        {:email, %{subject: "Reconnect your Google Ads integration", to: to}} ->
          reconnect_email_recipients(acc ++ Enum.map(to, &elem(&1, 1)))

        {:email, _other} ->
          reconnect_email_recipients(acc)
      after
        0 -> acc
      end
    end
  end
end
