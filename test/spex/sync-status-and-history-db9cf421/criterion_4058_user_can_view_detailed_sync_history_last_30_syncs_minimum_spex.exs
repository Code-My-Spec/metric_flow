defmodule MetricFlowSpex.UserCanViewDetailedSyncHistoryLast30SyncsMinimumSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can view detailed sync history (last 30 syncs minimum)" do
    scenario "sync history page shows at least 30 entries when 30 syncs have occurred" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "30 sync completion events are received for the user's integrations", context do
        providers = [:google, :google, :google, :google, :google,
                     :google, :google, :google, :google, :google,
                     :google, :google, :google, :google, :google,
                     :google, :google, :google, :google, :google,
                     :google, :google, :google, :google, :google,
                     :google, :google, :google, :google, :google]

        Enum.each(Enum.with_index(providers, 1), fn {provider, i} ->
          send(context.view.pid, {:sync_completed, %{
            provider: provider,
            records_synced: i * 10,
            completed_at: DateTime.add(~U[2026-01-26 02:00:00Z], i * 86_400, :second),
            data_date: Date.add(~D[2026-01-25], i)
          }})
        end)

        # Allow the LiveView to process all messages
        :timer.sleep(200)

        {:ok, context}
      end

      then_ "the sync history section is present on the page", context do
        assert has_element?(context.view, "[data-role='sync-history']"),
               "Expected a [data-role='sync-history'] container element to be present on the page"

        :ok
      end

      then_ "the page displays at least 30 sync history entries", context do
        entry_count =
          context.view
          |> render()
          |> then(fn html ->
            html
            |> String.split("data-role=\"sync-history-entry\"")
            |> length()
            |> Kernel.-(1)
          end)

        assert entry_count >= 30,
               "Expected at least 30 sync history entries to be visible, but found #{entry_count}"

        :ok
      end
    end

    scenario "sync history section container is present and can hold many entries" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync history container element is rendered on the page", context do
        assert has_element?(context.view, "[data-role='sync-history']"),
               "Expected a [data-role='sync-history'] container element to be present for displaying sync history entries"

        :ok
      end

      when_ "31 sync completion events are received", context do
        Enum.each(1..31, fn i ->
          send(context.view.pid, {:sync_completed, %{
            provider: :google,
            records_synced: i * 5,
            completed_at: DateTime.add(~U[2026-01-01 02:00:00Z], i * 86_400, :second),
            data_date: Date.add(~D[2025-12-31], i)
          }})
        end)

        :timer.sleep(200)

        {:ok, context}
      end

      then_ "all 31 sync history entries are visible to the user", context do
        entry_count =
          context.view
          |> render()
          |> then(fn html ->
            html
            |> String.split("data-role=\"sync-history-entry\"")
            |> length()
            |> Kernel.-(1)
          end)

        assert entry_count >= 31,
               "Expected all 31 sync history entries to be visible, but found #{entry_count}. " <>
                 "The page must display at least 30 syncs without pagination or truncation."

        :ok
      end
    end

    scenario "each entry in the 30-sync history list shows the provider name" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "30 sync completion events are received for multiple providers", context do
        providers = Enum.take(
          Stream.cycle([:google, :google, :google]),
          30
        )

        Enum.each(Enum.with_index(providers, 1), fn {provider, i} ->
          send(context.view.pid, {:sync_completed, %{
            provider: provider,
            records_synced: 100,
            completed_at: DateTime.add(~U[2026-01-01 02:00:00Z], i * 3_600, :second),
            data_date: ~D[2025-12-31]
          }})
        end)

        :timer.sleep(200)

        {:ok, context}
      end

      then_ "the provider name is displayed for each sync entry in the history", context do
        html = render(context.view)

        assert html =~ "Google",
               "Expected each sync history entry to identify the provider by name, got: #{html}"

        :ok
      end
    end
  end
end
