defmodule MetricFlowWeb.InvitationLive.SendTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import ExUnit.CaptureLog

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Invitations
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
    |> AccountMember.changeset(%{account_id: account.id, user_id: user.id, role: role})
    |> Repo.insert!()
  end

  defp account_fixture(user, attrs \\ %{}) do
    account = insert_account!(user, attrs)
    insert_member!(account, user, :owner)
    account
  end

  defp invitation_fixture(account, invited_by_user, invited_email, role \\ :read_only) do
    {:ok, invitation} =
      Invitations.create_invitation(%{
        account_id: account.id,
        invited_by_user_id: invited_by_user.id,
        email: invited_email,
        role: role
      })

    invitation
  end

  # ---------------------------------------------------------------------------
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders invitation page with send form and pending invitations for owner" do
    test "shows form and pending section", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user, %{name: "Acme Corp"})
      conn = log_in_user(conn, user)

      {:ok, lv, html} = live(conn, ~p"/accounts/invitations")

      assert html =~ "Invite Members"
      assert html =~ "Acme Corp"
      assert html =~ "Send an Invitation"
      assert has_element?(lv, "[data-role='invite-form-section']")
      assert has_element?(lv, "[data-role='pending-invitations']")
    end
  end

  describe "redirects non-owner/admin users to members page with error flash" do
    test "redirects read_only member", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      reader = user_fixture()
      insert_member!(account, reader, :read_only)
      conn = log_in_user(conn, reader)

      capture_log(fn ->
        assert {:error, {:redirect, %{to: "/accounts/members", flash: flash}}} =
                 live(conn, ~p"/accounts/invitations")

        assert flash["error"] =~ "You do not have permission to invite members."
      end)
    end

    test "redirects account_manager", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      manager = user_fixture()
      insert_member!(account, manager, :account_manager)
      conn = log_in_user(conn, manager)

      capture_log(fn ->
        assert {:error, {:redirect, %{to: "/accounts/members", flash: flash}}} =
                 live(conn, ~p"/accounts/invitations")

        assert flash["error"] =~ "You do not have permission to invite members."
      end)
    end
  end

  describe "live-validates invitation form fields on change" do
    test "shows error for invalid email", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/invitations")

      html =
        lv
        |> form("form[phx-submit='send_invitation']", %{
          "invitation" => %{"email" => "not-an-email", "role" => "read_only"}
        })
        |> render_change()

      assert html =~ "must be a valid email address"
    end
  end

  describe "sends invitation and shows success flash with recipient email" do
    test "sends and shows flash", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/invitations")

      html =
        lv
        |> form("form[phx-submit='send_invitation']", %{
          "invitation" => %{"email" => "newmember@example.com", "role" => "read_only"}
        })
        |> render_submit()

      assert html =~ "Invitation sent to newmember@example.com"
      assert has_element?(lv, "[data-role='invitation-email']", "newmember@example.com")
    end
  end

  describe "shows changeset errors when submitting invalid invitation data" do
    test "shows error for blank email", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/invitations")

      html =
        lv
        |> form("form[phx-submit='send_invitation']", %{
          "invitation" => %{"email" => "", "role" => "read_only"}
        })
        |> render_submit()

      assert html =~ "can&#39;t be blank"
      refute html =~ "Invitation sent"
    end

    test "shows error for invalid email format", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/invitations")

      html =
        lv
        |> form("form[phx-submit='send_invitation']", %{
          "invitation" => %{"email" => "bad-email", "role" => "read_only"}
        })
        |> render_submit()

      assert html =~ "must be a valid email address"
    end
  end

  describe "displays pending invitations list with email, role badge, and cancel button" do
    test "shows pending invitation details", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      _invitation = invitation_fixture(account, user, "pending@example.com", :admin)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/invitations")

      assert has_element?(lv, "[data-role='pending-invitation-row']")
      assert has_element?(lv, "[data-role='invitation-email']", "pending@example.com")
      assert has_element?(lv, "[data-role='cancel-invitation']")
    end
  end

  describe "cancels a pending invitation and removes it from the list" do
    test "cancels and removes invitation", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      _invitation = invitation_fixture(account, user, "tobe.cancelled@example.com")
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/invitations")

      assert has_element?(lv, "[data-role='invitation-email']", "tobe.cancelled@example.com")

      html =
        lv
        |> element("[data-role='cancel-invitation']")
        |> render_click()

      assert html =~ "Invitation to tobe.cancelled@example.com cancelled."
      refute has_element?(lv, "[data-role='invitation-email']", "tobe.cancelled@example.com")
    end
  end

  describe "shows empty state when no pending invitations exist" do
    test "displays no pending invitations message", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts/invitations")

      assert html =~ "No pending invitations."
    end
  end
end
