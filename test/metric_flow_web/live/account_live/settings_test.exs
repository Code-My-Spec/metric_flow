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

  defp insert_account!(user, attrs \\ %{}) do
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

  # Creates a team account with the given user as the owner member.
  defp team_account_fixture(user, attrs \\ %{}) do
    account = insert_account!(user, attrs)
    insert_member!(account, user, :owner)
    account
  end

  # Creates a personal account with the given user as the owner member.
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

  # Creates a user with a valid password set, required for delete_account password check.
  defp user_with_password_fixture do
    user = unconfirmed_user_fixture()

    {:ok, {user, _tokens}} =
      MetricFlow.Users.update_user_password(user, %{password: valid_user_password()})

    user
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3"
  # ---------------------------------------------------------------------------

  describe "mount/3" do
    test "renders the settings page for an authenticated owner", %{conn: conn} do
      user = user_fixture()
      account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts/settings")

      assert html =~ "Account Settings"
      assert html =~ account.name
    end

    test "displays the current account name pre-filled in the form", %{conn: conn} do
      user = user_fixture()
      account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "input[value='#{account.name}']")
    end

    test "displays the current account slug pre-filled in the form", %{conn: conn} do
      user = user_fixture()
      account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "input[value='#{account.slug}']")
    end

    test "shows the transfer ownership section for account owners on team accounts", %{conn: conn} do
      user = user_fixture()
      _account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "[data-role='transfer-ownership']")
    end

    test "shows the delete account section for account owners on team accounts", %{conn: conn} do
      user = user_fixture()
      _account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "[data-role='delete-account']")
    end

    test "hides the transfer ownership section for admin role", %{conn: conn} do
      owner = user_fixture()
      account = team_account_fixture(owner)
      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      conn = log_in_user(conn, admin_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "[data-role='transfer-ownership']")
    end

    test "hides the delete account section for admin role", %{conn: conn} do
      owner = user_fixture()
      account = team_account_fixture(owner)
      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      conn = log_in_user(conn, admin_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "[data-role='delete-account']")
    end

    test "redirects unauthenticated users to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/accounts/settings")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "render/1"
  # ---------------------------------------------------------------------------

  describe "render/1" do
    test "displays account type as Personal for personal accounts", %{conn: conn} do
      user = user_fixture()
      _account = personal_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts/settings")

      assert html =~ "Personal"
    end

    test "displays account type as Team for team accounts", %{conn: conn} do
      user = user_fixture()
      _account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts/settings")

      assert html =~ "Team"
    end

    test "shows the Save Changes button for owners", %{conn: conn} do
      user = user_fixture()
      _account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "button", "Save Changes")
    end

    test "shows the Save Changes button for admins", %{conn: conn} do
      owner = user_fixture()
      account = team_account_fixture(owner)
      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      conn = log_in_user(conn, admin_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "button", "Save Changes")
    end

    test "hides the Save Changes button for read_only members", %{conn: conn} do
      owner = user_fixture()
      account = team_account_fixture(owner)
      reader_user = user_fixture()
      insert_member!(account, reader_user, :read_only)
      conn = log_in_user(conn, reader_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "button", "Save Changes")
    end

    test "hides the Save Changes button for account_manager members", %{conn: conn} do
      owner = user_fixture()
      account = team_account_fixture(owner)
      manager_user = user_fixture()
      insert_member!(account, manager_user, :account_manager)
      conn = log_in_user(conn, manager_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "button", "Save Changes")
    end

    test "lists non-owner members in the transfer ownership dropdown", %{conn: conn} do
      owner = user_fixture()
      account = team_account_fixture(owner)
      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "[data-role='transfer-ownership'] select option")
    end

    test "does not include the owner in the transfer ownership dropdown", %{conn: conn} do
      owner = user_fixture()
      _account = team_account_fixture(owner)
      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(
               lv,
               "[data-role='transfer-ownership'] select option[value='#{owner.id}']"
             )
    end

    test "hides the transfer ownership and delete sections for personal accounts", %{conn: conn} do
      user = user_fixture()
      _account = personal_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "[data-role='transfer-ownership']")
      refute has_element?(lv, "[data-role='delete-account']")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event validate"
  # ---------------------------------------------------------------------------

  describe "handle_event validate" do
    test "shows validation error for blank account name", %{conn: conn} do
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

    test "shows validation error for invalid slug format", %{conn: conn} do
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

    test "shows no errors for valid account name and slug", %{conn: conn} do
      user = user_fixture()
      _account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("form[phx-submit='save']", %{
          "account" => %{"name" => "Valid Name", "slug" => "valid-slug"}
        })
        |> render_change()

      refute html =~ "has invalid format"
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event save"
  # ---------------------------------------------------------------------------

  describe "handle_event save" do
    test "owner can update account name and slug successfully", %{conn: conn} do
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
    end

    test "shows success flash after saving valid settings", %{conn: conn} do
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

      assert html =~ "saved"
    end

    test "admin can update account name and slug successfully", %{conn: conn} do
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

    test "shows changeset errors when saving with invalid slug", %{conn: conn} do
      user = user_fixture()
      _account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("form[phx-submit='save']", %{
          "account" => %{"name" => "Valid Name", "slug" => "INVALID SLUG!"}
        })
        |> render_submit()

      assert html =~ "has invalid format"
    end

    test "shows changeset errors when saving with blank name", %{conn: conn} do
      user = user_fixture()
      _account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("form[phx-submit='save']", %{
          "account" => %{"name" => "", "slug" => "valid-slug"}
        })
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event transfer_ownership"
  # ---------------------------------------------------------------------------

  describe "handle_event transfer_ownership" do
    test "owner can transfer ownership to another member", %{conn: conn} do
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
    end

    test "shows success flash after transferring ownership", %{conn: conn} do
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
    end

    test "demotes previous owner to admin after transfer", %{conn: conn} do
      owner = user_fixture()
      account = team_account_fixture(owner)
      target_user = user_fixture()
      insert_member!(account, target_user, :admin)
      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      lv
      |> form("[data-role='transfer-ownership']", %{"user_id" => target_user.id})
      |> render_submit()

      new_role =
        Repo.get_by!(AccountMember, account_id: account.id, user_id: owner.id)
        |> Map.fetch!(:role)

      assert new_role == :admin
    end

    test "hides transfer ownership section after ownership is transferred to current user", %{
      conn: conn
    } do
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

      refute has_element?(lv, "[data-role='transfer-ownership']")

      assert html =~ "transferred"
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event delete_account"
  # ---------------------------------------------------------------------------

  describe "handle_event delete_account" do
    test "owner can delete a team account with correct name and password", %{conn: conn} do
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

    test "shows error flash when account name does not match", %{conn: conn} do
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

    test "shows error flash when password is incorrect", %{conn: conn} do
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

    test "personal accounts cannot be deleted", %{conn: conn} do
      user = user_with_password_fixture()
      account = personal_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "[data-role='delete-account']")

      assert account.type == "personal"
    end

    test "non-owner members do not see the delete account form", %{conn: conn} do
      owner = user_fixture()
      account = team_account_fixture(owner)
      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      conn = log_in_user(conn, admin_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "[data-role='delete-account']")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_info"
  # ---------------------------------------------------------------------------

  describe "handle_info" do
    test "refreshes account data when the account is updated via PubSub", %{conn: conn} do
      user = user_fixture()
      account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      updated_account = %{account | name: "PubSub Updated Name"}
      send(lv.pid, {:updated, updated_account})

      html = render(lv)
      assert html =~ "PubSub Updated Name"
    end

    test "handles account deleted message and redirects to accounts list", %{conn: conn} do
      user = user_fixture()
      account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      send(lv.pid, {:deleted, account})

      assert_redirect(lv, "/accounts")
    end
  end
end
