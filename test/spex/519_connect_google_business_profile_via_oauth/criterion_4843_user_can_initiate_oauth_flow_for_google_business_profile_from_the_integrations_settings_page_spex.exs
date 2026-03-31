defmodule MetricFlowSpex.Criterion4843UserCanInitiateOAuthFlowForGoogleBusinessProfileSpex do
  use SexySpex
  use MetricFlowTest.ConnCase, async: false
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can initiate OAuth flow for Google Business Profile from the integrations settings page" do
    scenario "authenticated user sees Google Business listed as a provider on the connect page" do
      given_ :user_logged_in_as_owner

      then_ "the connect page lists Google Business as a provider", context do
        {:ok, _view, html} = live(context.owner_conn, "/integrations/connect")
        assert html =~ "Google Business"
        :ok
      end
    end

    scenario "Google Business provider card has a connect button" do
      given_ :user_logged_in_as_owner

      then_ "the Google Business card shows a connect button with the correct data attributes",
            context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        assert has_element?(view, "[data-platform='google_business']")
        assert has_element?(view, "[data-platform='google_business'] [data-role='connect-button']")
        :ok
      end
    end

    scenario "unauthenticated user is redirected away from the connect page" do
      then_ "visiting the connect page without a session redirects to login" do
        result = live(build_conn(), "/integrations/connect")
        assert {:error, {:redirect, _}} = result
        :ok
      end
    end

    scenario "Google Business connect detail page is accessible to authenticated user" do
      given_ :user_logged_in_as_owner

      then_ "the Google Business detail page loads and shows the provider name", context do
        {:ok, _view, html} = live(context.owner_conn, "/integrations/connect/google_business")
        assert html =~ "Google Business"
        :ok
      end
    end
  end
end
