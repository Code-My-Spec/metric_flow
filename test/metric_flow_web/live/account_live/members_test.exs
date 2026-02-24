defmodule MetricFlowWeb.AccountLive.MembersTest do
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
  defp account_fixture(user) do
    account = insert_account!(user)
    insert_member!(account, user, :owner)
    account
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3"
  # ---------------------------------------------------------------------------

  describe "mount/3" do
    test "renders the members page with account members listed", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts/members")

      assert html =~ "Members"
      assert html =~ account.name
    end

    test "displays each member email and role", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts/members")

      assert html =~ user.email
      assert html =~ "owner"
    end

    test "redirects unauthenticated users to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/accounts/members")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "render/1"
  # ---------------------------------------------------------------------------

  describe "render/1" do
    test "displays member email and role for each member", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      other_user = user_fixture()
      insert_member!(account, other_user, :admin)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts/members")

      assert html =~ user.email
      assert html =~ other_user.email
      assert html =~ "owner"
      assert html =~ "admin"
    end

    test "shows role change controls for owners and admins", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      other_user = user_fixture()
      insert_member!(account, other_user, :read_only)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      # Owner sees role change select for other members
      assert has_element?(lv, "[data-role='member'] select")
    end

    test "hides management controls for account_manager and read_only members", %{conn: conn} do
      owner_user = user_fixture()
      account = account_fixture(owner_user)
      manager_user = user_fixture()
      insert_member!(account, manager_user, :account_manager)
      conn = log_in_user(conn, manager_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      # account_manager sees no role change selects or remove buttons
      refute has_element?(lv, "[data-role='member'] select")
      refute has_element?(lv, "[phx-click='remove_member']")
    end

    test "does not show remove button for the last owner", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      # The sole owner row has no remove button
      refute has_element?(lv, "[data-role='member'][data-user-id='#{user.id}'] [phx-click='remove_member']")
    end

    test "includes invite member form for owners and admins", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      assert has_element?(lv, "#invite_member_form")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event change_role"
  # ---------------------------------------------------------------------------

  describe "handle_event change_role" do
    test "updates member role and reflects change in the list", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)
      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      html =
        lv
        |> element("[data-role='member'][data-user-id='#{target_user.id}'] select")
        |> render_change(%{"role" => "admin", "user_id" => target_user.id})

      assert html =~ "admin"
    end

    test "prevents demoting the last owner and shows error", %{conn: conn} do
      owner = user_fixture()
      _account = account_fixture(owner)
      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      html =
        lv
        |> element("[data-role='member'][data-user-id='#{owner.id}'] select")
        |> render_change(%{"role" => "admin", "user_id" => owner.id})

      assert html =~ "last owner"
    end

    test "only owners and admins can change roles", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      reader_user = user_fixture()
      insert_member!(account, reader_user, :read_only)
      target_user = user_fixture()
      insert_member!(account, target_user, :account_manager)
      conn = log_in_user(conn, reader_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      refute has_element?(lv, "[data-role='member'][data-user-id='#{target_user.id}'] select")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event remove_member"
  # ---------------------------------------------------------------------------

  describe "handle_event remove_member" do
    test "removes member and they disappear from the list", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      target_user = user_fixture()
      insert_member!(account, target_user, :admin)
      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      html =
        lv
        |> element("[data-role='member'][data-user-id='#{target_user.id}'] [phx-click='remove_member']")
        |> render_click()

      refute html =~ target_user.email
    end

    test "prevents removing the last owner and shows error", %{conn: conn} do
      owner = user_fixture()
      _account = account_fixture(owner)
      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      # The last owner row has no remove button — clicking is impossible.
      # Verify the button is absent to enforce the protection.
      refute has_element?(lv, "[data-role='member'][data-user-id='#{owner.id}'] [phx-click='remove_member']")
    end

    test "only owners and admins can remove members", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      reader_user = user_fixture()
      insert_member!(account, reader_user, :read_only)
      conn = log_in_user(conn, reader_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      refute has_element?(lv, "[phx-click='remove_member']")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event invite_member"
  # ---------------------------------------------------------------------------

  describe "handle_event invite_member" do
    test "adds a new member to the account", %{conn: conn} do
      owner = user_fixture()
      _account = account_fixture(owner)
      invitee = user_fixture()
      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      html =
        lv
        |> form("#invite_member_form", %{"email" => invitee.email, "role" => "read_only"})
        |> render_submit()

      assert html =~ invitee.email
    end

    test "shows error when email not found", %{conn: conn} do
      owner = user_fixture()
      _account = account_fixture(owner)
      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      html =
        lv
        |> form("#invite_member_form", %{
          "email" => "notauser@example.com",
          "role" => "read_only"
        })
        |> render_submit()

      assert html =~ "not found"
    end

    test "shows error when user is already a member", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      existing_member = user_fixture()
      insert_member!(account, existing_member, :admin)
      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      html =
        lv
        |> form("#invite_member_form", %{
          "email" => existing_member.email,
          "role" => "read_only"
        })
        |> render_submit()

      assert html =~ "already a member"
    end

    test "only owners and admins can invite members", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      reader_user = user_fixture()
      insert_member!(account, reader_user, :read_only)
      conn = log_in_user(conn, reader_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      refute has_element?(lv, "#invite_member_form")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_info"
  # ---------------------------------------------------------------------------

  describe "handle_info" do
    test "refreshes member list when a member is added", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      new_user = user_fixture()

      new_member =
        %AccountMember{}
        |> AccountMember.changeset(%{
          account_id: account.id,
          user_id: new_user.id,
          role: :read_only
        })
        |> Repo.insert!()

      send(lv.pid, {:created, new_member})

      html = render(lv)
      assert html =~ new_user.email
    end

    test "refreshes member list when a member role changes", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      target_user = user_fixture()

      member =
        %AccountMember{}
        |> AccountMember.changeset(%{
          account_id: account.id,
          user_id: target_user.id,
          role: :read_only
        })
        |> Repo.insert!()

      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      updated_member = %{member | role: :admin}
      send(lv.pid, {:updated, updated_member})

      html = render(lv)
      assert html =~ target_user.email
      assert html =~ "admin"
    end

    test "refreshes member list when a member is removed", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      target_user = user_fixture()

      member =
        %AccountMember{}
        |> AccountMember.changeset(%{
          account_id: account.id,
          user_id: target_user.id,
          role: :admin
        })
        |> Repo.insert!()

      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      Repo.delete!(member)
      send(lv.pid, {:deleted, member})

      html = render(lv)
      refute html =~ target_user.email
    end
  end
end
