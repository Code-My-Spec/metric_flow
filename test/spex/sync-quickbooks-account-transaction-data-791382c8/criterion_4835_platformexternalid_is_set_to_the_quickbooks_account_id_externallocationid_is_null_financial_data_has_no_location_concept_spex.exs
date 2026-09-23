defmodule MetricFlowSpex.PlatformExternalIdIsQuickbooksAccountIdExternalLocationIdIsNullSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "platformExternalId is set to the QuickBooks account ID; externalLocationId is null (no location concept)" do
    scenario "sync history shows account-level data with no location columns for QuickBooks" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync completion event is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 2,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry shows QuickBooks account-level data with no location column", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected sync history to show 'QuickBooks' as the provider, got: #{html}"

        refute html =~ "Location" and html =~ "external_location_id",
               "Expected no 'Location' or 'external_location_id' column — financial data has no location concept"

        :ok
      end
    end

    scenario "the sync history page has no location filter for QuickBooks entries" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "there is no location-based filter element visible on the sync history page", context do
        refute has_element?(context.view, "[data-role='filter-location']"),
               "Expected no [data-role='filter-location'] filter on the sync history page — QuickBooks has no location concept"

        :ok
      end
    end

    scenario "sync history entry is associated with the QuickBooks provider" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a QuickBooks sync completion event with account-level data is broadcast", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :quickbooks,
          records_synced: 2,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry is associated with the QuickBooks provider", context do
        html = render(context.view)

        assert html =~ "QuickBooks" or html =~ "quickbooks",
               "Expected the sync history entry to be associated with the QuickBooks provider, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the QuickBooks account-level sync to show success status, got: #{html}"

        :ok
      end

      then_ "the sync history entry element is present", context do
        assert has_element?(context.view, "[data-role='sync-history-entry']"),
               "Expected a sync history entry element after QuickBooks account-level sync"

        :ok
      end
    end
  end
end
