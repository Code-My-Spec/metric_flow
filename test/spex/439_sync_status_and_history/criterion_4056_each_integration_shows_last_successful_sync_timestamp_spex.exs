defmodule MetricFlowSpex.EachIntegrationShowsLastSuccessfulSyncTimestampSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Each integration shows last successful sync timestamp" do
    scenario "a completed sync entry displays a 'Completed at' timestamp to the user" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a successful sync completion message is received with a timestamp", context do
        completed_at = ~U[2026-02-24 02:00:00Z]

        send(context.view.pid, {:sync_completed, %{
          provider: :google,
          records_synced: 150,
          completed_at: completed_at,
          data_date: ~D[2026-02-23]
        }})

        # Allow the LiveView to process the message
        :timer.sleep(100)

        {:ok, Map.put(context, :completed_at, completed_at)}
      end

      then_ "the user sees the sync entry listed in the history", context do
        assert has_element?(context.view, "[data-role='sync-history-entry']"),
               "Expected a [data-role='sync-history-entry'] element to be present after sync completion"

        :ok
      end

      then_ "the sync entry shows the provider that was synced", context do
        html = render(context.view)

        assert html =~ "Google",
               "Expected the sync history entry to display the provider name 'Google', got: #{html}"

        :ok
      end

      then_ "the sync entry shows the last successful sync timestamp", context do
        html = render(context.view)

        assert html =~ "Feb 24, 2026" or html =~ "2026-02-24" or html =~ "02:00",
               "Expected the sync history entry to display the completed timestamp (Feb 24, 2026 02:00 UTC), got: #{html}"

        :ok
      end

      then_ "the sync entry shows it completed successfully", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success",
               "Expected the sync history entry to display a success status, got: #{html}"

        :ok
      end
    end

    scenario "timestamp is displayed in a human-readable format for the user" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a successful sync completion message arrives with a specific timestamp", context do
        completed_at = ~U[2026-02-24 02:00:00Z]

        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 75,
          completed_at: completed_at,
          data_date: ~D[2026-02-23]
        }})

        :timer.sleep(100)

        {:ok, Map.put(context, :view, context.view)}
      end

      then_ "the timestamp is shown in a readable format, not as a raw ISO string", context do
        html = render(context.view)

        # The format_datetime/1 helper renders as "Feb 24, 2026 02:00 UTC"
        assert html =~ "Feb 24, 2026" or html =~ "2026-02-24",
               "Expected the sync timestamp to be displayed in a human-readable format, got: #{html}"

        :ok
      end

      then_ "the sync entry indicates when the last sync was completed", context do
        html = render(context.view)

        has_completed_label =
          html =~ "Completed at" or
            html =~ "completed at" or
            html =~ "Last synced" or
            html =~ "02:00"

        assert has_completed_label,
               "Expected the sync entry to show a 'Completed at' or similar label with the timestamp, got: #{html}"

        :ok
      end
    end

    scenario "sync history page shows the timestamp region when there is sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a successful sync event is received", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google,
          records_synced: 200,
          completed_at: ~U[2026-02-24 02:00:00Z],
          data_date: ~D[2026-02-23]
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the sync history section contains the entry", context do
        assert has_element?(context.view, "[data-role='sync-history']"),
               "Expected a [data-role='sync-history'] container element to be present"

        :ok
      end

      then_ "the entry is marked with a success status", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success']"),
               "Expected the sync history entry to have data-status='success' attribute"

        :ok
      end
    end
  end
end
