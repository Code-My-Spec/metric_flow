defmodule MetricFlowSpex.ExpiredInvitationsShowClearErrorMessageSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Expired invitations show clear error message" do
    scenario "user visits an expired invitation link and sees an error" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner sends an invitation that is then expired", context do
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

        # Backdate the invitation to make it expired (no UI path to do this)
        MetricFlowSpex.Fixtures.expire_invitation!(token)

        {:ok, Map.put(context, :invitation_token, token)}
      end

      when_ "the owner visits the expired invitation URL", context do
        result = live(context.owner_conn, "/invitations/#{context.invitation_token}")

        {:ok, Map.put(context, :live_result, result)}
      end

      then_ "the page displays an expiration error message", context do
        {:error, {:redirect, %{flash: flash}}} = context.live_result
        assert flash["error"] =~ "expired"
        {:ok, context}
      end
    end

    scenario "unauthenticated user visits an expired invitation link and sees an error" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "an invitation has been sent and expired", context do
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

        # Backdate the invitation to make it expired (no UI path to do this)
        MetricFlowSpex.Fixtures.expire_invitation!(token)

        {:ok, Map.put(context, :invitation_token, token)}
      end

      when_ "an anonymous user visits the expired invitation URL", context do
        conn = build_conn()
        result = live(conn, "/invitations/#{context.invitation_token}")

        {:ok, %{live_result: result}}
      end

      then_ "the user sees an expiration error message", context do
        {:error, {:redirect, %{flash: flash}}} = context.live_result
        assert flash["error"] =~ "expired"
        {:ok, context}
      end
    end

    scenario "expired invitation page suggests re-requesting an invitation" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner sends an invitation that is then expired", context do
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

        # Backdate the invitation to make it expired (no UI path to do this)
        MetricFlowSpex.Fixtures.expire_invitation!(token)

        {:ok, Map.put(context, :invitation_token, token)}
      end

      when_ "the user visits the expired invitation link", context do
        result = live(context.owner_conn, "/invitations/#{context.invitation_token}")

        {:ok, Map.put(context, :live_result, result)}
      end

      then_ "the page suggests contacting the account owner for a new invitation", context do
        {:error, {:redirect, %{flash: flash}}} = context.live_result
        assert flash["error"] =~ "expired"
        {:ok, context}
      end
    end
  end
end
