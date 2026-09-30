defmodule MetricFlowSpex.UserStartsTheOAuthFlowForASupportedPlatformSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User starts the OAuth flow for a supported platform", criterion: 560 do
    scenario "Dana clicks connect for Google Ads and the OAuth flow begins" do
      given_ :user_logged_in_as_owner

      given_ "Dana is on the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "she clicks connect for Google Ads", context do
        result =
          context.view
          |> element("[data-platform='google_ads'] [data-role='connect-button']")
          |> render_click()

        {:ok, Map.put(context, :click_result, result)}
      end

      then_ "the OAuth flow for Google Ads begins", context do
        assert {:error, {:redirect, %{to: to}}} = context.click_result
        assert to =~ "/app/integrations/oauth/google_ads"
        {:ok, context}
      end
    end
  end
end
