defmodule MetricFlowWeb.UserLive.LoginTest do
  use MetricFlowTest.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import Swoosh.TestAssertions

  test "renders in the public Layouts.content as a centred card on the dark theme, with the logo",
       %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/users/log-in")

    # Layouts.content renders the public footer (Layouts.app does not).
    assert html =~ "Privacy Policy"
    assert html =~ "Terms of Service"
    # The Anderson BI logo renders with the default-logo role for the
    # unbranded login card (an agency white label would swap this for
    # the agency-logo role via Layouts.content).
    assert has_element?(view, "img[data-role='default-logo'][alt='Anderson BI']")
  end

  test "shows the password form with a distinct magic-link button, Google sign-in, and clear recovery and registration links",
       %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/log-in")

    assert has_element?(view, "#login_form_password")
    assert has_element?(view, "#password_email")
    assert has_element?(view, "#google-login")
    # The magic-link option is a distinct button inside the password form;
    # the spex explicitly refutes a separate form for it.
    assert has_element?(view, "#email-sign-in-link[data-login-method='magic-link']")
    assert has_element?(view, "#forgot-password-link[href='/users/forgot-password']")
    assert has_element?(view, "#register-link[href='/users/register']")
    refute has_element?(view, "#login_form_magic")
    refute has_element?(view, "#login_form_password button[name='user[remember_me]']")
  end

  test "password form logs in and uses the persistent session default", %{conn: conn} do
    user = user_fixture() |> set_password()
    {:ok, view, _html} = live(conn, ~p"/users/log-in")

    assert has_element?(
             view,
             "#login_form_password input[name='user[remember_me]'][value='true']"
           )

    conn =
      view
      |> form("#login_form_password",
        user: %{email: user.email, password: valid_user_password(), remember_me: "true"}
      )
      |> submit_form(conn)

    assert redirected_to(conn) == ~p"/app/chat"
    assert conn.resp_cookies["_metric_flow_web_user_remember_me"]
  end

  test "magic-link button sends login instructions and confirms discreetly", %{conn: conn} do
    user = user_fixture()
    {:ok, view, _html} = live(conn, ~p"/users/log-in")

    # Mirror a user typing their email into the shared form, then clicking
    # the magic-link button.
    view
    |> form("#login_form_password", user: %{email: user.email})
    |> render_change()

    result =
      view
      |> element("#email-sign-in-link")
      |> render_click()

    {:ok, _new_view, html} = follow_redirect(result, conn, ~p"/users/log-in")
    assert html =~ "a sign-in link is on its way"

    assert_email_sent(fn email ->
      assert email.to == [{"", user.email}]
      assert email.subject == "Log in instructions"
    end)
  end

  test "magic-link button flashes the same message when the email does not exist", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/log-in")

    view
    |> form("#login_form_password", user: %{email: "nobody@example.com"})
    |> render_change()

    result =
      view
      |> element("#email-sign-in-link")
      |> render_click()

    {:ok, _new_view, html} = follow_redirect(result, conn, ~p"/users/log-in")
    assert html =~ "a sign-in link is on its way"
  end

  test "invalid credentials show a generic error", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/log-in")
    form = form(view, "#login_form_password", user: %{email: "test@email.com", password: "wrong"})
    render_submit(form)
    conn = follow_trigger_action(form, conn)

    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
    assert redirected_to(conn) == ~p"/users/log-in"
  end

  test "recovery link opens the reset request form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/log-in")

    {:ok, forgot_view, _html} =
      view
      |> element("#forgot-password-link")
      |> render_click()
      |> follow_redirect(conn, ~p"/users/forgot-password")

    assert has_element?(forgot_view, "#forgot-password-form")
  end

  test "registration link opens the registration form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/log-in")

    {:ok, registration_view, _html} =
      view
      |> element("#register-link")
      |> render_click()
      |> follow_redirect(conn, ~p"/users/register")

    assert has_element?(registration_view, "#registration_form")
  end

  test "reauthentication shows a notice, keeps the user's email readonly, and hides registration",
       %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)
    {:ok, view, html} = live(conn, ~p"/users/log-in")

    assert html =~ "You need to reauthenticate"
    assert has_element?(view, "#password_email[readonly][value='#{user.email}']")
    refute has_element?(view, "#register-link")
    refute has_element?(view, "#login_form_password input[name='user[remember_me]']")
  end

  test "shows local mail adapter guidance in development", %{conn: conn} do
    original = Application.get_env(:metric_flow, MetricFlow.Mailer)
    Application.put_env(:metric_flow, MetricFlow.Mailer, adapter: Swoosh.Adapters.Local)
    on_exit(fn -> Application.put_env(:metric_flow, MetricFlow.Mailer, original) end)

    {:ok, view, _html} = live(conn, ~p"/users/log-in")
    assert has_element?(view, "a[href='/dev/mailbox']")
  end
end
