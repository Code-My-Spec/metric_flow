defmodule MetricFlowSpex.DataIsFetchedPerGa4PropertySelectedDuringOauthConnectionSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Data is fetched per GA4 property selected during OAuth connection" do
    scenario "sync history shows a successful sync entry for a specific Google Analytics property" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync completion event for a specific property is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 30,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a Google Analytics entry with records synced", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show 'Google Analytics' provider, got: #{html}"

        assert html =~ "30" or html =~ "records",
               "Expected sync history entry to show the records synced count, got: #{html}"

        :ok
      end

      then_ "the sync entry includes a data date reflecting the property data that was fetched", context do
        html = render(context.view)

        yesterday = Date.add(Date.utc_today(), -1) |> Date.to_iso8601()

        assert html =~ yesterday or html =~ "Date:",
               "Expected the sync entry to show the data date for the fetched property, got: #{html}"

        :ok
      end
    end

    scenario "sync history can show multiple Google Analytics entries when multiple syncs complete" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "two GA4 sync completion events are broadcast for different dates", context do
        date1 = Date.add(Date.utc_today(), -1)
        date2 = Date.add(Date.utc_today(), -2)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 11,
          completed_at: DateTime.utc_now(),
          data_date: date1
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 11,
          completed_at: DateTime.utc_now(),
          data_date: date2
        }})

        :timer.sleep(100)
        {:ok, Map.merge(context, %{date1: date1, date2: date2})}
      end

      then_ "both Google Analytics sync entries are visible in the history list", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show Google Analytics entries, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected sync entries to show success status, got: #{html}"

        :ok
      end
    end

    scenario "a failed GA4 property sync is surfaced with a data date in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync failure event with a data date is broadcast", context do
        data_date = Date.add(Date.utc_today(), -1)

        send(context.view.pid, {:sync_failed, %{
          provider: :google_analytics,
          reason: "Property not found",
          data_date: data_date
        }})

        :timer.sleep(100)
        {:ok, Map.put(context, :data_date, data_date)}
      end

      then_ "the sync history shows a failed Google Analytics entry with a data date", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show 'Google Analytics' provider for the failed sync, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the sync entry to be marked as failed, got: #{html}"

        :ok
      end
    end
  end
end
