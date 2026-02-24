defmodule MetricFlowSpex.UserCanInitiateOAuthFlowForSupportedPlatformsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can initiate OAuth flow for supported platforms: Google Ads, Facebook Ads, Google Analytics" do
    scenario "authenticated user sees the platform connection page with all supported platforms listed" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees Google Ads as a supported platform", context do
        assert render(context.view) =~ "Google Ads"
        :ok
      end

      then_ "the user sees Facebook Ads as a supported platform", context do
        assert render(context.view) =~ "Facebook Ads"
        :ok
      end

      then_ "the user sees Google Analytics as a supported platform", context do
        assert render(context.view) =~ "Google Analytics"
        :ok
      end
    end

    scenario "authenticated user can initiate OAuth flow for Google Ads" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Google Ads platform has a connect button", context do
        assert has_element?(context.view, "[data-platform='google_ads'] [data-role='connect-button']") or
                 has_element?(context.view, "[data-role='connect-google-ads']")
        :ok
      end
    end

    scenario "authenticated user can initiate OAuth flow for Facebook Ads" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Facebook Ads platform has a connect button", context do
        assert has_element?(context.view, "[data-platform='facebook_ads'] [data-role='connect-button']") or
                 has_element?(context.view, "[data-role='connect-facebook-ads']")
        :ok
      end
    end

    scenario "authenticated user can initiate OAuth flow for Google Analytics" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Google Analytics platform has a connect button", context do
        assert has_element?(context.view, "[data-platform='google_analytics'] [data-role='connect-button']") or
                 has_element?(context.view, "[data-role='connect-google-analytics']")
        :ok
      end
    end

    scenario "unauthenticated user cannot access the platform connection page" do
      given_ "the user navigates to the integrations connect page without being logged in", context do
        result = live(build_conn(), "/integrations/connect")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the user is redirected away from the integrations connect page", context do
        case context.result do
          {:error, {:redirect, _}} -> :ok
          {:error, {:live_redirect, _}} -> :ok
          {:ok, view, _html} ->
            refute render(view) =~ "Google Ads"
            :ok
        end
      end
    end
  end
end
