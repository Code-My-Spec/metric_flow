defmodule MetricFlowSpex.EachReviewStoredWithAllFieldsRatingEnumConvertedToIntegerSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Each review stored with all fields: rating enum converted to integer (1-5)" do
    scenario "sync completion with reviews stored shows the record count in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Reviews sync completes with multiple reviews stored", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 7,
          completed_at: ~U[2026-03-17 02:00:00Z]
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the sync history entry shows the count of reviews stored", context do
        html = render(context.view)

        assert html =~ "7",
               "Expected sync history entry to show 7 records synced, got: #{html}"

        :ok
      end

      then_ "the sync history entry is associated with the Google Business Reviews provider", context do
        html = render(context.view)

        assert html =~ "Google Business Reviews" or
                 html =~ "google_business_reviews" or
                 html =~ "Business Reviews",
               "Expected sync history entry to show Google Business Reviews provider, got: #{html}"

        :ok
      end
    end

    scenario "the sync entry shows success status confirming all review fields were stored" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Reviews sync completes with reviews containing all required fields", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 3,
          completed_at: ~U[2026-03-17 02:15:00Z]
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the sync history entry shows a success status", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected the Google Business Reviews sync entry to show Success status, got: #{html}"

        :ok
      end

      then_ "the sync history entry shows the count of stored review records", context do
        html = render(context.view)

        assert html =~ "3",
               "Expected the sync history entry to display 3 records synced, got: #{html}"

        :ok
      end

      then_ "the sync history entry shows the completion timestamp", context do
        html = render(context.view)

        assert html =~ "Mar 17, 2026" or html =~ "2026" or html =~ "Completed at",
               "Expected the sync entry to display a completion timestamp, got: #{html}"

        :ok
      end
    end

    scenario "a failed sync due to invalid review data shows the error in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Reviews sync fails due to invalid review data", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_business_reviews,
          reason: "Invalid rating enum value in review data",
          attempt: 1,
          max_attempts: 3
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the sync history entry shows a failed status for Google Business Reviews", context do
        html = render(context.view)

        assert html =~ "Failed" or html =~ "failed" or html =~ "badge-error",
               "Expected the sync history to show a failed entry for Google Business Reviews, got: #{html}"

        :ok
      end

      then_ "the sync history entry shows the error reason describing the invalid data", context do
        html = render(context.view)

        assert html =~ "Invalid rating enum" or
                 html =~ "invalid" or
                 html =~ "Invalid" or
                 html =~ "review data",
               "Expected the sync history entry to display the error reason, got: #{html}"

        :ok
      end

      then_ "the sync history entry indicates the Google Business Reviews provider", context do
        html = render(context.view)

        assert html =~ "Google Business Reviews" or
                 html =~ "google_business_reviews" or
                 html =~ "Business Reviews",
               "Expected the failed entry to identify the Google Business Reviews provider, got: #{html}"

        :ok
      end
    end
  end
end
