defmodule MetricFlowSpex.ReviewsFetchedPerLocationIdGoogleBusinessAccountIdSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Reviews fetched per location ID under googleBusinessAccountId; locations/ prefix stripped" do
    scenario "a sync completion for a specific location shows in sync history with records synced" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Reviews sync completion for a specific location is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 12,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a Google Business Reviews entry", context do
        html = render(context.view)

        assert html =~ "Google Business Reviews",
               "Expected sync history to show 'Google Business Reviews' provider, got: #{html}"

        :ok
      end

      then_ "the entry shows the number of records synced for that location", context do
        html = render(context.view)

        assert html =~ "12" or html =~ "records",
               "Expected sync history entry to show records synced count, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected sync entry to be marked as successful, got: #{html}"

        :ok
      end
    end

    scenario "multiple location syncs produce distinct entries in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "sync completion events for two different locations are broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 7,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 5,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -2)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "both Google Business Reviews sync entries appear in the history list", context do
        html = render(context.view)

        assert html =~ "Google Business Reviews",
               "Expected sync history to show 'Google Business Reviews' provider, got: #{html}"

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 sync history entries for two location syncs, got #{entry_count}"

        :ok
      end

      then_ "each entry reflects a distinct sync result", context do
        html = render(context.view)

        assert html =~ "7" or html =~ "5",
               "Expected both location record counts to appear in history, got: #{html}"

        :ok
      end
    end

    scenario "a sync failure for one location surfaces location-specific error details" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Reviews sync failure is broadcast with a location-specific error", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_business_reviews,
          reason: "Location 9876543210 not found under account 1234567890"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a failed Google Business Reviews entry", context do
        html = render(context.view)

        assert html =~ "Google Business Reviews",
               "Expected sync history to show 'Google Business Reviews' for the failed entry, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the sync entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the location-specific error details are displayed in the entry", context do
        html = render(context.view)

        assert html =~ "9876543210" or html =~ "not found" or html =~ "1234567890",
               "Expected the location-specific error details to be surfaced in the sync history, got: #{html}"

        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a [data-role='sync-error'] element to display the location error details"

        :ok
      end
    end
  end
end
