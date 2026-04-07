defmodule MetricFlowWeb.Hooks.RequireSubscriptionHookTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.{Account, AccountMember}
  alias MetricFlow.Billing.Subscription
  alias MetricFlow.Repo

  defp unique_slug, do: "account-#{System.unique_integer([:positive])}"

  defp insert_account!(user) do
    %Account{}
    |> Account.creation_changeset(%{
      name: "Test Account",
      slug: unique_slug(),
      type: "team",
      originator_user_id: user.id
    })
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

  defp subscription_fixture(account, attrs \\ %{}) do
    defaults = %{
      stripe_subscription_id: "sub_#{System.unique_integer([:positive])}",
      stripe_customer_id: "cus_#{System.unique_integer([:positive])}",
      status: :active,
      account_id: account.id
    }

    %Subscription{}
    |> Subscription.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  describe "on_mount/4" do
    test "continues for accounts with active subscription", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      subscription_fixture(account, %{status: :active})
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/correlations")
      assert html =~ "Correlation"
    end

    test "continues for accounts with trialing subscription", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      subscription_fixture(account, %{status: :trialing})
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/correlations")
      assert html =~ "Correlation"
    end

    test "halts and redirects for accounts with no subscription", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user)
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/app/subscriptions/checkout"}}} =
               live(conn, "/app/correlations")
    end

    test "halts and redirects for accounts with cancelled subscription", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      subscription_fixture(account, %{status: :cancelled})
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/app/subscriptions/checkout"}}} =
               live(conn, "/app/correlations")
    end

    test "halts and redirects for accounts with past_due subscription", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      subscription_fixture(account, %{status: :past_due})
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/app/subscriptions/checkout"}}} =
               live(conn, "/app/correlations")
    end

    test "continues when no current scope is present", %{conn: conn} do
      user = user_fixture()
      _account = account_fixture(user)
      subscription_fixture(_account, %{status: :active})
      conn = log_in_user(conn, user)

      {:ok, _lv, _html} = live(conn, "/app/correlations")
    end
  end
end
