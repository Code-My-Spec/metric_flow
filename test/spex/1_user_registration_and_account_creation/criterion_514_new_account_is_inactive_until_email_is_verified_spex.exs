defmodule MetricFlowSpex.NewAccountInactiveUntilVerifiedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  spex "New account is inactive until email is verified", criterion: 514 do
    scenario "Dana's account is not fully activated before she confirms her email" do
      given_ "Dana has just registered", context do
        {:ok, view, _html} = live(context.conn, "/users/register")

        view
        |> form("#registration_form", user: %{
          email: "unactivated_dana@example.com",
          password: "SecurePassword123!",
          account_name: "Dana Ventures"
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "Dana has not yet clicked the verification link and tries to access the app", context do
        result = live(context.conn, "/app/accounts")
        {:ok, Map.put(context, :access_result, result)}
      end

      then_ "Dana's account is not fully activated", context do
        case context.access_result do
          {:ok, _view, _html} ->
            flunk("Expected the unverified account to be denied access, but it was granted")

          {:error, {:redirect, %{to: path}}} ->
            assert path =~ "/users/log-in"

          {:error, {:live_redirect, %{to: path}}} ->
            assert path =~ "/users/log-in"
        end

        {:ok, context}
      end
    end
  end
end
