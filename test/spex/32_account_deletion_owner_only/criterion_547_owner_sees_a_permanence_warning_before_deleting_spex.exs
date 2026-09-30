defmodule MetricFlowSpex.OwnerSeesAPermanenceWarningBeforeDeletingSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Owner sees a permanence warning before deleting", criterion: 547 do
    scenario "owner starts the delete-account flow and the confirmation screen appears" do
      given_ :user_logged_in_as_owner

      when_ "Alex starts the delete-account flow", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the confirmation screen warns that deletion is permanent and irreversible", context do
        delete_section = element(context.view, "[data-role='delete-account']")
        html = render(delete_section)
        assert html =~ "permanent"
        assert html =~ "irreversible"
        {:ok, context}
      end
    end
  end
end
