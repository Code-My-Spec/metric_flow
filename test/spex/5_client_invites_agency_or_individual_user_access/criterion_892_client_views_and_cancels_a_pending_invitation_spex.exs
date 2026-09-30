defmodule MetricFlowSpex.Criterion892ClientViewsAndCancelsAPendingInvitationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Client views and cancels a pending invitation", criterion: 892 do
    scenario "a client cancels an invitation that has not yet been accepted" do
      given_ :user_logged_in_as_owner

      given_ "a client has sent an invitation that has not yet been accepted", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")

        view
        |> form("#invite_member_form",
          invitation: %{
            email: "not-yet-accepted@example.com",
            role: "read_only"
          }
        )
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "they view pending invitations and cancel it", context do
        assert has_element?(context.view, "[data-role='pending-invitation-row'] [data-role='invitation-email']", "not-yet-accepted@example.com")

        context.view
        |> element("[data-role='cancel-invitation'][data-email='not-yet-accepted@example.com']")
        |> render_click()

        {:ok, context}
      end

      then_ "the invitation is cancelled and can no longer be accepted", context do
        refute has_element?(context.view, "[data-role='pending-invitation-row'] [data-role='invitation-email']", "not-yet-accepted@example.com")
        {:ok, context}
      end
    end
  end
end
