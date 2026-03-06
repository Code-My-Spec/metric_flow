defmodule MetricFlowSpex.UsersWhoRegisterWithMatchingEmailDomainAreAutomaticallyAddedToAgencyAccountSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Users who register with matching email domain are automatically added to agency account" do
    scenario "new user with matching email domain is auto-enrolled in the agency account after registration" do
      given_ :user_logged_in_as_owner

      given_ "the owner configures auto-enrollment for domain testco.com", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")

        view
        |> form("#auto-enrollment-form", auto_enrollment: %{
          domain: "testco.com"
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "a new user registers with an email matching that domain", context do
        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: "newuser@testco.com",
          password: "SecurePassword123!",
          account_name: "New User Account"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the new user appears as a member of the agency account", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")
        html = render(view)
        assert html =~ "newuser@testco.com"
        :ok
      end
    end

    scenario "new user with non-matching email domain is NOT auto-enrolled" do
      given_ :user_logged_in_as_owner

      given_ "the owner configures auto-enrollment for domain testco.com", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")

        view
        |> form("#auto-enrollment-form", auto_enrollment: %{
          domain: "testco.com"
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "a new user registers with an email from a different domain", context do
        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: "outsider@otherdomain.com",
          password: "SecurePassword123!",
          account_name: "Other Account"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the outsider user does not appear in the agency members list", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")
        html = render(view)
        refute html =~ "outsider@otherdomain.com"
        :ok
      end

      then_ "only the owner remains in the agency members list", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/members")
        html = render(view)
        assert html =~ context.owner_email
        :ok
      end
    end
  end
end
