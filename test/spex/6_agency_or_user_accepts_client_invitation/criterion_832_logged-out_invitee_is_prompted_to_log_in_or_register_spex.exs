defmodule MetricFlowSpex.Criterion832LoggedOutInviteeIsPromptedToLogInOrRegisterSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Logged-out invitee is prompted to log in or register", criterion: 832 do
    scenario "a logged-out invitee opening the invitation link is offered log in and register" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner has sent an invitation", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form",
          invitation: %{
            email: context.second_user_email,
            role: "read_only"
          }
        )
        |> render_submit()

        token =
          assert_email_sent(fn email ->
            [_, t] = Regex.run(~r|/invitations/([^\s/]+)|, email.text_body)
            t
          end)

        {:ok, Map.put(context, :invitation_token, token)}
      end

      when_ "the logged-out invitee opens the invitation link", context do
        conn = build_conn()
        {:ok, view, _html} = live(conn, "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page prompts them to log in", context do
        assert has_element?(context.view, "[data-role=log-in-btn]", "Log In to Accept")
        {:ok, context}
      end

      then_ "the page prompts them to register", context do
        assert has_element?(context.view, "[data-role=register-btn]", "Create an Account")
        {:ok, context}
      end
    end
  end
end
