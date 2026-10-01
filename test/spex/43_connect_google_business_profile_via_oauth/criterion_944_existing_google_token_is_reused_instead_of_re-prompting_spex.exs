defmodule MetricFlowSpex.ExistingGoogleTokenIsReusedInsteadOfRePromptingSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Existing Google token is reused instead of re-prompting", criterion: 944 do
    scenario "connecting Google Business Profile with an existing Google Ads/GA4 token skips a fresh authorization" do
      given_ :user_logged_in_as_owner

      given_ "a user already has Google Ads or GA4 connected", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)

        MetricFlowTest.IntegrationsFixtures.integration_fixture(user, %{
          provider: :google_analytics,
          access_token: "existing-ga4-token",
          refresh_token: "existing-ga4-refresh",
          granted_scopes: ["https://www.googleapis.com/auth/analytics.readonly"]
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they connect Google Business Profile", context do
        result =
          context.view
          |> element("[data-platform='google_business'] [data-role='connect-button']")
          |> render_click()

        {:ok, Map.put(context, :click_result, result)}
      end

      then_ "the system reuses the existing Google OAuth token rather than requiring a separate authorization",
            context do
        refute match?({:error, {:redirect, %{to: _to}}}, context.click_result)
        {:ok, context}
      end
    end
  end
end
