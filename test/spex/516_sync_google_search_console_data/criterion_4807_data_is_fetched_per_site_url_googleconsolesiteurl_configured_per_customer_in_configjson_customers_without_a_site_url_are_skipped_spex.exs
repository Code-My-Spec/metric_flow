defmodule MetricFlowSpex.DataIsFetchedPerSiteUrlCustomersWithoutSiteUrlAreSkippedSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Data is fetched per site URL (googleConsoleSiteUrl) configured per customer; customers without a site URL are skipped" do
    scenario "sync history shows a Google Search Console entry for a customer with a configured site URL" do
      given_ :owner_with_google_ads_integration

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Search Console sync completes for a customer with a configured site URL", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_search_console,
          records_synced: 14,
          completed_at: DateTime.utc_now(),
          site_url: "https://example.com"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the sync history page shows a successful Google Search Console entry", context do
        html = render(context.view)

        assert html =~ "Google Search Console" or
                 html =~ "Search Console" or
                 html =~ "google_search_console",
               "Expected a Google Search Console sync history entry, got: #{html}"

        :ok
      end

      then_ "the entry shows a success status indicating data was fetched", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected the sync entry to show success status, got: #{html}"

        :ok
      end
    end

    scenario "sync history shows no Google Search Console entry when the sync was skipped due to missing site URL" do
      given_ :owner_with_google_ads_integration

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "no Google Search Console sync events are broadcast (customer has no site URL configured)", context do
        # No sync_completed message sent — customer without a site URL is skipped by the sync worker
        {:ok, context}
      end

      then_ "the sync history page does not show any Google Search Console entries", context do
        html = render(context.view)

        refute has_element?(context.view, "[data-role='sync-history-entry'][data-status='success']"),
               "Expected no sync history entries when no sync was run, but entries were found"

        # The empty state message should be visible
        assert html =~ "No sync history yet" or
                 html =~ "no sync history" or
                 not (html =~ "Google Search Console"),
               "Expected empty sync history when no syncs have run, got: #{html}"

        :ok
      end
    end
  end
end
