defmodule MetricFlowWeb.AgencyLive.PlansTest do
  # async: false because stripe_account_fixture/1 wires a cassette plug through
  # Application env (StripeClient.post/3's test fallback) for calls made from
  # the LiveView's own process, which a concurrently running async test could
  # otherwise overwrite.
  use MetricFlowTest.ConnCase, async: false

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

  defp stripe_account_fixture(account) do
    stripe_account =
      %StripeAccount{}
      |> StripeAccount.changeset(%{
        stripe_account_id: "acct_test_#{System.unique_integer([:positive])}",
        agency_account_id: account.id,
        onboarding_status: :complete
      })
      |> Repo.insert!()

    Application.put_env(:metric_flow, :stripe_test_plug, &stripe_stub_plug/1)
    ExUnit.Callbacks.on_exit(fn -> Application.delete_env(:metric_flow, :stripe_test_plug) end)

    stripe_account
  end

  defp stripe_stub_plug(conn) do
    {status, body} =
      case {conn.method, conn.request_path} do
        {"POST", "/v1/products"} ->
          {200,
           %{"id" => "prod_test_#{System.unique_integer([:positive])}", "object" => "product"}}

        {"POST", "/v1/prices"} ->
          {200,
           %{"id" => "price_test_#{System.unique_integer([:positive])}", "object" => "price"}}
      end

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, Jason.encode!(body))
  end

  defp price_rotation_stub_plug(conn) do
    {status, body} =
      case {conn.method, conn.request_path} do
        {"GET", "/v1/prices/price_original"} ->
          {200, %{"id" => "price_original", "object" => "price", "product" => "prod_original"}}

        {"POST", "/v1/prices"} ->
          {200, %{"id" => "price_new", "object" => "price"}}

        {"POST", "/v1/prices/price_original"} ->
          {200, %{"id" => "price_original", "object" => "price", "active" => false}}
      end

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, Jason.encode!(body))
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
    test "mounts and displays the plans heading", %{conn: conn} do
      user = user_fixture()
      _account = agency_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/agency/plans")

      assert html =~ "Price the subscriptions your clients can buy"
    end

    test "shows Stripe Connect warning when agency has no connected Stripe account", %{conn: conn} do
      user = user_fixture()
      _account = agency_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/agency/plans")

      assert html =~ "Connect your Stripe account"
    end

    test "lists existing plans with name, price, and status", %{conn: conn} do
      user = user_fixture()
      account = agency_fixture(user)
      stripe_account_fixture(account)
      plan_fixture(account, %{name: "Pro Plan", price_cents: 9999})
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/agency/plans")

      assert html =~ "Pro Plan"
      assert html =~ "$99.99"
      assert html =~ "Active"
    end

    test "shows empty state when no plans exist", %{conn: conn} do
      user = user_fixture()
      _account = agency_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/agency/plans")

      assert html =~ "No plans created yet"
    end

    test "plan creation form is disabled when Stripe is not connected", %{conn: conn} do
      user = user_fixture()
      _account = agency_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/agency/plans")

      assert html =~ "disabled"
      assert html =~ "Connect your Stripe account"
    end

    test "editing an existing plan is not blocked by a disconnected Stripe account", %{conn: conn} do
      user = user_fixture()
      account = agency_fixture(user)
      plan = plan_fixture(account, %{name: "Pre-existing"})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, "/app/agency/plans")

      lv
      |> element("[data-role='edit-plan'][phx-value-id='#{plan.id}']")
      |> render_click()

      html = render(lv)
      refute html =~ ~s(disabled="disabled")

      lv
      |> form("#plan-form", plan: %{name: "Renamed", price_cents: to_string(plan.price_cents)})
      |> render_submit()

      html = render(lv)
      assert html =~ "Plan updated"
      assert html =~ "Renamed"
    end
  end

  describe "handle_event/3" do
    test "creates a new plan on valid form submission", %{conn: conn} do
      user = user_fixture()
      account = agency_fixture(user)
      stripe_account_fixture(account)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, "/app/agency/plans")

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

      {:ok, lv, _html} = live(conn, "/app/agency/plans")

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

      {:ok, lv, _html} = live(conn, "/app/agency/plans")

      lv
      |> element("[data-role='edit-plan'][phx-value-id='#{plan.id}']")
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

      {:ok, lv, _html} = live(conn, "/app/agency/plans")

      lv
      |> element("[data-role='edit-plan'][phx-value-id='#{plan.id}']")
      |> render_click()

      lv
      |> form("#plan-form", plan: %{name: "New Name", price_cents: 5999})
      |> render_submit()

      html = render(lv)
      assert html =~ "New Name"
      assert html =~ "Plan updated"
    end

    test "updating price rotates the Stripe Price and leaves the Product unchanged", %{conn: conn} do
      user = user_fixture()
      account = agency_fixture(user)
      stripe_account_fixture(account)

      plan =
        plan_fixture(account, %{
          name: "Rotates",
          price_cents: 4900,
          stripe_price_id: "price_original"
        })

      conn = log_in_user(conn, user)

      Application.put_env(:metric_flow, :stripe_test_plug, &price_rotation_stub_plug/1)

      {:ok, lv, _html} = live(conn, "/app/agency/plans")

      lv
      |> element("[data-role='edit-plan'][phx-value-id='#{plan.id}']")
      |> render_click()

      lv
      |> form("#plan-form", plan: %{name: "Rotates", price_cents: 5900})
      |> render_submit()

      html = render(lv)
      assert html =~ "Plan updated"
      assert html =~ "$59.00"

      updated_plan = Repo.get!(Plan, plan.id)
      assert updated_plan.stripe_price_id == "price_new"
      refute updated_plan.stripe_price_id == "price_original"
    end

    test "deactivates plan when deactivate button is clicked", %{conn: conn} do
      user = user_fixture()
      account = agency_fixture(user)
      stripe_account_fixture(account)
      plan = plan_fixture(account, %{name: "Deactivate Me"})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, "/app/agency/plans")

      lv
      |> element("[data-role='deactivate-plan'][phx-value-id='#{plan.id}']")
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

      {:ok, _lv, html} = live(conn, "/app/agency/plans")

      assert html =~ "Inactive"
    end
  end

  describe "/app/agency/plans Anderson BI layout" do
    test "wraps the page in an Anderson BI column that cannot scroll sideways at 390px", %{
      conn: conn
    } do
      user = user_fixture()
      account = agency_fixture(user)
      stripe_account_fixture(account)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/agency/plans")

      doc = Floki.parse_document!(html)

      assert [root] = Floki.find(doc, "[data-role='agency-plans-root']")
      class = root |> Floki.attribute("class") |> List.first() || ""

      assert class =~ "overflow-x-hidden",
             "root column must carry overflow-x-hidden so nothing scrolls sideways at 390px; got: #{class}"

      assert class =~ ~r/\bmax-w-/,
             "root column must be width-capped (max-w-*) so desktop doesn't stretch; got: #{class}"
    end

    test "leads with a single h1 inside the agency-plans-root", %{conn: conn} do
      user = user_fixture()
      account = agency_fixture(user)
      stripe_account_fixture(account)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/agency/plans")

      doc = Floki.parse_document!(html)

      h1s =
        doc
        |> Floki.find("[data-role='agency-plans-root'] h1")
        |> Enum.map(&Floki.text/1)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      assert length(h1s) == 1,
             "expected exactly one h1 inside the agency-plans-root, got: #{inspect(h1s)}"
    end

    test "renders each plan as its own Anderson BI card showing its price", %{conn: conn} do
      user = user_fixture()
      account = agency_fixture(user)
      stripe_account_fixture(account)
      plan_fixture(account, %{name: "Starter Plan", price_cents: 4900})
      plan_fixture(account, %{name: "Pro Plan", price_cents: 9900})
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/agency/plans")

      doc = Floki.parse_document!(html)

      cards = Floki.find(doc, "[data-role='agency-plans-root'] [data-role='plan-row']")

      assert length(cards) == 2,
             "expected one plan-row card per plan, got: #{length(cards)}"

      for card <- cards do
        class = card |> Floki.attribute("class") |> List.first() || ""

        for token <- ["rounded-box", "border", "bg-base-200"] do
          assert class =~ token,
                 "plan card is missing Anderson BI card token #{inspect(token)}; got: #{class}"
        end
      end

      assert html =~ "$49.00"
      assert html =~ "$99.00"
    end

    test "makes creating a new plan the primary brand-gradient action", %{conn: conn} do
      user = user_fixture()
      account = agency_fixture(user)
      stripe_account_fixture(account)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/agency/plans")

      doc = Floki.parse_document!(html)

      submit_buttons = Floki.find(doc, "form#plan-form button[type='submit']")
      assert submit_buttons != [], "expected a submit button inside form#plan-form"

      assert Enum.any?(submit_buttons, fn btn ->
               class = btn |> Floki.attribute("class") |> List.first() || ""
               class =~ "btn-brand-gradient"
             end),
             "Create Plan submit must use the Anderson BI brand-gradient primary button"
    end
  end
end
