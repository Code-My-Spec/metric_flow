defmodule MetricFlowSpex.UserInitiatesGbpOauthFromIntegrationsSettingsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User initiates GBP OAuth from integrations settings", criterion: 943 do
    scenario "clicking connect on the Google Business card starts the OAuth flow" do
      given_ :user_logged_in_as_owner

      given_ "a user viewing the integrations settings page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they start connecting Google Business Profile", context do
        result =
          context.view
          |> element("[data-platform='google_business'] [data-role='connect-button']")
          |> render_click()

        {:ok, Map.put(context, :click_result, result)}
      end

      then_ "the OAuth flow begins", context do
        assert {:error, {:redirect, %{to: to}}} = context.click_result
        assert to =~ "/app/integrations/oauth/google_business"
        {:ok, context}
      end
    end
  end
end
