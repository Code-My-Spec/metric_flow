defmodule MetricFlowSpex.UserRevokesTheirOwnAccessFromAccountSettingsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User revokes their own access from account settings", criterion: 907 do
    scenario "a non-owner member leaves the client account from account settings" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_member_with_access

      given_ "the member switches into the owner's account", context do
        {:ok, accounts_view, _html} = live(context.member_conn, "/app/accounts")

        accounts_view
        |> element("[data-role='switch-account']", "Switch to Owner Account")
        |> render_click()

        {:ok, context}
      end

      given_ "the member navigates to account settings", context do
        {:ok, settings_view, _html} = live(context.member_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :settings_view, settings_view)}
      end

      when_ "the member chooses to revoke their own access and confirms", context do
        context.settings_view
        |> element("[data-role='revoke-own-access']")
        |> render_click()

        html =
          context.settings_view
          |> element("[data-role='confirm-leave']")
          |> render_click()

        {:ok, Map.put(context, :result_html, html)}
      end

      then_ "their access is revoked", context do
        assert context.result_html =~ "Your access has been revoked"
        {:ok, context}
      end
    end
  end
end
