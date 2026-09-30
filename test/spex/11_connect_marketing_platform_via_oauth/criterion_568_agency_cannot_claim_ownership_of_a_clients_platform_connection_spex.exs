defmodule MetricFlowSpex.AgencyCannotClaimOwnershipOfAClientsPlatformConnectionSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Agency cannot claim ownership of a client's platform connection", criterion: 568 do
    scenario "an attempt to transfer Jordan's Google Ads connection to Acme Agency is blocked" do
      given_ :owner_with_google_ads_integration

      when_ "an attempt is made to transfer the connection's ownership to an agency", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_ads")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the transfer is blocked because no mechanism exists to reassign the connection's owning account", context do
        refute has_element?(context.view, "[data-role='transfer-to-agency']")
        refute render(context.view) =~ "Transfer to agency"
        refute render(context.view) =~ "Assign to agency"
        {:ok, context}
      end
    end
  end
end
