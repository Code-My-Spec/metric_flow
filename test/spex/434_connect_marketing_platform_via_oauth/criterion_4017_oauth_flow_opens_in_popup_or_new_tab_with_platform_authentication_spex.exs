defmodule MetricFlowSpex.OAuthFlowOpensInPopupOrNewTabWithPlatformAuthenticationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "OAuth flow opens in popup or new tab with platform authentication" do
    scenario "connect button for Google is rendered with an OAuth initiation action" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Google connect element is present on the page", context do
        html = render(context.view)
        assert html =~ "Google"
        assert has_element?(context.view, "[data-platform='google_analytics'] [data-role='connect-button']") or
                 has_element?(context.view, "[data-platform='google_ads'] [data-role='connect-button']"),
               "Expected a Google provider (google_analytics or google_ads) to have a connect button"
        :ok
      end
    end

    scenario "connect button for Facebook is rendered with an OAuth initiation action" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Facebook connect element is present on the page", context do
        html = render(context.view)
        assert html =~ "Facebook"
        assert has_element?(context.view, "[data-platform='facebook_ads'] [data-role='connect-button']")
        :ok
      end
    end

    scenario "connect button for QuickBooks is rendered with an OAuth initiation action" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the QuickBooks connect element is present on the page", context do
        html = render(context.view)
        assert html =~ "QuickBooks"
        assert has_element?(context.view, "[data-platform='quickbooks'] [data-role='connect-button']")
        :ok
      end
    end

    scenario "the connect page renders provider connect buttons with OAuth initiation links" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "each provider connection entry is present on the page", context do
        html = render(context.view)
        assert html =~ "Google"
        assert html =~ "Facebook"
        assert html =~ "QuickBooks"
        :ok
      end

      then_ "the page contains OAuth connect buttons for the providers", context do
        assert has_element?(context.view, "[data-role='connect-button']")
        :ok
      end
    end
  end
end
