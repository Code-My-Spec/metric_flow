defmodule MetricFlowSpex.NavigationClearlyDisplaysTheCurrentClientContextSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures

  spex "Navigation clearly displays the current client context", criterion: 599 do
    scenario "the navigation shows which client account is currently active after switching" do
      given_(:user_logged_in_as_owner)

      given_ "the agency has switched into a client account", context do
        client = AgenciesFixtures.account_fixture(%{name: "Client 599 Active"})

        MetricFlowSpex.Fixtures.grant_client_account_access(
          context.owner_email,
          client.id,
          :admin,
          false
        )

        {:ok, view, _html} = live(context.owner_conn, "/app/accounts")

        view
        |> element("[data-role='switch-account']", "Client 599 Active")
        |> render_click()

        {:ok, Map.put(context, :client_name, "Client 599 Active")}
      end

      when_ "they view any page for that client", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the navigation clearly shows which client account is currently active", context do
        assert render(context.view) =~ context.client_name
        {:ok, context}
      end
    end
  end
end
