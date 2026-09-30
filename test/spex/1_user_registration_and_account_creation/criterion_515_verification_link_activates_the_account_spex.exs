defmodule MetricFlowSpex.VerificationLinkActivatesAccountSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  spex "Verification link activates the account", criterion: 515 do
    scenario "Dana's account becomes activated after she clicks the verification link" do
      given_ "Dana received a verification email after registering", context do
        {:ok, view, _html} = live(context.conn, "/users/register")

        view
        |> form("#registration_form", user: %{
          email: "activate_dana@example.com",
          password: "SecurePassword123!",
          account_name: "Dana Activation Co"
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "Dana clicks the verification link", context do
        token = MetricFlowSpex.Fixtures.login_token_for("activate_dana@example.com")
        result = live(context.conn, "/users/log-in/#{token}")
        {:ok, Map.put(context, :verify_result, result)}
      end

      then_ "Dana's account becomes activated and she can reach the app", context do
        access_result =
          case context.verify_result do
            {:ok, _view, _html} ->
              live(context.conn, "/app/accounts")

            {:error, {:redirect, %{to: path}}} when path != "/users/log-in" ->
              live(recycle(context.conn), "/app/accounts")

            {:error, {:live_redirect, %{to: path}}} when path != "/users/log-in" ->
              live(recycle(context.conn), "/app/accounts")

            other ->
              other
          end

        case access_result do
          {:ok, view, _html} ->
            assert has_element?(view, "h1, h2", "Your Accounts")

          other ->
            flunk(
              "Expected Dana to reach the app after clicking the verification link, " <>
                "but she was denied access: #{inspect(other)}"
            )
        end

        {:ok, context}
      end
    end
  end
end
