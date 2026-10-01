defmodule MetricFlowWeb.Journeys.NewUserRegistrationToFirstDashboardTest do
  @moduledoc """
  Journey 1 from `.code_my_spec/qa/journey_plan.md`: a new user registers,
  confirms their email, sees an empty dashboard, checks account/settings
  pages, and is guarded once logged out.
  """

  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Dashboards.Dashboard
  alias MetricFlow.Repo
  alias MetricFlow.Users

  defp canned_dashboard_fixture(user, attrs \\ %{}) do
    defaults = %{
      name: "Marketing Overview",
      user_id: user.id,
      built_in: true
    }

    %Dashboard{}
    |> Dashboard.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  test "registers, confirms, sees empty dashboard, checks account/settings, and is guarded after logout", %{
    conn: conn
  } do
    # Step 1-2: registration form
    {:ok, lv, _html} = live(conn, ~p"/users/register")

    email = unique_user_email()

    form =
      form(lv, "#registration_form",
        user: valid_user_attributes(email: email, account_name: "QA Journey1 Account", account_type: "client")
      )

    render_submit(form)

    # Step 3: success screen, confirmation email implied
    assert render(lv) =~ "Registration successful"
    assert render(lv) =~ "An email was sent to #{email}"

    user = Users.get_user_by_email(email)
    refute user.confirmed_at

    # Step 4-5: confirm via magic link, land on /onboarding
    token =
      extract_user_token(fn url ->
        Users.deliver_login_instructions(user, url)
      end)

    {:ok, confirm_lv, _html} = live(conn, ~p"/users/log-in/#{token}")
    confirm_form = form(confirm_lv, "#confirmation_form", %{"user" => %{"token" => token}})
    render_submit(confirm_form)
    conn = follow_trigger_action(confirm_form, conn)

    assert redirected_to(conn) == ~p"/onboarding"
    assert Users.get_user!(user.id).confirmed_at

    # Step 7-8: dashboards list shows the canned dashboard, viewing it shows
    # the onboarding prompt since this user has no integrations
    canned = canned_dashboard_fixture(user)

    conn = recycle(conn)
    {:ok, _lv, html} = live(conn, ~p"/app/dashboards")
    assert html =~ canned.name
    assert html =~ "Built-in"

    {:ok, _show_lv, show_html} = live(conn, ~p"/app/dashboards/#{canned.id}")
    assert show_html =~ ~s(data-role="onboarding-prompt")
    assert show_html =~ "Connect Your Platforms"

    # Step 9: account listed with owner role
    {:ok, _accounts_lv, accounts_html} = live(conn, ~p"/app/accounts")
    assert accounts_html =~ "QA Journey1 Account"
    assert accounts_html =~ "owner"

    # Step 10: settings forms render (real route is /app/users/settings)
    {:ok, _settings_lv, settings_html} = live(conn, ~p"/app/users/settings")
    assert settings_html =~ ~s(id="user_email")
    assert settings_html =~ ~s(id="user_password")

    # Step 11-12: logout, then guarded access redirects to log-in
    conn = conn |> recycle() |> delete(~p"/users/log-out")
    assert redirected_to(conn) == ~p"/users/log-in"

    conn = conn |> recycle() |> get(~p"/app/dashboards")
    assert redirected_to(conn) == ~p"/users/log-in"
  end
end
