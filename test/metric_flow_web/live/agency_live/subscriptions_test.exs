defmodule MetricFlowWeb.AgencyLive.SubscriptionsTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.{Account, AccountMember}
  alias MetricFlow.Billing.{Plan, StripeAccount, Subscription}
  alias MetricFlow.Repo

  defp unique_slug, do: "agency-#{System.unique_integer([:positive])}"

  defp insert_account!(user, attrs \\ %{}) do
    defaults = %{
      name: "Test Agency",
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

  describe "Anderson BI layout" do
    test "wraps content in an Anderson BI root column with overflow-x-hidden",
         %{conn: conn} do
      user = user_fixture()
      _account = agency_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/agency/subscriptions")

      assert html =~ ~s(data-role="agency-subscriptions-root"),
             "Expected the page to be wrapped in an agency-subscriptions-root element."

      assert html =~ "overflow-x-hidden",
             "Expected the root column to carry overflow-x-hidden to stop sideways scroll at 390px."

      assert html =~ "max-w-3xl",
             "Expected the root column to cap its width with a max-w-* token."

      assert Regex.scan(~r(<h1\b)i, html) |> length() == 1,
             "Expected exactly one h1 on the page."
    end

    test "lists each client subscription as its own row with its status",
         %{conn: conn} do
      user = user_fixture()
      account = agency_fixture(user)
      plan = plan_fixture(account)

      client = user_fixture()
      client_account = insert_account!(client, %{name: "Row Client"})
      insert_member!(client_account, client, :owner)

      subscription_fixture(client_account, plan, %{
        stripe_customer_id: "cus_row_active",
        status: :active
      })

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, "/app/agency/subscriptions")

      rows = Regex.scan(~r/data-role="subscription-row"/, html)

      assert length(rows) == 1,
             "Expected exactly one subscription-row per client subscription. Got #{length(rows)}."

      assert html =~ ~s(data-status="active"),
             "Expected the row to carry its subscription status as a data attribute."
    end

    test "problem-status subscriptions are listed before healthy ones",
         %{conn: conn} do
      user = user_fixture()
      account = agency_fixture(user)
      plan = plan_fixture(account)

      healthy_client = user_fixture()
      healthy_account = insert_account!(healthy_client, %{name: "Healthy Client"})
      insert_member!(healthy_account, healthy_client, :owner)

      problem_client = user_fixture()
      problem_account = insert_account!(problem_client, %{name: "Problem Client"})
      insert_member!(problem_account, problem_client, :owner)

      # The healthy subscription is inserted AFTER the problem one, so the
      # pre-pass ordering (inserted_at desc) would place the healthy row first.
      subscription_fixture(problem_account, plan, %{
        stripe_customer_id: "cus_problem",
        status: :past_due
      })

      subscription_fixture(healthy_account, plan, %{
        stripe_customer_id: "cus_healthy",
        status: :active
      })

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, "/app/agency/subscriptions")

      problem_pos = :binary.match(html, "cus_problem") |> elem(0)
      healthy_pos = :binary.match(html, "cus_healthy") |> elem(0)

      assert problem_pos < healthy_pos,
             "Expected the past_due subscription to appear before the active one on the page."
    end
  end
end
