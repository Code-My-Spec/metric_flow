defmodule MetricFlowSpex.AccountNameDuringRegistrationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User is prompted to create an account name during registration" do
    scenario "registration form displays an account name field" do
      given_ "the user navigates to the registration page", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees an account name input field on the form", context do
        assert has_element?(context.view, "input[name='user[account_name]']")
        :ok
      end

      then_ "the form prompts the user to enter an account name", context do
        assert render(context.view) =~ "account name"
        :ok
      end
    end

    scenario "account name is required to complete registration" do
      given_ "the user navigates to the registration page", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits the form without an account name", context do
        context.view
        |> form("#registration_form", user: %{
          email: "no_account_name@example.com",
          password: "SecurePassword123!",
          account_name: ""
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the user sees a validation error indicating account name is required", context do
        assert render(context.view) =~ "can&#39;t be blank"
        :ok
      end
    end

    scenario "user successfully registers with an account name" do
      given_ "the user navigates to the registration page", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user fills in email, password, and account name and submits the form", context do
        context.view
        |> form("#registration_form", user: %{
          email: "with_account@example.com",
          password: "SecurePassword123!",
          account_name: "My Company"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the user sees a confirmation message that registration was successful", context do
        assert render(context.view) =~ "An email was sent to with_account@example.com"
        :ok
      end
    end
  end
end
