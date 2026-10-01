defmodule MetricFlowSpex.ConfirmationPromptWarnsThatThisActionCannotBeUndoneSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Confirmation prompt warns that this action cannot be undone", criterion: 61 do
    scenario "the self-revoke confirmation prompt warns deletion cannot be undone" do
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

      when_ "the member clicks to revoke their own access", context do
        html =
          context.settings_view
          |> element("[data-role='revoke-own-access']")
          |> render_click()

        {:ok, Map.put(context, :result_html, html)}
      end

      then_ "the confirmation prompt warns that this action cannot be undone", context do
        assert context.result_html =~ "cannot be undone"
        {:ok, context}
      end
    end
  end
end
