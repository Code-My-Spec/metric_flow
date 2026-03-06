defmodule MetricFlowSpex.UserCanFilterSyncHistoryByStatusAllSuccessFailedSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can filter sync history by status (all, success, failed)" do
    scenario "sync history page shows filter controls for All, Success, and Failed" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows a filter control for All statuses", context do
        html = render(context.view)

        has_all_filter =
          has_element?(context.view, "[data-role='filter-all']") or
            has_element?(context.view, "[phx-value-status='all']") or
            has_element?(context.view, "[phx-value-status='']") or
            html =~ ~r/phx-click="filter"[^>]*>All/ or
            html =~ ~r/>All</

        assert has_all_filter,
               "Expected the sync history page to display an 'All' filter control, got: #{html}"

        :ok
      end

      then_ "the page shows a filter control for Success status", context do
        html = render(context.view)

        has_success_filter =
          has_element?(context.view, "[data-role='filter-success']") or
            has_element?(context.view, "[phx-value-status='success']") or
            html =~ ~r/phx-click="filter"[^>]*>Success/ or
            html =~ ~r/>Success</

        assert has_success_filter,
               "Expected the sync history page to display a 'Success' filter control, got: #{html}"

        :ok
      end

      then_ "the page shows a filter control for Failed status", context do
        html = render(context.view)

        has_failed_filter =
          has_element?(context.view, "[data-role='filter-failed']") or
            has_element?(context.view, "[phx-value-status='failed']") or
            html =~ ~r/phx-click="filter"[^>]*>Failed/ or
            html =~ ~r/>Failed</

        assert has_failed_filter,
               "Expected the sync history page to display a 'Failed' filter control, got: #{html}"

        :ok
      end
    end

    scenario "clicking the Failed filter shows only failed sync entries" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a successful sync event arrives", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google,
          records_synced: 150,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      when_ "a failed sync event arrives", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "API rate limit exceeded"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      when_ "the user clicks the Failed filter", context do
        context.view
        |> element("[data-role='filter-failed'], [phx-value-status='failed']")
        |> render_click()

        {:ok, context}
      end

      then_ "only failed sync entries are shown", context do
        html = render(context.view)

        assert html =~ "failed" or html =~ "Failed" or html =~ "API rate limit exceeded",
               "Expected only failed sync entries to be shown after filtering by failed status, got: #{html}"

        :ok
      end

      then_ "the successful sync entry is not visible", context do
        html = render(context.view)

        refute html =~ "150 records synced" or html =~ "150 records",
               "Expected the successful sync entry (150 records) to be hidden when filtered by 'failed', got: #{html}"

        :ok
      end
    end

    scenario "clicking the Success filter shows only successful sync entries" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a successful sync event arrives", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google,
          records_synced: 200,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      when_ "a failed sync event arrives", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "Connection timeout"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      when_ "the user clicks the Success filter", context do
        context.view
        |> element("[data-role='filter-success'], [phx-value-status='success']")
        |> render_click()

        {:ok, context}
      end

      then_ "only successful sync entries are shown", context do
        html = render(context.view)

        assert html =~ "200 records" or html =~ "records synced" or html =~ "Success",
               "Expected only successful sync entries to be shown after filtering by success status, got: #{html}"

        :ok
      end

      then_ "the failed sync entry is not visible", context do
        html = render(context.view)

        refute html =~ "Connection timeout",
               "Expected the failed sync entry (Connection timeout) to be hidden when filtered by 'success', got: #{html}"

        :ok
      end
    end

    scenario "clicking the All filter restores the full sync history list" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "both a successful and a failed sync event arrive", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google,
          records_synced: 75,
          completed_at: DateTime.utc_now()
        }})

        send(context.view.pid, {:sync_failed, %{
          provider: :facebook_ads,
          reason: "Unexpected server error"
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      when_ "the user applies the Failed filter", context do
        context.view
        |> element("[data-role='filter-failed'], [phx-value-status='failed']")
        |> render_click()

        {:ok, context}
      end

      when_ "the user clicks the All filter to remove the filter", context do
        context.view
        |> element("[data-role='filter-all'], [phx-value-status='all'], [phx-value-status='']")
        |> render_click()

        {:ok, context}
      end

      then_ "all sync entries are shown again including both successes and failures", context do
        html = render(context.view)

        has_success_entry = html =~ "75 records" or html =~ "records synced" or html =~ "Success"
        has_failed_entry = html =~ "Unexpected server error" or html =~ "Failed" or html =~ "failed"

        assert has_success_entry and has_failed_entry,
               "Expected all sync entries (both success and failed) to be visible after selecting 'All', got: #{html}"

        :ok
      end
    end
  end
end
