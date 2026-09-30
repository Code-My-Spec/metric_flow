defmodule MetricFlowSpex.AccountOriginatorsAccessCannotBeRevokedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Account originator's access cannot be revoked", criterion: 559 do
    scenario "Jordan attempts to revoke the sole owner's (originator's) own access" do
      given_ :user_logged_in_as_owner

      given_ "the account originator still holds their original access", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Jordan attempts to revoke the originator's access", context do
        {:ok, context}
      end

      then_ "the action is blocked, since only an ownership transfer can change the originator's status", context do
        refute has_element?(
          context.view,
          "[data-role='remove-member'][data-user-email='#{context.owner_email}']"
        )

        {:ok, context}
      end
    end
  end
end
