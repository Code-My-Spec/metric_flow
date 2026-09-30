defmodule MetricFlowSpex.TheLastRemainingOwnerCannotBeRemovedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "The last remaining owner cannot be removed", criterion: 538 do
    scenario "Alex is the only owner and cannot be removed or demoted" do
      given_ :user_logged_in_as_owner

      given_ "Alex is on the members page as the only owner", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no remove control is offered for Alex", context do
        refute has_element?(
                 context.view,
                 "[data-role='remove-member'][data-user-email='#{context.owner_email}']"
               )

        {:ok, context}
      end

      then_ "no role change control is offered for Alex either", context do
        refute has_element?(
                 context.view,
                 "[data-role='change-role'][data-user-email='#{context.owner_email}']"
               )

        {:ok, context}
      end
    end
  end
end
