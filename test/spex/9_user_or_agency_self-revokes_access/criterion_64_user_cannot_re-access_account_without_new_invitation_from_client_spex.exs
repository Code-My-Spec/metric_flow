defmodule MetricFlowSpex.UserCannotReAccessAccountWithoutNewInvitationFromClientSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User cannot re-access account without new invitation from client", criterion: 64 do
    scenario "a user who revoked their own access cannot get back in without a fresh invitation" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_member_with_access

      given_ "the member switches into the owner's account", context do
        {:ok, accounts_view, _html} = live(context.member_conn, "/app/accounts")

        accounts_view
        |> element("[data-role='switch-account']", "Switch to Owner Account")
        |> render_click()

        {:ok, context}
      end

      given_ "the member has revoked their own access", context do
        {:ok, settings_view, _html} = live(context.member_conn, "/app/accounts/settings")

        settings_view
        |> element("[data-role='revoke-own-access']")
        |> render_click()

        settings_view
        |> element("[data-role='confirm-leave']")
        |> render_click()

        {:ok, context}
      end

      when_ "the user tries to reach the client account without a new invitation", context do
        {:ok, accounts_view, html} = live(context.member_conn, "/app/accounts")
        {:ok, Map.merge(context, %{accounts_view: accounts_view, result_html: html})}
      end

      then_ "the account is not accessible to them", context do
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
