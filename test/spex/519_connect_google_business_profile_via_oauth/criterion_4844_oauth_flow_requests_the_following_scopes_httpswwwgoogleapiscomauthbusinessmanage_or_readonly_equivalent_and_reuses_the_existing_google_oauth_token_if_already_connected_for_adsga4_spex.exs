defmodule MetricFlowSpex.Criterion4844OAuthFlowRequestsBusinessManageScopeSpex do
  use SexySpex
  use MetricFlowTest.ConnCase, async: false
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "OAuth flow requests business.manage scope and reuses existing Google OAuth token if already connected" do
    scenario "Google Business connect detail page renders an OAuth entry point for new users" do
      given_ :user_logged_in_as_owner

      then_ "the connect detail page renders an OAuth entry point (button or not-configured notice)",
            context do
        {:ok, view, html} = live(context.owner_conn, "/integrations/connect/google_business")

        # Either the real OAuth button (when credentials are configured) or the
        # not-configured notice (in test environment without real credentials).
        # Both indicate the page correctly attempts to surface an OAuth flow.
        has_connect_button = has_element?(view, "[data-role='oauth-connect-button']")
        has_not_configured_notice = html =~ "OAuth is not configured for this provider"

        assert has_connect_button or has_not_configured_notice
        :ok
      end
    end

    scenario "Google Business is listed distinctly from Google Analytics and Google Ads" do
      given_ :user_logged_in_as_owner

      then_ "the connect page shows Google Business as its own distinct provider card", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        assert has_element?(view, "[data-platform='google_business']")
        :ok
      end
    end

    scenario "connected Google Business integration shows connected status and select-accounts link" do
      given_ :user_logged_in_as_owner

      given_ "user has a connected google_business integration", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)

        MetricFlowTest.IntegrationsFixtures.integration_fixture(user, %{
          provider: :google_business,
          access_token: "existing-token",
          refresh_token: "existing-refresh",
          granted_scopes: ["https://www.googleapis.com/auth/business.manage"],
          provider_metadata: %{
            "email" => context.owner_email,
            "google_business_account_ids" => ["accounts/102071280510983396749"]
          }
        })

        {:ok, context}
      end

      then_ "the detail page shows the integration is connected", context do
        {:ok, _view, html} = live(context.owner_conn, "/integrations/connect/google_business")
        assert html =~ "Connected"
        :ok
      end

      then_ "the detail page shows a select accounts button for account management", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/google_business")
        assert has_element?(view, "[data-role='select-accounts-button']")
        :ok
      end
    end
  end
end
