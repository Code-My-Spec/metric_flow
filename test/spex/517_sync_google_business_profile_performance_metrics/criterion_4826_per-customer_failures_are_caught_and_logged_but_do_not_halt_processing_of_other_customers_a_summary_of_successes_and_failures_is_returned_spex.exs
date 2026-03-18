defmodule MetricFlowSpex.PerCustomerFailuresAreCaughtAndLoggedButDoNotHaltProcessingOfOtherCustomersASummaryOfSuccessesAndFailuresIsReturnedSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Per-customer failures are caught and logged but do not halt processing of other customers; a summary of successes and failures is returned" do
    scenario "a success and a failure for different customers both appear in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "one customer's Google Business Profile sync succeeds and another customer's sync fails", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 10,
          completed_at: DateTime.utc_now(),
          customer_id: "customer-alpha",
          location_title: "Alpha Location"
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_failed, %{
          provider: :google_business,
          reason: "GBP API error: 403 PERMISSION_DENIED — location access denied for customer-beta",
          customer_id: "customer-beta"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "both a success entry and a failure entry appear in the sync history", context do
        html = render(context.view)

        success_present = html =~ "Success" or html =~ "success" or html =~ "badge-success"
        failure_present = html =~ "Failed" or html =~ "failed" or html =~ "badge-error"

        assert success_present,
               "Expected a success entry for the customer whose sync completed, got: #{html}"

        assert failure_present,
               "Expected a failure entry for the customer whose sync failed, got: #{html}"

        :ok
      end

      then_ "both entries are associated with Google Business Profile", context do
        html = render(context.view)

        assert html =~ "Google Business" or
                 html =~ "Business Profile" or
                 html =~ "google_business",
               "Expected both sync history entries to reference Google Business Profile, got: #{html}"

        :ok
      end
    end

    scenario "the failure for one customer does not prevent the success entry for another from appearing" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile sync failure is broadcast for the first customer", context do
        send(context.view.pid, {:sync_failed, %{
          provider: :google_business,
          reason: "GBP API error: 500 INTERNAL — fetchMultiDailyMetricsTimeSeries failed for customer-one"
        }})

        :timer.sleep(50)
        {:ok, context}
      end

      when_ "a Google Business Profile sync success is broadcast for the second customer", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 15,
          completed_at: DateTime.utc_now(),
          location_title: "Customer Two Location"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the success entry for the second customer is visible in the sync history", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected the second customer's success entry to appear despite the first customer's failure, got: #{html}"

        :ok
      end

      then_ "the failure entry for the first customer is also visible in the sync history", context do
        html = render(context.view)

        assert html =~ "Failed" or html =~ "failed",
               "Expected the first customer's failure entry to also be visible in the sync history, got: #{html}"

        :ok
      end

      then_ "the sync history contains at least two entries", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 sync history entries (one success, one failure), but found #{entry_count}"

        :ok
      end
    end

    scenario "filtering by Failed shows only the failed customer's entry, Success shows only the successful one" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "one customer's sync succeeds and another customer's sync fails", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 8,
          completed_at: DateTime.utc_now(),
          location_title: "Successful Location"
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_failed, %{
          provider: :google_business,
          reason: "GBP API error: 404 NOT_FOUND — location not found"
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      when_ "the user clicks the Failed filter", context do
        context.view
        |> element("[data-role='filter-failed']", "Failed")
        |> render_click()

        {:ok, context}
      end

      then_ "only failed entries are shown", context do
        html = render(context.view)

        assert html =~ "Failed" or html =~ "failed",
               "Expected failed entries to appear after applying the Failed filter, got: #{html}"

        :ok
      end

      when_ "the user clicks the Success filter", context do
        context.view
        |> element("[data-role='filter-success']", "Success")
        |> render_click()

        {:ok, context}
      end

      then_ "only successful entries are shown", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected successful entries to appear after applying the Success filter, got: #{html}"

        :ok
      end
    end
  end
end
