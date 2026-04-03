defmodule MetricFlowWeb.AgencyLive.SettingsTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.AgenciesFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Agencies
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp unique_slug, do: "account-#{System.unique_integer([:positive])}"

  defp insert_account!(user, attrs) do
    defaults = %{
      name: "Test Agency",
      slug: unique_slug(),
      type: "team",
      originator_user_id: user.id
    }

    %Account{}
    |> Account.creation_changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp insert_member!(account, user, role) do
    %AccountMember{}
    |> AccountMember.changeset(%{
      account_id: account.id,
      user_id: user.id,
      role: role
    })
    |> Repo.insert!()
  end

  defp team_account_with_owner(user, attrs \\ %{}) do
    account = insert_account!(user, attrs)
    insert_member!(account, user, :owner)
    account
  end

  defp personal_account_with_owner(user) do
    account =
      %Account{}
      |> Account.creation_changeset(%{
        name: "#{user.email} Personal",
        slug: "personal-#{System.unique_integer([:positive])}",
        type: "personal",
        originator_user_id: user.id
      })
      |> Repo.insert!()

    insert_member!(account, user, :owner)
    account
  end

  # ---------------------------------------------------------------------------
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders auto-enrollment and white-label cards for team account owners" do
    test "shows both sections for owner", %{conn: conn} do
      user = user_fixture()
      _account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "[data-role='agency-auto-enrollment']")
      assert has_element?(lv, "[data-role='agency-white-label']")
    end

    test "shows both sections for admin", %{conn: conn} do
      owner = user_fixture()
      account = team_account_with_owner(owner)
      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      conn = log_in_user(conn, admin_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "[data-role='agency-auto-enrollment']")
      assert has_element?(lv, "[data-role='agency-white-label']")
    end
  end

  describe "hides agency settings cards for non-owner/admin roles and personal accounts" do
    test "hidden for read_only members", %{conn: conn} do
      owner = user_fixture()
      account = team_account_with_owner(owner)
      reader = user_fixture()
      insert_member!(account, reader, :read_only)
      conn = log_in_user(conn, reader)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "[data-role='agency-auto-enrollment']")
      refute has_element?(lv, "[data-role='agency-white-label']")
    end

    test "hidden for personal accounts", %{conn: conn} do
      user = user_fixture()
      _account = personal_account_with_owner(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "[data-role='agency-auto-enrollment']")
      refute has_element?(lv, "[data-role='agency-white-label']")
    end
  end

  describe "enables auto-enrollment with domain and access level and shows success flash" do
    test "enables and flashes success", %{conn: conn} do
      user = user_fixture()
      account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("form#auto-enrollment-form", %{
          "auto_enrollment" => %{"domain" => "myagency.com", "default_access_level" => "read_only"}
        })
        |> render_submit()

      assert html =~ "Auto-enrollment enabled"

      scope = Scope.for_user(user)
      rule = Agencies.get_auto_enrollment_rule(scope, account.id)
      assert rule.email_domain == "myagency.com"
    end
  end

  describe "shows validation errors on auto-enrollment form with invalid data" do
    test "shows error for blank domain", %{conn: conn} do
      user = user_fixture()
      _account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("form#auto-enrollment-form", %{
          "auto_enrollment" => %{"domain" => "", "default_access_level" => "read_only"}
        })
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "disables active auto-enrollment rule and updates status badge" do
    test "disables and updates badge", %{conn: conn} do
      user = user_fixture()
      account = team_account_with_owner(user)
      _rule = auto_enrollment_rule_fixture(account.id, %{enabled: true})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, ".badge-success", "Active")

      html =
        lv
        |> element("[data-role='disable-auto-enrollment']")
        |> render_click()

      assert html =~ "Auto-enrollment disabled"
      assert has_element?(lv, ".badge-ghost", "Disabled")
      refute has_element?(lv, "[data-role='disable-auto-enrollment']")

      scope = Scope.for_user(user)
      rule = Agencies.get_auto_enrollment_rule(scope, account.id)
      assert rule.enabled == false
    end
  end

  describe "saves white-label branding settings and shows success flash" do
    test "saves and flashes success", %{conn: conn} do
      user = user_fixture()
      account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      unique = System.unique_integer([:positive])

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("form#white-label-form", %{
          "white_label" => %{
            "subdomain" => "myagency-#{unique}",
            "logo_url" => "https://example.com/logo.png",
            "primary_color" => "#FF5733",
            "secondary_color" => "#3498DB"
          }
        })
        |> render_submit()

      assert html =~ "White-label settings saved"

      scope = Scope.for_user(user)
      config = Agencies.get_white_label_config(scope, account.id)
      assert config.subdomain == "myagency-#{unique}"
    end
  end

  describe "shows validation errors on white-label form with invalid data" do
    test "shows error for blank subdomain", %{conn: conn} do
      user = user_fixture()
      _account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("form#white-label-form", %{
          "white_label" => %{
            "subdomain" => "",
            "logo_url" => "https://example.com/logo.png",
            "primary_color" => "#FF5733",
            "secondary_color" => "#3498DB"
          }
        })
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "live-validates white-label fields and shows color preview" do
    test "shows color preview when colors are entered", %{conn: conn} do
      user = user_fixture()
      _account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("form#white-label-form", %{
          "white_label" => %{
            "subdomain" => "test",
            "logo_url" => "",
            "primary_color" => "#FF5733",
            "secondary_color" => "#3498DB"
          }
        })
        |> render_change()

      assert html =~ "white-label-preview"
    end
  end

  describe "resets white-label config to default on reset click" do
    test "clears config on reset", %{conn: conn} do
      user = user_fixture()
      account = team_account_with_owner(user)
      _config = white_label_config_fixture(account.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      lv
      |> element("[data-role='reset-white-label']")
      |> render_click()

      scope = Scope.for_user(user)
      assert Agencies.get_white_label_config(scope, account.id) == nil
    end
  end

  describe "shows DNS verification panel when subdomain is saved" do
    test "displays DNS verification section", %{conn: conn} do
      user = user_fixture()
      account = team_account_with_owner(user)
      _config = white_label_config_fixture(account.id, %{subdomain: "myagency"})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "[data-role='dns-verification']")
      assert has_element?(lv, "[data-role='verify-dns']")
    end
  end
end
