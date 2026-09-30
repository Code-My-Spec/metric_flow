defmodule MetricFlowSpex.UsersOnDifferentAccountsCannotSeeEachOthersDataSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Users on different accounts cannot see each other's data", criterion: 540 do
    scenario "a user from one account cannot view another account's data" do
      given_ :user_logged_in_as_owner

      given_ "a completely separate user registers their own account", context do
        email = "separate#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        {:ok, reg_view, _html} = live(build_conn(), "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: email,
          password: password,
          account_name: "Separate Account"
        })
        |> render_submit()

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: email,
            password: password,
            remember_me: true
          })

        separate_conn = build_conn() |> then(&submit_form(login_form, &1)) |> recycle()

        {:ok, Map.merge(context, %{separate_conn: separate_conn, separate_email: email})}
      end

      when_ "a user from Dana's account attempts to view Alex's account data", context do
        {:ok, _view, html} = live(context.separate_conn, "/app/accounts/members")
        {:ok, Map.put(context, :separate_members_html, html)}
      end

      then_ "access is denied and no cross-account data is shown", context do
        refute context.separate_members_html =~ context.owner_email
        assert context.separate_members_html =~ context.separate_email

        {:ok, context}
      end
    end
  end
end
