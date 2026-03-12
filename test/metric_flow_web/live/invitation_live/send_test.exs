defmodule MetricFlowWeb.InvitationLive.SendTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import ExUnit.CaptureLog

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Invitations
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

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
  # describe "mount/3"
  # ---------------------------------------------------------------------------

  describe "mount/3" do
    test "renders invite form and pending invitations list for an owner", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user, %{name: "Acme Corp"})
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts/invitations")

      assert html =~ "Invite Members"
      assert html =~ "Acme Corp"
      assert html =~ "Send an Invitation"
    end

    test "assigns page_title to Invite Members", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/invitations")

      assert page_title(lv) =~ "Invite Members"
    end

    test "renders invite form and pending invitations list for an admin", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      admin = user_fixture()
      insert_member!(account, admin, :admin)
      conn = log_in_user(conn, admin)

      {:ok, _lv, html} = live(conn, ~p"/accounts/invitations")

      assert html =~ "Invite Members"
      assert html =~ "Send an Invitation"
    end

    test "shows the invite form section", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/invitations")

      assert has_element?(lv, "[data-role='invite-form-section']")
    end

    test "shows the pending invitations section", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/invitations")

      assert has_element?(lv, "[data-role='pending-invitations']")
    end

    test "shows empty state when no pending invitations exist", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts/invitations")

      assert html =~ "No pending invitations."
    end

    test "lists existing pending invitations on mount", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      _invitation = invitation_fixture(account, user, "pending@example.com", :admin)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/invitations")

      assert has_element?(lv, "[data-role='pending-invitation-row']")
      assert has_element?(lv, "[data-role='invitation-email']", "pending@example.com")
    end

    test "redirects non-owner/non-admin to /accounts/members with error flash", %{conn: conn} do
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

    test "redirects account_manager to /accounts/members with error flash", %{conn: conn} do
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

    test "redirects unauthenticated users to /users/log-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/accounts/invitations")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event validate"
  # ---------------------------------------------------------------------------

  describe "handle_event validate" do
    test "shows validation error for invalid email format", %{conn: conn} do
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

    test "clears validation error when a valid email is entered", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/invitations")

      html =
        lv
        |> form("form[phx-submit='send_invitation']", %{
          "invitation" => %{"email" => "valid@example.com", "role" => "read_only"}
        })
        |> render_change()

      refute html =~ "must be a valid email address"
    end

    test "does not persist any data on validate", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/invitations")

      lv
      |> form("form[phx-submit='send_invitation']", %{
        "invitation" => %{"email" => "valid@example.com", "role" => "read_only"}
      })
      |> render_change()

      assert Invitations.list_invitations(%Scope{user: user}, account.id) == []
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event send_invitation"
  # ---------------------------------------------------------------------------

  describe "handle_event send_invitation" do
    test "sends invitation and shows success flash for a valid email", %{conn: conn} do
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
    end

    test "appends new invitation to the pending invitations list after success", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/invitations")

      lv
      |> form("form[phx-submit='send_invitation']", %{
        "invitation" => %{"email" => "newmember@example.com", "role" => "read_only"}
      })
      |> render_submit()

      assert has_element?(lv, "[data-role='invitation-email']", "newmember@example.com")
    end

    test "resets the form to empty after a successful submission", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/invitations")

      lv
      |> form("form[phx-submit='send_invitation']", %{
        "invitation" => %{"email" => "newmember@example.com", "role" => "read_only"}
      })
      |> render_submit()

      refute has_element?(lv, "input[name='invitation[email]'][value='newmember@example.com']")
    end

    test "shows error flash when email is blank", %{conn: conn} do
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

      refute html =~ "Invitation sent"
      assert html =~ "can&#39;t be blank"
    end

    test "shows changeset errors when email format is invalid and does not put flash", %{
      conn: conn
    } do
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

      refute html =~ "Invitation sent"
      assert html =~ "must be a valid email address"
    end

    test "owner is not an available role in the invitation form", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts/invitations")

      refute html =~ "<option value=\"owner\""
    end

    test "admin can send an invitation successfully", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      admin = user_fixture()
      insert_member!(account, admin, :admin)
      conn = log_in_user(conn, admin)

      {:ok, lv, _html} = live(conn, ~p"/accounts/invitations")

      html =
        lv
        |> form("form[phx-submit='send_invitation']", %{
          "invitation" => %{"email" => "invited@example.com", "role" => "read_only"}
        })
        |> render_submit()

      assert html =~ "Invitation sent to invited@example.com"
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event cancel_invitation"
  # ---------------------------------------------------------------------------

  describe "handle_event cancel_invitation" do
    test "removes cancelled invitation from the list and shows info flash", %{conn: conn} do
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

    test "shows error flash when cancellation fails due to already-used invitation", %{
      conn: conn
    } do
      user = user_fixture()
      account = account_fixture(user)
      invitation = invitation_fixture(account, user, "willbe.accepted@example.com")
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/invitations")

      # Accept the invitation so the token is no longer pending, causing cancel to fail
      invitee = user_fixture(%{email: "willbe.accepted@example.com"})
      invitee_scope = Scope.for_user(invitee)
      {:ok, _} = Invitations.accept_invitation(invitee_scope, invitation.token)

      html =
        lv
        |> element("[data-role='cancel-invitation']")
        |> render_click()

      assert html =~ "Could not cancel invitation. Please try again."
    end

    test "only shows cancel button for pending invitations", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      _invitation = invitation_fixture(account, user, "pending@example.com")
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/invitations")

      assert has_element?(lv, "[data-role='cancel-invitation']")
    end

    test "admin can cancel a pending invitation", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      admin = user_fixture()
      insert_member!(account, admin, :admin)
      _invitation = invitation_fixture(account, owner, "invited@example.com")
      conn = log_in_user(conn, admin)

      {:ok, lv, _html} = live(conn, ~p"/accounts/invitations")

      html =
        lv
        |> element("[data-role='cancel-invitation']")
        |> render_click()

      assert html =~ "Invitation to invited@example.com cancelled."
      refute has_element?(lv, "[data-role='invitation-email']", "invited@example.com")
    end
  end
end
