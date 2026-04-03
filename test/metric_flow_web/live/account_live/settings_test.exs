defmodule MetricFlowWeb.AccountLive.SettingsTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp unique_slug, do: "account-#{System.unique_integer([:positive])}"

  defp insert_account!(user, attrs) do
    defaults = %{
      name: "Test Account",
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

  defp team_account_fixture(user, attrs \\ %{}) do
    account = insert_account!(user, attrs)
    insert_member!(account, user, :owner)
    account
  end

  defp personal_account_fixture(user) do
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

  defp user_with_password_fixture do
    user = unconfirmed_user_fixture()

    {:ok, {user, _tokens}} =
      MetricFlow.Users.update_user_password(user, %{password: valid_user_password()})

    user
  end

  # ---------------------------------------------------------------------------
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders account settings page with account name and slug fields for owner" do
    test "shows settings page with pre-filled fields", %{conn: conn} do
      user = user_fixture()
      account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, html} = live(conn, ~p"/accounts/settings")

      assert html =~ "Account Settings"
      assert html =~ account.name
      assert has_element?(lv, "input[value='#{account.name}']")
      assert has_element?(lv, "input[value='#{account.slug}']")
    end
  end

  describe "shows Account Type as read-only text (Personal or Team)" do
    test "displays Personal for personal accounts", %{conn: conn} do
      user = user_fixture()
      _account = personal_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts/settings")

      assert html =~ "Personal"
    end

    test "displays Team for team accounts", %{conn: conn} do
      user = user_fixture()
      _account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts/settings")

      assert html =~ "Team"
    end
  end

  describe "live-validates account name and slug on change and shows inline errors" do
    test "shows error for blank account name", %{conn: conn} do
      user = user_fixture()
      _account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("form[phx-submit='save']", %{"account" => %{"name" => "", "slug" => "valid-slug"}})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "shows error for invalid slug format", %{conn: conn} do
      user = user_fixture()
      _account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("form[phx-submit='save']", %{
          "account" => %{"name" => "Valid Name", "slug" => "Invalid Slug!"}
        })
        |> render_change()

      assert html =~ "has invalid format"
    end
  end

  describe "saves account settings and shows success flash on valid submit" do
    test "owner saves successfully", %{conn: conn} do
      user = user_fixture()
      _account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("form[phx-submit='save']", %{
          "account" => %{"name" => "Updated Name", "slug" => "updated-slug"}
        })
        |> render_submit()

      assert html =~ "Updated Name"
      assert html =~ "saved"
    end

    test "admin saves successfully", %{conn: conn} do
      owner = user_fixture()
      account = team_account_fixture(owner)
      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      conn = log_in_user(conn, admin_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("form[phx-submit='save']", %{
          "account" => %{"name" => "Admin Updated", "slug" => "admin-updated"}
        })
        |> render_submit()

      assert html =~ "Admin Updated"
    end
  end

  describe "shows unauthorized error when non-owner/admin attempts to save" do
    test "read_only member cannot see save button", %{conn: conn} do
      owner = user_fixture()
      account = team_account_fixture(owner)
      reader_user = user_fixture()
      insert_member!(account, reader_user, :read_only)
      conn = log_in_user(conn, reader_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "button", "Save Changes")
    end

    test "account_manager member cannot see save button", %{conn: conn} do
      owner = user_fixture()
      account = team_account_fixture(owner)
      manager_user = user_fixture()
      insert_member!(account, manager_user, :account_manager)
      conn = log_in_user(conn, manager_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "button", "Save Changes")
    end
  end

  describe "displays Transfer Ownership section for owners of team accounts" do
    test "owner sees transfer ownership form", %{conn: conn} do
      user = user_fixture()
      account = team_account_fixture(user)
      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "[data-role='transfer-ownership']")
      assert has_element?(lv, "[data-role='transfer-ownership'] select option")
    end
  end

  describe "hides Transfer Ownership section for non-owners and personal accounts" do
    test "hidden for admin role", %{conn: conn} do
      owner = user_fixture()
      account = team_account_fixture(owner)
      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      conn = log_in_user(conn, admin_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "[data-role='transfer-ownership']")
    end

    test "hidden for personal accounts", %{conn: conn} do
      user = user_fixture()
      _account = personal_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "[data-role='transfer-ownership']")
    end
  end

  describe "transfers ownership to selected member and demotes current user to admin" do
    test "transfers and demotes", %{conn: conn} do
      owner = user_fixture()
      account = team_account_fixture(owner)
      target_user = user_fixture()
      insert_member!(account, target_user, :admin)
      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("[data-role='transfer-ownership']", %{"user_id" => target_user.id})
        |> render_submit()

      assert html =~ "transferred"

      new_role =
        Repo.get_by!(AccountMember, account_id: account.id, user_id: owner.id)
        |> Map.fetch!(:role)

      assert new_role == :admin
      refute has_element?(lv, "[data-role='transfer-ownership']")
    end
  end

  describe "displays Danger Zone with delete account form for owners of team accounts" do
    test "owner sees delete account form", %{conn: conn} do
      user = user_fixture()
      _account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "[data-role='delete-account']")
    end
  end

  describe "hides Danger Zone for non-owners and personal accounts" do
    test "hidden for admin role", %{conn: conn} do
      owner = user_fixture()
      account = team_account_fixture(owner)
      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      conn = log_in_user(conn, admin_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "[data-role='delete-account']")
    end

    test "hidden for personal accounts", %{conn: conn} do
      user = user_fixture()
      _account = personal_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "[data-role='delete-account']")
    end
  end

  describe "shows Account name does not match error when confirmation name is wrong" do
    test "error flash on name mismatch", %{conn: conn} do
      user = user_with_password_fixture()
      _account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("[data-role='delete-account']", %{
          "account_name_confirmation" => "wrong name",
          "password" => valid_user_password()
        })
        |> render_submit()

      assert html =~ "Account name does not match"
    end
  end

  describe "shows Incorrect password error when password is wrong during deletion" do
    test "error flash on wrong password", %{conn: conn} do
      user = user_with_password_fixture()
      account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("[data-role='delete-account']", %{
          "account_name_confirmation" => account.name,
          "password" => "wrong-password-123"
        })
        |> render_submit()

      assert html =~ "Incorrect password"
    end
  end

  describe "deletes account and redirects to /accounts on valid confirmation" do
    test "deletes and redirects", %{conn: conn} do
      user = user_with_password_fixture()
      account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      result =
        lv
        |> form("[data-role='delete-account']", %{
          "account_name_confirmation" => account.name,
          "password" => valid_user_password()
        })
        |> render_submit()

      assert {:error, {:redirect, %{to: "/accounts"}}} = result
    end
  end

  describe "prevents deletion of personal accounts" do
    test "no delete form for personal accounts", %{conn: conn} do
      user = user_with_password_fixture()
      account = personal_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "[data-role='delete-account']")
      assert account.type == "personal"
    end
  end

  describe "shows read-only settings view for non-editor roles" do
    test "read_only member sees readonly inputs", %{conn: conn} do
      owner = user_fixture()
      account = team_account_fixture(owner)
      reader_user = user_fixture()
      insert_member!(account, reader_user, :read_only)
      conn = log_in_user(conn, reader_user)

      {:ok, _lv, html} = live(conn, ~p"/accounts/settings")

      assert html =~ "readonly"
      assert html =~ account.name
      refute html =~ "phx-submit=\"save\""
    end
  end

  describe "subscribes to account PubSub and updates on real-time changes" do
    test "updates on PubSub account update", %{conn: conn} do
      user = user_fixture()
      account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      updated_account = %{account | name: "PubSub Updated Name"}
      send(lv.pid, {:updated, updated_account})

      html = render(lv)
      assert html =~ "PubSub Updated Name"
    end

    test "redirects on PubSub account deletion", %{conn: conn} do
      user = user_fixture()
      account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      send(lv.pid, {:deleted, account})

      assert_redirect(lv, "/accounts")
    end
  end

  describe "redirects to /accounts when user has no accounts" do
    test "redirects when no accounts exist", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/accounts"}}} =
               live(conn, ~p"/accounts/settings")
    end
  end

  describe "shows Leave Account section for non-owner members of team accounts" do
    test "non-owner sees leave account button", %{conn: conn} do
      owner = user_fixture()
      account = team_account_fixture(owner)
      member_user = user_fixture()
      insert_member!(account, member_user, :read_only)
      conn = log_in_user(conn, member_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "[data-role='revoke-own-access']")
    end
  end

  describe "confirms and processes leave account action" do
    test "member can leave account after confirmation", %{conn: conn} do
      owner = user_fixture()
      account = team_account_fixture(owner)
      member_user = user_fixture()
      insert_member!(account, member_user, :read_only)
      conn = log_in_user(conn, member_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      lv |> element("[data-role='revoke-own-access']") |> render_click()
      assert has_element?(lv, "[data-role='confirm-leave']")

      lv |> element("[data-role='confirm-leave']") |> render_click()

      html = render(lv)
      assert html =~ "left the account"
    end
  end
end
