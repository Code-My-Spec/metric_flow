defmodule MetricFlowSpex.OwnerSeesTheDeleteAccountOptionSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Owner sees the delete-account option", criterion: 541 do
    scenario "owner holding the owner role sees the delete-account option in settings" do
      given_ :user_logged_in_as_owner

      when_ "Alex opens account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "Alex sees the delete-account option", context do
        assert has_element?(context.view, "[data-role='delete-account']")
        {:ok, context}
      end
    end
  end
end
