defmodule MetricFlowSpex.SelectingAgencyCreatesAgencyAccountSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import MetricFlowTest.ConnCase, only: [log_in_user: 2]

  spex "Selecting Agency creates an Agency account", criterion: 518 do
    scenario "Alex's account is created as an Agency account" do
      given_ "Alex is registering", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "he selects Agency as his account type", context do
        context.view
        |> form("#registration_form", user: %{
          email: "agency_alex@example.com",
          password: "SecurePassword123!",
          account_name: "Alex Agency Co",
          account_type: "agency"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "his account is created as an Agency account", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email("agency_alex@example.com")
        auth_conn = log_in_user(build_conn(), user)

        {:ok, accounts_view, _html} = live(auth_conn, "/app/accounts")
        html = render(accounts_view)

        assert html =~ "Alex Agency Co"
        assert html =~ "Agency"

        {:ok, context}
      end
    end
  end
end
