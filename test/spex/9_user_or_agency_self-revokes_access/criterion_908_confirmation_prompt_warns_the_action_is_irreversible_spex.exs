defmodule MetricFlowSpex.ConfirmationPromptWarnsTheActionIsIrreversibleSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Confirmation prompt warns the action is irreversible", criterion: 908 do
    scenario "the leave-account confirmation prompt warns the action cannot be undone" do
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

      when_ "the member is about to revoke their own access and the confirmation prompt appears",
            context do
        html =
          context.settings_view
          |> element("[data-role='revoke-own-access']")
          |> render_click()

        {:ok, Map.put(context, :result_html, html)}
      end

      then_ "it warns that the action cannot be undone before they can proceed", context do
        assert context.result_html =~ "cannot be undone"
        assert has_element?(context.settings_view, "[data-role='confirm-leave']")
        {:ok, context}
      end
    end
  end
end
