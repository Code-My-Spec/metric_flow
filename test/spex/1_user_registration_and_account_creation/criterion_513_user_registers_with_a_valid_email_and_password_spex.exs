defmodule MetricFlowSpex.UserRegistersWithValidEmailAndPasswordSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import MetricFlowTest.ConnCase, only: [log_in_user: 2]

  spex "User registers with a valid email and password", criterion: 513 do
    scenario "a new account is created for the registering user" do
      given_ "Dana is a new visitor on the registration page", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Dana submits a valid email and password on the registration form", context do
        context.view
        |> form("#registration_form", user: %{
          email: "dana@example.com",
          password: "SecurePassword123!",
          account_name: "Dana's Company"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "a new account is created for Dana", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email("dana@example.com")
        auth_conn = log_in_user(build_conn(), user)

        {:ok, accounts_view, _html} = live(auth_conn, "/app/accounts")

        refute has_element?(accounts_view, "*", "No accounts found.")
        assert has_element?(accounts_view, "[data-role='account-card']")

        {:ok, context}
      end
    end
  end
end
