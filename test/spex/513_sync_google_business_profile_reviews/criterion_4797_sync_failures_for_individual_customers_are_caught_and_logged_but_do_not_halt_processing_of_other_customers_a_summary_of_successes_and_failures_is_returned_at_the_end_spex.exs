defmodule MetricFlowSpex.SyncFailuresForIndividualCustomersAreCaughtAndDoNotHaltOthersSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Sync failures for individual customers are caught; a summary of successes and failures is returned" do
    scenario "a success and a failure for different customers both appear in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a sync success event is broadcast for one customer", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 15,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(50)
        {:ok, context}
      end

      when_ "a sync failure event is broadcast for a different customer", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_business_reviews,
          reason: "Location details unavailable for customer B — sync failed"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "both entries appear in the sync history", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 sync history entries (one success, one failure), but found #{entry_count}. HTML: #{html}"

        :ok
      end

      then_ "the success entry is marked as succeeded", context do
        html = render(context.view)

        assert html =~ "Success",
               "Expected a Success badge in the sync history, got: #{html}"

        :ok
      end

      then_ "the failure entry is marked as failed", context do
        html = render(context.view)

        assert html =~ "Failed",
               "Expected a Failed badge in the sync history, got: #{html}"

        :ok
      end
    end

    scenario "the failure of one customer does not prevent the success entry from appearing" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a sync failure is broadcast for the first customer", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_business_reviews,
          reason: "Google Business API error: 403 PERMISSION_DENIED for customer A"
        }})

        :timer.sleep(50)
        {:ok, context}
      end

      when_ "a sync success is broadcast for the second customer", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 8,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the success entry for the second customer is visible", context do
        html = render(context.view)

        assert html =~ "Google Business Reviews",
               "Expected 'Google Business Reviews' to appear in the sync history, got: #{html}"

        assert html =~ "Success",
               "Expected a Success entry to be visible despite the earlier failure, got: #{html}"

        :ok
      end

      then_ "the failure entry for the first customer is also visible", context do
        html = render(context.view)

        assert html =~ "Failed",
               "Expected a Failed entry for the first customer to remain visible, got: #{html}"

        :ok
      end
    end

    scenario "filtering by Failed shows only failed entries; filtering by Success shows only success entries" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page with both a success and a failure broadcast", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")

        send(view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 22,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(50)

        send(view.pid, {:sync_failed, %{
          provider: :google_business_reviews,
          reason: "Sync failed for customer C: location not found"
        }})

        :timer.sleep(100)
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the Failed filter tab", context do
        context.view
        |> element("[data-role='filter-failed']", "Failed")
        |> render_click()

        {:ok, context}
      end

      then_ "only the failed entry is shown", context do
        html = render(context.view)

        assert has_element?(context.view, "[data-status='failed']"),
               "Expected a failed entry to be visible after clicking the Failed filter"

        refute has_element?(context.view, "[data-status='success']"),
               "Expected no success entries to be visible after clicking the Failed filter"

        :ok
      end

      when_ "the user clicks the Success filter tab", context do
        context.view
        |> element("[data-role='filter-success']", "Success")
        |> render_click()

        {:ok, context}
      end

      then_ "only the success entry is shown", context do
        html = render(context.view)

        assert has_element?(context.view, "[data-status='success']"),
               "Expected a success entry to be visible after clicking the Success filter"

        refute has_element?(context.view, "[data-status='failed']"),
               "Expected no failed entries to be visible after clicking the Success filter"

        :ok
      end
    end
  end
end
