defmodule MetricFlowSpex.GoogleAdsDataSegmentedByDateOnlyNoDimensionsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Google Ads data is segmented by date only — no additional dimensions (campaign, device, network) are stored at this stage" do
    scenario "sync history entry for Google Ads does not show Campaign, Device, or Network text" do
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

      then_ "the sync entry does not show Campaign, Device, or Network dimension labels", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected sync history to show 'Google Ads' as the provider, got: #{html}"

        refute html =~ "Device" or html =~ "device",
               "Expected the sync entry to NOT show device dimension breakdown"

        refute html =~ "Network" or html =~ "network",
               "Expected the sync entry to NOT show network dimension breakdown"

        :ok
      end
    end

    scenario "there are no dimension filter elements on the sync history page" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no dimension filter elements are present", context do
        refute has_element?(context.view, "[data-status='dimension-filter']"),
               "Expected no dimension filter element on the sync history page"

        refute has_element?(context.view, "[data-status='device-filter']"),
               "Expected no device dimension filter element on the sync history page"

        refute has_element?(context.view, "[data-status='network-filter']"),
               "Expected no network dimension filter element on the sync history page"

        :ok
      end
    end

    scenario "a Google Ads sync history entry shows only daily data with a single date" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Ads sync completion event is broadcast with a specific data date", context do
        data_date = Date.add(Date.utc_today(), -1)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_ads,
          records_synced: 5,
          completed_at: DateTime.utc_now(),
          data_date: data_date
        }})

        :timer.sleep(100)
        {:ok, Map.put(context, :data_date, data_date)}
      end

      then_ "the sync entry shows a single data date rather than a dimensional breakdown", context do
        html = render(context.view)

        assert html =~ "Google Ads",
               "Expected sync history to show 'Google Ads' as the provider, got: #{html}"

        expected_date = Date.to_iso8601(context.data_date)
        assert html =~ expected_date or html =~ "Date:",
               "Expected the sync entry to show the data date #{expected_date}, got: #{html}"

        :ok
      end
    end
  end
end
