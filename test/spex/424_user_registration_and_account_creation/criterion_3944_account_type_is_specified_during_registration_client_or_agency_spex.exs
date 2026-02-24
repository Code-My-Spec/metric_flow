defmodule MetricFlowSpex.AccountTypeSpecifiedDuringRegistrationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Account type is specified during registration (Client or Agency)" do
    scenario "registration form shows account type options" do
      given_ "the user navigates to the registration page", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees an account type field on the form", context do
        assert has_element?(context.view, "[name='user[account_type]']")
        :ok
      end

      then_ "the user sees a Client option", context do
        html = render(context.view)
        assert html =~ "Client"
        :ok
      end

      then_ "the user sees an Agency option", context do
        html = render(context.view)
        assert html =~ "Agency"
        :ok
      end
    end

    scenario "user selects Client account type and completes registration" do
      given_ "the user navigates to the registration page", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user fills in the form with the Client account type and submits", context do
        context.view
        |> form("#registration_form", user: %{
          email: "client_user@example.com",
          password: "SecurePassword123!",
          account_name: "Client Corp",
          account_type: "client"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the user sees a confirmation message that registration was successful", context do
        assert render(context.view) =~ "An email was sent to client_user@example.com"
        :ok
      end
    end

    scenario "user selects Agency account type and completes registration" do
      given_ "the user navigates to the registration page", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user fills in the form with the Agency account type and submits", context do
        context.view
        |> form("#registration_form", user: %{
          email: "agency_user@example.com",
          password: "SecurePassword123!",
          account_name: "Agency Inc",
          account_type: "agency"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the user sees a confirmation message that registration was successful", context do
        assert render(context.view) =~ "An email was sent to agency_user@example.com"
        :ok
      end
    end
  end
end
