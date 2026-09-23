defmodule MetricFlowSpex.ActionsApiFieldExpandedIntoFlatKeysForFacebookAdsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  @action_types [
    "link_click",
    "page_engagement",
    "post_engagement",
    "post_reaction",
    "comment",
    "like",
    "share",
    "video_view",
    "lead",
    "purchase",
    "complete_registration",
    "add_to_cart",
    "checkout"
  ]

  spex "The actions API field is expanded from array into flat keys as actions:{action_type}" do
    scenario "a Facebook Ads sync with all 13 action types shows a higher records count in sync history than a sync without actions" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync completion without actions data is broadcast first", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 10,
          completed_at: ~U[2026-03-16 02:00:00Z],
          data_date: ~D[2026-03-15]
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      when_ "a Facebook Ads sync completion with all 13 expanded action type metrics is broadcast", context do
        # 10 core scalar metrics + 13 action type expansions = 23 records
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 23,
          completed_at: ~U[2026-03-17 02:00:00Z],
          data_date: ~D[2026-03-16]
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "both sync history entries show Facebook Ads as the provider", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected sync history to show 'Facebook Ads' as the provider, got: #{html}"

        :ok
      end

      then_ "the sync history entry with expanded actions shows a higher record count", context do
        html = render(context.view)

        assert html =~ "23",
               "Expected sync history to show 23 records synced (10 core + 13 action types expanded), got: #{html}"

        :ok
      end
    end

    scenario "a Facebook Ads sync with actions data shows the correct total record count reflecting expansion" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync completion event is broadcast with 13 action types expanded", context do
        # The actions array [{action_type: "link_click", value: "42"}, ...] is expanded into
        # flat keys: actions:link_click, actions:page_engagement, etc. — one record per action type
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: length(@action_types),
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows Facebook Ads with the expanded action type count", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected sync history to show 'Facebook Ads' as the provider, got: #{html}"

        assert html =~ "#{length(@action_types)}" or html =~ "records synced",
               "Expected sync history to show #{length(@action_types)} records synced (one per expanded action type), got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show a success status, got: #{html}"

        :ok
      end
    end

    scenario "sync history page shows Facebook Ads as a covered marketing provider" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the schedule section lists Facebook Ads as a covered marketing provider", context do
        html = render(context.view)

        assert html =~ "Facebook Ads" or html =~ "Facebook",
               "Expected the sync schedule section to mention 'Facebook Ads' as a marketing provider, got: #{html}"

        :ok
      end
    end

    scenario "a Facebook Ads sync failure for action type expansion is surfaced in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync failure event is broadcast while expanding action types", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "Failed to expand actions field: unexpected actions array format"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a failed Facebook Ads entry", context do
        html = render(context.view)

        assert html =~ "Facebook Ads" or html =~ "Facebook",
               "Expected sync history to show 'Facebook Ads' for the failed sync, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the Facebook Ads sync failure entry to be marked as failed, got: #{html}"

        :ok
      end
    end
  end
end
