defmodule MetricFlowWeb.UserLive.SettingsTest do
  use MetricFlowTest.ConnCase, async: true

  alias MetricFlow.Users
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp authenticated_conn(conn) do
    log_in_user(conn, user_fixture())
  end

  defp authenticated_conn_with_user(conn) do
    user = user_fixture()
    {log_in_user(conn, user), user}
  end

  # ---------------------------------------------------------------------------
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders settings page with email and password change forms" do
    test "renders settings page with email and password change forms", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> authenticated_conn()
        |> live(~p"/app/users/settings")

      assert html =~ "Account Settings"
      assert html =~ "Change Email"
      assert html =~ "Save Password"
    end
  end

  describe "validates email on change and shows inline errors for invalid email" do
    setup %{conn: conn} do
      {conn, user} = authenticated_conn_with_user(conn)
      %{conn: conn, user: user}
    end

    test "validates email on change and shows inline errors for invalid email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/app/users/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "user" => %{"email" => "invalid email with spaces"}
        })

      assert result =~ "must have the @ sign and no spaces"
    end
  end

  describe "sends email change confirmation link on valid email submit" do
    setup %{conn: conn} do
      {conn, user} = authenticated_conn_with_user(conn)
      %{conn: conn, user: user}
    end

    test "sends email change confirmation link on valid email submit", %{conn: conn, user: user} do
      new_email = unique_user_email()
      {:ok, lv, _html} = live(conn, ~p"/app/users/settings")

      result =
        lv
        |> form("#email_form", %{"user" => %{"email" => new_email}})
        |> render_submit()

      assert result =~ "A link to confirm your email change has been sent to the new address."
      assert Users.get_user_by_email(user.email)
    end
  end

  describe "shows error when submitting email change outside sudo mode" do
    test "shows error when submitting email change outside sudo mode", %{conn: _conn} do
      conn_no_sudo =
        build_conn()
        |> log_in_user(user_fixture(),
          token_authenticated_at: DateTime.add(DateTime.utc_now(:second), -11, :minute)
        )

      assert {:ok, conn_redirected} =
               conn_no_sudo
               |> live(~p"/app/users/settings")
               |> follow_redirect(conn_no_sudo, ~p"/users/log-in")

      assert conn_redirected.resp_body =~ "You must re-authenticate to access this page."
    end
  end

  describe "validates password on change and shows inline errors" do
    setup %{conn: conn} do
      {conn, user} = authenticated_conn_with_user(conn)
      %{conn: conn, user: user}
    end

    test "validates password on change and shows inline errors", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/app/users/settings")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "user" => %{
            "password" => "short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end
  end

  describe "triggers password form submission on valid password submit" do
    setup %{conn: conn} do
      {conn, user} = authenticated_conn_with_user(conn)
      %{conn: conn, user: user}
    end

    test "triggers password form submission on valid password submit", %{conn: conn, user: user} do
      new_password = valid_user_password()
      {:ok, lv, _html} = live(conn, ~p"/app/users/settings")

      form =
        form(lv, "#password_form", %{
          "user" => %{
            "email" => user.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/app/users/settings"

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Users.get_user_by_email_and_password(user.email, new_password)
    end
  end

  describe "processes email confirmation token and shows success flash" do
    test "processes email confirmation token and shows success flash", %{conn: conn} do
      {conn, user} = authenticated_conn_with_user(conn)
      new_email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Users.deliver_user_update_email_instructions(%{user | email: new_email}, user.email, url)
        end)

      {:error, redirect} = live(conn, ~p"/app/users/settings/confirm-email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/app/users/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Users.get_user_by_email(user.email)
      assert Users.get_user_by_email(new_email)
    end
  end

  describe "shows error flash for invalid or expired email confirmation token" do
    test "shows error flash for invalid or expired email confirmation token", %{conn: conn} do
      {conn, user} = authenticated_conn_with_user(conn)

      {:error, redirect} = live(conn, ~p"/app/users/settings/confirm-email/invalid-token")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/app/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Users.get_user_by_email(user.email)
    end

  end
end
