defmodule MetricFlowWeb.AgencyLive.PlansTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.{Account, AccountMember}
  alias MetricFlow.Billing.{Plan, StripeAccount}
  alias MetricFlow.Repo

  defp unique_slug, do: "agency-#{System.unique_integer([:positive])}"

  defp insert_account!(user, attrs \\ %{}) do
    defaults = %{
      name: "Test Agency",
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

  defp agency_fixture(user) do
    account = insert_account!(user)
    insert_member!(account, user, :owner)
    account
  end

  defp stripe_account_fixture(account) do
    %StripeAccount{}
    |> StripeAccount.changeset(%{
      stripe_account_id: "acct_test_#{System.unique_integer([:positive])}",
      agency_account_id: account.id,
      onboarding_status: :complete
    })
    |> Repo.insert!()
  end

  defp plan_fixture(account, attrs \\ %{}) do
    defaults = %{
      name: "Test Plan",
      price_cents: 4999,
      currency: "usd",
      billing_interval: :monthly,
      agency_account_id: account.id
    }

    %Plan{}
    |> Plan.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  describe "mount/3" do
    test "mounts and displays Subscription Plans heading", %{conn: conn} do
      user = user_fixture()
      _account = agency_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/agency/plans")

      assert html =~ "Subscription Plans"
    end

    test "shows Stripe Connect warning when agency has no connected Stripe account", %{conn: conn} do
      user = user_fixture()
      _account = agency_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/agency/plans")

      assert html =~ "Connect your Stripe account"
    end

    test "lists existing plans with name, price, and status", %{conn: conn} do
      user = user_fixture()
      account = agency_fixture(user)
      stripe_account_fixture(account)
      plan_fixture(account, %{name: "Pro Plan", price_cents: 9999})
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/agency/plans")

      assert html =~ "Pro Plan"
      assert html =~ "$99.99"
      assert html =~ "Active"
    end

    test "shows empty state when no plans exist", %{conn: conn} do
      user = user_fixture()
      _account = agency_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/agency/plans")

      assert html =~ "No plans created yet"
    end

    test "plan creation form is disabled when Stripe is not connected", %{conn: conn} do
      user = user_fixture()
      _account = agency_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/agency/plans")

      assert html =~ "disabled"
      assert html =~ "Connect your Stripe account"
    end
  end

  describe "handle_event/3" do
    test "creates a new plan on valid form submission", %{conn: conn} do
      user = user_fixture()
      account = agency_fixture(user)
      stripe_account_fixture(account)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, "/agency/plans")

      lv
      |> form("#plan-form", plan: %{name: "Starter", price_cents: 2999})
      |> render_submit()

      html = render(lv)
      assert html =~ "Starter"
      assert html =~ "Plan created"
    end

    test "displays validation errors for missing required fields", %{conn: conn} do
      user = user_fixture()
      account = agency_fixture(user)
      stripe_account_fixture(account)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, "/agency/plans")

      lv
      |> form("#plan-form", plan: %{name: "", price_cents: ""})
      |> render_change()

      html = render(lv)
      assert html =~ "can&#39;t be blank"
    end

    test "opens edit form when edit button is clicked", %{conn: conn} do
      user = user_fixture()
      account = agency_fixture(user)
      stripe_account_fixture(account)
      plan = plan_fixture(account, %{name: "Edit Me"})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, "/agency/plans")

      lv
      |> element("[data-role=edit-plan][phx-value-id=#{plan.id}]")
      |> render_click()

      html = render(lv)
      assert html =~ "Edit Plan"
      assert html =~ "Edit Me"
    end

    test "updates plan on valid edit submission", %{conn: conn} do
      user = user_fixture()
      account = agency_fixture(user)
      stripe_account_fixture(account)
      plan = plan_fixture(account, %{name: "Old Name"})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, "/agency/plans")

      lv
      |> element("[data-role=edit-plan][phx-value-id=#{plan.id}]")
      |> render_click()

      lv
      |> form("#plan-form", plan: %{name: "New Name", price_cents: 5999})
      |> render_submit()

      html = render(lv)
      assert html =~ "New Name"
      assert html =~ "Plan updated"
    end

    test "deactivates plan when deactivate button is clicked", %{conn: conn} do
      user = user_fixture()
      account = agency_fixture(user)
      stripe_account_fixture(account)
      plan = plan_fixture(account, %{name: "Deactivate Me"})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, "/agency/plans")

      lv
      |> element("[data-role=deactivate-plan][phx-value-id=#{plan.id}]")
      |> render_click()

      html = render(lv)
      assert html =~ "Plan deactivated"
    end

    test "deactivated plan shows inactive badge", %{conn: conn} do
      user = user_fixture()
      account = agency_fixture(user)
      stripe_account_fixture(account)
      _plan = plan_fixture(account, %{name: "Inactive Plan", active: false})
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/agency/plans")

      assert html =~ "Inactive"
    end
  end
end
