defmodule MetricFlowSpex.RegisteringUserBecomesDefaultOwnerSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import MetricFlowTest.ConnCase, only: [log_in_user: 2]

  spex "Registering user becomes the account's default owner", criterion: 519 do
    scenario "Alex is recorded as the account's default owner" do
      given_ "Alex completes registration for a new Agency account", context do
        {:ok, view, _html} = live(context.conn, "/users/register")

        view
        |> form("#registration_form", user: %{
          email: "owner_alex@example.com",
          password: "SecurePassword123!",
          account_name: "Alex Owner Co",
          account_type: "agency"
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "the account is created and Alex views his accounts page", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email("owner_alex@example.com")
        auth_conn = log_in_user(build_conn(), user)

        {:ok, view, _html} = live(auth_conn, "/app/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "Alex is shown as the account's owner", context do
        html = render(context.view)

        assert html =~ "Alex Owner Co"
        assert html =~ "owner"

        {:ok, context}
      end
    end
  end
end
