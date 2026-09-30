defmodule MetricFlowSpex.EachTeamMemberHasDistinctLoginCredentialsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Each team member has distinct login credentials", criterion: 530 do
    scenario "a teammate sets up their own access, separate from every other user" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      when_ "the teammate logs in with their own email and password", context do
        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: context.second_user_password,
            remember_me: true
          })

        result_conn = submit_form(login_form, build_conn())
        {:ok, Map.put(context, :teammate_login_conn, result_conn)}
      end

      then_ "they have their own separate login credentials", context do
        assert context.second_user_email != context.owner_email
        refute redirected_to(context.teammate_login_conn) == "/users/log-in"
        {:ok, context}
      end

      then_ "an incorrect password does not work for the teammate's email", context do
        # Not context.owner_password: every fixture in this suite hardcodes
        # the same literal password string, so that would coincidentally
        # equal the teammate's real password and defeat this check.
        fresh_conn = build_conn()
        {:ok, login_view, _html} = live(fresh_conn, "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: "DefinitelyWrongPassword999!"
          })

        render_submit(login_form)
        wrong_password_conn = follow_trigger_action(login_form, fresh_conn)

        assert redirected_to(wrong_password_conn) == "/users/log-in"
        refute get_session(wrong_password_conn, :user_token)

        {:ok, context}
      end
    end
  end
end
