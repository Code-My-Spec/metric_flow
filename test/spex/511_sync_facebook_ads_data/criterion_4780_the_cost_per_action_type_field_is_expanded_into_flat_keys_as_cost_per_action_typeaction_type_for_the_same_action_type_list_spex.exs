defmodule MetricFlowSpex.CostPerActionTypeFieldExpandedIntoFlatKeysSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  @cost_per_action_type_count 13

  spex "The 'cost_per_action_type' field is expanded into flat keys as 'cost_per_action_type:{action_type}' for the same action type list" do
    scenario "a Facebook Ads sync completion with cost_per_action_type metrics shows the expanded count in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync completion event is broadcast including cost_per_action_type expanded metrics", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: @cost_per_action_type_count,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows Facebook Ads with the expanded cost_per_action_type records synced", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected sync history to show 'Facebook Ads' as the provider, got: #{html}"

        assert html =~ "#{@cost_per_action_type_count}" or html =~ "records synced",
               "Expected sync history to show #{@cost_per_action_type_count} records synced (one per cost_per_action_type expanded key), got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show a success status, got: #{html}"

        :ok
      end
    end

    scenario "the sync history entry for Facebook Ads confirms cost metrics were synced alongside action metrics" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync completion event is broadcast reflecting both actions and cost_per_action_type metrics", context do
        total_records = @cost_per_action_type_count * 2

        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: total_records,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, Map.put(context, :total_records, total_records)}
      end

      then_ "the sync history entry reflects both the actions and cost_per_action_type expanded record counts", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected sync history to show 'Facebook Ads' as the provider, got: #{html}"

        assert html =~ "#{context.total_records}" or html =~ "records synced",
               "Expected sync history to show #{context.total_records} records synced (actions + cost_per_action_type expanded keys), got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show a success status, got: #{html}"

        :ok
      end
    end

    scenario "a failed sync that errors during cost_per_action_type expansion shows appropriate error details" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync failure event is broadcast due to an error during cost_per_action_type expansion", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "Failed to expand cost_per_action_type field: unexpected nested structure"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a failed Facebook Ads entry", context do
        html = render(context.view)

        assert html =~ "Facebook Ads" or html =~ "Facebook",
               "Expected the failed sync entry to show 'Facebook Ads' as the provider, got: #{html}"

        assert html =~ "Failed" or html =~ "failed",
               "Expected the sync entry to be marked as failed, got: #{html}"

        :ok
      end

      then_ "the error details reference the cost_per_action_type expansion failure", context do
        html = render(context.view)

        assert html =~ "cost_per_action_type" or html =~ "expand" or html =~ "error",
               "Expected the failure reason to mention the cost_per_action_type expansion error, got: #{html}"

        :ok
      end
    end
  end
end
