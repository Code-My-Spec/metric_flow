defmodule MetricFlowWeb.AccountLive.IndexTest do
  use MetricFlowTest.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts
  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Agencies.AgencyClientAccessGrant
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

  defp grant_client_access(agency_account, client_account, attrs) do
    defaults = %{
      agency_account_id: agency_account.id,
      client_account_id: client_account.id,
      access_level: :read_only,
      origination_status: :invited
    }

    %AgencyClientAccessGrant{}
    |> AgencyClientAccessGrant.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3"
  # ---------------------------------------------------------------------------

  describe "mount/3" do
    test "renders the accounts page with page title 'Accounts'", %{conn: conn} do
      user = user_fixture()
      _account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts")

      assert html =~ "Accounts"
    end

    test "lists all accounts the user belongs to", %{conn: conn} do
      user = user_fixture()
      team = team_account_fixture(user, %{name: "My Team"})
      personal = personal_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts")

      assert html =~ team.name
      assert html =~ personal.name
    end

    test "highlights the currently active account with data-active='true'", %{conn: conn} do
      user = user_fixture()
      account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      assert has_element?(
               lv,
               "[data-role='account-card'][data-account-id='#{account.id}'][data-active='true']"
             )
    end

    test "redirects unauthenticated users to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/accounts")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "render/1"
  # ---------------------------------------------------------------------------

  describe "render/1" do
    test "displays account name for each account", %{conn: conn} do
      user = user_fixture()
      account = team_account_fixture(user, %{name: "Acme Corp"})
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts")

      assert html =~ "Acme Corp"
      assert html =~ account.name
    end

    test "displays account type badge Personal for personal accounts", %{conn: conn} do
      user = user_fixture()
      _account = personal_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts")

      assert html =~ "Personal"
    end

    test "displays account type badge Team for team accounts", %{conn: conn} do
      user = user_fixture()
      _account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts")

      assert html =~ "Team"
    end

    test "displays the user's role in each account", %{conn: conn} do
      user = user_fixture()
      _account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts")

      assert html =~ "owner"
    end

    test "active account has a visual indicator", %{conn: conn} do
      user = user_fixture()
      account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      assert has_element?(lv, "[data-role='account-card'][data-active='true']")

      assert has_element?(
               lv,
               "[data-role='account-card'][data-account-id='#{account.id}'][data-active='true']"
             )
    end

    test "includes a form to create a new team account", %{conn: conn} do
      user = user_fixture()
      _account = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      assert has_element?(lv, "form[phx-submit='create_team']")
    end

    test "shows 'No accounts found.' when user has no accounts", %{conn: conn} do
      user = user_fixture()
      user_id = user.id
      Repo.delete_all(from(m in AccountMember, where: m.user_id == ^user_id))
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts")

      assert html =~ "No accounts found."
    end

    test "displays access level badge for client accounts linked via agency grant", %{conn: conn} do
      agency_user = user_fixture()
      agency_account = team_account_fixture(agency_user, %{name: "Agency HQ"})

      client_user = user_fixture()
      client_account = team_account_fixture(client_user, %{name: "Client Co"})

      insert_member!(client_account, agency_user, :read_only)

      _grant =
        grant_client_access(agency_account, client_account, %{
          access_level: :account_manager,
          origination_status: :invited
        })

      conn = log_in_user(conn, agency_user)

      {:ok, _lv, html} = live(conn, ~p"/accounts")

      assert html =~ "Account Manager"
    end

    test "displays origination status badge 'Originator' for originator client accounts", %{
      conn: conn
    } do
      agency_user = user_fixture()
      agency_account = team_account_fixture(agency_user, %{name: "Agency HQ"})

      client_user = user_fixture()
      client_account = team_account_fixture(client_user, %{name: "Client Co"})

      insert_member!(client_account, agency_user, :read_only)

      _grant =
        grant_client_access(agency_account, client_account, %{
          access_level: :admin,
          origination_status: :originator
        })

      conn = log_in_user(conn, agency_user)

      {:ok, _lv, html} = live(conn, ~p"/accounts")

      assert html =~ "Originator"
    end

    test "displays origination status badge 'Invited' for invited client accounts", %{conn: conn} do
      agency_user = user_fixture()
      agency_account = team_account_fixture(agency_user, %{name: "Agency HQ"})

      client_user = user_fixture()
      client_account = team_account_fixture(client_user, %{name: "Client Co"})

      insert_member!(client_account, agency_user, :read_only)

      _grant =
        grant_client_access(agency_account, client_account, %{
          access_level: :read_only,
          origination_status: :invited
        })

      conn = log_in_user(conn, agency_user)

      {:ok, _lv, html} = live(conn, ~p"/accounts")

      assert html =~ "Invited"
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event switch_account"
  # ---------------------------------------------------------------------------

  describe "handle_event switch_account" do
    test "updates the active account and highlights the newly selected account", %{conn: conn} do
      user = user_fixture()
      first_account = team_account_fixture(user, %{name: "First Account"})
      _second_account = team_account_fixture(user, %{name: "Second Account"})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      lv
      |> element("[data-role='switch-account'][phx-value-account_id='#{first_account.id}']")
      |> render_click()

      assert has_element?(
               lv,
               "[data-role='account-card'][data-account-id='#{first_account.id}'][data-active='true']"
             )
    end

    test "displays a confirmation flash message after switching account", %{conn: conn} do
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
    end

    test "the switch-account button is disabled for the currently active account", %{conn: conn} do
      user = user_fixture()
      account = team_account_fixture(user, %{name: "Active Account"})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      assert has_element?(
               lv,
               "[data-role='switch-account'][phx-value-account_id='#{account.id}'][disabled]"
             )
    end

    test "the switch-account button shows 'Active' label for the current active account", %{
      conn: conn
    } do
      user = user_fixture()
      _account = team_account_fixture(user, %{name: "My Account"})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      assert has_element?(lv, "[data-role='switch-account'][disabled]", "Active")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event create_team"
  # ---------------------------------------------------------------------------

  describe "handle_event create_team" do
    test "creates a team account and adds it to the list", %{conn: conn} do
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
    end

    test "shows success flash after creating a team account", %{conn: conn} do
      user = user_fixture()
      _existing = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      html =
        lv
        |> form("form[phx-submit='create_team']", %{
          "team" => %{"name" => "Brand New Team", "slug" => "brand-new-team"}
        })
        |> render_submit()

      assert html =~ "Team account created"
    end

    test "shows validation error for blank name", %{conn: conn} do
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

    test "shows validation error for invalid slug format", %{conn: conn} do
      user = user_fixture()
      _existing = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      html =
        lv
        |> form("form[phx-submit='create_team']", %{
          "team" => %{"name" => "Valid Name", "slug" => "INVALID SLUG!"}
        })
        |> render_submit()

      assert html =~ "has invalid format"
    end

    test "does not clear user input on validation error", %{conn: conn} do
      user = user_fixture()
      _existing = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      html =
        lv
        |> form("form[phx-submit='create_team']", %{
          "team" => %{"name" => "Valid Name", "slug" => "INVALID!"}
        })
        |> render_submit()

      assert html =~ "Valid Name"
    end

    test "new team account appears in the accounts list after creation", %{conn: conn} do
      user = user_fixture()
      _existing = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      lv
      |> form("form[phx-submit='create_team']", %{
        "team" => %{"name" => "Freshly Created Team", "slug" => "freshly-created-team"}
      })
      |> render_submit()

      html = render(lv)
      assert html =~ "Freshly Created Team"
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event validate_team"
  # ---------------------------------------------------------------------------

  describe "handle_event validate_team" do
    test "provides live validation feedback for blank name input", %{conn: conn} do
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

    test "provides live validation feedback for invalid slug format", %{conn: conn} do
      user = user_fixture()
      _existing = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      html =
        lv
        |> form("form[phx-submit='create_team']", %{
          "team" => %{"name" => "Valid Name", "slug" => "INVALID SLUG!"}
        })
        |> render_change()

      assert html =~ "has invalid format"
    end

    test "shows no errors for valid name and slug during live validation", %{conn: conn} do
      user = user_fixture()
      _existing = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      html =
        lv
        |> form("form[phx-submit='create_team']", %{
          "team" => %{"name" => "Valid Name", "slug" => "valid-slug"}
        })
        |> render_change()

      refute html =~ "can&#39;t be blank"
      refute html =~ "has invalid format"
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_info"
  # ---------------------------------------------------------------------------

  describe "handle_info" do
    test "refreshes the account list when a new account is created", %{conn: conn} do
      user = user_fixture()
      _existing = team_account_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      new_account = insert_account!(user, %{name: "PubSub Created Account"})
      insert_member!(new_account, user, :member)

      send(lv.pid, {:created, new_account})

      html = render(lv)
      assert html =~ "PubSub Created Account"
    end

    test "refreshes the account list when an account is updated", %{conn: conn} do
      user = user_fixture()
      account = team_account_fixture(user, %{name: "Original Name"})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      scope = Scope.for_user(user)

      {:ok, updated_account} =
        Accounts.update_account(scope, account, %{
          name: "Updated via PubSub",
          slug: account.slug
        })

      send(lv.pid, {:updated, updated_account})

      html = render(lv)
      assert html =~ "Updated via PubSub"
    end

    test "refreshes the account list when an account is deleted", %{conn: conn} do
      user = user_fixture()
      account_to_keep = team_account_fixture(user, %{name: "Keep This"})
      account_to_delete = team_account_fixture(user, %{name: "Delete This"})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      scope = Scope.for_user(user)
      {:ok, deleted} = Accounts.delete_account(scope, account_to_delete)

      send(lv.pid, {:deleted, deleted})

      html = render(lv)
      assert html =~ account_to_keep.name
      refute html =~ "Delete This"
    end

    test "preserves active_account_id after account list refresh", %{conn: conn} do
      user = user_fixture()
      active_account = team_account_fixture(user, %{name: "Active Account"})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts")

      new_account = insert_account!(user, %{name: "Newly Added"})
      insert_member!(new_account, user, :member)

      send(lv.pid, {:created, new_account})

      assert has_element?(
               lv,
               "[data-role='account-card'][data-account-id='#{active_account.id}'][data-active='true']"
             )
    end
  end
end
