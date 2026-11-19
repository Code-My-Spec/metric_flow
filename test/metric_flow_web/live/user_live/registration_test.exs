defmodule MetricFlowWeb.UserLive.RegistrationTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  describe "renders registration form with email, password, account name, and account type fields" do
    test "renders registration form with email, password, account name, and account type fields",
         %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ ~s(type="email")
      assert html =~ ~s(type="password")
      assert html =~ "Account name"
      assert html =~ "Account type"
      assert html =~ "Client"
      assert html =~ "Agency"
    end
  end

  test "explains account types beside the accessible selector", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/register")

    assert has_element?(
             view,
             "#registration_form select[name='user[account_type]'][aria-describedby='account-type-help']"
           )

    assert has_element?(view, "#account-type-help", "your own business")
    assert has_element?(view, "#account-type-help", "multiple client businesses")
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
        |> follow_redirect(conn, ~p"/app/chat")

      assert {:ok, _conn} = result
    end
  end

  describe "live-validates email format on change and shows inline error for invalid email" do
    test "live-validates email format on change and shows inline error for invalid email", %{
      conn: conn
    } do
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
    test "creates user and shows success screen with confirmation email message on valid submit",
         %{conn: conn} do
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
    test "displays account name confirmation on success screen when account name was provided", %{
      conn: conn
    } do
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

  describe "registering through an agency referral link" do
    alias MetricFlow.Accounts.AccountMember
    alias MetricFlow.Agencies.AgencyClientAccessGrant
    alias MetricFlow.Onboarding.Tools
    alias MetricFlow.Repo
    alias MetricFlow.Users.User

    defp agency_with_team do
      joel = user_fixture()
      teammate = user_fixture()
      agency = MetricFlowTest.AgenciesFixtures.account_with_member_fixture(joel, :owner)

      %AccountMember{}
      |> AccountMember.changeset(%{account_id: agency.id, user_id: teammate.id, role: :member})
      |> Repo.insert!()

      {agency, joel, teammate}
    end

    defp register_via(conn, token) do
      email = unique_user_email()
      {:ok, lv, _html} = live(conn, ~p"/users/register?ref=#{token}")

      html =
        lv
        |> form("#registration_form",
          user: valid_user_attributes(email: email, account_name: "Acme")
        )
        |> render_submit()

      jane = Repo.get_by!(User, email: email)
      [%{id: acme_id, name: "Acme"}] = MetricFlow.AccountAccess.memberships(jane.id)
      {html, acme_id}
    end

    test "gives the agency and its whole team account_manager access to the client", %{
      conn: conn
    } do
      {agency, joel, teammate} = agency_with_team()
      token = MetricFlow.Agencies.generate_referral_token(agency.id)

      {_html, acme_id} = register_via(conn, token)

      assert %AgencyClientAccessGrant{access_level: :account_manager} =
               Repo.get_by(AgencyClientAccessGrant,
                 agency_account_id: agency.id,
                 client_account_id: acme_id
               )

      for user <- [joel, teammate] do
        assert %AccountMember{role: :account_manager} =
                 Repo.get_by(AccountMember, account_id: acme_id, user_id: user.id)
      end

      assert {:ok, %{accounts: accounts}} = Tools.call(:mcp, "list_accounts", %{}, %{user: joel})
      assert %{name: "Acme", can_change_setup: true} = Enum.find(accounts, &(&1.id == acme_id))

      result =
        Tools.call(
          :mcp,
          "save_sync_selection",
          %{"account_id" => acme_id, "product" => "google_analytics", "ids" => ["123"]},
          %{user: joel}
        )

      refute match?({:error, "Your role on this account is read-only" <> _}, result)
      refute match?({:error, "You are not a member of account" <> _}, result)
    end

    test "a forged or expired ref token grants nothing and registration still succeeds", %{
      conn: conn
    } do
      {agency, joel, teammate} = agency_with_team()

      secret =
        :metric_flow
        |> Application.get_env(MetricFlowWeb.Endpoint, [])
        |> Keyword.fetch!(:secret_key_base)

      expired =
        Phoenix.Token.sign(secret, "agency_referral", agency.id,
          signed_at: System.system_time(:second) - 2 * 365 * 24 * 60 * 60
        )

      forged = MetricFlow.Agencies.generate_referral_token(agency.id) <> "tampered"

      for token <- [expired, forged] do
        {html, acme_id} = register_via(conn, token)
        assert html =~ "Acme" or html =~ "@"

        refute Repo.get_by(AgencyClientAccessGrant,
                 agency_account_id: agency.id,
                 client_account_id: acme_id
               )

        for user <- [joel, teammate] do
          refute Repo.get_by(AccountMember, account_id: acme_id, user_id: user.id)
        end
      end
    end
  end
end
