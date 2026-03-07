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

    # Backdate the inserted_at so the token is expired
    Repo.update_all(
      from(i in Invitations.Invitation, where: i.id == ^invitation_id),
      set: [inserted_at: ~N[2000-01-01 00:00:00]]
    )

    invitation
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3"
  # ---------------------------------------------------------------------------

  describe "mount/3" do
    test "renders invitation details for a valid token when user is authenticated", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner, %{name: "Acme Corp"})
      invitee = user_fixture()
      invitation = invitation_fixture(account, owner, invitee.email, :admin)
      conn = log_in_user(conn, invitee)

      {:ok, _lv, html} = live(conn, ~p"/invitations/#{invitation.token}")

      assert html =~ "You&#39;ve been invited"
      assert html =~ "Acme Corp"
      assert html =~ owner.email
      assert html =~ "Admin"
    end

    test "renders invitation details for a valid token when user is unauthenticated", %{
      conn: conn
    } do
      owner = user_fixture()
      account = account_fixture(owner, %{name: "Acme Corp"})
      invitation = invitation_fixture(account, owner, "guest@example.com", :read_only)

      {:ok, _lv, html} = live(conn, ~p"/invitations/#{invitation.token}")

      assert html =~ "You&#39;ve been invited"
      assert html =~ "Acme Corp"
      assert html =~ owner.email
    end

    test "assigns page_title to Accept Invitation", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      invitation = invitation_fixture(account, owner, "guest@example.com")

      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invitation.token}")

      assert page_title(lv) =~ "Accept Invitation"
    end

    test "redirects to / with error flash when token is not found", %{conn: conn} do
      capture_log(fn ->
        assert {:error, {:redirect, %{to: "/", flash: flash}}} =
                 live(conn, ~p"/invitations/nonexistent-token-abc123")

        assert flash["error"] =~ "invalid or has already been used"
      end)
    end

    test "redirects to / with error flash when invitation has already been used", %{conn: conn} do
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

    test "redirects to / with error flash when invitation has expired", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      invitation = expired_invitation_fixture(account, owner, "guest@example.com")

      capture_log(fn ->
        assert {:error, {:redirect, %{to: "/", flash: flash}}} =
                 live(conn, ~p"/invitations/#{invitation.token}")

        assert flash["error"] =~ "expired"
      end)
    end

    test "shows accept and decline buttons when user is authenticated", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      invitee = user_fixture()
      invitation = invitation_fixture(account, owner, invitee.email)
      conn = log_in_user(conn, invitee)

      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invitation.token}")

      assert has_element?(lv, "[data-role='accept-btn']")
      assert has_element?(lv, "[data-role='decline-btn']")
    end

    test "shows log in and register buttons when user is unauthenticated", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      invitation = invitation_fixture(account, owner, "guest@example.com")

      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invitation.token}")

      assert has_element?(lv, "[data-role='log-in-btn']")
      assert has_element?(lv, "[data-role='register-btn']")
    end

    test "does not show accept and decline buttons when user is unauthenticated", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      invitation = invitation_fixture(account, owner, "guest@example.com")

      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invitation.token}")

      refute has_element?(lv, "[data-role='accept-btn']")
      refute has_element?(lv, "[data-role='decline-btn']")
    end

    test "does not show log in and register buttons when user is authenticated", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      invitee = user_fixture()
      invitation = invitation_fixture(account, owner, invitee.email)
      conn = log_in_user(conn, invitee)

      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invitation.token}")

      refute has_element?(lv, "[data-role='log-in-btn']")
      refute has_element?(lv, "[data-role='register-btn']")
    end

    test "displays human-readable role label in invitation subtext", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      invitee = user_fixture()
      invitation = invitation_fixture(account, owner, invitee.email, :account_manager)
      conn = log_in_user(conn, invitee)

      {:ok, _lv, html} = live(conn, ~p"/invitations/#{invitation.token}")

      assert html =~ "Account Manager"
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event accept"
  # ---------------------------------------------------------------------------

  describe "handle_event accept" do
    test "redirects to /accounts with success flash after accepting invitation", %{conn: conn} do
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

    test "redirects to /accounts with info flash when user is already a member", %{conn: conn} do
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

    test "redirects to / with error flash when invitation has expired at accept time", %{
      conn: conn
    } do
      owner = user_fixture()
      account = account_fixture(owner)
      invitee = user_fixture()
      invitation = invitation_fixture(account, owner, invitee.email)
      conn = log_in_user(conn, invitee)

      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invitation.token}")

      invitation_id = invitation.id

      # Expire the invitation after mount but before accept
      Repo.update_all(
        from(i in Invitations.Invitation, where: i.id == ^invitation_id),
        set: [inserted_at: ~N[2000-01-01 00:00:00]]
      )

      lv |> element("[data-role='accept-btn']") |> render_click()
      flash = assert_redirect(lv, "/")

      assert flash["error"] =~ "expired"
    end

    test "redirects to / with error flash when invitation is not found at accept time", %{
      conn: conn
    } do
      owner = user_fixture()
      account = account_fixture(owner)
      invitee = user_fixture()
      invitation = invitation_fixture(account, owner, invitee.email)
      conn = log_in_user(conn, invitee)

      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invitation.token}")

      invitation_id = invitation.id

      # Delete the invitation after mount
      Repo.delete_all(from(i in Invitations.Invitation, where: i.id == ^invitation_id))

      lv |> element("[data-role='accept-btn']") |> render_click()
      flash = assert_redirect(lv, "/")

      assert flash["error"] =~ "no longer valid"
    end

    test "redirects with error when accept encounters deleted account (cascade deletes invitation)", %{
      conn: conn
    } do
      owner = user_fixture()
      account = account_fixture(owner)
      invitee = user_fixture()
      invitation = invitation_fixture(account, owner, invitee.email)
      conn = log_in_user(conn, invitee)

      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invitation.token}")

      # Deleting the account cascade-deletes the invitation, so accept
      # encounters :not_found when re-looking up the token
      account_id = account.id
      Repo.delete_all(from(m in AccountMember, where: m.account_id == ^account_id))
      Repo.delete_all(from(a in Account, where: a.id == ^account_id))

      lv |> element("[data-role='accept-btn']") |> render_click()
      flash = assert_redirect(lv, "/")

      assert flash["error"] =~ "no longer valid"
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event decline"
  # ---------------------------------------------------------------------------

  describe "handle_event decline" do
    test "redirects to / with info flash after declining invitation", %{conn: conn} do
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

    test "shows error flash and stays on page when decline fails", %{conn: conn} do
      owner = user_fixture()
      account = account_fixture(owner)
      invitee = user_fixture()
      invitation = invitation_fixture(account, owner, invitee.email)
      conn = log_in_user(conn, invitee)

      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invitation.token}")

      invitation_id = invitation.id

      # Delete the invitation after mount to force a not_found error on decline
      Repo.delete_all(from(i in Invitations.Invitation, where: i.id == ^invitation_id))

      html = lv |> element("[data-role='decline-btn']") |> render_click()

      assert html =~ "Something went wrong"
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event log_in_to_accept"
  # ---------------------------------------------------------------------------

  describe "handle_event log_in_to_accept" do
    test "navigates to log-in page with return_to param pointing to invitation URL", %{
      conn: conn
    } do
      owner = user_fixture()
      account = account_fixture(owner)
      invitation = invitation_fixture(account, owner, "guest@example.com")

      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invitation.token}")

      assert {:error, {:redirect, %{to: redirect_to}}} =
               lv |> element("[data-role='log-in-btn']") |> render_click()

      assert redirect_to =~ "/users/log-in"
      assert redirect_to =~ URI.encode("/invitations/#{invitation.token}")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event register_to_accept"
  # ---------------------------------------------------------------------------

  describe "handle_event register_to_accept" do
    test "navigates to register page with return_to param pointing to invitation URL", %{
      conn: conn
    } do
      owner = user_fixture()
      account = account_fixture(owner)
      invitation = invitation_fixture(account, owner, "guest@example.com")

      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invitation.token}")

      assert {:error, {:redirect, %{to: redirect_to}}} =
               lv |> element("[data-role='register-btn']") |> render_click()

      assert redirect_to =~ "/users/register"
      assert redirect_to =~ URI.encode("/invitations/#{invitation.token}")
    end
  end
end
