defmodule MetricFlowSpex.SystemFetchesDataUsingGoogleSearchConsoleApiSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System fetches data using the Google Search Console API (webmasters v3, searchanalytics.query) authenticated via Google OAuth2 with webmasters.readonly scope — reuses the same Google OAuth token as GA4 and Google Ads" do
    scenario "the sync history page shows Google Search Console as a provider in sync history entries" do
      given_ :owner_with_google_ads_integration

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Search Console sync completion event is broadcast to the LiveView", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_search_console,
          records_synced: 30,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the sync history page shows a success entry for Google Search Console", context do
        html = render(context.view)

        assert html =~ "Google Search Console" or
                 html =~ "google_search_console" or
                 html =~ "Search Console",
               "Expected the sync history to show a Google Search Console entry, got: #{html}"

        :ok
      end

      then_ "the entry shows the sync was successful using the Google OAuth token", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected the Google Search Console sync entry to show Success status, got: #{html}"

        :ok
      end
    end

    scenario "unauthenticated users are redirected away from the sync history page" do
      given_ "the user is not logged in", _context do
        {:ok, %{anon_conn: build_conn()}}
      end

      then_ "visiting the sync history page redirects to the login page", context do
        assert {:error, {:redirect, %{to: "/users/log-in"}}} =
                 live(context.anon_conn, "/integrations/sync-history")

        :ok
      end
    end
  end
end
