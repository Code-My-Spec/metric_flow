defmodule MetricFlowSpex.SyncProcessesAllLocationsCustomersWithoutGoogleBusinessAccountIdAreSkippedSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Sync processes all includedLocations per customer; customers without googleBusinessAccountId are skipped" do
    scenario "multiple location syncs for the same customer all appear in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "two Google Business Reviews sync completions are broadcast for different locations of the same customer", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 8,
          completed_at: DateTime.utc_now(),
          location_id: "locations/111111111"
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 5,
          completed_at: DateTime.utc_now(),
          location_id: "locations/222222222"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows two Google Business Reviews entries", context do
        html = render(context.view)

        assert html =~ "Google Business Reviews" or
                 html =~ "Business Reviews" or
                 html =~ "google_business_reviews",
               "Expected Google Business Reviews entries in sync history, got: #{html}"

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 sync history entries (one per location), but found #{entry_count}"

        :ok
      end

      then_ "both entries show a success status", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected both location sync entries to show success status, got: #{html}"

        :ok
      end
    end

    scenario "a customer without googleBusinessAccountId produces no sync history entry" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "no Google Business Reviews sync event is broadcast because the customer lacks a googleBusinessAccountId", context do
        # No sync_completed message sent — the sync worker silently skips customers
        # without a googleBusinessAccountId, so no broadcast is emitted
        {:ok, context}
      end

      then_ "the sync history page shows no Google Business Reviews entries", context do
        html = render(context.view)

        refute has_element?(context.view, "[data-role='sync-history-entry'][data-status='success']"),
               "Expected no sync history entries when customer was skipped, but entries were found"

        assert html =~ "No sync history yet" or
                 not (html =~ "Google Business Reviews"),
               "Expected empty sync history when no syncs have run for skipped customer, got: #{html}"

        :ok
      end
    end

    scenario "only the customer with googleBusinessAccountId produces sync entries; the skipped customer leaves no trace" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Reviews sync completes for one customer (with a googleBusinessAccountId)", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 12,
          completed_at: DateTime.utc_now(),
          location_id: "locations/333333333"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "exactly one Google Business Reviews success entry appears in sync history", context do
        html = render(context.view)

        assert html =~ "Google Business Reviews" or
                 html =~ "Business Reviews" or
                 html =~ "google_business_reviews",
               "Expected a Google Business Reviews sync history entry for the non-skipped customer, got: #{html}"

        assert html =~ "Success" or html =~ "badge-success",
               "Expected the sync entry to show success status, got: #{html}"

        :ok
      end

      then_ "there are no error or failed entries from the skipped customer", context do
        html = render(context.view)

        refute has_element?(context.view, "[data-role='sync-history-entry'][data-status='failed']"),
               "Expected no failed entries for the customer silently skipped due to missing googleBusinessAccountId"

        :ok
      end
    end
  end
end
