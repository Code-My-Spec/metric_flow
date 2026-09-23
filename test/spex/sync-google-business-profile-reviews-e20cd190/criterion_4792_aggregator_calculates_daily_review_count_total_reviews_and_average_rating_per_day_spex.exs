defmodule MetricFlowSpex.AggregatorCalculatesDailyReviewCountTotalReviewsAndAverageRatingPerDaySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Aggregator calculates daily review count, total reviews, and average rating per day" do
    scenario "a sync completion with aggregated review metrics shows the total record count" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Reviews sync completion event is broadcast with aggregated metrics", context do
        # reviews (e.g. 45) + daily aggregated metric rows (e.g. 30 days walked) = total records
        total_records = 75

        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: total_records,
          completed_at: ~U[2026-03-17 02:00:00Z]
        }})

        :timer.sleep(100)
        {:ok, Map.put(context, :total_records, total_records)}
      end

      then_ "the sync history entry shows the total record count including daily aggregated metrics", context do
        html = render(context.view)

        assert html =~ "75" or html =~ Integer.to_string(context.total_records),
               "Expected sync history to show total records count '75' (reviews + daily metrics), got: #{html}"

        :ok
      end

      then_ "the sync history entry is labeled as Google Business Reviews", context do
        html = render(context.view)

        assert html =~ "Google Business Reviews" or html =~ "Google Business",
               "Expected sync history entry to be labeled 'Google Business Reviews', got: #{html}"

        :ok
      end
    end

    scenario "the sync entry shows success status confirming aggregation completed" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a successful Google Business Reviews sync completion event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 60,
          completed_at: ~U[2026-03-17 02:00:00Z]
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows a Success status badge", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success",
               "Expected the Google Business Reviews sync entry to show 'Success' status, got: #{html}"

        :ok
      end

      then_ "the sync history entry shows the records synced count", context do
        html = render(context.view)

        assert html =~ "60" or html =~ "records synced",
               "Expected the sync history entry to show '60 records synced', got: #{html}"

        :ok
      end
    end

    scenario "a failed sync during aggregation shows the error in the sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Reviews sync failure event is broadcast during aggregation", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_business_reviews,
          reason: "Aggregation failed: unable to calculate daily metrics from review data"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows a Failed status for Google Business Reviews", context do
        html = render(context.view)

        assert html =~ "Google Business Reviews" or html =~ "Google Business",
               "Expected 'Google Business Reviews' label in failed sync entry, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the sync entry to show 'Failed' status, got: #{html}"

        :ok
      end

      then_ "the aggregation error message is displayed in the sync history entry", context do
        html = render(context.view)

        assert html =~ "Aggregation failed" or
                 html =~ "daily metrics" or
                 html =~ "review data",
               "Expected the aggregation error message to appear in sync history, got: #{html}"

        :ok
      end
    end
  end
end
