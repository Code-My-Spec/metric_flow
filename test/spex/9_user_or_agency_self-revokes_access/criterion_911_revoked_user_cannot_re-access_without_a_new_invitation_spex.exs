defmodule MetricFlowSpex.RevokedUserCannotReAccessWithoutANewInvitationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Revoked user cannot re-access without a new invitation", criterion: 911 do
    scenario "a user who revoked their own access has no way back into the account" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_member_with_access

      given_ "the member switches into the owner's account", context do
        {:ok, accounts_view, _html} = live(context.member_conn, "/app/accounts")

        accounts_view
        |> element("[data-role='switch-account']", "Switch to Owner Account")
        |> render_click()

        {:ok, context}
      end

      given_ "the member has revoked their own access to that client account", context do
        {:ok, settings_view, _html} = live(context.member_conn, "/app/accounts/settings")

        settings_view
        |> element("[data-role='revoke-own-access']")
        |> render_click()

        settings_view
        |> element("[data-role='confirm-leave']")
        |> render_click()

        {:ok, context}
      end

      when_ "they attempt to access that account again without a new invitation", context do
        {:ok, accounts_view, html} = live(context.member_conn, "/app/accounts")
        {:ok, Map.merge(context, %{accounts_view: accounts_view, result_html: html})}
      end

      then_ "they are denied access", context do
        refute context.result_html =~ "Owner Account"

        refute has_element?(
                 context.accounts_view,
                 "[data-role='switch-account']",
                 "Switch to Owner Account"
               )

        {:ok, context}
      end
    end
  end
end
