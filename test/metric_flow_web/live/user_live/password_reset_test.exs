defmodule MetricFlowWeb.UserLive.PasswordResetTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Repo
  alias MetricFlow.Users
  alias MetricFlow.Users.UserToken

  describe "renders in Layouts.content as an Anderson BI centred card with the logo" do
    test "logged-out forgot-password renders the Anderson BI card and gradient submit, not the old daisyUI shell",
         %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/forgot-password")

      # Public Layouts.content is used (not Layouts.app): its Privacy/Terms
      # footer is only emitted by the content layout.
      assert html =~ "Privacy Policy"

      # The forgot-password card uses the DESIGN.md Card tokens (bg-base-200
      # on a neutral border with the theme radius), matching the login card.
      assert html =~ "rounded-box border border-neutral bg-base-200"

      # The Anderson BI logo is rendered inline above the card (not just in
      # the layout header), matching the login page.
      assert Regex.match?(
               ~r/<img[^>]*\/images\/anderson-bi-logo\.png[^>]*data-role="default-logo"/,
               html
             ) or
               Regex.match?(
                 ~r/<img[^>]*data-role="default-logo"[^>]*\/images\/anderson-bi-logo\.png/,
                 html
               )

      # The submit button is the DESIGN.md Primary (brand gradient) button,
      # not the previous daisyUI `btn btn-primary`.
      assert html =~ "btn-brand-gradient"

      refute Regex.match?(
               ~r/class="[^"]*\bbtn btn-primary\b[^"]*"[^>]*>\s*Send reset link/,
               html
             )
    end
  end

  test "known and unknown emails receive the same response", %{conn: conn} do
    user = user_fixture() |> set_password()

    {:ok, known_view, _html} = live(conn, ~p"/users/forgot-password")
    known_view |> form("#forgot-password-form", user: %{email: user.email}) |> render_submit()
    assert_redirect(known_view, ~p"/users/log-in")
    assert Repo.get_by!(UserToken, user_id: user.id, context: "reset_password")

    {:ok, unknown_view, _html} = live(conn, ~p"/users/forgot-password")

    unknown_view
    |> form("#forgot-password-form", user: %{email: unique_user_email()})
    |> render_submit()

    assert_redirect(unknown_view, ~p"/users/log-in")
  end

  test "reset link changes password once and revokes existing sessions", %{conn: conn} do
    user = user_fixture() |> set_password()
    session_token = Users.generate_user_session_token(user)

    reset_token =
      extract_user_token(fn url ->
        Users.deliver_password_reset_instructions(user, url)
      end)

    {:ok, view, _html} = live(conn, ~p"/users/reset-password/#{reset_token}")
    assert has_element?(view, "#reset-password-form")

    view
    |> form("#reset-password-form",
      user: %{password: "new password 123", password_confirmation: "new password 123"}
    )
    |> render_submit()

    assert_redirect(view, ~p"/users/log-in")
    assert Users.get_user_by_email_and_password(user.email, "new password 123")
    refute Users.get_user_by_email_and_password(user.email, valid_user_password())
    refute Users.get_user_by_password_reset_token(reset_token)
    refute Users.get_user_by_session_token(session_token)
  end

  test "invalid reset link returns to recovery", %{conn: conn} do
    assert {:error, :invalid_token} =
             Users.reset_user_password("bad-token", %{password: "new password 123"})

    assert {:error, {:live_redirect, %{to: path}}} =
             live(conn, ~p"/users/reset-password/bad-token")

    assert path == ~p"/users/forgot-password"
  end

  test "mismatched confirmation leaves the token usable", %{conn: conn} do
    user = user_fixture() |> set_password()

    reset_token =
      extract_user_token(fn url ->
        Users.deliver_password_reset_instructions(user, url)
      end)

    {:ok, view, _html} = live(conn, ~p"/users/reset-password/#{reset_token}")

    view
    |> form("#reset-password-form",
      user: %{password: "new password 123", password_confirmation: "different password"}
    )
    |> render_submit()

    assert has_element?(view, "#reset-password-form")
    assert Users.get_user_by_password_reset_token(reset_token)
    assert Users.get_user_by_email_and_password(user.email, valid_user_password())
  end
end
