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
        {:ok, confirm_view, _html} = live(context.conn, "/users/log-in/#{token}")

        form =
          form(confirm_view, "#confirmation_form", %{"user" => %{"token" => token}})

        render_submit(form)
        authenticated_conn = follow_trigger_action(form, context.conn)

        {:ok, Map.put(context, :authenticated_conn, authenticated_conn)}
      end

      then_ "Dana's account becomes activated and she can reach the app", context do
        {:ok, accounts_view, _html} = live(context.authenticated_conn, "/app/accounts")
        assert has_element?(accounts_view, "h1, h2", "Your Accounts")

        {:ok, context}
      end
    end
  end
end
