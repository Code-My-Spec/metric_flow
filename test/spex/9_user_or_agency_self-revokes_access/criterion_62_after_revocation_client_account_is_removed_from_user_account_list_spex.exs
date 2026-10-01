defmodule MetricFlowSpex.AfterRevocationClientAccountIsRemovedFromUserAccountListSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "After revocation, client account is removed from user account list", criterion: 62 do
    scenario "the client account no longer appears in the user's account list after revocation" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_member_with_access

      given_ "the member switches into the owner's account", context do
        {:ok, accounts_view, _html} = live(context.member_conn, "/app/accounts")

        accounts_view
        |> element("[data-role='switch-account']", "Switch to Owner Account")
        |> render_click()

        {:ok, context}
      end

      when_ "the member revokes their own access from account settings", context do
        {:ok, settings_view, _html} = live(context.member_conn, "/app/accounts/settings")

        settings_view
        |> element("[data-role='revoke-own-access']")
        |> render_click()

        settings_view
        |> element("[data-role='confirm-leave']")
        |> render_click()

        {:ok, context}
      end

      then_ "the client account is removed from the user's account list", context do
        {:ok, _accounts_view, html} = live(context.member_conn, "/app/accounts")
        refute html =~ "Owner Account"
        {:ok, context}
      end
    end
  end
end
