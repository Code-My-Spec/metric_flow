defmodule MetricFlowSpex.SyncUsesInsertNotUpsertDuplicateSyncCausesUniqueConstraintViolationKnownLimitationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Sync uses insert (not upsert) — re-running without clearing existing data will cause unique constraint violations; KNOWN LIMITATION: should be migrated to upsert consistent with the GSC integration" do
    scenario "a duplicate Google Business Profile sync attempt shows a constraint violation error in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "an initial Google Business Profile sync completes successfully", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 30,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      when_ "the same date range is synced again without clearing existing data, causing a unique constraint violation", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_business,
          reason: "unique constraint violation: metrics_account_id_provider_metric_key_date_index"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the sync history page shows the constraint violation failure as a failed Google Business Profile entry", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "google_business",
               "Expected 'Google Business' in sync history for the constraint violation failure, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the duplicate sync entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the error message is specific about the unique constraint issue", context do
        html = render(context.view)

        assert html =~ "unique constraint" or html =~ "constraint" or html =~ "violation" or
                 html =~ "unique",
               "Expected the error message to mention the unique constraint issue, got: #{html}"

        :ok
      end

      then_ "a sync-error element is visible for the failed entry", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a [data-role='sync-error'] element for the constraint violation failure"

        :ok
      end
    end

    scenario "the original successful sync entry remains visible alongside the failed duplicate" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "an initial Google Business Profile sync completes successfully", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 30,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      when_ "a duplicate sync attempt fails with a unique constraint violation", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_business,
          reason: "unique constraint violation: metrics_account_id_provider_metric_key_date_index"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "both the success entry and the failed duplicate entry are visible in sync history", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 sync history entries (one success, one failed duplicate), but found #{entry_count}"

        :ok
      end

      then_ "the success entry shows the correct record count from the original sync", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected the original successful sync entry to remain visible with success status, got: #{html}"

        assert html =~ "30",
               "Expected the original sync record count (30) to remain visible, got: #{html}"

        :ok
      end

      then_ "filtering by Failed shows only the constraint violation failure entry", context do
        html =
          context.view
          |> element("[data-role='filter-failed']", "Failed")
          |> render_click()

        assert html =~ "Failed" or html =~ "failed",
               "Expected the Failed filter to show the constraint violation failure, got: #{html}"

        assert html =~ "Google Business" or html =~ "google_business",
               "Expected the failed Google Business Profile entry to be shown in the Failed filter, got: #{html}"

        :ok
      end
    end

    scenario "the Failed filter shows the constraint violation failure with a specific error message" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile sync fails with a unique constraint violation", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_business,
          reason: "unique constraint violation: metrics_account_id_provider_metric_key_date_index"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      when_ "the user filters sync history by Failed status", context do
        context.view
        |> element("[data-role='filter-failed']", "Failed")
        |> render_click()

        {:ok, context}
      end

      then_ "the Google Business Profile constraint violation entry is visible in the failed results", context do
        html = render(context.view)

        assert html =~ "Google Business" or html =~ "google_business",
               "Expected 'Google Business' to appear in the Failed filter results, got: #{html}"

        :ok
      end

      then_ "the error details reference the unique constraint to distinguish it from a generic failure", context do
        html = render(context.view)

        assert html =~ "constraint" or html =~ "unique" or html =~ "violation",
               "Expected the unique constraint violation message to be present, distinguishing this from a generic sync failure, got: #{html}"

        :ok
      end
    end
  end
end
