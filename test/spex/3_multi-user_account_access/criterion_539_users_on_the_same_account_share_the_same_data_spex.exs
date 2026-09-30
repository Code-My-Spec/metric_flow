defmodule MetricFlowSpex.UsersOnTheSameAccountShareTheSameDataSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Users on the same account share the same data", criterion: 539 do
    scenario "a teammate added directly to the account sees the same account" do
      given_ :user_logged_in_as_owner
      given_ :agency_member_registered

      when_ "each opens their accounts list", context do
        # The Members page itself is deliberately owner/admin-only (see
        # AccountLive.Members's own moduledoc), so a non-admin teammate seeing
        # nothing there is by design, not a data-isolation bug. The accounts
        # list is the role-independent surface: every member of an account
        # sees the same account there regardless of their own role.
        {:ok, owner_view, _html} = live(context.owner_conn, "/app/accounts")
        {:ok, member_view, _html} = live(context.member_conn, "/app/accounts")

        {:ok,
         Map.merge(context, %{
           owner_view_html: render(owner_view),
           member_view_html: render(member_view)
         })}
      end

      then_ "they see the same shared account", context do
        assert context.owner_view_html =~ "Owner Account"
        assert context.member_view_html =~ "Owner Account"

        {:ok, context}
      end
    end
  end
end
