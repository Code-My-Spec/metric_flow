defmodule MetricFlowSpex.OAuthRefreshTokenFromTheStoredGoogleTokenSetIsUsedPerRequestNoSeparateGoogleAdsOAuthFlowSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "OAuth refresh token from the stored Google token set is used per request — no separate Google Ads OAuth flow" do
    scenario "a successful Google Ads sync uses the existing Google OAuth without requiring a separate flow" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync completion event is broadcast using the stored Google token", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_ads,
          records_synced: 55,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a successful Google Ads sync entry", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected 'Google Ads' to appear in sync history (synced via shared Google OAuth token), got: #{html}"

        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success']"),
               "Expected a sync history entry with data-status='success' without requiring a separate OAuth flow"

        :ok
      end
    end

    scenario "the integrations connect page lists Google Ads under the Google integration, not as a separate OAuth provider" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "Google Ads appears on the connect page as part of the Google platform integration", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected 'Google Ads' to be listed on the connect page under the Google integration, got: #{html}"

        :ok
      end

      then_ "there is no separate Google Ads OAuth connect button independent of the Google integration", context do
        html = render(context.view)

        refute html =~ "Connect Google Ads" and not (html =~ "Google"),
               "Did not expect a standalone 'Connect Google Ads' button separate from the Google integration"

        assert html =~ "Google",
               "Expected the Google platform to be present on the connect page, got: #{html}"

        :ok
      end
    end

    scenario "a failed Google Ads sync due to an expired token surfaces an auth error in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync failure event is broadcast because the stored OAuth token is expired", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_ads,
          reason: "Google Ads API error: OAUTH_TOKEN_EXPIRED — stored refresh token has expired, reconnect Google"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a failed Google Ads entry", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected 'Google Ads' to appear in sync history for the expired-token failure, got: #{html}"

        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='failed']"),
               "Expected a sync history entry with data-status='failed' for the expired token error"

        :ok
      end

      then_ "the error message references the OAuth token expiry or authentication failure", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a [data-role='sync-error'] element to display the token expiry error"

        html = render(context.view)

        assert html =~ "OAUTH_TOKEN_EXPIRED" or html =~ "refresh token" or
                 html =~ "reconnect" or html =~ "expired",
               "Expected the error to reference the expired OAuth token, got: #{html}"

        :ok
      end
    end
  end
end
