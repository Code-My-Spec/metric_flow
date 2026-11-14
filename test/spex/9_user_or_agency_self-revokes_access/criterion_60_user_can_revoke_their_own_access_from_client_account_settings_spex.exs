defmodule MetricFlowSpex.UserCanRevokeTheirOwnAccessFromClientAccountSettingsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can revoke their own access from client account settings", criterion: 60 do
    scenario "a non-owner member revokes their own access from account settings" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_member_with_access)

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

      then_ "a revoke-own-access option is present", context do
        assert has_element?(context.settings_view, "[data-role='revoke-own-access']")
        {:ok, context}
      end

      when_ "the member revokes their own access and confirms", context do
        context.settings_view
        |> element("[data-role='revoke-own-access']")
        |> render_click()

        html =
          context.settings_view
          |> element("[data-role='confirm-leave']")
          |> render_click()

        {:ok, Map.put(context, :result_html, html)}
      end

      then_ "their access to the client account is revoked", context do
        assert context.result_html =~ "Your access has been revoked"
        {:ok, context}
      end
    end
  end
end
