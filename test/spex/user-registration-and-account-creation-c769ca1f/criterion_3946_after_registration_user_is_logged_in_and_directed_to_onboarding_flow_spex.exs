defmodule MetricFlowSpex.PostRegistrationOnboardingRedirectSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "After registration, user is logged in and directed to onboarding flow" do
    scenario "after completing email verification, the user is redirected to the onboarding flow" do
      given_ "a new user submits the registration form", context do
        {:ok, view, _html} = live(context.conn, "/users/register")

        view
        |> form("#registration_form", user: %{
          email: "onboarding_user@example.com",
          password: "SecurePassword123!",
          account_name: "Onboarding Co",
          account_type: "client"
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user visits the email confirmation link to verify their account", context do
        # Generate a real login token for the registered user
        user = MetricFlow.Users.get_user_by_email("onboarding_user@example.com")

        {:ok, captured_email} =
          MetricFlow.Users.deliver_login_instructions(user, &"[TOKEN]#{&1}[TOKEN]")

        [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")

        result = live(context.conn, "/users/log-in/#{token}")
        {:ok, Map.put(context, :confirmation_result, result)}
      end

      then_ "the user is redirected to the onboarding flow instead of the login page", context do
        case context.confirmation_result do
          {:error, {:redirect, %{to: path}}} ->
            assert path =~ "/onboarding",
                   "Expected redirect to onboarding flow, but was redirected to: #{path}"

          {:error, {:live_redirect, %{to: path}}} ->
            assert path =~ "/onboarding",
                   "Expected live redirect to onboarding flow, but was redirected to: #{path}"

          {:ok, view, _html} ->
            assert render(view) =~ "onboarding",
                   "Expected to land on onboarding page after email verification"
        end

        :ok
      end
    end

    scenario "after registration and verification, the user sees the onboarding welcome experience" do
      given_ "a verified user navigates to the onboarding page", context do
        # Create and authenticate a verified user
        user = MetricFlowTest.UsersFixtures.user_fixture()
        auth_conn = log_in_user(build_conn(), user)

        result = live(auth_conn, "/onboarding")
        {:ok, Map.put(context, :onboarding_result, result)}
      end

      then_ "the user sees an onboarding setup experience with a welcome message", context do
        {:ok, view, _html} = context.onboarding_result
        html = render(view)
        assert html =~ "welcome" or html =~ "Welcome" or html =~ "get started" or
                 html =~ "Get started" or html =~ "Getting Started" or html =~ "onboarding" or
                 html =~ "Onboarding",
               "Expected the onboarding page to contain a welcome or setup message"

        :ok
      end
    end

    scenario "after registration, the user is not sent to the login page but directly into the app" do
      given_ "the registration page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user submits a valid registration form", context do
        result =
          context.view
          |> form("#registration_form", user: %{
            email: "direct_login@example.com",
            password: "SecurePassword123!",
            account_name: "Direct Login Inc",
            account_type: "client"
          })
          |> render_submit()

        {:ok, Map.put(context, :submit_result, result)}
      end

      then_ "the user does not see a message directing them back to the login page", context do
        html = render(context.view)
        # The desired behavior is NOT to tell the user to go log in manually —
        # they should be automatically authenticated and directed to onboarding.
        refute html =~ "Please log in",
               "User should not be directed to log in manually after registration"

        refute html =~ "Sign in to continue",
               "User should be authenticated automatically, not asked to sign in"

        :ok
      end

      then_ "the post-registration view confirms the user's account setup journey has begun", context do
        html = render(context.view)
        # The confirmation message should indicate next steps toward onboarding,
        # not simply an email-sent notice that dead-ends the user.
        assert html =~ "onboard" or html =~ "Onboard" or html =~ "get started" or
                 html =~ "Get Started" or html =~ "set up" or html =~ "Set up",
               "Expected confirmation that user's account journey is beginning"

        :ok
      end
    end
  end
end
