defmodule MetricFlowSpex.ClientIsNotifiedViaEmailWhenUserRevokesTheirOwnAccessSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  import MetricFlowSpex.SharedGivens

  spex "Client is notified via email when user revokes their own access", criterion: 63 do
    scenario "the client receives an email notification after a user self-revokes" do
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

      when_ "the member revokes their own access", context do
        context.settings_view
        |> element("[data-role='revoke-own-access']")
        |> render_click()

        context.settings_view
        |> element("[data-role='confirm-leave']")
        |> render_click()

        {:ok, context}
      end

      then_ "the client is notified via email", context do
        assert_email_sent(fn email ->
          to_addresses = Enum.map(email.to, fn {_name, addr} -> addr end)
          context.owner_email in to_addresses
        end)

        {:ok, context}
      end
    end
  end
end
