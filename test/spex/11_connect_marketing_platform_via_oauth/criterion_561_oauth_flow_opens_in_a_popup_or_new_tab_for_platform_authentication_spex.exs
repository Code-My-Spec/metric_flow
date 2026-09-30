defmodule MetricFlowSpex.OAuthFlowOpensInAPopupOrNewTabForPlatformAuthenticationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "OAuth flow opens in a popup or new tab for platform authentication", criterion: 561 do
    scenario "Dana starts the OAuth flow for Facebook Ads and it opens in a popup or new tab" do
      given_ :user_logged_in_as_owner

      given_ "Dana starts the OAuth flow for Facebook Ads", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/facebook_ads")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the OAuth flow launches in a popup or new tab showing Facebook's login", context do
        assert has_element?(context.view, "a[data-role='oauth-connect-button'][target='_blank']")
        {:ok, context}
      end
    end
  end
end
