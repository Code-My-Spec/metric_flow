defmodule MetricFlowWeb.SubscriptionLive.CheckoutTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.{Account, AccountMember}
  alias MetricFlow.Billing.{Plan, Subscription, StripeAccount}
  alias MetricFlow.Repo

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

  defp account_fixture(user) do
    account = insert_account!(user)
    insert_member!(account, user, :owner)
    account
  end

  defp plan_fixture(account_id \\ nil, attrs \\ %{}) do
    defaults = %{
      name: "Pro Plan",
      price_cents: 4999,
      currency: "usd",
      billing_interval: :monthly,
      agency_account_id: account_id
    }

    %Plan{}
    |> Plan.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp subscription_fixture(account, attrs \\ %{}) do
    defaults = %{
      stripe_subscription_id: "sub_test_#{System.unique_integer([:positive])}",
      stripe_customer_id: "cus_test_#{System.unique_integer([:positive])}",
      status: :active,
      account_id: account.id,
      current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
    }

    %Subscription{}
    |> Subscription.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  test "mounts and displays plan name and price", %{conn: conn} do
    user = user_fixture()
    _account = account_fixture(user)
    plan_fixture(nil, %{name: "MetricFlow Pro", price_cents: 4999})
    conn = log_in_user(conn, user)

    {:ok, _lv, html} = live(conn, "/app/subscriptions/checkout")

    assert html =~ "MetricFlow Pro"
    assert html =~ "$49.99"
  end

  test "shows subscribe button for free users", %{conn: conn} do
    user = user_fixture()
    _account = account_fixture(user)
    conn = log_in_user(conn, user)

    {:ok, _lv, html} = live(conn, "/app/subscriptions/checkout")

    assert html =~ "Subscribe"
    assert html =~ "data-role=\"subscribe-button\""
  end

  test "shows active subscription status for subscribed users", %{conn: conn} do
    user = user_fixture()
    account = account_fixture(user)
    subscription_fixture(account)
    conn = log_in_user(conn, user)

    {:ok, _lv, html} = live(conn, "/app/subscriptions/checkout")

    assert html =~ "Active"
    assert html =~ "Current Subscription"
  end

  test "shows cancel option for subscribed users", %{conn: conn} do
    user = user_fixture()
    account = account_fixture(user)
    subscription_fixture(account)
    conn = log_in_user(conn, user)

    {:ok, _lv, html} = live(conn, "/app/subscriptions/checkout")

    assert html =~ "Cancel Subscription"
  end

  test "displays agency plans for agency customers instead of platform default", %{conn: conn} do
    user = user_fixture()
    account = account_fixture(user)
    plan_fixture(account.id, %{name: "Agency Custom Plan", price_cents: 2999})
    conn = log_in_user(conn, user)

    {:ok, _lv, html} = live(conn, "/app/subscriptions/checkout")

    assert html =~ "Agency Custom Plan"
    assert html =~ "$29.99"
  end
end
