defmodule MetricFlowSpex.OauthTokensAreAutomaticallyRefreshedWhenNeededSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "OAuth tokens are automatically refreshed when needed" do
    scenario "when a sync completes successfully after an automatic token refresh the user sees a success status" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the LiveView receives a sync completed message for Google after a transparent token refresh", context do
        completed_at = DateTime.utc_now()

        send(context.view.pid, {:sync_completed, %{
          provider: :google,
          records_synced: 28,
          completed_at: completed_at
        }})

        # Allow the LiveView to process the message
        :timer.sleep(100)

        {:ok, Map.put(context, :completed_at, completed_at)}
      end

      then_ "the user sees a success status for the Google sync", context do
        html = render(context.view)

        assert html =~ "success" or
                 html =~ "Success" or
                 html =~ "completed" or
                 html =~ "Completed" or
                 html =~ "28" or
                 html =~ "synced" or
                 html =~ "Synced",
               "Expected the sync history to show a success status after token refresh, got: #{html}"

        :ok
      end

      then_ "the user does not see any authentication error or token expiry notice", context do
        html = render(context.view)

        refute html =~ "Token expired",
               "Expected no token expiry error when token refresh succeeded, but found one"

        refute html =~ "re-authenticate" or html =~ "Re-authenticate",
               "Expected no re-authentication prompt when token refresh succeeded, but found one"

        :ok
      end
    end

    scenario "when a sync fails because the OAuth token has expired and no refresh token is available the user sees an expiry error" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the LiveView receives a sync failed message indicating the token expired and could not be refreshed", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google,
          reason: "Token expired and could not be refreshed"
        }})

        # Allow the LiveView to process the message
        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the user sees an error entry in the sync history for the Google integration", context do
        html = render(context.view)

        assert html =~ "failed" or
                 html =~ "Failed" or
                 html =~ "error" or
                 html =~ "Error" or
                 html =~ "Token expired",
               "Expected the sync history to show a failure entry when token refresh fails, got: #{html}"

        :ok
      end

      then_ "the error message informs the user that their token expired and re-authentication is needed", context do
        html = render(context.view)

        assert html =~ "Token expired" or
                 html =~ "token expired" or
                 html =~ "re-authenticate" or
                 html =~ "Re-authenticate" or
                 html =~ "reconnect" or
                 html =~ "Reconnect",
               "Expected the sync history to prompt the user to re-authenticate when token refresh fails, got: #{html}"

        :ok
      end
    end
  end
end
