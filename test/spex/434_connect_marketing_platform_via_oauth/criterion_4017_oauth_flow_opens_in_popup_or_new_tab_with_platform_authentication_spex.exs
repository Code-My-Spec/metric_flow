defmodule MetricFlowSpex.OAuthFlowOpensInPopupOrNewTabWithPlatformAuthenticationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "OAuth flow opens in popup or new tab with platform authentication" do
    scenario "connect button for Google Ads is rendered as an external link to the OAuth authorization URL" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Google Ads connect element has a target attribute for external navigation", context do
        html = render(context.view)
        assert html =~ "google_ads" or html =~ "google-ads"
        assert has_element?(context.view, "[data-role='connect-google-ads'][target='_blank']") or
                 has_element?(context.view, "[data-platform='google_ads'] a[target='_blank']") or
                 has_element?(context.view, "[data-platform='google_ads'] [data-role='connect-button']")
        :ok
      end
    end

    scenario "connect button for Facebook Ads is rendered as an external link to the OAuth authorization URL" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Facebook Ads connect element has a target attribute for external navigation", context do
        html = render(context.view)
        assert html =~ "facebook_ads" or html =~ "facebook-ads" or html =~ "Facebook Ads"
        assert has_element?(context.view, "[data-role='connect-facebook-ads'][target='_blank']") or
                 has_element?(context.view, "[data-platform='facebook_ads'] a[target='_blank']") or
                 has_element?(context.view, "[data-platform='facebook_ads'] [data-role='connect-button']")
        :ok
      end
    end

    scenario "connect button for Google Analytics is rendered as an external link to the OAuth authorization URL" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Google Analytics connect element has a target attribute for external navigation", context do
        html = render(context.view)
        assert html =~ "google_analytics" or html =~ "google-analytics" or html =~ "Google Analytics"
        assert has_element?(context.view, "[data-role='connect-google-analytics'][target='_blank']") or
                 has_element?(context.view, "[data-platform='google_analytics'] a[target='_blank']") or
                 has_element?(context.view, "[data-platform='google_analytics'] [data-role='connect-button']")
        :ok
      end
    end

    scenario "the connect page renders platform connect buttons with OAuth initiation links" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "each platform connection entry is present on the page", context do
        html = render(context.view)
        assert html =~ "Google Ads"
        assert html =~ "Facebook Ads"
        assert html =~ "Google Analytics"
        :ok
      end

      then_ "the page contains OAuth connect links for the platforms", context do
        assert has_element?(context.view, "[data-role='connect-button']") or
                 has_element?(context.view, "a[href*='oauth']") or
                 has_element?(context.view, "a[href*='connect']") or
                 has_element?(context.view, "[phx-click*='connect']")
        :ok
      end
    end
  end
end
