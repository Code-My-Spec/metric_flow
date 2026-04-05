defmodule MetricFlowWeb.AccountLive.IndexTest do
  use MetricFlowTest.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
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
    |> AccountMember.changeset(%{
      account_id: account.id,
      user_id: user.id,
      role: role
    })
    |> Repo.insert!()
  end

  defp team_account_fixture(user, attrs \\ %{}) do
    account = insert_account!(user, attrs)
    insert_member!(account, user, :owner)
    account
  end

  defp personal_account_fixture(user) do
    account =
      %Account{}
      |> Account.creation_changeset(%{
        name: "Personal #{System.unique_integer([:positive])}",
        slug: "personal-#{System.unique_integer([:positive])}",
        type: "personal",
        originator_user_id: user.id
      })
      |> Repo.insert!()

    insert_member!(account, user, :owner)
    account
  end

  # ---------------------------------------------------------------------------
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders accounts page with Your Accounts header for authenticated user" do
    test "renders accounts page with Your Accounts header for authenticated user", %{conn: conn} do
      user = user_fixture()
      _account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts")

      assert html =~ "Your Accounts"
    end
  end

  describe "displays account cards with name, type badge, and role badge" do
    test "displays account cards with name, type badge, and role badge", %{conn: conn} do
      user = user_fixture()
      team = team_account_fixture(user, %{name: "My Team"})
      personal = personal_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts")

      assert html =~ team.name
      assert html =~ personal.name
      assert html =~ "Team"
      assert html =~ "Personal"
      assert html =~ "owner"
    end
  end

  describe "highlights the active account with data-active true" do
    test "highlights the active account with data-active true", %{conn: conn} do
      user = user_fixture()
      account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      assert has_element?(
               lv,
               "[data-role='account-card'][data-account-id='#{account.id}'][data-active='true']"
             )
    end
  end

  describe "shows Switch button for inactive accounts and Active label for current account" do
    test "shows Switch button for inactive accounts and Active label for current account", %{conn: conn} do
      user = user_fixture()
      _account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      assert has_element?(lv, "[data-role='switch-account'][disabled]", "Active")
    end
  end

  describe "switches active account on switch_account click and shows success flash" do
    test "switches active account on switch_account click and shows success flash", %{conn: conn} do
      user = user_fixture()
      first = team_account_fixture(user, %{name: "First Account"})
      _second = team_account_fixture(user, %{name: "Second Account"})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      html =
        lv
        |> element("[data-role='switch-account'][phx-value-account_id='#{first.id}']")
        |> render_click()

      assert html =~ "Switched to"
      assert html =~ first.name

      assert has_element?(
               lv,
               "[data-role='account-card'][data-account-id='#{first.id}'][data-active='true']"
             )
    end
  end

  describe "shows empty state when user has no accounts" do
    test "shows empty state when user has no accounts", %{conn: conn} do
      user = user_fixture()
      user_id = user.id
      Repo.delete_all(from(m in AccountMember, where: m.user_id == ^user_id))
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts")

      assert html =~ "No accounts found."
    end
  end

  describe "creates a new team account via inline form and shows success flash" do
    test "creates a new team account via inline form and shows success flash", %{conn: conn} do
      user = user_fixture()
      _existing = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      html =
        lv
        |> form("form[phx-submit='create_team']", %{
          "team" => %{"name" => "New Team", "slug" => "new-team-slug"}
        })
        |> render_submit()

      assert html =~ "New Team"
      assert html =~ "Team account created"
    end
  end

  describe "shows validation errors on create team form with invalid data" do
    test "shows validation errors on create team form with invalid data", %{conn: conn} do
      user = user_fixture()
      _existing = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      html =
        lv
        |> form("form[phx-submit='create_team']", %{
          "team" => %{"name" => "", "slug" => "valid-slug"}
        })
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "live-validates team form fields on change" do
    test "live-validates team form fields on change", %{conn: conn} do
      user = user_fixture()
      _existing = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      html =
        lv
        |> form("form[phx-submit='create_team']", %{
          "team" => %{"name" => "", "slug" => "some-slug"}
        })
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "subscribes to PubSub and refreshes account list on real-time updates" do
    test "subscribes to PubSub and refreshes account list on real-time updates", %{conn: conn} do
      user = user_fixture()
      _existing = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      new_account = insert_account!(user, %{name: "PubSub Created"})
      insert_member!(new_account, user, :member)

      send(lv.pid, {:created, new_account})

      html = render(lv)
      assert html =~ "PubSub Created"
    end
  end

  describe "redirects unauthenticated users to login" do
    test "redirects unauthenticated users to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/accounts")
    end
  end
end
