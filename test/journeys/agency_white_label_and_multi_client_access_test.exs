defmodule MetricFlowWeb.Journeys.AgencyWhiteLabelAndMultiClientAccessTest do
  @moduledoc """
  Journey 5 from `.code_my_spec/qa/journey_plan.md`: a user who belongs to
  several accounts with different roles can see them all, switch between
  them, and gets a restricted view on an account where they are read_only.
  """

  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Repo

  defp unique_slug, do: "account-#{System.unique_integer([:positive])}"

  defp insert_account!(user, attrs) do
    defaults = %{
      name: "Test Account",
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

  test "shows multiple accounts with different roles, switches between them, and restricts a read_only account", %{
    conn: conn
  } do
    user = user_fixture()

    owned = insert_account!(user, %{name: "QA Agency 1101", type: "agency"})
    insert_member!(owned, user, :owner)

    read_only_account = insert_account!(user, %{name: "Client Read Only"})
    insert_member!(read_only_account, user, :read_only)

    conn = log_in_user(conn, user)

    # Step 2-3: both accounts listed with their respective roles
    {:ok, lv, accounts_html} = live(conn, ~p"/app/accounts")
    assert accounts_html =~ owned.name
    assert accounts_html =~ "owner"
    assert accounts_html =~ read_only_account.name
    assert accounts_html =~ "read_only"

    # Which account starts active is whichever membership was touched most
    # recently, with no deterministic tiebreak between two freshly-inserted
    # rows — so make `owned` active first if it isn't already.
    unless has_element?(
             lv,
             "[data-role='account-card'][data-account-id='#{owned.id}'][data-active='true']"
           ) do
      lv
      |> element("[data-role='switch-account'][phx-value-account_id='#{owned.id}']")
      |> render_click()
    end

    # Step 6: switch to the read_only account
    html =
      lv
      |> element("[data-role='switch-account'][phx-value-account_id='#{read_only_account.id}']")
      |> render_click()

    assert html =~ "Switched to"

    assert has_element?(
             lv,
             "[data-role='account-card'][data-account-id='#{read_only_account.id}'][data-active='true']"
           )

    # Step 6 (cont.): restricted UI on the members page for a read_only member
    {:ok, members_lv, members_html} = live(conn, ~p"/app/accounts/members")
    refute has_element?(members_lv, "[data-role='members-list']")
    refute members_html =~ "Invite Members"

    # Step 8: switch back to the owned account
    html =
      lv
      |> element("[data-role='switch-account'][phx-value-account_id='#{owned.id}']")
      |> render_click()

    assert html =~ "Switched to"

    assert has_element?(
             lv,
             "[data-role='account-card'][data-account-id='#{owned.id}'][data-active='true']"
           )
  end
end
