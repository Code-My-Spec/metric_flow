defmodule MetricFlowSpex.IfNotLoggedInUserIsPromptedToLogInOrRegisterSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import_givens MetricFlowSpex.SharedGivens

  spex "If not logged in, user is prompted to log in or register" do
    scenario "anonymous user visiting an invitation link sees log in and register options" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner has sent an invitation", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        token =
          assert_email_sent(fn email ->
            [_, t] = Regex.run(~r|/invitations/([^\s/]+)|, email.text_body)
            t
          end)

        {:ok, Map.put(context, :invitation_token, token)}
      end

      when_ "an unauthenticated user visits an invitation acceptance URL", context do
        conn = build_conn()
        {:ok, view, _html} = live(conn, "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page prompts the user to log in", context do
        assert has_element?(context.view, "[data-role=log-in-btn]", "Log In to Accept")
        :ok
      end

      then_ "the page prompts the user to register", context do
        assert has_element?(context.view, "[data-role=register-btn]", "Create an Account")
        :ok
      end
    end

    scenario "anonymous user can navigate to registration from the invitation page" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner has sent an invitation", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        token =
          assert_email_sent(fn email ->
            [_, t] = Regex.run(~r|/invitations/([^\s/]+)|, email.text_body)
            t
          end)

        {:ok, Map.put(context, :invitation_token, token)}
      end

      when_ "an unauthenticated user visits an invitation acceptance URL", context do
        conn = build_conn()
        {:ok, view, _html} = live(conn, "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a register link is present on the page", context do
        assert has_element?(context.view, "[data-role=register-btn]", "Create an Account")
        :ok
      end
    end

    scenario "anonymous user can navigate to login from the invitation page" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner has sent an invitation", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        token =
          assert_email_sent(fn email ->
            [_, t] = Regex.run(~r|/invitations/([^\s/]+)|, email.text_body)
            t
          end)

        {:ok, Map.put(context, :invitation_token, token)}
      end

      when_ "an unauthenticated user visits an invitation acceptance URL", context do
        conn = build_conn()
        {:ok, view, _html} = live(conn, "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a log in link is present on the page", context do
        assert has_element?(context.view, "[data-role=log-in-btn]", "Log In to Accept")
        :ok
      end
    end
  end
end
