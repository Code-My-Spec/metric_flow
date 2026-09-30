defmodule MetricFlowSpex.Criterion890ClientSelectsAnAccessLevelWhenInvitingSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Client selects an access level when inviting", criterion: 890 do
    scenario "a client sending an invitation is offered read-only, account manager, and admin" do
      given_ :user_logged_in_as_owner

      when_ "they choose an access level", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/invitations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "they can select read-only, account manager, or admin", context do
        html = render(context.view)
        assert html =~ ~s(value="read_only")
        assert html =~ ~s(value="account_manager")
        assert html =~ ~s(value="admin")
        {:ok, context}
      end
    end
  end
end
