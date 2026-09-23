defmodule MetricFlowSpex.CreatorBecomesOriginatorAndOwnerSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User who creates the account becomes the originator and default owner" do
    scenario "registration confirmation message acknowledges the account was created for the user" do
      given_ "the user navigates to the registration page", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits the registration form with account details", context do
        context.view
        |> form("#registration_form", user: %{
          email: "founder@example.com",
          password: "SecurePassword123!",
          account_name: "Founder Corp",
          account_type: "client"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the user sees a confirmation that their account was created", context do
        assert render(context.view) =~ "An email was sent to founder@example.com"
        :ok
      end

      then_ "the confirmation message references the account name they provided", context do
        assert render(context.view) =~ "Founder Corp"
        :ok
      end
    end

    scenario "after logging in, the account creator sees their Owner role on the accounts page" do
      given_ "a user registers and completes the full registration flow", context do
        # Register through the UI
        {:ok, view, _html} = live(context.conn, "/users/register")

        view
        |> form("#registration_form", user: %{
          email: "owner_check@example.com",
          password: "SecurePassword123!",
          account_name: "Owner Corp",
          account_type: "client"
        })
        |> render_submit()

        # Authenticate the registered user for subsequent requests
        user = MetricFlow.Users.get_user_by_email("owner_check@example.com")
        auth_conn = log_in_user(build_conn(), user)

        {:ok, context |> Map.put(:registered_email, "owner_check@example.com") |> Map.put(:conn, auth_conn)}
      end

      when_ "the authenticated user navigates to the accounts page", context do
        result = live(context.conn, "/app/accounts")
        {:ok, Map.put(context, :accounts_result, result)}
      end

      then_ "the user sees their Owner role displayed on the accounts page", context do
        {:ok, view, _html} = context.accounts_result
        assert render(view) =~ "Owner"
        :ok
      end
    end

    scenario "after logging in, the account creator is shown as the originator of the account" do
      given_ "a user registers with account details", context do
        {:ok, view, _html} = live(context.conn, "/users/register")

        view
        |> form("#registration_form", user: %{
          email: "originator@example.com",
          password: "SecurePassword123!",
          account_name: "Originator LLC",
          account_type: "client"
        })
        |> render_submit()

        # Authenticate the registered user for subsequent requests
        user = MetricFlow.Users.get_user_by_email("originator@example.com")
        auth_conn = log_in_user(build_conn(), user)

        {:ok, context |> Map.put(:registered_email, "originator@example.com") |> Map.put(:conn, auth_conn)}
      end

      when_ "the authenticated user navigates to the accounts page", context do
        result = live(context.conn, "/app/accounts")
        {:ok, Map.put(context, :accounts_result, result)}
      end

      then_ "the user sees themselves listed as the account originator", context do
        {:ok, view, _html} = context.accounts_result
        html = render(view)
        assert html =~ "originator@example.com"
        :ok
      end
    end
  end
end
