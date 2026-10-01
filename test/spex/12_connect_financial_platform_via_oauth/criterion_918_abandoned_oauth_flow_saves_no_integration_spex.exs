defmodule MetricFlowSpex.AbandonedOauthFlowSavesNoIntegrationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Abandoned OAuth flow saves no integration", criterion: 918 do
    scenario "a user starts but does not complete the QuickBooks OAuth flow" do
      given_ :user_logged_in_as_owner

      given_ "the user starts the OAuth flow but does not complete it", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/quickbooks")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they abandon the process", context do
        {:ok, context}
      end

      then_ "no integration record is saved", context do
        html = render(context.view)
        refute html =~ "Connected as"
        assert html =~ "Not connected" or html =~ "Connect QuickBooks"
        {:ok, context}
      end
    end
  end
end
