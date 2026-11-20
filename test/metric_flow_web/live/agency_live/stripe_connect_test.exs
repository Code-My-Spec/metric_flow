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

  test "has no live trigger for the unreachable refresh_status event handler", %{conn: conn} do
    user = user_fixture()
    _account = agency_fixture(user)
    conn = log_in_user(conn, user)

    {:ok, lv, _html} = live(conn, "/app/agency/stripe-connect")

    refute has_element?(lv, "[phx-click='refresh_status']")

    Process.flag(:trap_exit, true)
    catch_exit(render_hook(lv, "refresh_status", %{}))

    refute Process.alive?(lv.pid)
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

  describe "Anderson BI layout" do
    test "wraps content in a stripe-connect root that caps width and blocks sideways scroll",
         %{conn: conn} do
      user = user_fixture()
      _account = agency_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/agency/stripe-connect")

      [{_tag, attrs, _children}] =
        Floki.parse_document!(html)
        |> Floki.find(~s|main[data-role="agency-stripe-connect-root"]|)

      class = attrs |> Enum.into(%{}) |> Map.fetch!("class")

      assert class =~ "overflow-x-hidden",
             ~s|Expected stripe-connect root to carry overflow-x-hidden; got class="#{class}"|

      assert class =~ ~r/\bmax-w-/,
             ~s|Expected stripe-connect root to cap its width with a max-w-* class; got class="#{class}"|
    end

    test "renders exactly one h1 inside the stripe-connect root", %{conn: conn} do
      user = user_fixture()
      _account = agency_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/agency/stripe-connect")

      headings =
        html
        |> Floki.parse_document!()
        |> Floki.find(~s|main[data-role="agency-stripe-connect-root"] h1|)

      assert length(headings) == 1,
             "Expected one h1 inside the stripe-connect root, got #{length(headings)}"
    end

    test "not-connected state exposes exactly one next-action with the brand-gradient button",
         %{conn: conn} do
      user = user_fixture()
      _account = agency_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/agency/stripe-connect")

      actions =
        html
        |> Floki.parse_document!()
        |> Floki.find(~s|[data-role="stripe-next-action"]|)

      assert length(actions) == 1,
             "Expected one stripe-next-action, got #{length(actions)}"

      assert html =~ "btn-brand-gradient",
             "Expected the connect button to use the brand-gradient component class"
    end

    test "connected state exposes exactly one next-action and no brand-gradient button",
         %{conn: conn} do
      user = user_fixture()
      account = agency_fixture(user)
      stripe_account_fixture(account)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/agency/stripe-connect")

      actions =
        html
        |> Floki.parse_document!()
        |> Floki.find(~s|[data-role="stripe-next-action"]|)

      assert length(actions) == 1,
             "Expected one stripe-next-action, got #{length(actions)}"
    end
  end
end
