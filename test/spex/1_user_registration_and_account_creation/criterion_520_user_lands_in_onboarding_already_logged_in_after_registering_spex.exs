defmodule MetricFlowSpex.UserLandsInOnboardingAfterRegisteringSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  spex "User lands in onboarding already logged in after registering", criterion: 520 do
    scenario "Dana is logged in and directed to onboarding as soon as registration succeeds" do
      given_ "Dana has just completed registration", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "registration succeeds", context do
        result =
          context.view
          |> form("#registration_form", user: %{
            email: "onboard_now_dana@example.com",
            password: "SecurePassword123!",
            account_name: "Dana Onboard Co"
          })
          |> render_submit()

        {:ok, Map.put(context, :submit_result, result)}
      end

      then_ "Dana is logged in and directed to the onboarding flow", context do
        case context.submit_result do
          html when is_binary(html) ->
            flunk(
              "Expected registration to log Dana in and redirect her to onboarding, " <>
                "but the registration page re-rendered in place instead"
            )

          {:error, {:redirect, %{to: path}}} ->
            assert path =~ "/onboarding"

          {:error, {:live_redirect, %{to: path}}} ->
            assert path =~ "/onboarding"
        end

        {:ok, context}
      end
    end
  end
end
