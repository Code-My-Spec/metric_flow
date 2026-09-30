defmodule MetricFlowSpex.SelectingClientCreatesClientAccountSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import MetricFlowTest.ConnCase, only: [log_in_user: 2]

  spex "Selecting Client creates a Client account", criterion: 517 do
    scenario "Dana's account is created as a Client account" do
      given_ "Dana is registering", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "she selects Client as her account type", context do
        context.view
        |> form("#registration_form", user: %{
          email: "client_dana@example.com",
          password: "SecurePassword123!",
          account_name: "Dana Client Co",
          account_type: "client"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "her account is created as a Client account", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email("client_dana@example.com")
        auth_conn = log_in_user(build_conn(), user)

        {:ok, accounts_view, _html} = live(auth_conn, "/app/accounts")
        html = render(accounts_view)

        assert html =~ "Dana Client Co"
        assert html =~ "Client"

        {:ok, context}
      end
    end
  end
end
