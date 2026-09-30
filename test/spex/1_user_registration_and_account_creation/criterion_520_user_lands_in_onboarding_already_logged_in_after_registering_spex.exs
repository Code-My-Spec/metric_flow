defmodule MetricFlowSpex.UserLandsInOnboardingAfterRegisteringSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  spex "User lands in onboarding already logged in after registering", criterion: 520 do
    scenario "Dana is logged in and directed to onboarding once registration succeeds" do
      given_ "Dana has just completed registration", context do
        {:ok, view, _html} = live(context.conn, "/users/register")

        view
        |> form("#registration_form", user: %{
          email: "onboard_now_dana@example.com",
          password: "SecurePassword123!",
          account_name: "Dana Onboard Co"
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "registration succeeds", context do
        token = MetricFlowSpex.Fixtures.login_token_for("onboard_now_dana@example.com")
        {:ok, confirm_view, _html} = live(context.conn, "/users/log-in/#{token}")

        form =
          form(confirm_view, "#confirmation_form", %{"user" => %{"token" => token}})

        render_submit(form)
        result_conn = follow_trigger_action(form, context.conn)

        {:ok, Map.put(context, :result_conn, result_conn)}
      end

      then_ "Dana is logged in and directed to the onboarding flow", context do
        assert redirected_to(context.result_conn) == "/onboarding"

        {:ok, context}
      end

      then_ "Dana's session is authenticated once she reaches onboarding", context do
        {:ok, onboarding_view, _html} =
          live(recycle(context.result_conn), "/onboarding")

        refute has_element?(onboarding_view, "a", "Log in")

        {:ok, context}
      end
    end
  end
end
