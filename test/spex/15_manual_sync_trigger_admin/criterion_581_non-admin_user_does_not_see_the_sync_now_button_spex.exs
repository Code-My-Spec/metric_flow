defmodule MetricFlowSpex.NonAdminUserDoesNotSeeTheSyncNowButtonSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Non-admin user does not see the Sync Now button", criterion: 581 do
    scenario "a plain member without admin access does not see a Sync Now button" do
      given_ :owner_with_integrations
      given_ :agency_member_registered

      when_ "they open an integration's settings", context do
        {:ok, view, _html} = live(context.member_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no Sync Now button is shown", context do
        refute has_element?(context.view, "button", "Sync Now")
        {:ok, context}
      end
    end
  end
end
