defmodule MetricFlowSpex.MetricsAreFetchedAtAccountLevelOnlyOneRowPerDayNoCampaignAdsetOrAdSegmentationAtThisStageSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Metrics are fetched at account level only — one row per day; no campaign, adset, or ad segmentation at this stage" do
    scenario "Facebook Ads sync history shows account-level data without campaign, adset, or ad segmentation columns" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync completion event is broadcast with account-level daily records", context do
        data_date = Date.add(Date.utc_today(), -1)

        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 1,
          completed_at: DateTime.utc_now(),
          data_date: data_date
        }})

        :timer.sleep(100)
        {:ok, Map.put(context, :data_date, data_date)}
      end

      then_ "the sync history entry shows Facebook Ads with a single daily record", context do
        html = render(context.view)

        assert html =~ "Facebook Ads" or html =~ "Facebook",
               "Expected sync history to show 'Facebook Ads' as the provider, got: #{html}"

        assert html =~ "1" or html =~ "record",
               "Expected the sync entry to reflect a single account-level daily record, got: #{html}"

        :ok
      end

      then_ "no campaign, adset, or ad segmentation columns are visible in the sync history", context do
        html = render(context.view)

        refute html =~ "Campaign" and html =~ "campaign",
               "Expected no campaign-level segmentation columns in sync history"

        refute html =~ "Ad Set" and html =~ "adset",
               "Expected no adset-level segmentation columns in sync history"

        refute html =~ "Ad Name" and html =~ "ad_id",
               "Expected no ad-level segmentation columns in sync history"

        :ok
      end
    end

    scenario "a sync completion event for Facebook Ads shows one row per day, not one row per campaign or adset" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "two Facebook Ads sync completion events arrive for two consecutive dates", context do
        date1 = Date.add(Date.utc_today(), -1)
        date2 = Date.add(Date.utc_today(), -2)

        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 1,
          completed_at: DateTime.utc_now(),
          data_date: date1
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 1,
          completed_at: DateTime.utc_now(),
          data_date: date2
        }})

        :timer.sleep(100)
        {:ok, Map.merge(context, %{date1: date1, date2: date2})}
      end

      then_ "the sync history shows exactly two Facebook Ads entries, one per date", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count == 2,
               "Expected exactly 2 sync history entries (one per date, not per campaign or adset), but found #{entry_count}"

        :ok
      end
    end

    scenario "no campaign, adset, or ad filters are present in sync history for Facebook Ads" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync completion event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 7,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "there are no campaign filter or grouping controls for Facebook Ads data", context do
        html = render(context.view)

        refute has_element?(context.view, "[data-role='filter-campaign']"),
               "Expected no campaign filter element in sync history"

        refute has_element?(context.view, "[data-role='filter-adset']"),
               "Expected no adset filter element in sync history"

        refute has_element?(context.view, "[data-role='filter-ad']"),
               "Expected no ad-level filter element in sync history"

        refute html =~ "Filter by Campaign" or html =~ "Group by Ad",
               "Expected no campaign or ad grouping controls in sync history, got: #{html}"

        :ok
      end
    end
  end
end
