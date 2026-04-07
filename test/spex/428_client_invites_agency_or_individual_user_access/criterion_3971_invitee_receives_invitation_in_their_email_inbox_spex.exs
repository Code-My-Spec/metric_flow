defmodule MetricFlowSpex.InviteeReceivesInvitationInTheirEmailInboxSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import_givens MetricFlowSpex.SharedGivens

  spex "Invitee receives invitation in their email inbox" do
    scenario "invitation email is addressed to the invitee's email address" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner sends an invitation to the invitee's email address", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the email is delivered to the invitee's address", context do
        assert_email_sent(to: context.second_user_email)
        :ok
      end
    end

    scenario "invitation email subject identifies which account the invitee is being invited to" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner sends an invitation", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the email subject mentions the account name so the invitee knows who invited them", context do
        assert_email_sent(fn email ->
          assert email.subject =~ "invited"
        end)

        :ok
      end
    end

    scenario "invitation email body is personalised with the invitee's email address" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner sends an invitation to the invitee", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the email body greets the invitee by their email address", context do
        assert_email_sent(fn email ->
          assert email.text_body =~ context.second_user_email
        end)

        :ok
      end
    end

    scenario "no invitation email is sent when the invite form is not submitted" do
      given_ :user_logged_in_as_owner

      given_ "the owner is on the invitations page without submitting the form", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the pending invitations list shows no invitations", context do
        assert render(context.view) =~ "No pending invitations"
        :ok
      end
    end
  end
end
