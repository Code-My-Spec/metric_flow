defmodule MetricFlowWeb.UserLive.LoginTest do
  use MetricFlowTest.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  describe "renders login page with magic link form and password form" do
    test "both forms are present", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "Log in"
      assert html =~ "login_form_magic"
      assert html =~ "login_form_password"
      assert html =~ "Log in with email"
      assert html =~ "Log in and stay logged in"
      assert html =~ "Log in only this time"
    end
  end

  describe "autofocuses email input on mount" do
    test "email input has phx-mounted focus hook", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "phx-mounted"
    end
  end

  describe "shows Sign up link for unauthenticated users" do
    test "Sign up link is visible", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "Sign up"
      assert html =~ ~s(href="/users/register")
    end
  end

  describe "sends magic link email and shows ambiguous confirmation flash when user exists" do
    test "sends magic link and shows flash", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", user: %{email: user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"

      assert MetricFlow.Repo.get_by!(MetricFlow.Users.UserToken, user_id: user.id).context ==
               "login"
    end
  end

  describe "shows same ambiguous confirmation flash when user does not exist" do
    test "does not disclose if user is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", user: %{email: "idonotexist@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"
    end
  end

  describe "triggers password form submission to UserSessionController on submit_password event" do
    test "sets trigger_submit to true", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password",
          user: %{email: user.email, password: valid_user_password()}
        )

      render_submit(form)

      assert render(lv) =~ ~s(phx-trigger-action)
    end
  end

  describe "redirects to signed-in path with valid password credentials" do
    test "redirects on valid login", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password",
          user: %{email: user.email, password: valid_user_password(), remember_me: true}
        )

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/integrations"
    end
  end

  describe "shows invalid email or password error with invalid credentials" do
    test "shows error flash", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password", user: %{email: "test@email.com", password: "123456"})

      render_submit(form, %{user: %{remember_me: true}})

      conn = follow_trigger_action(form, conn)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "navigates to registration page when Sign up link is clicked" do
    test "Sign up navigates to registration", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, _reg_live, reg_html} =
        lv
        |> element("main a", "Sign up")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/register")

      assert reg_html =~ "Register"
    end
  end

  describe "shows reauthentication notice in sudo mode with email pre-filled" do
    setup %{conn: conn} do
      user = user_fixture()
      %{user: user, conn: log_in_user(conn, user)}
    end

    test "shows reauth notice and pre-fills email", %{conn: conn, user: user} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "You need to reauthenticate"
      assert html =~ user.email
    end
  end

  describe "hides Sign up link in sudo mode" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user)}
    end

    test "Sign up link is not visible", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      refute html =~ ">Sign up<"
    end
  end

  describe "makes email input readonly in sudo mode" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user)}
    end

    test "email input is readonly", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "readonly"
    end
  end

  describe "shows local mail adapter info banner when using Swoosh.Adapters.Local" do
    setup do
      original = Application.get_env(:metric_flow, MetricFlow.Mailer)
      Application.put_env(:metric_flow, MetricFlow.Mailer, adapter: Swoosh.Adapters.Local)
      on_exit(fn -> Application.put_env(:metric_flow, MetricFlow.Mailer, original) end)
      :ok
    end

    test "shows info banner when local adapter is configured", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "local mail adapter"
      assert html =~ "/dev/mailbox"
    end
  end
end
