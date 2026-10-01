defmodule MetricFlowWeb.Journeys.AccountAdministrationAndTeamManagementTest do
  @moduledoc """
  Journey 2 from `.code_my_spec/qa/journey_plan.md`: an owner manages team
  members, sends and cancels an invitation, and edits account settings. A
  non-owner member sees restricted controls on the same account.
  """

  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Repo

  defp unique_slug, do: "account-#{System.unique_integer([:positive])}"

  defp insert_account!(user, attrs \\ %{}) do
    defaults = %{
      name: "QA Test Account",
      slug: unique_slug(),
      type: "client",
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

  test "owner manages members, invitations, and settings; non-owner sees restrictions", %{conn: conn} do
    owner = user_fixture()
    account = insert_account!(owner)
    insert_member!(account, owner, :owner)
    member = user_fixture()
    insert_member!(account, member, :read_only)

    owner_conn = log_in_user(conn, owner)

    # Step 4: member list renders with role column
    {:ok, _lv, members_html} = live(owner_conn, ~p"/app/accounts/members")
    assert members_html =~ member.email
    assert members_html =~ "read_only"

    # Step 5: owner changes the member's role
    {:ok, members_lv, _html} = live(owner_conn, ~p"/app/accounts/members")

    html =
      members_lv
      |> element("[data-role='member-row'][data-user-id='#{member.id}'] form")
      |> render_submit(%{"role" => "admin", "user_id" => member.id})

    assert html =~ "admin"

    # Step 6-8: send an invitation, verify it's pending, then cancel it
    {:ok, invite_lv, _html} = live(owner_conn, ~p"/app/accounts/invitations")

    html =
      invite_lv
      |> form("form[phx-submit='send_invitation']", %{
        "invitation" => %{"email" => "journey2-invitee@example.com", "role" => "admin"}
      })
      |> render_submit()

    assert html =~ "Invitation sent to journey2-invitee@example.com"
    assert has_element?(invite_lv, "[data-role='invitation-email']", "journey2-invitee@example.com")

    html =
      invite_lv
      |> element("[data-role='cancel-invitation']")
      |> render_click()

    refute has_element?(invite_lv, "[data-role='invitation-email']", "journey2-invitee@example.com")
    assert html =~ "cancelled"

    # Step 10-11: edit account settings
    {:ok, settings_lv, _html} = live(owner_conn, ~p"/app/accounts/settings")

    html =
      settings_lv
      |> form("form[phx-submit='save']", %{
        "account" => %{"name" => "QA Journey2 Renamed", "slug" => account.slug}
      })
      |> render_submit()

    assert html =~ "QA Journey2 Renamed"
    assert html =~ "saved"

    # Step 12-14: the non-owner member sees their role, but no ownership controls
    member_conn = log_in_user(conn, member)

    {:ok, _lv, accounts_html} = live(member_conn, ~p"/app/accounts")
    assert accounts_html =~ "QA Journey2 Renamed"

    {:ok, _settings_lv, settings_html} = live(member_conn, ~p"/app/accounts/settings")
    refute settings_html =~ "Transfer Ownership"
    refute settings_html =~ "Danger Zone"
  end
end
