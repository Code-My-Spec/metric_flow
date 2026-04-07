defmodule MetricFlowWeb.UserLive.RegistrationTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  describe "renders registration form with email, password, account name, and account type fields" do
    test "renders registration form with email, password, account name, and account type fields", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ ~s(type="email")
      assert html =~ ~s(type="password")
      assert html =~ "Account name"
      assert html =~ "Account type"
      assert html =~ "Client"
      assert html =~ "Agency"
    end
  end

  describe "autofocuses email input on mount" do
    test "autofocuses email input on mount", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "phx-mounted"
    end
  end

  describe "shows Already registered? subtitle with link to log in page" do
    test "shows Already registered? subtitle with link to log in page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Already registered?"
      assert html =~ ~s(href="/users/log-in")
      assert html =~ "Log in"
    end
  end

  describe "redirects to signed-in path if user is already logged in" do
    test "redirects to signed-in path if user is already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn, ~p"/app/integrations")

      assert {:ok, _conn} = result
    end
  end

  describe "live-validates email format on change and shows inline error for invalid email" do
    test "live-validates email format on change and shows inline error for invalid email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces"})

      assert result =~ "must have the @ sign and no spaces"
    end
  end

  describe "shows has already been taken error when submitting a duplicate email" do
    test "shows has already been taken error when submitting a duplicate email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture(%{email: "test@email.com"})

      result =
        lv
        |> form("#registration_form", user: %{"email" => user.email})
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end

  describe "creates user and shows success screen with confirmation email message on valid submit" do
    test "creates user and shows success screen with confirmation email message on valid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()
      form = form(lv, "#registration_form", user: valid_user_attributes(email: email))

      render_submit(form)

      assert render(lv) =~ "Registration successful"
      assert render(lv) =~ "An email was sent to #{email}"
      assert render(lv) =~ "Please confirm your account to get started"
    end
  end

  describe "displays account name confirmation on success screen when account name was provided" do
    test "displays account name confirmation on success screen when account name was provided", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()

      form =
        form(lv, "#registration_form",
          user: valid_user_attributes(email: email, account_name: "My Company")
        )

      render_submit(form)

      assert render(lv) =~ "My Company"
      assert render(lv) =~ "has been created"
    end
  end

  describe "shows Creating account... on submit button while form is processing" do
    test "shows Creating account... on submit button while form is processing", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Creating account..."
    end
  end

  describe "navigates to login page when Log in link is clicked" do
    test "navigates to login page when Log in link is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Log in")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert login_html =~ "Log in"
    end
  end
end
