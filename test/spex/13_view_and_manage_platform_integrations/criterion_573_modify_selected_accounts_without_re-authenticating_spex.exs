defmodule MetricFlowSpex.ModifySelectedAccountsWithoutReAuthenticatingSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Modify selected accounts without re-authenticating", criterion: 573 do
    scenario "a connected, healthy integration has its selection changed" do
      given_ :owner_with_integrations

      given_ "the user is on the account editing page for that integration", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/connect/google_analytics/accounts")

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user changes which accounts or properties are selected and saves", context do
        {:ok, view, html} =
          context.view
          |> form("[data-role='account-selection']", %{"manual_property_id" => "GA4-99999"})
          |> render_submit()
          |> follow_redirect(context.owner_conn)

        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the selection is saved without prompting the user to re-authenticate", context do
        assert context.html =~ "saved"
        {:ok, context}
      end
    end
  end
end
