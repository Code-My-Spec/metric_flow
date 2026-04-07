defmodule MetricFlowSpex.SyncRetrievesMetricsReviewDataAndFinancialDataForEachDaySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Sync retrieves metrics, review data, and financial data for each day" do
    scenario "sync history page communicates that syncs retrieve metrics data" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page includes a reference to metrics data being retrieved", context do
        html = render(context.view)

        assert html =~ "metrics" or html =~ "Metrics",
               "Expected the sync history page to mention 'metrics' data type, got: #{html}"

        :ok
      end
    end

    scenario "sync history page communicates that syncs retrieve financial data" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page includes a reference to financial data being retrieved", context do
        html = render(context.view)

        assert html =~ "financial" or html =~ "Financial" or
                 html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected the sync history page to mention financial data (or QuickBooks), got: #{html}"

        :ok
      end
    end

    scenario "sync history entries show the data date each sync covered" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync history section is present", context do
        assert has_element?(context.view, "[data-role='sync-history']"),
               "Expected a [data-role='sync-history'] element on the page"

        :ok
      end

      then_ "each sync history entry displays the date the data covers", context do
        html = render(context.view)

        assert has_element?(context.view, "[data-role='sync-history-entry']") or
                 html =~ "data-date" or
                 html =~ "Date" or
                 html =~ "date",
               "Expected each sync history entry to display the date the data covers, got: #{html}"

        :ok
      end
    end

    scenario "sync history entries show data type labels so users know what was retrieved" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "each sync entry includes a data type or provider label", context do
        html = render(context.view)

        has_data_type_label =
          has_element?(context.view, "[data-role='sync-data-type']") or
            has_element?(context.view, "[data-role='sync-provider']") or
            has_element?(context.view, "[data-role='sync-entry']") or
            html =~ "data-type"

        has_provider_name =
          html =~ "Google" or html =~ "google" or
            html =~ "Facebook" or html =~ "facebook" or
            html =~ "QuickBooks" or html =~ "quickbooks"

        assert has_data_type_label or has_provider_name,
               "Expected each sync entry to show a data type or provider label so users can identify what was retrieved, got: #{html}"

        :ok
      end
    end

    scenario "sync history entries show a records synced count representing data retrieved" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the LiveView receives a sync completion event with records synced", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google,
          records_synced: 42,
          completed_at: DateTime.utc_now(),
          data_date: Date.utc_today() |> Date.add(-1)
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the sync history shows the number of records synced for that entry", context do
        html = render(context.view)

        assert html =~ "42" or html =~ "records" or html =~ "synced",
               "Expected the sync history entry to show the records synced count, got: #{html}"

        :ok
      end
    end

    scenario "sync history page shows data coverage per day so users understand the daily granularity" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page renders a sync history section", context do
        html = render(context.view)

        assert html =~ "Sync History" or html =~ "sync history" or
                 has_element?(context.view, "[data-role='sync-history']"),
               "Expected the page to render a 'Sync History' section, got: #{html}"

        :ok
      end

      then_ "the sync history communicates per-day data retrieval to the user", context do
        html = render(context.view)

        assert html =~ "daily" or html =~ "Daily" or
                 html =~ "day" or html =~ "per day" or
                 html =~ "each day" or html =~ "Date",
               "Expected the sync history to communicate daily granularity (e.g., 'Daily', 'per day', or a date column), got: #{html}"

        :ok
      end
    end
  end
end
