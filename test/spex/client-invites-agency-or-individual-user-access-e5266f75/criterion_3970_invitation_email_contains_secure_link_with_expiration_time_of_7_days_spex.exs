defmodule MetricFlowSpex.InvitationEmailContainsSecureLinkWithExpirationTimeOf7DaysSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import_givens MetricFlowSpex.SharedGivens

  spex "Invitation email contains secure link with expiration time of 7 days" do
    scenario "email sent after owner submits invitation form contains a secure acceptance link" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the invite form with a recipient email", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "an invitation email is sent to the recipient address", context do
        assert_email_sent(to: context.second_user_email)
        :ok
      end
    end

    scenario "invitation email contains a secure token link pointing to the acceptance path" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the invite form", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the email body contains a secure acceptance link", context do
        assert_email_sent(fn email ->
          assert email.text_body =~ "/invitations/"
        end)

        :ok
      end
    end

    scenario "invitation email states that it expires in 7 days" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner is on the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner submits the invite form", context do
        context.view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the email body mentions the 7-day expiration period", context do
        assert_email_sent(fn email ->
          assert email.text_body =~ "7 days"
        end)

        :ok
      end
    end
  end
end
