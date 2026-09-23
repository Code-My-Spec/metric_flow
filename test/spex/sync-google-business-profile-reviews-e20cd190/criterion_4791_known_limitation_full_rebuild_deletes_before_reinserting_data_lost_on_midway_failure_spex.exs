defmodule MetricFlowSpex.KnownLimitationFullRebuildDeletesBeforeReinsertingDataLostOnMidwayFailureSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "KNOWN LIMITATION: Full rebuild sync deletes all records before re-inserting; data lost if sync fails midway" do
    scenario "a failed sync after deletion shows zero records synced in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Reviews sync failure event is broadcast after deletion", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_business_reviews,
          reason: "Sync failed midway: all existing Review and BUSINESS_REVIEW_ Metric records were deleted before re-insertion; data is lost until next successful sync"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a failed Google Business Reviews entry", context do
        html = render(context.view)

        assert html =~ "Google Business Reviews",
               "Expected sync history to show 'Google Business Reviews', got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the sync entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the failure reason indicates data was lost due to the full rebuild deletion", context do
        html = render(context.view)

        assert html =~ "deleted" or html =~ "data is lost" or html =~ "midway" or
                 html =~ "BUSINESS_REVIEW_" or html =~ "re-insertion",
               "Expected the failure reason to reference the full rebuild data loss, got: #{html}"

        :ok
      end

      then_ "no records synced count is shown for the failed entry", context do
        html = render(context.view)

        refute html =~ "records synced" and html =~ ~r/\d+ records synced/ |> Regex.match?(html),
               "Expected no positive records synced count for a midway failure, got: #{html}"

        :ok
      end
    end

    scenario "a successful re-sync after a midway failure shows restored record count in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a previous midway failure event is broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_business_reviews,
          reason: "Sync failed midway: all existing Review and BUSINESS_REVIEW_ Metric records were deleted before re-insertion; data is lost until next successful sync"
        }})

        :timer.sleep(50)
        {:ok, context}
      end

      when_ "a subsequent successful re-sync event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 47,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a successful Google Business Reviews entry with a record count", context do
        html = render(context.view)

        assert html =~ "Google Business Reviews",
               "Expected sync history to show 'Google Business Reviews' for the success entry, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the re-sync entry to be marked as successful, got: #{html}"

        assert html =~ "47",
               "Expected the restored record count (47) to appear in sync history, got: #{html}"

        :ok
      end
    end

    scenario "the failed entry and the subsequent success both appear together in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a midway failure event is broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_business_reviews,
          reason: "Sync failed midway after deleting BUSINESS_REVIEW_ metrics and Review records"
        }})

        :timer.sleep(50)
        {:ok, context}
      end

      when_ "a subsequent successful sync event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 23,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "at least two Google Business Reviews entries appear in sync history", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 sync history entries (one failed, one success), but found #{entry_count}"

        :ok
      end

      then_ "the failed entry is visible when filtering by Failed status", context do
        html =
          context.view
          |> element("[data-role='filter-failed']", "Failed")
          |> render_click()

        assert html =~ "Google Business Reviews",
               "Expected 'Google Business Reviews' to appear when filtering by Failed, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the failed entry to appear under the Failed filter, got: #{html}"

        :ok
      end

      then_ "the successful entry is visible when filtering by Success status", context do
        context.view
        |> element("[data-role='filter-success']", "Success")
        |> render_click()

        html = render(context.view)

        assert html =~ "Google Business Reviews",
               "Expected 'Google Business Reviews' to appear when filtering by Success, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the success entry to appear under the Success filter, got: #{html}"

        :ok
      end
    end
  end
end
