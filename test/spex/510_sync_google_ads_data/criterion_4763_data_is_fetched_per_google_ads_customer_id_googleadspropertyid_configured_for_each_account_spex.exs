defmodule MetricFlowSpex.DataIsFetchedPerGoogleAdsCustomerIdGoogleAdsPropertyIdConfiguredForEachAccountSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Data is fetched per Google Ads customer ID (googleAdsPropertyId) configured for each account" do
    scenario "a per-account Google Ads sync shows the record count for that account" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync completion event is broadcast for a specific customer account", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_ads,
          records_synced: 18,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry for Google Ads shows the number of records synced for that account", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected 'Google Ads' to appear in sync history, got: #{html}"

        assert html =~ "18",
               "Expected the per-account records synced count (18) to be visible, got: #{html}"

        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success']"),
               "Expected a successful sync history entry with data-status='success'"

        :ok
      end
    end

    scenario "multiple per-account Google Ads syncs produce distinct history entries" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "two Google Ads sync completion events are broadcast for different customer accounts", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_ads,
          records_synced: 10,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_ads,
          records_synced: 25,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "both Google Ads sync entries appear in the history list", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 sync history entries (one per customer account), but found #{entry_count}"

        :ok
      end

      then_ "the success filter shows both Google Ads entries", context do
        context.view
        |> element("[data-role='filter-success']")
        |> render_click()

        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success']"),
               "Expected successful Google Ads entries to appear after filtering by Success"

        :ok
      end
    end

    scenario "a failed Google Ads sync for one account shows an error in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync failure event is broadcast for a specific customer account", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_ads,
          reason: "Google Ads API error: CUSTOMER_NOT_FOUND — customer ID not accessible"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a failed Google Ads entry for that account", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected 'Google Ads' to appear in sync history, got: #{html}"

        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='failed']"),
               "Expected a failed sync history entry with data-status='failed'"

        :ok
      end

      then_ "the error message references the specific customer account failure", context do
        assert has_element?(context.view, "[data-role='sync-error']"),
               "Expected a [data-role='sync-error'] element to display the customer account error"

        html = render(context.view)

        assert html =~ "CUSTOMER_NOT_FOUND" or html =~ "customer ID" or html =~ "Google Ads API error",
               "Expected the customer-specific error message to be displayed, got: #{html}"

        :ok
      end
    end
  end
end
