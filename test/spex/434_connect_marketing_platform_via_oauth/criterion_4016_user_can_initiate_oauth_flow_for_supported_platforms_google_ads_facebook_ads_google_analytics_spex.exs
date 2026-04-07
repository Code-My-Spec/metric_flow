defmodule MetricFlowSpex.UserCanInitiateOAuthFlowForSupportedPlatformsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can initiate OAuth flow for supported providers: Google, Facebook, QuickBooks" do
    scenario "authenticated user sees the provider connection page with all supported providers listed" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees Google as a supported provider", context do
        assert render(context.view) =~ "Google"
        :ok
      end

      then_ "the user sees Facebook as a supported provider", context do
        assert render(context.view) =~ "Facebook"
        :ok
      end

      then_ "the user sees QuickBooks as a supported provider", context do
        assert render(context.view) =~ "QuickBooks"
        :ok
      end
    end

    scenario "authenticated user can initiate OAuth flow for Google" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Google provider has a connect button", context do
        assert has_element?(context.view, "[data-platform='google_analytics'] [data-role='connect-button']") or
                 has_element?(context.view, "[data-platform='google_ads'] [data-role='connect-button']"),
               "Expected a Google provider (google_analytics or google_ads) to have a connect button"
        :ok
      end
    end

    scenario "authenticated user can initiate OAuth flow for Facebook" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Facebook provider has a connect button", context do
        assert has_element?(context.view, "[data-platform='facebook_ads'] [data-role='connect-button']")
        :ok
      end
    end

    scenario "authenticated user can initiate OAuth flow for QuickBooks" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the QuickBooks provider has a connect button", context do
        assert has_element?(context.view, "[data-platform='quickbooks'] [data-role='connect-button']")
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
            refute render(view) =~ "Google"
            :ok
        end
      end
    end
  end
end
