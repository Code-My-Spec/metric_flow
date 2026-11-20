defmodule MetricFlowWeb.AgencyLive.ClientsTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.AgenciesFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Repo

  defp unique_slug, do: "account-#{System.unique_integer([:positive])}"

  defp insert_account!(user, attrs) do
    defaults = %{
      name: "Test Account",
      slug: unique_slug(),
      type: "agency",
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

  defp agency_owner_with_login(conn) do
    user = user_fixture()
    agency = insert_account!(user, %{name: "Anderson the Fish"})
    insert_member!(agency, user, :owner)
    {log_in_user(conn, user), user, agency}
  end

  describe "with no clients" do
    test "renders an empty state that explains how to add the first client", %{conn: conn} do
      {conn, _user, _agency} = agency_owner_with_login(conn)

      {:ok, lv, html} = live(conn, ~p"/app/agency/clients")

      assert has_element?(lv, "[data-role='clients-empty-state']")
      refute has_element?(lv, "[data-role='client-card']")

      empty_html = lv |> element("[data-role='clients-empty-state']") |> render()
      assert empty_html =~ "Invite a client"
      assert empty_html =~ "referral link"

      assert html =~ "Invite a client"
    end
  end

  describe "inviting a client is the primary action" do
    test "the invite button uses the brand-gradient primary style and reveals a referral link",
         %{conn: conn} do
      {conn, _user, _agency} = agency_owner_with_login(conn)

      {:ok, lv, _html} = live(conn, ~p"/app/agency/clients")

      assert has_element?(lv, "[data-role='invite-client'].btn-brand-gradient")
      refute has_element?(lv, "[data-role='referral-link']")

      lv |> element("[data-role='invite-client']") |> render_click()

      assert has_element?(lv, "[data-role='referral-link']")
    end
  end

  describe "with clients" do
    test "renders one card per client with name, data health, last activity, and a link",
         %{conn: conn} do
      {conn, _user, agency} = agency_owner_with_login(conn)

      client_owner = user_fixture()

      client =
        insert_account!(client_owner, %{
          name: "Anderson Retail Co.",
          type: "client",
          originator_user_id: client_owner.id
        })

      agency_client_access_grant_fixture(agency.id, client.id, %{
        access_level: :admin,
        origination_status: :originator
      })

      {:ok, lv, _html} = live(conn, ~p"/app/agency/clients")

      refute has_element?(lv, "[data-role='clients-empty-state']")

      card = lv |> element("[data-role='client-card']") |> render()
      assert card =~ "Anderson Retail Co."
      assert card =~ "Data health"
      assert card =~ "Last activity"

      assert has_element?(
               lv,
               "[data-role='client-card'] [data-role='client-data-health']"
             )

      assert has_element?(
               lv,
               "[data-role='client-card'] [data-role='client-last-activity']"
             )

      # Clicking the card takes the owner into that client's workspace.
      assert {:error, {:live_redirect, %{to: "/app/dashboard"}}} =
               lv
               |> element("[data-role='client-card'] button")
               |> render_click()
    end
  end
end
