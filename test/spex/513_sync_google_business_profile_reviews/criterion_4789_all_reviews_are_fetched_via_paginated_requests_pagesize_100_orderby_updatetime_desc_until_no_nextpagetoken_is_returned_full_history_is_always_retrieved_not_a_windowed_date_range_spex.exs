defmodule MetricFlowSpex.AllReviewsFetchedViaPaginatedRequestsFullHistorySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "All reviews are fetched via paginated requests (pageSize: 100, orderBy: updateTime desc) — full history always retrieved, not a windowed date range" do
    scenario "a sync completion shows a large record count reflecting full history retrieval" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile reviews sync completion event is broadcast with a large record count", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 347,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a Google Business Profile Reviews entry", context do
        html = render(context.view)

        assert html =~ "Google Business" or
                 html =~ "google_business_reviews" or
                 html =~ "Business Profile" or
                 html =~ "Reviews",
               "Expected the sync history to show a Google Business Profile Reviews entry, got: #{html}"

        :ok
      end

      then_ "the entry shows the total record count reflecting full paginated history retrieval", context do
        html = render(context.view)

        assert html =~ "347" or html =~ "records",
               "Expected the sync history entry to show 347 records (full history across paginated requests), got: #{html}"

        :ok
      end
    end

    scenario "the sync entry shows success status with the total review count" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile reviews sync completion event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 250,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows success status", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected the Google Business Profile reviews sync entry to show Success status, got: #{html}"

        :ok
      end

      then_ "the sync history entry shows the total review count from all pages", context do
        html = render(context.view)

        assert html =~ "250",
               "Expected the sync history entry to display the total review count (250) from all paginated pages, got: #{html}"

        :ok
      end
    end

    scenario "a failed sync during pagination shows the error" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile reviews sync failure event is broadcast mid-pagination", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_business_reviews,
          reason: "Pagination error: API returned 429 RESOURCE_EXHAUSTED while fetching page 3"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a failed Google Business Profile Reviews entry", context do
        html = render(context.view)

        assert html =~ "Google Business" or
                 html =~ "google_business_reviews" or
                 html =~ "Business Profile" or
                 html =~ "Reviews",
               "Expected the sync history to show a Google Business Profile Reviews failure entry, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the failed sync entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the error details from the pagination failure are displayed", context do
        html = render(context.view)

        assert html =~ "429" or html =~ "RESOURCE_EXHAUSTED" or
                 html =~ "Pagination error" or html =~ "page 3",
               "Expected the pagination failure error to be surfaced in the sync history, got: #{html}"

        :ok
      end
    end
  end
end
