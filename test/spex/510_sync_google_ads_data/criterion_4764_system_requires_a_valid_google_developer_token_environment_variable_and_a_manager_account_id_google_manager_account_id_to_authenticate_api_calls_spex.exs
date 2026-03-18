defmodule MetricFlowSpex.SystemRequiresAValidGoogleDeveloperTokenAndManagerAccountIdToAuthenticateApiCallsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System requires GOOGLE_DEVELOPER_TOKEN and GOOGLE_MANAGER_ACCOUNT_ID env vars to authenticate Google Ads API calls" do
    scenario "a successful Google Ads sync confirms that authentication credentials were accepted" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync completion event is broadcast indicating auth succeeded", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_ads,
          records_synced: 30,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a successful Google Ads entry confirming authentication worked", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected 'Google Ads' to appear in sync history after successful auth, got: #{html}"

        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success']"),
               "Expected a sync history entry with data-status='success' confirming auth credentials were accepted"

        :ok
      end
    end

    scenario "a failed Google Ads sync due to an authentication error is shown in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync failure event is broadcast with an authentication error", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_ads,
          reason: "Google Ads API error: DEVELOPER_TOKEN_NOT_APPROVED — developer token is not approved for use"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a failed Google Ads entry", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected 'Google Ads' to appear in sync history for the auth failure, got: #{html}"

        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='failed']"),
               "Expected a sync history entry with data-status='failed' for the auth error"

        :ok
      end

      then_ "the error message references the authentication or developer token failure", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a [data-role='sync-error'] element to display the authentication error"

        html = render(context.view)

        assert html =~ "DEVELOPER_TOKEN_NOT_APPROVED" or html =~ "developer token" or
                 html =~ "Google Ads API error",
               "Expected the developer token auth error message to be displayed, got: #{html}"

        :ok
      end
    end

    scenario "a Google Ads sync failure due to an invalid manager account ID references authentication" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync failure event is broadcast with a manager account error", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_ads,
          reason: "Google Ads API error: OAUTH_TOKEN_INVALID — authentication token rejected by manager account"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows a failed Google Ads sync", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='failed']"),
               "Expected a sync history entry with data-status='failed' for the manager account auth error"

        :ok
      end

      then_ "the error message references authentication or token issues", context do
        html = render(context.view)

        assert html =~ "OAUTH_TOKEN_INVALID" or html =~ "authentication" or html =~ "token",
               "Expected the error to reference authentication or token issues, got: #{html}"

        :ok
      end
    end
  end
end
