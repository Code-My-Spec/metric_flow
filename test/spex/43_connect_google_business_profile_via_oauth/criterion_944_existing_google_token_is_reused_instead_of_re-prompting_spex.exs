defmodule MetricFlowSpex.ExistingGoogleTokenIsReusedInsteadOfRePromptingSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Existing Google token is reused instead of re-prompting", criterion: 944 do
    scenario "connecting Google Business Profile with a token that already carries the business.manage scope skips a fresh authorization" do
      given_ :user_logged_in_as_owner

      given_ "a user's existing Google Ads token already carries the Business Profile scope, from a prior GBP authorization that Google's incremental consent carried forward",
            context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)

        MetricFlowTest.IntegrationsFixtures.integration_fixture(user, %{
          provider: :google_ads,
          access_token: "existing-ads-token",
          refresh_token: "existing-ads-refresh",
          granted_scopes: [
            "https://www.googleapis.com/auth/adwords",
            "https://www.googleapis.com/auth/business.manage"
          ]
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
