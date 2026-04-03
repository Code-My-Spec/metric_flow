defmodule MetricFlowWeb.InvitationLive.AcceptTest do
  use MetricFlowTest.ConnCase, async: true

  import Ecto.Query
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
    defaults = %{name: "Test Account", slug: unique_slug(), type: "team", originator_user_id: user.id}

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

  defp expired_invitation_fixture(account, invited_by_user, invited_email) do
    {:ok, invitation} =
      Invitations.create_invitation(%{
        account_id: account.id,
        invited_by_user_id: invited_by_user.id,
        email: invited_email,
        role: :read_only
      })

    invitation_id = invitation.id

    Repo.update_all(
      from(i in Invitations.Invitation, where: i.id == ^invitation_id),
      set: [inserted_at: ~N[2000-01-01 00:00:00]]
    )

    invitation
  end

  # ---------------------------------------------------------------------------
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders invitation details with account name, inviting user, and role for authenticated user" do
    test "shows invitation details", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner, %{name: "Acme Corp"})
      invitee = user_fixture()
      invitation = invitation_fixture(account, owner, invitee.email, :admin)
      conn = log_in_user(conn, invitee)

      {:ok, _lv, html} = live(conn, ~p"/invitations/#{invitation.token}")

      assert html =~ "invited"
      assert html =~ "Acme Corp"
      assert html =~ owner.email
      assert html =~ "Admin"
    end
  end

  describe "shows accept and decline buttons for authenticated user" do
    test "displays accept and decline", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      invitee = user_fixture()
      invitation = invitation_fixture(account, owner, invitee.email)
      conn = log_in_user(conn, invitee)

      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invitation.token}")

      assert has_element?(lv, "[data-role='accept-btn']")
      assert has_element?(lv, "[data-role='decline-btn']")
      refute has_element?(lv, "[data-role='log-in-btn']")
      refute has_element?(lv, "[data-role='register-btn']")
    end
  end

  describe "shows log in and register buttons for unauthenticated user" do
    test "displays log in and register", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      invitation = invitation_fixture(account, owner, "guest@example.com")

      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invitation.token}")

      assert has_element?(lv, "[data-role='log-in-btn']")
      assert has_element?(lv, "[data-role='register-btn']")
      refute has_element?(lv, "[data-role='accept-btn']")
      refute has_element?(lv, "[data-role='decline-btn']")
    end
  end

  describe "accepts invitation and redirects to accounts with success flash" do
    test "accepts and redirects", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner, %{name: "Acme Corp"})
      invitee = user_fixture()
      invitation = invitation_fixture(account, owner, invitee.email)
      conn = log_in_user(conn, invitee)

      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invitation.token}")

      lv |> element("[data-role='accept-btn']") |> render_click()
      flash = assert_redirect(lv, "/accounts")

      assert flash["info"] =~ "You now have access to Acme Corp"
    end
  end

  describe "declines invitation and redirects to root with info flash" do
    test "declines and redirects", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      invitee = user_fixture()
      invitation = invitation_fixture(account, owner, invitee.email)
      conn = log_in_user(conn, invitee)

      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invitation.token}")

      lv |> element("[data-role='decline-btn']") |> render_click()
      flash = assert_redirect(lv, "/")

      assert flash["info"] =~ "Invitation declined"
    end
  end

  describe "shows error and redirects for invalid or already-used token" do
    test "redirects for invalid token", %{conn: conn} do
      capture_log(fn ->
        assert {:error, {:redirect, %{to: "/", flash: flash}}} =
                 live(conn, ~p"/invitations/nonexistent-token-abc123")

        assert flash["error"] =~ "invalid or has already been used"
      end)
    end

    test "redirects for already-used token", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      invitee = user_fixture()
      invitation = invitation_fixture(account, owner, invitee.email)
      invitee_scope = Scope.for_user(invitee)

      {:ok, _membership} = Invitations.accept_invitation(invitee_scope, invitation.token)

      capture_log(fn ->
        assert {:error, {:redirect, %{to: "/", flash: flash}}} =
                 live(conn, ~p"/invitations/#{invitation.token}")

        assert flash["error"] =~ "invalid or has already been used"
      end)
    end
  end

  describe "shows error and redirects for expired invitation token" do
    test "redirects for expired token", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      invitation = expired_invitation_fixture(account, owner, "guest@example.com")

      capture_log(fn ->
        assert {:error, {:redirect, %{to: "/", flash: flash}}} =
                 live(conn, ~p"/invitations/#{invitation.token}")

        assert flash["error"] =~ "expired"
      end)
    end
  end

  describe "shows already a member flash when accepting a duplicate invitation" do
    test "shows already member flash", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      invitee = user_fixture()
      insert_member!(account, invitee, :read_only)
      invitation = invitation_fixture(account, owner, invitee.email)
      conn = log_in_user(conn, invitee)

      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invitation.token}")

      lv |> element("[data-role='accept-btn']") |> render_click()
      flash = assert_redirect(lv, "/accounts")

      assert flash["info"] =~ "already have access"
    end
  end
end
