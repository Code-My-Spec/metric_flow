defmodule MetricFlowSpex.IncompleteOAuthLeavesNoSavedIntegrationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Incomplete OAuth leaves no saved integration", criterion: 565 do
    scenario "Dana abandons the Google Ads OAuth flow before completing it" do
      given_ :user_logged_in_as_owner

      given_ "Dana starts connecting Google Ads", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_ads")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "she abandons the OAuth flow without completing it", context do
        {:ok, context}
      end

      then_ "no integration record is saved for Google Ads", context do
        html = render(context.view)
        assert html =~ "Not connected"
        refute html =~ "Connected as"
        {:ok, context}
      end
    end
  end
end
