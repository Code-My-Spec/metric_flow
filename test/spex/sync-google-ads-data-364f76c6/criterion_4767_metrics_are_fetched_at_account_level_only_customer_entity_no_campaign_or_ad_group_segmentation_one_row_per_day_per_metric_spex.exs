defmodule MetricFlowSpex.GoogleAdsMetricsFetchedAtAccountLevelOnlySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Google Ads metrics are fetched at account level only (customer entity) — one row per day per metric, no campaign or ad group segmentation" do
    scenario "sync history shows account-level Google Ads data without campaign or ad group columns" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync completion event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_ads,
          records_synced: 5,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows Google Ads without campaign or ad group breakdown", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected sync history to show 'Google Ads' as the provider, got: #{html}"

        refute html =~ "campaign" and html =~ "Campaign",
               "Expected the sync entry to NOT show campaign-level segmentation"

        refute html =~ "ad group" or html =~ "Ad Group",
               "Expected the sync entry to NOT show ad group-level segmentation"

        :ok
      end
    end

    scenario "the sync history page has no campaign or ad group filter elements" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "there are no campaign or ad group filter elements on the page", context do
        refute has_element?(context.view, "[data-status='campaign-filter']"),
               "Expected no campaign filter element on the sync history page"

        refute has_element?(context.view, "[data-status='ad-group-filter']"),
               "Expected no ad group filter element on the sync history page"

        :ok
      end
    end

    scenario "two Google Ads sync events for two different dates each appear as a separate entry" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "two Google Ads sync completion events arrive for two consecutive dates", context do
        date1 = Date.add(Date.utc_today(), -1)
        date2 = Date.add(Date.utc_today(), -2)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_ads,
          records_synced: 5,
          completed_at: DateTime.utc_now(),
          data_date: date1
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_ads,
          records_synced: 5,
          completed_at: DateTime.utc_now(),
          data_date: date2
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows exactly two Google Ads entries, one per date", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count == 2,
               "Expected exactly 2 sync history entries (one per date, not per campaign/ad group), but found #{entry_count}"

        :ok
      end
    end
  end
end
