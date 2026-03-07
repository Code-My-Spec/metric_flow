defmodule MetricFlowSpex.ClientCanViewPendingInvitationsAndCancelThemBeforeAcceptanceSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import_givens MetricFlowSpex.SharedGivens

  spex "Client can view pending invitations and cancel them before acceptance" do
    scenario "pending invitation appears in the invitations list after being sent" do
      given_ :user_logged_in_as_owner

      given_ "the owner is on the members page and sends an invitation", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")

        view
        |> form("#invite_member_form", invitation: %{
          email: "pending@agency.com",
          role: "read_only"
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the pending invitation is listed on the members page", context do
        assert render(context.view) =~ "pending@agency.com"
        :ok
      end

      then_ "the pending invitation shows a status of pending", context do
        assert render(context.view) =~ "pending"
        :ok
      end
    end

    scenario "owner can cancel a pending invitation before it is accepted" do
      given_ :user_logged_in_as_owner

      given_ "the owner is on the members page and sends an invitation", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")

        view
        |> form("#invite_member_form", invitation: %{
          email: "tocancel@agency.com",
          role: "read_only"
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the owner cancels the pending invitation", context do
        context.view
        |> element("[data-role='cancel-invitation'][data-email='tocancel@agency.com']")
        |> render_click()

        {:ok, context}
      end

      then_ "the cancelled invitation no longer appears in the pending list", context do
        refute has_element?(context.view, "[data-role='pending-invitation-row'] [data-role='invitation-email']", "tocancel@agency.com")
        :ok
      end

      then_ "a confirmation message is shown that the invitation was cancelled", context do
        assert render(context.view) =~ "cancelled"
        :ok
      end
    end

    scenario "pending invitations section is visible to the owner on the members page" do
      given_ :user_logged_in_as_owner

      given_ "the owner sends an invitation from the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")

        view
        |> form("#invite_member_form", invitation: %{
          email: "listed@agency.com",
          role: "admin"
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "a pending invitations section is displayed on the members page", context do
        assert has_element?(context.view, "[data-role='pending-invitations']")
        :ok
      end
    end

    scenario "a cancelled invitation link is invalidated and cannot be accepted" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner sends an invitation and then cancels it", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/invitations")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "read_only"
        })
        |> render_submit()

        token =
          assert_email_sent(fn email ->
            [_, token] = Regex.run(~r|/invitations/([^\s]+)|, email.text_body)
            token
          end)

        view
        |> element("[data-role='cancel-invitation'][data-email='#{context.second_user_email}']")
        |> render_click()

        {:ok, Map.put(context, :invitation_token, token)}
      end

      when_ "the invitee tries to visit the now-cancelled invitation link", context do
        result = live(build_conn(), "/invitations/#{context.invitation_token}")
        {:ok, Map.put(context, :visit_result, result)}
      end

      then_ "the invitee sees an error telling them the invitation is invalid", context do
        assert {:error, {:redirect, %{flash: flash}}} = context.visit_result
        assert flash["error"] =~ "invalid or has already been used"
        :ok
      end
    end
  end
end
