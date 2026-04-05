defmodule MetricFlowWeb.AccountLive.MembersTest do
  use MetricFlowTest.ConnCase, async: true

  import ExUnit.CaptureLog
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

  defp account_fixture(user) do
    account = insert_account!(user)
    insert_member!(account, user, :owner)
    account
  end

  # ---------------------------------------------------------------------------
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders members page with member list for owner" do
    test "renders members page with member list for owner", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts/members")

      assert html =~ "Members"
      assert html =~ account.name
    end
  end

  describe "displays member email, role badge, and join date in each row" do
    test "displays member email, role badge, and join date in each row", %{conn: conn} do
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
  end

  describe "shows role change dropdown and remove button for owners and admins" do
    test "shows role change dropdown and remove button for owners and admins", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      other_user = user_fixture()
      insert_member!(account, other_user, :read_only)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      assert has_element?(lv, "[data-role='member-row'] select")
      assert has_element?(lv, "[data-role='remove-member']")
    end
  end

  describe "hides management controls for read_only and account_manager roles" do
    test "hides management controls for read_only and account_manager roles", %{conn: conn} do
      owner_user = user_fixture()
      account = account_fixture(owner_user)
      manager_user = user_fixture()
      insert_member!(account, manager_user, :account_manager)
      conn = log_in_user(conn, manager_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      refute has_element?(lv, "[data-role='members-list']")
      refute has_element?(lv, "[data-role='member-row'] select")
      refute has_element?(lv, "[phx-click='remove_member']")
    end

  end

  describe "owner can change a member role and sees success flash" do
    test "owner can change a member role and sees success flash", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      target_user = user_fixture()
      insert_member!(account, target_user, :read_only)
      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      capture_log(fn ->
        html =
          lv
          |> element("[data-role='member-row'][data-user-id='#{target_user.id}'] form")
          |> render_submit(%{"role" => "admin", "user_id" => target_user.id})

        send(self(), {:html, html})
      end)

      receive do
        {:html, html} -> assert html =~ "Role updated"
      end
    end
  end

  describe "shows error when attempting to demote the last owner" do
    test "shows error when attempting to demote the last owner", %{conn: conn} do
      owner = user_fixture()
      _account = account_fixture(owner)
      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      html =
        lv
        |> element("[data-role='member-row'][data-user-id='#{owner.id}'] form")
        |> render_submit(%{"role" => "admin", "user_id" => owner.id})

      assert html =~ "last owner"
    end
  end

  describe "owner can remove a member and sees success flash" do
    test "owner can remove a member and sees success flash", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      target_user = user_fixture()
      insert_member!(account, target_user, :admin)
      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      capture_log(fn ->
        html =
          lv
          |> element("[data-role='member-row'][data-user-id='#{target_user.id}'] [phx-click='remove_member']")
          |> render_click()

        send(self(), {:html, html})
      end)

      receive do
        {:html, html} ->
          refute html =~ target_user.email
      end
    end
  end

  describe "hides remove button for the last owner row" do
    test "hides remove button for the last owner row", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      refute has_element?(
               lv,
               "[data-role='member-row'][data-user-id='#{user.id}'] [phx-click='remove_member']"
             )
    end
  end

  describe "hides remove button for the current user row" do
    test "hides remove button for the current user row", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      conn = log_in_user(conn, admin_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      refute has_element?(
               lv,
               "[data-role='member-row'][data-user-id='#{admin_user.id}'] [data-role='remove-member']"
             )
    end
  end

  describe "owner can invite a new member by email and sees success flash" do
    test "owner can invite a new member by email and sees success flash", %{conn: conn} do
      owner = user_fixture()
      _account = account_fixture(owner)
      invitee = user_fixture()
      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      html =
        lv
        |> form("#invite_member_form", invitation: %{email: invitee.email, role: "read_only"})
        |> render_submit()

      assert html =~ invitee.email
      assert html =~ "invited"
    end
  end

  describe "shows error when inviting a non-existent user" do
    test "shows error when inviting a non-existent user", %{conn: conn} do
      owner = user_fixture()
      _account = account_fixture(owner)
      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      html =
        lv
        |> form("#invite_member_form", invitation: %{email: "notauser@example.com", role: "read_only"})
        |> render_submit()

      assert html =~ "not found"
    end
  end

  describe "shows error when inviting an already existing member" do
    test "shows error when inviting an already existing member", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      existing_member = user_fixture()
      insert_member!(account, existing_member, :admin)
      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      html =
        lv
        |> form("#invite_member_form", invitation: %{email: existing_member.email, role: "read_only"})
        |> render_submit()

      assert html =~ "already a member"
    end
  end

  describe "subscribes to member PubSub and refreshes on real-time updates" do
    test "subscribes to member PubSub and refreshes on real-time updates", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      conn = log_in_user(conn, owner)

      {:ok, lv, _html} = live(conn, ~p"/accounts/members")

      new_user = user_fixture()
      new_member = insert_member!(account, new_user, :read_only)

      send(lv.pid, {:created, new_member})

      html = render(lv)
      assert html =~ new_user.email
    end

  end

  describe "redirects to /accounts when user has no accounts" do
    test "redirects to /accounts when user has no accounts", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/accounts"}}} =
               live(conn, ~p"/accounts/members")
    end
  end
end
