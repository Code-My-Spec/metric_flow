defmodule MetricFlowSpex.AuthenticationUsesADedicatedFacebookOAuthFlowSeparateFromGoogleOAuthSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Authentication uses a dedicated Facebook OAuth flow separate from Google OAuth, requiring FACEBOOK_APP_ID, FACEBOOK_APP_SECRET, and ads_read scope" do
    scenario "Facebook Ads appears as a separate platform on the connect page, distinct from Google" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page lists Facebook Ads as a platform", context do
        html = render(context.view)

        assert html =~ "Facebook",
               "Expected the connect page to list Facebook as a platform, got: #{html}"

        :ok
      end

      then_ "the page also lists Google as a separate platform", context do
        html = render(context.view)

        assert html =~ "Google",
               "Expected the connect page to list Google as a separate platform, got: #{html}"

        :ok
      end

      then_ "Facebook Ads has its own connect button separate from Google", context do
        assert has_element?(context.view, "[data-platform='facebook_ads'] [data-role='connect-button']"),
               "Expected Facebook Ads to have its own connect button with data-platform='facebook_ads'"

        assert has_element?(context.view, "[data-platform='google_analytics'] [data-role='connect-button']") or
                 has_element?(context.view, "[data-platform='google_ads'] [data-role='connect-button']"),
               "Expected Google to have its own connect button with data-platform='google_analytics' or 'google_ads'"

        :ok
      end
    end

    scenario "the Facebook Ads detail page identifies Facebook authentication, not Google" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the Facebook Ads provider detail page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/facebook_ads")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows Facebook branding and description", context do
        html = render(context.view)

        assert html =~ "Facebook",
               "Expected the Facebook Ads detail page to show 'Facebook', got: #{html}"

        :ok
      end

      then_ "the page does not show Google branding as the authentication provider", context do
        html = render(context.view)

        refute html =~ "Connect Google",
               "Expected the Facebook Ads detail page to not show 'Connect Google', got: #{html}"

        refute html =~ "Google Analytics",
               "Expected the Facebook Ads detail page to not reference 'Google Analytics', got: #{html}"

        :ok
      end
    end

    scenario "clicking Connect on Facebook Ads routes to the Facebook OAuth endpoint, not Google" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the Connect button for Facebook Ads", context do
        # The connect event triggers redirect/2 to /integrations/oauth/facebook_ads.
        # render_click returns the HTML; assert_redirect captures the redirect path.
        try do
          context.view
          |> element("[data-platform='facebook_ads'] [data-role='connect-button']")
          |> render_click()
        rescue
          _ -> :ok
        end

        {:ok, context}
      end

      then_ "the OAuth redirect targets the Facebook-specific OAuth endpoint, not Google", context do
        {path, _flash} = assert_redirect(context.view)

        assert path =~ "facebook_ads",
               "Expected redirect to target the facebook_ads OAuth endpoint, got path: #{path}"

        refute path =~ "google",
               "Expected redirect to not target the Google OAuth endpoint, got path: #{path}"

        :ok
      end
    end

    scenario "the Facebook Ads connect button routes to /integrations/oauth/facebook_ads" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Facebook Ads connect button uses the facebook_ads provider key", context do
        assert has_element?(
                 context.view,
                 "[data-platform='facebook_ads'] [data-role='connect-button'][phx-value-provider='facebook_ads']"
               ),
               "Expected the Facebook Ads connect button to have phx-value-provider='facebook_ads'"

        :ok
      end

      then_ "the Google connect button uses a google provider key, not facebook_ads", context do
        assert has_element?(
                 context.view,
                 "[data-platform='google_analytics'] [data-role='connect-button'][phx-value-provider='google_analytics']"
               ) or
               has_element?(
                 context.view,
                 "[data-platform='google_ads'] [data-role='connect-button'][phx-value-provider='google_ads']"
               ),
               "Expected a Google connect button (google_analytics or google_ads provider), confirming the two OAuth flows are separate"

        :ok
      end
    end
  end
end
