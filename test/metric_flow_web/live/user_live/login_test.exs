defmodule MetricFlowWeb.UserLive.LoginTest do
  use MetricFlowTest.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  describe "renders login page with magic link form and password form" do
    test "renders login page with magic link form and password form", %{conn: conn} do
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
    test "autofocuses email input on mount", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "phx-mounted"
    end
  end

  describe "shows Sign up link for unauthenticated users" do
    test "shows Sign up link for unauthenticated users", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "Sign up"
      assert html =~ ~s(href="/users/register")
    end
  end

  describe "sends magic link email and shows ambiguous confirmation flash when user exists" do
    test "sends magic link email and shows ambiguous confirmation flash when user exists", %{conn: conn} do
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
    test "shows same ambiguous confirmation flash when user does not exist", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", user: %{email: "idonotexist@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"
    end
  end

  describe "triggers password form submission to UserSessionController on submit_password event" do
    test "triggers password form submission to UserSessionController on submit_password event", %{conn: conn} do
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
    test "redirects to signed-in path with valid password credentials", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password",
          user: %{email: user.email, password: valid_user_password(), remember_me: true}
        )

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/app/integrations"
    end
  end

  describe "shows invalid email or password error with invalid credentials" do
    test "shows invalid email or password error with invalid credentials", %{conn: conn} do
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
    test "navigates to registration page when Sign up link is clicked", %{conn: conn} do
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

    test "shows reauthentication notice in sudo mode with email pre-filled", %{conn: conn, user: user} do
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

    test "hides Sign up link in sudo mode", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      refute html =~ ">Sign up<"
    end
  end

  describe "makes email input readonly in sudo mode" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user)}
    end

    test "makes email input readonly in sudo mode", %{conn: conn} do
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

    test "shows local mail adapter info banner when using Swoosh.Adapters.Local", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "local mail adapter"
      assert html =~ "/dev/mailbox"
    end
  end
end
