defmodule MetricFlowWeb.AccountTransferLive.AcceptTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts
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

  defp account_fixture(user, attrs) do
    account = insert_account!(user, attrs)
    insert_member!(account, user, :owner)
    account
  end

  defp pending_transfer_to(member, owner, account, opts \\ []) do
    remain_admin = Keyword.get(opts, :remain_admin, false)
    insert_member!(account, member, :admin)
    scope = MetricFlow.Users.Scope.for_user(owner)

    {:ok, transfer} =
      Accounts.initiate_ownership_transfer(scope, account.id, %{
        "transfer_target" => "existing",
        "user_id" => to_string(member.id),
        "remain_admin" => to_string(remain_admin)
      })

    transfer
  end

  describe "accept button follows Anderson BI design" do
    test "accept-transfer-btn carries the Anderson BI btn-brand-gradient class",
         %{conn: conn} do
      owner = user_fixture()
      member = user_fixture()
      account = account_fixture(owner, %{name: "Anderson Retail Co."})
      transfer = pending_transfer_to(member, owner, account)
      conn = log_in_user(conn, member)

      {:ok, lv, _html} = live(conn, ~p"/account_transfers/#{transfer.token}")

      accept_html = lv |> element("[data-role='accept-transfer-btn']") |> render()

      assert accept_html =~ "btn-brand-gradient",
             "the accept button must use the Anderson BI brand-gradient primary style"
    end
  end

  describe "page explains what changes on accepting the transfer" do
    test "page names the account, the initiator, and spells out the ownership change",
         %{conn: conn} do
      owner = user_fixture()
      member = user_fixture()
      account = account_fixture(owner, %{name: "Anderson Retail Co."})
      transfer = pending_transfer_to(member, owner, account)
      conn = log_in_user(conn, member)

      {:ok, _lv, html} = live(conn, ~p"/account_transfers/#{transfer.token}")

      assert html =~ "Anderson Retail Co."
      assert html =~ owner.email
      assert html =~ "owner"
    end
  end

  describe "accepting the transfer still works" do
    test "clicking accept redirects to account settings with a success flash",
         %{conn: conn} do
      owner = user_fixture()
      member = user_fixture()
      account = account_fixture(owner, %{name: "Anderson Retail Co."})
      transfer = pending_transfer_to(member, owner, account)
      conn = log_in_user(conn, member)

      {:ok, lv, _html} = live(conn, ~p"/account_transfers/#{transfer.token}")

      lv |> element("[data-role='accept-transfer-btn']") |> render_click()
      flash = assert_redirect(lv, "/app/accounts/settings")

      assert flash["info"] =~ "owner"
    end
  end

  describe "unauthenticated visitor sees the log-in and register buttons" do
    test "log-in-to-confirm-btn and register-to-confirm-btn are rendered when logged out",
         %{conn: conn} do
      owner = user_fixture()
      member = user_fixture()
      account = account_fixture(owner, %{name: "Anderson Retail Co."})
      transfer = pending_transfer_to(member, owner, account)

      {:ok, lv, _html} = live(conn, ~p"/account_transfers/#{transfer.token}")

      assert has_element?(lv, "[data-role='log-in-to-confirm-btn']")
      assert has_element?(lv, "[data-role='register-to-confirm-btn']")
      refute has_element?(lv, "[data-role='accept-transfer-btn']")
    end
  end
end
