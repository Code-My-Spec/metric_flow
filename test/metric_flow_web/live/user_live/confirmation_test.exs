defmodule MetricFlowWeb.UserLive.ConfirmationTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Users

  setup do
    %{unconfirmed_user: unconfirmed_user_fixture(), confirmed_user: user_fixture()}
  end

  describe "renders in Layouts.content as an Anderson BI centred card with the logo" do
    test "logged-out confirmation with a valid magic-link token renders the Anderson BI card and gradient confirm, not the old daisyUI shell",
         %{conn: conn, unconfirmed_user: user} do
      token =
        extract_user_token(fn url ->
          Users.deliver_login_instructions(user, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/users/log-in/#{token}")

      # Public Layouts.content is used (not Layouts.app): its Privacy/Terms
      # footer is only emitted by the content layout.
      assert html =~ "Privacy Policy"

      # The confirmation card uses the DESIGN.md Card tokens (bg-base-200
      # on a neutral border with the theme radius), matching the login card.
      assert html =~ "rounded-box border border-neutral bg-base-200"

      # The Anderson BI logo is rendered inline above the card (not just in
      # the layout header), matching the login / forgot-password /
      # reset-password pages.
      assert Regex.match?(
               ~r/<img[^>]*\/images\/anderson-bi-logo\.png[^>]*data-role="default-logo"/,
               html
             ) or
               Regex.match?(
                 ~r/<img[^>]*data-role="default-logo"[^>]*\/images\/anderson-bi-logo\.png/,
                 html
               )

      # The primary confirm action uses the DESIGN.md Primary (brand
      # gradient) button, not the previous daisyUI `btn btn-primary`.
      assert html =~ "btn-brand-gradient"

      refute Regex.match?(
               ~r/class="[^"]*\bbtn btn-primary\b[^"]*"[^>]*>\s*Confirm and stay logged in/,
               html
             )

      # The existing ids the tests rely on are still rendered.
      assert html =~ ~s(id="confirmation_form")
    end
  end

  describe "Confirm user" do
    test "auto-confirms unconfirmed user and redirects to onboarding", %{
      conn: conn,
      unconfirmed_user: user
    } do
      token =
        extract_user_token(fn url ->
          Users.deliver_login_instructions(user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in/#{token}")

      form = form(lv, "#confirmation_form", %{"user" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/onboarding"
      assert Users.get_user!(user.id).confirmed_at

      conn = get(recycle(conn), ~p"/app/accounts")
      assert html_response(conn, 200)
    end

    test "renders login page for confirmed user", %{conn: conn, confirmed_user: user} do
      token =
        extract_user_token(fn url ->
          Users.deliver_login_instructions(user, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/users/log-in/#{token}")
      refute html =~ "Confirm my account"
      assert html =~ "Keep me logged in on this device"
    end

    test "renders login page for already logged in user", %{conn: conn, confirmed_user: user} do
      conn = log_in_user(conn, user)

      token =
        extract_user_token(fn url ->
          Users.deliver_login_instructions(user, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/users/log-in/#{token}")
      refute html =~ "Confirm my account"
      assert html =~ "Log in"
    end

    test "confirms the given token once", %{conn: conn, unconfirmed_user: user} do
      token =
        extract_user_token(fn url ->
          Users.deliver_login_instructions(user, url)
        end)

      # First visit auto-submits the confirm form, which confirms and logs in
      {:ok, lv, _html} = live(conn, ~p"/users/log-in/#{token}")

      form = form(lv, "#confirmation_form", %{"user" => %{"token" => token}})
      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/onboarding"
      assert Users.get_user!(user.id).confirmed_at

      # Token is consumed, second visit (with a fresh, unauthenticated conn)
      # redirects to login with error
      fresh_conn = build_conn()

      {:ok, _lv, html} =
        live(fresh_conn, ~p"/users/log-in/#{token}")
        |> follow_redirect(fresh_conn, ~p"/users/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end

    test "logs confirmed user in without changing confirmed_at", %{
      conn: conn,
      confirmed_user: user
    } do
      token =
        extract_user_token(fn url ->
          Users.deliver_login_instructions(user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in/#{token}")

      form = form(lv, "#login_form", %{"user" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Welcome back!"

      assert Users.get_user!(user.id).confirmed_at == user.confirmed_at

      # log out, new conn
      conn = build_conn()

      {:ok, _lv, html} =
        live(conn, ~p"/users/log-in/#{token}")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end

    test "raises error for invalid token", %{conn: conn} do
      {:ok, _lv, html} =
        live(conn, ~p"/users/log-in/invalid-token")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end
  end
end
