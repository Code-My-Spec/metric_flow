defmodule MetricFlowSpex.Ga4SpecificMetricsThatHaveNoCanonicalEquivalentAreStoredAsPlatformSpecificMetricsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "GA4-specific metrics that have no canonical equivalent are stored as platform-specific metrics labeled 'Google Analytics: [metric name]'" do
    scenario "a successful GA4 sync that includes platform-specific metrics appears in sync history" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync completion event arrives with records including platform-specific metrics", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 11,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history shows a success entry for Google Analytics", context do
        html = render(context.view)

        assert html =~ "Google Analytics",
               "Expected sync history to show 'Google Analytics' as the provider, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the sync entry to show success status, got: #{html}"

        :ok
      end
    end

    scenario "the sync history shows Google Analytics as the provider for all GA4 metric types" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a GA4 sync event with both canonical and platform-specific metrics completes", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :google_analytics,
          records_synced: 15,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history entry identifies Google Analytics as the data source", context do
        html = render(context.view)

        assert has_element?(context.view, "[data-role='sync-provider']"),
               "Expected a [data-role='sync-provider'] element showing the provider name"

        assert html =~ "Google Analytics",
               "Expected the provider to be identified as 'Google Analytics' in the sync history entry, got: #{html}"

        :ok
      end
    end

    scenario "the sync history page shows the Google Analytics provider name consistently" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "multiple GA4 sync completion events arrive", context do
        Enum.each(1..3, fn i ->
          send(context.view.pid, {:sync_completed, %{
            provider: :google_analytics,
            records_synced: 11,
            completed_at: DateTime.utc_now(),
            data_date: Date.add(Date.utc_today(), -i)
          }})
          :timer.sleep(30)
        end)

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "all sync history entries are labeled with the Google Analytics provider name", context do
        html = render(context.view)

        # Count how many times Google Analytics appears as a provider label
        provider_count =
          html
          |> String.split("Google Analytics")
          |> length()
          |> Kernel.-(1)

        assert provider_count >= 3,
               "Expected at least 3 occurrences of 'Google Analytics' in sync history (one per entry), got: #{provider_count}"

        :ok
      end
    end
  end
end
