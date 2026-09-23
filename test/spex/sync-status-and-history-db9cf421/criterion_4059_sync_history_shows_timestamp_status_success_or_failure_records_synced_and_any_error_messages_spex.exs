defmodule MetricFlowSpex.SyncHistoryShowsTimestampStatusRecordsSyncedAndErrorMessagesSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Sync history shows timestamp, status, records synced, and any error messages" do
    scenario "a successful sync entry shows the completion timestamp" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a successful sync completes with a known timestamp", context do
        completed_at = ~U[2026-02-24 02:00:00Z]

        send(context.view.pid, {:sync_completed, %{
          provider: :google,
          records_synced: 150,
          completed_at: completed_at,
          data_date: ~D[2026-02-23]
        }})

        :timer.sleep(100)

        {:ok, Map.put(context, :completed_at, completed_at)}
      end

      then_ "the user sees the timestamp of when the sync completed", context do
        html = render(context.view)

        assert html =~ "Feb 24, 2026" or
                 html =~ "2026-02-24" or
                 html =~ "02:00" or
                 html =~ "Completed at",
               "Expected the sync history entry to display the completion timestamp, got: #{html}"

        :ok
      end
    end

    scenario "a successful sync entry shows the success status" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a successful sync completion message arrives", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google,
          records_synced: 200,
          completed_at: ~U[2026-02-24 02:00:00Z],
          data_date: ~D[2026-02-23]
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the user sees the success status for the sync entry", context do
        html = render(context.view)

        assert html =~ "Success" or
                 html =~ "success",
               "Expected the sync history entry to display a success status indicator, got: #{html}"

        :ok
      end

      then_ "the success entry is marked with a success status attribute", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success']"),
               "Expected a sync history entry with data-status='success' to be present"

        :ok
      end
    end

    scenario "a successful sync entry shows the number of records synced" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a successful sync arrives reporting 342 records synced", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google,
          records_synced: 342,
          completed_at: ~U[2026-02-24 02:00:00Z],
          data_date: ~D[2026-02-23]
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the user sees that 342 records were synced", context do
        html = render(context.view)

        assert html =~ "342",
               "Expected the sync history entry to display '342' records synced, got: #{html}"

        assert html =~ "records synced" or html =~ "342",
               "Expected the sync history entry to indicate records were synced, got: #{html}"

        :ok
      end
    end

    scenario "a failed sync entry shows the failure status" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a sync failure message arrives", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google,
          reason: "API rate limit exceeded"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the user sees the failure status for the sync entry", context do
        html = render(context.view)

        assert html =~ "Failed" or
                 html =~ "failed",
               "Expected the sync history entry to display a failure status indicator, got: #{html}"

        :ok
      end

      then_ "the failed entry is marked with a failed status attribute", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='failed']"),
               "Expected a sync history entry with data-status='failed' to be present"

        :ok
      end
    end

    scenario "a failed sync entry shows the error message" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a sync failure arrives with a specific error message", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google,
          reason: "OAuth token has expired and could not be refreshed"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the user sees the error message explaining why the sync failed", context do
        html = render(context.view)

        assert html =~ "OAuth token has expired" or
                 html =~ "token has expired" or
                 html =~ "could not be refreshed" or
                 html =~ "expired",
               "Expected the sync history entry to display the error message, got: #{html}"

        :ok
      end

      then_ "the error message is rendered in the designated error area", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a [data-role='sync-error'] element to display the error message"

        :ok
      end
    end

    scenario "both a successful and a failed sync entry are visible with their respective details" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a successful sync arrives for Google with 500 records", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google,
          records_synced: 500,
          completed_at: ~U[2026-02-24 02:00:00Z],
          data_date: ~D[2026-02-23]
        }})

        :timer.sleep(50)

        {:ok, context}
      end

      when_ "a failed sync arrives for Facebook Ads with an error message", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "Invalid access token"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the user sees the success status and record count for the Google sync", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success",
               "Expected the successful Google sync to show a success status, got: #{html}"

        assert html =~ "500",
               "Expected the successful Google sync to show '500' records synced, got: #{html}"

        :ok
      end

      then_ "the user sees the failure status and error message for the Facebook Ads sync", context do
        html = render(context.view)

        assert html =~ "Failed" or html =~ "failed",
               "Expected the failed Facebook Ads sync to show a failure status, got: #{html}"

        assert html =~ "Invalid access token" or
                 html =~ "access token" or
                 html =~ "Invalid",
               "Expected the failed Facebook Ads sync to show the error message, got: #{html}"

        :ok
      end
    end
  end
end
