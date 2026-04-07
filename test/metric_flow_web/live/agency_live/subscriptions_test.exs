defmodule MetricFlowWeb.AgencyLive.SubscriptionsTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.{Account, AccountMember}
  alias MetricFlow.Billing.{Plan, Subscription, StripeAccount}
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

  defp plan_fixture(account) do
    %Plan{}
    |> Plan.changeset(%{
      name: "Agency Plan",
      price_cents: 4999,
      currency: "usd",
      billing_interval: :monthly,
      agency_account_id: account.id
    })
    |> Repo.insert!()
  end

  defp subscription_fixture(account, plan, attrs \\ %{}) do
    defaults = %{
      stripe_subscription_id: "sub_test_#{System.unique_integer([:positive])}",
      stripe_customer_id: "cus_test_#{System.unique_integer([:positive])}",
      status: :active,
      account_id: account.id,
      plan_id: plan.id,
      current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
    }

    %Subscription{}
    |> Subscription.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  test "mounts and displays Customer Subscriptions heading", %{conn: conn} do
    user = user_fixture()
    _account = agency_fixture(user)
    conn = log_in_user(conn, user)

    {:ok, _lv, html} = live(conn, "/app/agency/subscriptions")

    assert html =~ "Customer Subscriptions"
  end

  test "shows summary stats for active subscribers and MRR", %{conn: conn} do
    user = user_fixture()
    account = agency_fixture(user)
    conn = log_in_user(conn, user)

    {:ok, _lv, html} = live(conn, "/app/agency/subscriptions")

    assert html =~ "Active Subscribers"
    assert html =~ "MRR"
  end

  test "lists customer subscriptions with status and plan", %{conn: conn} do
    user = user_fixture()
    account = agency_fixture(user)
    plan = plan_fixture(account)

    # Create a client account with a subscription
    client = user_fixture()
    client_account = insert_account!(client, %{name: "Client Co"})
    insert_member!(client_account, client, :owner)
    subscription_fixture(client_account, plan)

    conn = log_in_user(conn, user)
    {:ok, _lv, html} = live(conn, "/app/agency/subscriptions")

    assert html =~ "Agency Plan"
    assert html =~ "Active"
  end

  test "shows cancel action for active subscriptions", %{conn: conn} do
    user = user_fixture()
    account = agency_fixture(user)
    plan = plan_fixture(account)

    client = user_fixture()
    client_account = insert_account!(client, %{name: "Cancel Client"})
    insert_member!(client_account, client, :owner)
    subscription_fixture(client_account, plan)

    conn = log_in_user(conn, user)
    {:ok, _lv, html} = live(conn, "/app/agency/subscriptions")

    assert html =~ "Cancel"
  end

  test "scopes data to current agency only", %{conn: conn} do
    user = user_fixture()
    account = agency_fixture(user)
    conn = log_in_user(conn, user)

    # Create another agency's subscription that should NOT be visible
    other_user = user_fixture()
    other_account = agency_fixture(other_user)
    other_plan = plan_fixture(other_account)
    subscription_fixture(other_account, other_plan, %{stripe_customer_id: "cus_other_agency"})

    {:ok, _lv, html} = live(conn, "/app/agency/subscriptions")

    refute html =~ "cus_other_agency"
  end

  test "provides search input for filtering customers", %{conn: conn} do
    user = user_fixture()
    _account = agency_fixture(user)
    conn = log_in_user(conn, user)

    {:ok, _lv, html} = live(conn, "/app/agency/subscriptions")

    assert html =~ "Search"
    assert html =~ "phx-change=\"search\""
  end

  test "shows status badges reflecting subscription state", %{conn: conn} do
    user = user_fixture()
    account = agency_fixture(user)
    plan = plan_fixture(account)

    client = user_fixture()
    client_account = insert_account!(client, %{name: "Badge Client"})
    insert_member!(client_account, client, :owner)
    subscription_fixture(client_account, plan, %{status: :active})

    conn = log_in_user(conn, user)
    {:ok, _lv, html} = live(conn, "/app/agency/subscriptions")

    assert html =~ "badge-success"
  end
end
