defmodule MetricFlowSpex.EmailVerificationRequiredSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Email verification is required before account activation" do
    scenario "after registration, user is told to verify their email before accessing the app" do
      given_ "a new user submits the registration form", context do
        {:ok, view, _html} = live(context.conn, "/users/register")

        view
        |> form("#registration_form", user: %{
          email: "verify_me@example.com",
          password: "SecurePassword123!",
          account_name: "Verify Co"
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees a message instructing them to check their email", context do
        assert render(context.view) =~ "An email was sent to verify_me@example.com"
        :ok
      end

      then_ "the user sees a message to confirm their account via the email link", context do
        assert render(context.view) =~ "confirm your account"
        :ok
      end
    end

    scenario "an unverified user cannot access authenticated routes" do
      given_ "a new user has just registered but not yet confirmed their email", context do
        {:ok, view, _html} = live(context.conn, "/users/register")

        view
        |> form("#registration_form", user: %{
          email: "unverified_user@example.com",
          password: "SecurePassword123!",
          account_name: "Unverified Co"
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the unverified user tries to navigate to a protected route", context do
        result = live(context.conn, "/app/users/settings")
        {:ok, Map.put(context, :settings_result, result)}
      end

      then_ "the user is redirected to the login page instead of accessing the protected area", context do
        case context.settings_result do
          {:ok, _view, _html} ->
            flunk("Expected redirect to login, but got access to settings page")

          {:error, {:redirect, %{to: path}}} ->
            assert path =~ "/users/log-in"

          {:error, {:live_redirect, %{to: path}}} ->
            assert path =~ "/users/log-in"
        end

        :ok
      end
    end
  end
end
