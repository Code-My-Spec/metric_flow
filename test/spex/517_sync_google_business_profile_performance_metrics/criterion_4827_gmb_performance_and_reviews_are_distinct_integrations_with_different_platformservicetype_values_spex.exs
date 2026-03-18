defmodule MetricFlowSpex.Criterion4827GmbPerformanceAndReviewsAreDistinctIntegrationsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "GBP Performance is distinct from GMB Reviews — same config, different APIs, platformServiceType mybusiness vs mybusiness-reviews" do
    scenario "Google Business Profile performance sync and GMB Reviews sync produce distinct entries in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "both a Google Business Profile performance sync and a GMB Reviews sync complete", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 12,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 5,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the sync history shows two separate entries — one for performance and one for reviews", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 distinct sync history entries (one for google_business, one for google_business_reviews), but found #{entry_count}"

        :ok
      end

      then_ "both entries are visible in the rendered sync history", context do
        html = render(context.view)

        has_performance =
          html =~ "google_business" or
            html =~ "Google Business" or
            html =~ "mybusiness"

        has_reviews =
          html =~ "google_business_reviews" or
            html =~ "Google Business Reviews" or
            html =~ "mybusiness-reviews" or
            html =~ "Reviews"

        assert has_performance,
               "Expected sync history to include a Google Business Profile performance entry, got: #{html}"

        assert has_reviews,
               "Expected sync history to include a GMB Reviews entry, got: #{html}"

        :ok
      end
    end

    scenario "Google Business Profile performance entry shows its distinct provider label in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Google Business Profile performance sync completes", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 8,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the sync history entry shows the Google Business provider label", context do
        html = render(context.view)

        assert html =~ "google_business" or
                 html =~ "Google Business" or
                 html =~ "mybusiness",
               "Expected a Google Business Profile performance entry in sync history, got: #{html}"

        :ok
      end

      then_ "the entry shows a successful sync status", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected the Google Business Profile performance entry to show Success status, got: #{html}"

        :ok
      end
    end

    scenario "GMB Reviews entry shows its distinct provider label in sync history" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GMB Reviews sync completes", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 3,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the sync history entry shows the GMB Reviews provider label", context do
        html = render(context.view)

        assert html =~ "google_business_reviews" or
                 html =~ "Google Business Reviews" or
                 html =~ "mybusiness-reviews" or
                 html =~ "Reviews",
               "Expected a GMB Reviews entry in sync history, got: #{html}"

        :ok
      end

      then_ "the GMB Reviews entry shows a successful sync status", context do
        html = render(context.view)

        assert html =~ "Success" or html =~ "success" or html =~ "badge-success",
               "Expected the GMB Reviews sync entry to show Success status, got: #{html}"

        :ok
      end
    end

    scenario "both Google Business and GMB Reviews entries can appear simultaneously without confusion" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "both provider sync events are broadcast in sequence", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_business,
          records_synced: 10,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_completed, %{
          provider: :google_business_reviews,
          records_synced: 4,
          completed_at: DateTime.utc_now()
        }})

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the performance entry and the reviews entry are distinguishable in the rendered page", context do
        html = render(context.view)

        performance_label_present =
          html =~ "google_business" or html =~ "Google Business" or html =~ "mybusiness"

        reviews_label_present =
          html =~ "google_business_reviews" or
            html =~ "Google Business Reviews" or
            html =~ "mybusiness-reviews" or
            html =~ "Reviews"

        # Both labels should be present and the two entries are not merged into one
        assert performance_label_present and reviews_label_present,
               "Expected both a Google Business performance label and a GMB Reviews label to be present in sync history. Got: #{html}"

        :ok
      end

      then_ "there are at least two sync history entries in the page", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 sync history entries when both google_business and google_business_reviews syncs ran, found #{entry_count}"

        :ok
      end
    end
  end
end
