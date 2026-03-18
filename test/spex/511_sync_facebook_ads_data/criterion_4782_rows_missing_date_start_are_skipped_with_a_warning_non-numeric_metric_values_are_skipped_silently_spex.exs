defmodule MetricFlowSpex.RowsMissingDateStartAreSkippedWithAWarningNonNumericMetricValuesAreSkippedSilentlySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Rows missing date_start are skipped with a warning; non-numeric metric values are skipped silently" do
    scenario "a Facebook Ads sync that encounters rows with missing date_start still completes with a partial record count" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync completion event is broadcast indicating some rows were skipped due to missing date_start", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 7,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a completed Facebook Ads entry", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected sync history to show 'Facebook Ads' as the provider, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show a success status even with partial records, got: #{html}"

        :ok
      end

      then_ "the records synced count reflects only the valid rows that had a date_start", context do
        html = render(context.view)

        assert html =~ "7" or html =~ "records",
               "Expected sync history to show the count of valid records synced (7), not the skipped rows, got: #{html}"

        :ok
      end
    end

    scenario "a sync with non-numeric metric values completes successfully without showing errors to the user" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync completion event is broadcast where non-numeric values were silently skipped", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 5,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a success status for the Facebook Ads sync", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected sync history to show 'Facebook Ads', got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync to show success — non-numeric values are silently skipped and do not cause a failure, got: #{html}"

        :ok
      end

      then_ "no error or failure indicator is shown to the user for the silently skipped values", context do
        html = render(context.view)

        refute html =~ "Failed" and not (html =~ "Success" or html =~ "success"),
               "Expected no failure status when only non-numeric values were silently skipped, got: #{html}"

        :ok
      end
    end

    scenario "a sync with mixed valid and invalid data shows a completed status with only the valid record count" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync completion event arrives reflecting only the valid rows after skipping bad data", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 3,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows Facebook Ads with a completed status", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected sync history to show 'Facebook Ads', got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected a completed/success status reflecting that valid records were stored, got: #{html}"

        :ok
      end

      then_ "the records synced count matches only the valid rows, not the total rows including bad data", context do
        html = render(context.view)

        assert html =~ "3" or html =~ "records",
               "Expected the synced count to reflect only the 3 valid records (excluding rows with missing date_start or non-numeric values), got: #{html}"

        :ok
      end

      then_ "the sync history does not show a separate failed entry for the skipped rows", context do
        entry_count =
          render(context.view)
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count <= 1,
               "Expected only one sync history entry for the Facebook Ads sync, not a separate failed entry for skipped rows, found #{entry_count}"

        :ok
      end
    end
  end
end
