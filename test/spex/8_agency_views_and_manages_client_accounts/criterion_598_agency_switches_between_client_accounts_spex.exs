defmodule MetricFlowSpex.AgencySwitchesBetweenClientAccountsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures

  spex "Agency switches between client accounts", criterion: 598 do
    scenario "the agency uses the account switcher to select a different client account" do
      given_(:user_logged_in_as_owner)

      given_ "the agency is viewing one client account", context do
        client = AgenciesFixtures.account_fixture(%{name: "Client 598 Target"})

        MetricFlowSpex.Fixtures.grant_client_account_access(
          context.owner_email,
          client.id,
          :admin,
          false
        )

        {:ok, view, _html} = live(context.owner_conn, "/app/accounts")

        {:ok, Map.merge(context, %{view: view, client_name: "Client 598 Target"})}
      end

      when_ "they use the account switcher to select a different client", context do
        context.view
        |> element("[data-role='switch-account']", context.client_name)
        |> render_click()

        {:ok, context}
      end

      then_ "the agency's working context changes to that client account", context do
        assert render(context.view) =~ context.client_name
        {:ok, context}
      end
    end
  end
end
