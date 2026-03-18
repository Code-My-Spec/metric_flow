defmodule MetricFlowSpex.GoogleAdsSyncFailuresLoggedWithFullErrorDetailsAndSurfacedInHistorySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Sync failures are logged with full error details and surfaced in Sync Status and History" do
    scenario "a failed Google Ads sync shows in sync history with full error details" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync failure event with full error details is broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_ads,
          reason: "Google Ads API error: 403 PERMISSION_DENIED — customerId: 1234567890, errorCode: CUSTOMER_NOT_ENABLED"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a failed Google Ads entry", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected sync history to show 'Google Ads' for the failure entry, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the sync entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the full error details are visible in the history entry", context do
        html = render(context.view)

        assert html =~ "403" or html =~ "PERMISSION_DENIED" or
                 html =~ "CUSTOMER_NOT_ENABLED" or html =~ "1234567890",
               "Expected the full error details to be surfaced in sync history, got: #{html}"

        :ok
      end
    end

    scenario "multiple Google Ads sync failures all appear in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "two distinct Google Ads sync failure events are broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_ads,
          reason: "Google Ads API error: 429 RESOURCE_EXHAUSTED — quota exceeded"
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_failed, %{
          provider: :google_ads,
          reason: "Google Ads API error: 500 INTERNAL — backend error, customerId: 9999999999"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "both failed sync entries are visible in the history", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 Google Ads failure entries in sync history, but found #{entry_count}"

        :ok
      end

      then_ "the Failed filter shows only failed entries using data-status selectors", context do
        context.view
        |> element("[data-role='filter-failed']", "Failed")
        |> render_click()

        assert has_element?(context.view, "[data-status='failed']"),
               "Expected [data-status='failed'] elements to be visible after applying the Failed filter"

        refute has_element?(context.view, "[data-status='success']"),
               "Expected [data-status='success'] elements to be hidden after applying the Failed filter"

        :ok
      end
    end

    scenario "the Failed filter shows only failed entries and hides successful ones" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync failure and a success event are broadcast", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_ads,
          reason: "Google Ads API error: 503 UNAVAILABLE — transient failure"
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_ads,
          records_synced: 5,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      when_ "the user activates the Failed filter", context do
        context.view
        |> element("[data-role='filter-failed']", "Failed")
        |> render_click()

        {:ok, context}
      end

      then_ "only failed entries are shown using data-status attribute", context do
        assert has_element?(context.view, "[data-status='failed']"),
               "Expected [data-status='failed'] entries to be present after applying the Failed filter"

        refute has_element?(context.view, "[data-status='success']"),
               "Expected [data-status='success'] entries to not be shown when Failed filter is active"

        :ok
      end
    end
  end
end
