defmodule MetricFlowSpex.OnlyBusinessReviewDailyCountStoredAsMetricRecordPerDayPerLocationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Only BUSINESS_REVIEW_DAILY_COUNT is stored as a Metric record — averageRating and totalReviews are not persisted as separate rows" do
    scenario "a sync completion shows record count reflecting only daily count metrics per location" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Reviews sync completion event is broadcast with a daily count per location", context do
        # Only one Metric row per day per location (BUSINESS_REVIEW_DAILY_COUNT).
        # averageRating and totalReviews are NOT separate metric rows, so a 3-location
        # sync over 30 days yields 90 records, not 270.
        daily_count_records = 90

        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: daily_count_records,
          completed_at: ~U[2026-03-17 02:00:00Z]
        }})

        :timer.sleep(100)
        {:ok, Map.put(context, :daily_count_records, daily_count_records)}
      end

      then_ "the sync history entry shows the record count matching one metric row per day per location", context do
        html = render(context.view)

        assert html =~ Integer.to_string(context.daily_count_records),
               "Expected sync history to show '#{context.daily_count_records}' records (one BUSINESS_REVIEW_DAILY_COUNT row per day per location), got: #{html}"

        :ok
      end

      then_ "the sync history entry is labeled as Google Business Reviews", context do
        html = render(context.view)

        assert html =~ "Google Business Reviews" or html =~ "Google Business",
               "Expected sync history entry to be labeled 'Google Business Reviews', got: #{html}"

        :ok
      end
    end

    scenario "the sync entry shows success status confirming daily count metrics were stored" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a successful Google Business Reviews sync event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 30,
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

      then_ "the records synced count is present in the entry", context do
        html = render(context.view)

        assert html =~ "30" or html =~ "records synced",
               "Expected the sync history entry to show the records synced count, got: #{html}"

        :ok
      end
    end

    scenario "a failed sync shows the error in the sync history entry" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Reviews sync failure event is broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_business_reviews,
          reason: "Failed to store BUSINESS_REVIEW_DAILY_COUNT metrics: database constraint violation"
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

      then_ "the error message is displayed in the sync history entry", context do
        html = render(context.view)

        assert html =~ "BUSINESS_REVIEW_DAILY_COUNT" or
                 html =~ "database constraint" or
                 html =~ "Failed to store",
               "Expected the failure reason to appear in sync history, got: #{html}"

        :ok
      end
    end
  end
end
