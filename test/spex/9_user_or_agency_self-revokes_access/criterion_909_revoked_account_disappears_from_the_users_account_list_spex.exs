defmodule MetricFlowSpex.RevokedAccountDisappearsFromTheUsersAccountListSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Revoked account disappears from the user's account list", criterion: 909 do
    scenario "after revoking access, the client account no longer appears in the account list" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_member_with_access

      given_ "the member switches into the owner's account", context do
        {:ok, accounts_view, _html} = live(context.member_conn, "/app/accounts")

        accounts_view
        |> element("[data-role='switch-account']", "Switch to Owner Account")
        |> render_click()

        {:ok, context}
      end

      given_ "the member revokes their own access from account settings", context do
        {:ok, settings_view, _html} = live(context.member_conn, "/app/accounts/settings")

        settings_view
        |> element("[data-role='revoke-own-access']")
        |> render_click()

        settings_view
        |> element("[data-role='confirm-leave']")
        |> render_click()

        {:ok, context}
      end

      when_ "the member views their account list", context do
        {:ok, accounts_view, html} = live(context.member_conn, "/app/accounts")
        {:ok, Map.merge(context, %{accounts_view: accounts_view, result_html: html})}
      end

      then_ "that client account no longer appears there", context do
        refute context.result_html =~ "Owner Account"
        {:ok, context}
      end
    end
  end
end
