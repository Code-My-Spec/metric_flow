defmodule MetricFlowWeb.AgencyLive.StripeConnectTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.{Account, AccountMember}
  alias MetricFlow.Billing.StripeAccount
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

  defp stripe_account_fixture(account, attrs \\ %{}) do
    defaults = %{
      stripe_account_id: "acct_test_#{System.unique_integer([:positive])}",
      agency_account_id: account.id,
      onboarding_status: :complete,
      capabilities: %{"card_payments" => "active", "transfers" => "active"}
    }

    %StripeAccount{}
    |> StripeAccount.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  test "mounts and displays Stripe Connect heading", %{conn: conn} do
    user = user_fixture()
    _account = agency_fixture(user)
    conn = log_in_user(conn, user)

    {:ok, _lv, html} = live(conn, "/app/agency/stripe-connect")

    assert html =~ "Stripe Connect"
  end

  test "shows not connected status when no Stripe account exists", %{conn: conn} do
    user = user_fixture()
    _account = agency_fixture(user)
    conn = log_in_user(conn, user)

    {:ok, _lv, html} = live(conn, "/app/agency/stripe-connect")

    assert html =~ "Not connected"
  end

  test "shows connect button when not connected", %{conn: conn} do
    user = user_fixture()
    _account = agency_fixture(user)
    conn = log_in_user(conn, user)

    {:ok, _lv, html} = live(conn, "/app/agency/stripe-connect")

    assert html =~ "Connect Stripe Account"
    assert html =~ "data-role=\"connect-stripe\""
  end

  test "shows connected status with Stripe account ID when connected", %{conn: conn} do
    user = user_fixture()
    account = agency_fixture(user)
    sa = stripe_account_fixture(account)
    conn = log_in_user(conn, user)

    {:ok, _lv, html} = live(conn, "/app/agency/stripe-connect")

    assert html =~ "Connected"
    assert html =~ sa.stripe_account_id
  end

  test "shows restricted status when onboarding is incomplete", %{conn: conn} do
    user = user_fixture()
    account = agency_fixture(user)
    stripe_account_fixture(account, %{onboarding_status: :restricted})
    conn = log_in_user(conn, user)

    {:ok, _lv, html} = live(conn, "/app/agency/stripe-connect")

    assert html =~ "Restricted"
    assert html =~ "Resume Onboarding"
  end

  test "shows disconnect button when connected", %{conn: conn} do
    user = user_fixture()
    account = agency_fixture(user)
    stripe_account_fixture(account)
    conn = log_in_user(conn, user)

    {:ok, _lv, html} = live(conn, "/app/agency/stripe-connect")

    assert html =~ "data-role=\"disconnect-stripe\""
    assert html =~ "Disconnect Stripe Account"
  end

  test "hides connect button when already connected", %{conn: conn} do
    user = user_fixture()
    account = agency_fixture(user)
    stripe_account_fixture(account)
    conn = log_in_user(conn, user)

    {:ok, _lv, html} = live(conn, "/app/agency/stripe-connect")

    refute html =~ "data-role=\"connect-stripe\""
    end
  end
end
